#!/usr/bin/env python3
"""Read-only S3 artifact coverage audits; no record/schema validity is implied.

Run as a script or as ``python -m impresso_cookbook.check_collection_completeness``.
Only consolidatedcanonical is currently supported. Repair is deliberately disabled.
"""
from __future__ import annotations

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
import json
import logging
import math
from pathlib import Path
import re
import sys
import tempfile
import time
from typing import Any
from uuid import uuid4

LOG = logging.getLogger(__name__)
STREAMS = ('issues', 'pages', 'audios')
STATUSES = ('COMPLETE', 'INCOMPLETE', 'MISSING', 'EMPTY_INPUT', 'AUDIT_ERROR')
COMPONENT = re.compile(r'[A-Za-z0-9_][A-Za-z0-9_.-]*\Z')


@dataclass(frozen=True)
class Scope:
    segment: str
    years: tuple[str, ...] = ()  # Empty means the whole newspaper.

    @property
    def newspaper(self):
        return self.segment.rsplit('/', 1)[-1]

    def entries(self):
        return [f'{self.segment}/{year}' for year in self.years] or [self.segment]


def normalize_scopes(entries, has_provider, provider=None):
    """Merge duplicate/overlapping selections before listing any objects."""
    if provider and (not has_provider or not COMPONENT.fullmatch(provider)):
        raise ValueError('--provider requires provider mode and a valid path component')
    grouped = {}
    for raw in entries:
        entry = raw.strip()
        if not entry or entry.startswith('#'):
            continue
        parts = entry.split('/')
        if not all(COMPONENT.fullmatch(part) for part in parts):
            raise ValueError(f'Malformed collection entry: {entry!r}')
        if has_provider and len(parts) == 1 and provider:
            parts.insert(0, provider)
        count = 2 if has_provider else 1
        if len(parts) not in ({2, 3} if has_provider else {1}):
            raise ValueError(f'Entry does not match provider mode: {entry!r}')
        if provider and has_provider and parts[0] != provider:
            raise ValueError(f'Entry conflicts with --provider: {entry!r}')
        year = parts[count:]
        if year and not re.fullmatch(r'\d{4}', year[0]):
            raise ValueError(f'Invalid year: {entry!r}')
        segment = '/'.join(parts[:count])
        if segment not in grouped:
            grouped[segment] = set(year) if year else None
        elif not year:
            grouped[segment] = None
        elif grouped[segment] is not None:
            grouped[segment].update(year)
    if not grouped:
        raise ValueError('The requested collection is empty')
    return [Scope(segment, tuple(sorted(years or ())))
            for segment, years in sorted(grouped.items())]


@dataclass(frozen=True)
class Config:
    canonical_bucket: str
    consolidated_bucket: str
    run_version: str
    has_provider: bool
    langident_root: str | None = None
    canonical_input_kind: str = 'auto'
    check_streams: tuple[str, ...] = ()
    wip_max_age: float = 24
    concurrency: int = 16
    task: str = 'consolidatedcanonical'

    def validate(self):
        if self.task not in PROFILES:
            raise ValueError(f'Unsupported task: {self.task}')
        for bucket in (self.canonical_bucket, self.consolidated_bucket):
            if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]*', bucket):
                raise ValueError('Buckets must be bare bucket names')
        if not COMPONENT.fullmatch(self.run_version):
            raise ValueError('Run version must be a single path component')
        if self.canonical_input_kind not in ('auto', 'pages', 'audios'):
            raise ValueError('Invalid canonical input kind')
        if len(set(self.check_streams)) != len(self.check_streams) or any(
                stream not in STREAMS for stream in self.check_streams):
            raise ValueError('Streams must be a unique comma-separated selection of issues,pages,audios')
        if not math.isfinite(self.wip_max_age) or self.wip_max_age < 0:
            raise ValueError('WIP maximum age must be a finite nonnegative number')
        if self.concurrency < 1:
            raise ValueError('Concurrency must be positive')
        if not self.check_streams or 'issues' in self.check_streams:
            if not self.langident_root:
                raise ValueError('--langident-root is required when auditing issues')
        if self.langident_root:
            parse_root(self.langident_root)


