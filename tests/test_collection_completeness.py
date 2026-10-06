"""Read-only audit contract tests; no credentials, network, or S3 writes."""
from dataclasses import replace
from datetime import datetime, timedelta, timezone
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[1] / 'lib/check_collection_completeness.py'
spec = importlib.util.spec_from_file_location('collection_audit', MODULE)
audit = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = audit
spec.loader.exec_module(audit)
NOW = datetime(2026, 1, 1, tzinfo=timezone.utc)
ISSUE = 'issues/P-1900-issues.jsonl.bz2'
PAGE = 'pages/P-1900/P-1900-01-01-a-pages.jsonl.bz2'
AUDIO = 'audios/P-1900/P-1900-01-01-a-audios.jsonl.bz2'
CONFIG = audit.Config('input', 'output', 'v1', True, 's3://enrichment/langident/run', concurrency=2)


class S3Error(Exception):
    def __init__(self, code):
        self.response = {'Error': {'Code': code}}
        super().__init__(code)


class FakeS3:
    """Only exposes listing: any attempt to mutate S3 fails the test."""
    def __init__(self, page_size=100):
        self.objects = {}
        self.calls = []
        self.page_size = page_size
        self.failures = {}

    def put_fixture(self, bucket, key, size=10, age=0):
        self.objects[bucket, key] = {'Key': key, 'Size': size,
                                     'LastModified': NOW - timedelta(hours=age)}

    def list_objects_v2(self, Bucket, Prefix, ContinuationToken=None):
        self.calls.append((Bucket, Prefix, ContinuationToken))
        fault = self.failures.get((Bucket, Prefix, ContinuationToken), [])
        if fault:
            raise fault.pop(0)
        objects = [value for (bucket, key), value in sorted(self.objects.items())
                   if bucket == Bucket and key.startswith(Prefix)]
        start = int(ContinuationToken or 0)
        end = start + self.page_size
        return {'Contents': objects[start:end], 'IsTruncated': end < len(objects),
                'NextContinuationToken': str(end)}