def parse_root(root):
    match = re.fullmatch(r's3://([A-Za-z0-9][A-Za-z0-9.-]*)/(.+?)/?', root)
    if not match or not all(COMPONENT.fullmatch(p) for p in match[2].split('/')):
        raise ValueError('Langident root must be s3://BUCKET/PROCESS/RUN (without newspaper)')
    return match[1], match[2].rstrip('/')


def list_metadata(client, bucket, prefix):
    """Paginate without retaining raw response dictionaries; retry transient failures.

    Botocore also applies its configured per-request retry policy. A failed page
    always propagates, so partial inventories can never certify completeness.
    """
    request = {'Bucket': bucket, 'Prefix': prefix}
    seen_tokens = set()
    while True:
        for attempt in range(3):
            try:
                page = client.list_objects_v2(**request)
                break
            except Exception as exc:
                code = getattr(exc, 'response', {}).get('Error', {}).get('Code')
                transient = code in {'SlowDown', 'Throttling', 'RequestTimeout',
                                     'InternalError', 'ServiceUnavailable', '500', '503'}
                transient |= type(exc).__name__ in {
                    'EndpointConnectionError', 'ConnectionClosedError', 'ReadTimeoutError',
                    'ConnectTimeoutError'}
                if not transient or attempt == 2:
                    raise
                time.sleep(0.2 * 2 ** attempt)
        for obj in page.get('Contents', ()):
            key, size, modified = obj['Key'], obj['Size'], obj['LastModified']
            if not key.startswith(prefix) or not isinstance(size, int) or size < 0:
                raise ValueError('Invalid object metadata in S3 listing')
            if not isinstance(modified, datetime) or modified.tzinfo is None:
                raise ValueError(f'Missing timezone-aware LastModified for {key}')
            yield key[len(prefix):], size, modified
        if not page.get('IsTruncated', False):
            return
        token = page.get('NextContinuationToken')
        if not token or token in seen_tokens:
            raise ValueError('Invalid S3 pagination continuation token')
        seen_tokens.add(token)
        request['ContinuationToken'] = token


def data_year(newspaper, stream, key):
    name = re.escape(newspaper)
    pattern = (rf'{name}-(\d{{4}})-issues\.jsonl\.bz2' if stream == 'issues'
               else rf'{name}-(\d{{4}})/.+\.jsonl\.bz2')
    match = re.fullmatch(pattern, key)
    return match[1] if match else None


def inventory(client, bucket, prefix, scope, stream, now, max_age):
    sizes, locks = {}, []
    for key, size, modified in list_metadata(client, bucket, prefix):
        is_lock = key.endswith('.wip')
        year = data_year(scope.newspaper, stream, key[:-4] if is_lock else key)
        if not year or (scope.years and year not in scope.years):
            continue
        if is_lock:
            age = (now - modified).total_seconds() / 3600
            locks.append({'key': key, 'year': year, 'last_modified': modified.isoformat(),
                          'age_hours': age, 'state': 'stale' if age > max_age else 'active'})
        else:
            sizes[key] = size
    return sizes, sorted(locks, key=lambda item: item['key'])


def compare(expected, found):
    missing = sorted(expected.keys() - found.keys())
    invalid = sorted(key for key in expected.keys() & found.keys() if found[key] == 0)
    covered = len(expected) - len(missing) - len(invalid)
    return {'expected': len(expected), 'present': len(expected) - len(missing),
            'covered': covered, 'coverage_percent': 100 * covered / len(expected) if expected else None,
            'missing': missing, 'invalid': invalid,
            'unexpected': sorted(found.keys() - expected.keys()),
            'invalid_source': sorted(key for key, size in expected.items() if size == 0)}


class ConsolidatedCanonical:
    repair_supported = False

    def audit(self, client, config, scope, now):
        sources, outputs, locks = {}, {}, {}
        configured_records = (('pages', 'audios') if config.canonical_input_kind == 'auto'
                              else (config.canonical_input_kind,))
        needed = set(config.check_streams or ('issues',) + configured_records)
        if 'issues' in needed:
            needed.update(('pages', 'audios') if config.canonical_input_kind == 'auto'
                          else (config.canonical_input_kind,))
        for stream in sorted(needed):
            sources[stream], _ = inventory(
                client, config.canonical_bucket, f'{scope.segment}/{stream}/',
                scope, stream, now, config.wip_max_age)
        selected = config.check_streams or (
            ('issues',) + (tuple(s for s in ('pages', 'audios') if sources[s])
                          if config.canonical_input_kind == 'auto'
                          else (config.canonical_input_kind,)))
        blockers = []
        for stream in selected:
            outputs[stream], locks[stream] = inventory(
                client, config.consolidated_bucket,
                f'{config.run_version}/{scope.segment}/{stream}/', scope, stream,
                now, config.wip_max_age)
            if not sources[stream]:
                blockers.append(f'{stream}: required input stream is empty')
        if 'issues' in selected:
            issue_years = {data_year(scope.newspaper, 'issues', k) for k in sources['issues']}
            record_streams = (('pages', 'audios') if config.canonical_input_kind == 'auto'
                              else (config.canonical_input_kind,))
            record_years = {data_year(scope.newspaper, s, k) for s in record_streams
                            for k, size in sources[s].items() if size > 0}
            blockers.extend(f'{y}: missing canonical record prerequisite' for y in sorted(issue_years - record_years))
            content_years = {data_year(scope.newspaper, s, k)
                             for s in set(record_streams) | (set(selected) - {'issues'})
                             for k in sources[s]}
            blockers.extend(f'{y}: content exists without canonical issues' for y in sorted(content_years - issue_years))
            blockers.extend(f'{s}: zero-byte prerequisite source {k}'
                            for s in record_streams if s not in selected
                            for k, size in sources[s].items() if size == 0)
            bucket, root = parse_root(config.langident_root)
            enrichment = {}
            pattern = re.compile(rf'{re.escape(scope.newspaper)}-(\d{{4}})\.jsonl\.bz2')
            for key, size, _ in list_metadata(client, bucket, f'{root}/{scope.segment}/'):
                match = pattern.fullmatch(key)
                if match and match[1] in issue_years:
                    enrichment[match[1]] = size
            blockers.extend(f'{y}: missing or zero-byte langident prerequisite'
                            for y in sorted(issue_years) if not enrichment.get(y))
        details = {}
        all_years = set()
        for stream in selected:
            expected, found = sources[stream], outputs[stream]
            detail = compare(expected, found)
            expected_years, found_years = {}, {}
            for values, grouped in ((expected, expected_years), (found, found_years)):
                for key, size in values.items():
                    year = data_year(scope.newspaper, stream, key)
                    grouped.setdefault(year, {})[key] = size
            all_years.update(expected_years)
            detail['years'] = {year: compare(expected_years.get(year, {}), found_years.get(year, {}))
                               for year in sorted(expected_years.keys() | found_years.keys())}
            detail['empty_reason'] = 'required input absent' if not expected else None
            detail['locks'] = locks[stream]
            details[stream] = detail
            blockers.extend(f'{stream}: zero-byte source {k}' for k in detail['invalid_source'])
        blockers.extend(f'{y}: requested year absent upstream' for y in sorted(set(scope.years) - all_years))
        expected_count = sum(d['expected'] for d in details.values())
        present_count = sum(d['present'] for d in details.values())
        covered_count = sum(d['covered'] for d in details.values())
        status = ('EMPTY_INPUT' if not expected_count else
                  'COMPLETE' if covered_count == expected_count and not blockers else
                  'MISSING' if not present_count else 'INCOMPLETE')
        active = any(lock['state'] == 'active' for stream in details.values() for lock in stream['locks'])
        candidate = status in ('MISSING', 'INCOMPLETE') and not blockers and not active
        return {'scope': asdict(scope), 'entries': scope.entries(), 'status': status,
                'streams': details, 'selected_streams': list(selected),
                'inapplicable_streams': [s for s in ('pages', 'audios') if s not in selected]
                    if not config.check_streams and config.canonical_input_kind == 'auto' else [],
                'upstream_blockers': sorted(set(blockers)), 'active_locks': active,
                'repair_candidate': candidate, 'rerun_eligible': False,
                'repair_blockers': sorted(set(blockers + (['active lock'] if active else [])
                                          + ['repair adapter not implemented'])), 'errors': []}