class AuditTests(unittest.TestCase):
    def setUp(self):
        self.client = FakeS3()

    def source(self, relative, **kwargs):
        self.client.put_fixture('input', 'BL/P/' + relative, **kwargs)

    def output(self, relative, **kwargs):
        self.client.put_fixture('output', 'v1/BL/P/' + relative, **kwargs)

    def complete(self, content=PAGE):
        for key in (ISSUE, content):
            self.source(key)
            self.output(key)
        self.client.put_fixture('enrichment', 'langident/run/BL/P/P-1900.jsonl.bz2')

    def run_audit(self, config=CONFIG, entries=('BL/P',)):
        scopes = audit.normalize_scopes(entries, config.has_provider)
        return audit.audit_collection(self.client, config, scopes, entries, NOW, 'test-id')

    def test_complete_and_deterministic_reports(self):
        self.complete()
        first = self.run_audit()
        self.assertEqual(first, self.run_audit())
        self.assertEqual(first['exit_code'], 0)
        self.assertEqual(sum(first['status_counts'].values()), 1)
        with tempfile.TemporaryDirectory() as directory:
            audit.write_reports(first, directory)
            files = {p.name: p.read_bytes() for p in Path(directory).iterdir()}
            audit.write_reports(first, directory)
            self.assertEqual(files, {p.name: p.read_bytes() for p in Path(directory).iterdir()})
            self.assertEqual(json.loads(files['report_complete.json'])['audit_id'], 'test-id')
            self.assertEqual(files['newspapers_rerun.txt'], b'')

    def test_999_of_1000_and_extra_does_not_compensate(self):
        for index in range(1000):
            key = f'pages/P-1900/page-{index:04}.jsonl.bz2'
            self.source(key)
            if index < 999:
                self.output(key)
        self.output('pages/P-1900/extra.jsonl.bz2')
        report = self.run_audit(replace(CONFIG, check_streams=('pages',)))
        item = report['items'][0]
        detail = item['streams']['pages']
        self.assertEqual(item['status'], 'INCOMPLETE')
        self.assertEqual(detail['coverage_percent'], 99.9)
        self.assertEqual(len(detail['missing']), 1)
        self.assertEqual(len(detail['unexpected']), 1)
        self.assertTrue(item['repair_candidate'])
        self.assertFalse(item['rerun_eligible'])
        self.assertTrue(any(call[2] for call in self.client.calls))

    def test_stream_divergence(self):
        for absent in (ISSUE, PAGE, AUDIO):
            with self.subTest(absent=absent):
                self.client = FakeS3()
                self.complete()
                self.source(AUDIO)
                self.output(AUDIO)
                del self.client.objects['output', 'v1/BL/P/' + absent]
                report = self.run_audit()
                self.assertEqual(report['items'][0]['status'], 'INCOMPLETE')
                self.assertEqual(report['exit_code'], 1)

    def test_audio_auto_and_explicit_missing_stream(self):
        self.complete(AUDIO)
        item = self.run_audit()['items'][0]
        self.assertEqual(item['selected_streams'], ['issues', 'audios'])
        self.assertEqual(item['inapplicable_streams'], ['pages'])
        self.assertEqual(item['status'], 'COMPLETE')
        item = self.run_audit(replace(CONFIG, check_streams=('issues', 'pages', 'audios')))['items'][0]
        self.assertEqual(item['status'], 'INCOMPLETE')
        self.assertTrue(item['upstream_blockers'])

    def test_explicit_input_kind_does_not_scan_excluded_stream(self):
        self.complete()
        self.client.failures['input', 'BL/P/audios/', None] = [S3Error('AccessDenied')]
        self.assertEqual(self.run_audit(replace(CONFIG, canonical_input_kind='pages'))['exit_code'], 0)
        self.assertFalse(any(call[1].endswith('/audios/') for call in self.client.calls))

    def test_pages_only_needs_no_issue_or_enrichment(self):
        self.source(PAGE)
        self.output(PAGE)
        report = self.run_audit(replace(CONFIG, check_streams=('pages',), langident_root=None))
        self.assertEqual(report['exit_code'], 0)
        self.assertFalse(any(call[0] == 'enrichment' for call in self.client.calls))

    def test_missing_only_logs_locks_markers_and_unexpected_outputs(self):
        self.source(PAGE)
        for key in (PAGE + '.log.gz', 'pages/P-1900/', 'pages/P-1901/extra.jsonl.bz2'):
            self.output(key)
        self.output(PAGE + '.wip', age=25)
        item = self.run_audit(replace(CONFIG, check_streams=('pages',)))['items'][0]
        self.assertEqual(item['status'], 'MISSING')
        self.assertEqual(item['streams']['pages']['present'], 0)

    def test_zero_byte_source_and_output(self):
        self.source(PAGE)
        self.output(PAGE, size=0)
        config = replace(CONFIG, check_streams=('pages',))
        item = self.run_audit(config)['items'][0]
        self.assertEqual(item['status'], 'INCOMPLETE')
        self.assertEqual(item['streams']['pages']['covered'], 0)
        self.assertTrue(item['repair_candidate'])
        self.source(PAGE, size=0)
        self.output(PAGE)
        item = self.run_audit(config)['items'][0]
        self.assertEqual(item['status'], 'INCOMPLETE')
        self.assertFalse(item['repair_candidate'])
        self.assertTrue(item['streams']['pages']['invalid_source'])

    def test_missing_prerequisites_keep_expected_issues(self):
        self.source(ISSUE)
        self.output(ISSUE)
        item = self.run_audit()['items'][0]
        self.assertEqual(item['status'], 'INCOMPLETE')
        self.assertEqual(item['streams']['issues']['expected'], 1)
        self.assertEqual(len(item['upstream_blockers']), 2)
        self.assertFalse(item['repair_candidate'])

    def test_content_without_issues_is_upstream_blocker(self):
        self.source(PAGE)
        self.output(PAGE)
        item = self.run_audit()['items'][0]
        self.assertEqual(item['status'], 'INCOMPLETE')
        self.assertTrue(any('without canonical issues' in s for s in item['upstream_blockers']))

    def test_empty_and_requested_year(self):
        report = self.run_audit(entries=('BL/P/1900',))
        self.assertEqual(report['exit_code'], 1)
        item = report['items'][0]
        self.assertEqual(item['status'], 'EMPTY_INPUT')
        self.assertIn('1900: requested year absent upstream', item['upstream_blockers'])

    def test_year_filter_applies_to_output_and_locks(self):
        self.complete()
        self.output('issues/P-1901-issues.jsonl.bz2.wip')
        self.output('pages/P-1901/page.jsonl.bz2', size=0)
        report = self.run_audit(entries=('BL/P/1900',))
        self.assertEqual(report['exit_code'], 0)
        self.assertFalse(report['items'][0]['active_locks'])
        self.assertFalse(report['items'][0]['streams']['pages']['unexpected'])

    def test_active_stale_threshold_and_future_locks(self):
        self.complete()
        for age, expected in ((0, 1), (24, 1), (24.01, 0), (-1, 1)):
            with self.subTest(age=age):
                self.output(ISSUE + '.wip', age=age)
                report = self.run_audit()
                self.assertEqual(report['items'][0]['status'], 'COMPLETE')
                self.assertEqual(report['exit_code'], expected)
        del self.client.objects['output', 'v1/BL/P/' + PAGE]
        self.output(ISSUE + '.wip', age=0)
        self.assertFalse(self.run_audit()['items'][0]['repair_candidate'])

    def test_partial_listing_failure_is_not_partial_success(self):
        self.client.page_size = 1
        self.source(PAGE)
        self.source('pages/P-1900/second.jsonl.bz2')
        self.client.failures['input', 'BL/P/pages/', '1'] = [S3Error('AccessDenied')]
        report = self.run_audit(replace(CONFIG, check_streams=('pages',)))
        self.assertEqual(report['exit_code'], 2)
        self.assertEqual(report['items'][0]['status'], 'AUDIT_ERROR')
        self.assertEqual(report['items'][0]['streams'], {})

    @patch.object(audit.time, 'sleep')
    def test_transient_retry_and_exhaustion(self, sleep):
        self.complete()
        fault = ('input', 'BL/P/issues/', None)
        self.client.failures[fault] = [S3Error('SlowDown')]
        self.assertEqual(self.run_audit()['exit_code'], 0)
        sleep.assert_called_once()
        self.client.failures[fault] = [S3Error('ServiceUnavailable')] * 3
        self.assertEqual(self.run_audit()['exit_code'], 2)

    def test_providerless(self):
        for bucket, prefix in (('input', 'P/'), ('output', 'v1/P/')):
            self.client.put_fixture(bucket, prefix + PAGE)
        config = replace(CONFIG, has_provider=False, check_streams=('pages',), langident_root=None)
        self.assertEqual(self.run_audit(config, ('P',))['exit_code'], 0)

    def test_overlapping_scopes_and_validation(self):
        scopes = audit.normalize_scopes(['BL/P/1901', 'BL/P/1900', 'BL/P/1900'], True)
        self.assertEqual(scopes, [audit.Scope('BL/P', ('1900', '1901'))])
        self.assertEqual(audit.normalize_scopes(['BL/P', 'BL/P/1900'], True), [audit.Scope('BL/P')])
        self.assertEqual(audit.normalize_scopes(['P'], True, 'BL'), [audit.Scope('BL/P')])
        for entries, mode in ((['P/1900'], False), (['BL/P/no'], True), (['P'], True),
                              (['BL/../1900'], True), (['BL/P/1900/more'], True), ([], True)):
            with self.subTest(entries=entries), self.assertRaises(ValueError):
                audit.normalize_scopes(entries, mode)
        for config in (replace(CONFIG, task='langident'), replace(CONFIG, concurrency=0),
                       replace(CONFIG, wip_max_age=float('nan')), replace(CONFIG, langident_root=None),
                       replace(CONFIG, check_streams=('bogus',)), replace(CONFIG, run_version='../v1')):
            with self.subTest(config=config), self.assertRaises(ValueError):
                config.validate()

    def test_report_failure_removes_marker_and_stale_rerun_list(self):
        self.complete()
        report = self.run_audit()
        with tempfile.TemporaryDirectory() as directory:
            audit.write_reports(report, directory)
            rerun = Path(directory) / 'newspapers_rerun.txt'
            rerun.write_text('stale\n')
            with patch.object(audit.json, 'dumps', side_effect=OSError('disk full')):
                with self.assertRaises(OSError):
                    audit.write_reports(report, directory)
            self.assertFalse((Path(directory) / 'report_complete.json').exists())
            self.assertFalse(rerun.exists())

    def test_multiple_items_error_takes_precedence(self):
        self.complete()
        self.client.failures['input', 'BL/Q/issues/', None] = [S3Error('AccessDenied')]
        report = self.run_audit(entries=('BL/P', 'BL/Q'))
        self.assertEqual(report['exit_code'], 2)
        self.assertEqual(report['status_counts']['COMPLETE'], 1)
        self.assertEqual(report['status_counts']['AUDIT_ERROR'], 1)

    def test_metadata_and_pagination_corruption_are_errors(self):
        config = replace(CONFIG, check_streams=('pages',))
        self.source(PAGE)
        del self.client.objects['input', 'BL/P/' + PAGE]['LastModified']
        self.assertEqual(self.run_audit(config)['exit_code'], 2)
        with patch.object(self.client, 'list_objects_v2', return_value={'IsTruncated': True}):
            self.assertEqual(self.run_audit(config)['exit_code'], 2)

    def test_zero_byte_prerequisite_in_issues_only_audit(self):
        self.complete()
        self.source('pages/P-1900/bad.jsonl.bz2', size=0)
        report = self.run_audit(replace(CONFIG, check_streams=('issues',)))
        self.assertEqual(report['exit_code'], 1)
        self.assertTrue(report['items'][0]['upstream_blockers'])

    def test_cli_years_and_whitespace_collection(self):
        with tempfile.TemporaryDirectory() as directory:
            argv = ['--task', 'consolidatedcanonical', '--canonical-bucket', 'input',
                    '--consolidated-bucket', 'output', '--run-version', 'v1', '--has-provider', '1',
                    '--check-streams', 'pages', '--output-dir', directory]
            self.source(PAGE)
            self.output(PAGE)
            self.assertEqual(audit.main(argv + ['--newspaper', 'BL/P', '--years', '1900'], self.client), 0)
            self.assertEqual(audit.main(argv + ['--newspaper', 'BL/P', '--years', '1900 1901'], self.client), 1)
            self.assertEqual(audit.main(argv + ['--newspaper', 'BL/P', '--years', 'bad'], self.client), 2)
            listing = Path(directory) / 'selection.txt'
            listing.write_text('# comment\nBL/P/1900 BL/P/1900\tBL/P/1900\n')
            self.assertEqual(audit.main(argv + ['--newspaper-list', str(listing)], self.client), 0)
            self.assertEqual(audit.main(argv + ['--newspaper-list', str(listing), '--years', '1900'], self.client), 2)

    def test_cli_publication_failure_returns_error(self):
        with tempfile.TemporaryDirectory() as directory:
            argv = ['--task', 'consolidatedcanonical', '--canonical-bucket', 'input',
                    '--consolidated-bucket', 'output', '--run-version', 'v1', '--has-provider', '1',
                    '--newspaper', 'BL/P', '--check-streams', 'pages', '--output-dir', directory]
            with patch.object(audit, 'write_reports', side_effect=OSError('disk full')):
                self.assertEqual(audit.main(argv, self.client), 2)

    def test_configured_client_and_logging_are_used(self):
        try:
            import impresso_cookbook
        except ImportError:
            self.skipTest('Installed cookbook required for client integration test')
        with tempfile.TemporaryDirectory() as directory:
            argv = ['--task', 'consolidatedcanonical', '--canonical-bucket', 'input',
                    '--consolidated-bucket', 'output', '--run-version', 'v1', '--has-provider', '1',
                    '--newspaper', 'BL/P', '--check-streams', 'pages', '--output-dir', directory]
            with patch.object(impresso_cookbook, 'get_s3_client', return_value=self.client) as factory, \
                    patch.object(impresso_cookbook, 'setup_logging') as logging:
                self.assertEqual(audit.main(argv), 1)
                factory.assert_called_once_with()
                logging.assert_called_once_with('INFO', None)

    def test_cli_exit_codes_and_configuration_failure_invalidates_publication(self):
        with tempfile.TemporaryDirectory() as directory:
            argv = ['--task', 'consolidatedcanonical', '--canonical-bucket', 'input',
                    '--consolidated-bucket', 'output', '--run-version', 'v1', '--has-provider', '1',
                    '--newspaper', 'BL/P', '--check-streams', 'pages', '--output-dir', directory]
            self.assertEqual(audit.main(argv, self.client), 1)
            self.source(PAGE)
            self.output(PAGE)
            self.assertEqual(audit.main(argv, self.client), 0)
            self.assertEqual(audit.main(argv + ['--concurrency', '0'], self.client), 2)
            self.assertFalse((Path(directory) / 'report_complete.json').exists())
            self.client.failures['input', 'BL/P/pages/', None] = [S3Error('AccessDenied')]
            self.assertEqual(audit.main(argv, self.client), 2)
            self.assertEqual((Path(directory) / 'newspapers_rerun.txt').read_text(), '')


if __name__ == '__main__':
    unittest.main()