PROFILES = {'consolidatedcanonical': ConsolidatedCanonical}


def audit_collection(client, config, scopes, original_selection, now=None, audit_id=None):
    config.validate()
    now = now or datetime.now(timezone.utc)
    profile = PROFILES[config.task]()

    def scan(scope):
        try:
            return profile.audit(client, config, scope, now)
        except Exception as exc:
            LOG.error('Audit failed for %s: %s', scope.segment, exc)
            return {'scope': asdict(scope), 'entries': scope.entries(), 'status': 'AUDIT_ERROR',
                    'streams': {}, 'upstream_blockers': [], 'active_locks': False,
                    'repair_candidate': False, 'rerun_eligible': False,
                    'repair_blockers': ['audit error'], 'errors': [str(exc)]}

    # map preserves sorted scope order; only per-worker source inventories are retained.
    with ThreadPoolExecutor(max_workers=config.concurrency) as pool:
        items = list(pool.map(scan, scopes))
    counts = Counter(item['status'] for item in items)
    exit_code = (2 if counts['AUDIT_ERROR'] else
                 1 if any(i['status'] != 'COMPLETE' or i['active_locks'] for i in items) else 0)
    return {'schema_version': 1, 'audit_id': audit_id or str(uuid4()),
            'timestamp': now.isoformat(), 'task': config.task, 'config': asdict(config),
            'original_selection': list(original_selection), 'repair_supported': profile.repair_supported,
            'limits': 'Artifact presence and nonzero size only; no record, schema, or freshness validation.',
            'status_counts': {s: counts[s] for s in STATUSES},
            'observation_counts': {
                'items_with_active_locks': sum(i['active_locks'] for i in items),
                'items_with_upstream_blockers': sum(bool(i['upstream_blockers']) for i in items),
                'stale_locks': sum(lock['state'] == 'stale' for i in items
                                   for d in i['streams'].values() for lock in d['locks']),
                'invalid_outputs': sum(len(d['invalid']) for i in items for d in i['streams'].values()),
                'unexpected_outputs': sum(len(d['unexpected']) for i in items for d in i['streams'].values()),
            }, 'exit_code': exit_code, 'items': items}


def write_reports(report, output_dir):
    """Publish a generation, with the completion marker written last.

    Readers must require the marker and matching audit ID. Concurrent audits must
    use separate directories. Remove old eligibility before attempting publication.
    """
    directory = Path(output_dir)
    directory.mkdir(parents=True, exist_ok=True)
    (directory / 'report_complete.json').unlink(missing_ok=True)
    (directory / 'newspapers_rerun.txt').unlink(missing_ok=True)
    with tempfile.TemporaryDirectory(prefix='.audit-', dir=directory) as temporary:
        staging = Path(temporary)
        (staging / 'completeness_report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
        lines = ['scope\tstatus\tstream\texpected\tcovered\tcoverage_percent']
        for item in report['items']:
            for stream, detail in sorted(item['streams'].items()):
                lines.append('\t'.join(map(str, [','.join(item['entries']), item['status'], stream,
                                                 detail['expected'], detail['covered'], detail['coverage_percent']])))
            if not item['streams']:
                lines.append(f"{','.join(item['entries'])}\t{item['status']}\t\t\t\t")
        (staging / 'completeness_report.tsv').write_text('\n'.join(lines) + '\n')
        for label, status in [('missing', 'MISSING'), ('incomplete', 'INCOMPLETE'), ('rerun', None)]:
            entries = [entry for item in report['items']
                       if (item['status'] == status if status else item['rerun_eligible'] and report['exit_code'] != 2)
                       for entry in item['entries']]
            (staging / f'newspapers_{label}.txt').write_text(''.join(f'{e}\n' for e in entries))
        for path in sorted(staging.iterdir()):
            path.replace(directory / path.name)
        marker = staging / 'report_complete.json'
        marker.write_text(json.dumps({'audit_id': report['audit_id'], 'schema_version': report['schema_version'],
                                      'exit_code': report['exit_code']}) + '\n')
        marker.replace(directory / marker.name)


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument('--task', required=True, choices=sorted(PROFILES))
    result.add_argument('--canonical-bucket', required=True)
    result.add_argument('--consolidated-bucket', required=True)
    result.add_argument('--run-version', required=True)
    selection = result.add_mutually_exclusive_group(required=True)
    selection.add_argument('--newspaper-list', type=Path)
    selection.add_argument('--newspaper')
    result.add_argument('--provider')
    result.add_argument('--years', help='Space-separated years for --newspaper in provider mode')
    result.add_argument('--has-provider', required=True, type=int, choices=(0, 1))
    result.add_argument('--langident-root', help='Collection root s3://BUCKET/PROCESS/RUN; required for issues')
    result.add_argument('--canonical-input-kind', choices=('auto', 'pages', 'audios'), default='auto')
    result.add_argument('--check-streams', help='Comma-separated override; default issues plus configured content streams')
    result.add_argument('--wip-max-age', type=float, default=24, help='Hours (pass the pipeline configuration)')
    result.add_argument('--concurrency', type=int, default=16)
    result.add_argument('--output-dir', type=Path, default=Path('build.d/reports/completeness/consolidatedcanonical'))
    result.add_argument('--log-level', choices=('DEBUG', 'INFO', 'WARNING', 'ERROR'), default='INFO')
    return result


def main(argv=None, client=None):
    args = parser().parse_args(argv)
    try:
        # Invalidate previous publication even when new configuration is rejected.
        (args.output_dir / 'report_complete.json').unlink(missing_ok=True)
        (args.output_dir / 'newspapers_rerun.txt').unlink(missing_ok=True)
        entries = ([entry for line in args.newspaper_list.read_text().splitlines()
                    if not line.lstrip().startswith('#') for entry in line.split()]
                   if args.newspaper_list else [args.newspaper])
        if args.years is not None:
            if args.newspaper_list or not args.has_provider:
                raise ValueError('--years requires --newspaper and provider mode')
            base = normalize_scopes(entries, True, args.provider)[0]
            years = args.years.split()
            if base.years or not years or any(not re.fullmatch(r'\d{4}', y) for y in years):
                raise ValueError('--years requires a newspaper without a year and four-digit years')
            entries = [f'{base.segment}/{year}' for year in years]
        scopes = normalize_scopes(entries, bool(args.has_provider), args.provider)
        config = Config(args.canonical_bucket, args.consolidated_bucket, args.run_version,
                        bool(args.has_provider), args.langident_root, args.canonical_input_kind,
                        tuple(args.check_streams.split(',')) if args.check_streams is not None else (),
                        args.wip_max_age, args.concurrency, args.task)
        config.validate()
        if client is None:
            from dotenv import load_dotenv
            from impresso_cookbook import get_s3_client, setup_logging
            load_dotenv()
            setup_logging(args.log_level, None)
            try:
                client = get_s3_client(max_pool_connections=max(10, args.concurrency))
            except TypeError:
                client = get_s3_client()
        report = audit_collection(client, config, scopes, entries)
        write_reports(report, args.output_dir)
        print('  '.join(f'{status}: {count}' for status, count in report['status_counts'].items()))
        print(f"Reports: {args.output_dir} (repair disabled)")
        return report['exit_code']
    except Exception as exc:
        LOG.error('Completeness audit failed: %s', exc)
        return 2


if __name__ == '__main__':
    sys.exit(main())
