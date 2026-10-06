"""Exercise audit recipes with captured argv; never contact S3."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

COOKBOOK = Path(__file__).resolve().parents[1]
PARENT = COOKBOOK.parent


class CompletenessMakeTests(unittest.TestCase):
    def invoke(self, target, variables=(), status=0, fixture=False):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            shim = root / 'python'
            shim.write_text('#!' + sys.executable + '\nimport json,sys,os\n'
                            'print("CAPTURE=" + json.dumps(sys.argv[1:]))\n'
                            'sys.exit(int(os.environ["AUDIT_TEST_STATUS"]))\n')
            shim.chmod(0o755)
            cfg = root / 'config.mk'
            cfg.write_text('S3_BUCKET_CANONICAL := source-test\n'
                           'S3_BUCKET_CONSOLIDATEDCANONICAL := dest-test\n'
                           'RUN_VERSION_CONSOLIDATEDCANONICAL := test-run\n'
                           'S3_BUCKET_LANGIDENT := enrichment-test\n'
                           'PROCESS_LABEL_LANGIDENT := custom\nRUN_ID_LANGIDENT := custom-run\n'
                           'S3_BUCKET_LANGIDENT_ENRICHMENT := wrong-unused-bucket\n'
                           'NEWSPAPER_HAS_PROVIDER := 1\nNEWSPAPER := BL/P\n'
                           'CANONICAL_INPUT_KIND := audios\n'
                           'CONSOLIDATEDCANONICAL_WIP_MAX_AGE := 7\n')
            cwd = PARENT
            command = ['remake', '--no-print-directory', target, f'CFG={cfg}', f'PYTHON={shim}',
                       'LOGGING_LEVEL=ERROR', *variables]
            if fixture:
                makefile = root / 'Makefile'
                makefile.write_text(f'include {cfg}\nPYTHON := {shim}\nBUILD_DIR := build\n'
                                    'COMPLETENESS_TASK := consolidatedcanonical\n'
                                    f'include {COOKBOOK}/completeness.mk\n'
                                    f'include {COOKBOOK}/completeness.mk\n')
                command += ['-f', str(makefile)]
                cwd = root
            elif not (PARENT / 'Makefile').exists():
                self.skipTest('Parent processing repository unavailable')
            result = subprocess.run(command, cwd=cwd, text=True, capture_output=True,
                                    env=dict(os.environ, AUDIT_TEST_STATUS=str(status)))
            calls = [json.loads(line[len('CAPTURE='):]) for line in result.stdout.splitlines()
                     if line.startswith('CAPTURE=')]
            return result, calls

    def test_parent_configuration_and_quoted_paths(self):
        result, calls = self.invoke('check-collection-completeness', [
            "NEWSPAPERS_TO_PROCESS_FILE=list with ' quote.txt",
            'COMPLETENESS_REPORT_DIR=reports with spaces', 'COMPLETENESS_CONCURRENCY=3',
            'COMPLETENESS_STREAMS=pages,audios'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 1)
        args = calls[0]
        pairs = dict(zip(args[1::2], args[2::2]))
        self.assertEqual(pairs['--task'], 'consolidatedcanonical')
        self.assertEqual(pairs['--canonical-bucket'], 'source-test')
        self.assertEqual(pairs['--consolidated-bucket'], 'dest-test')
        self.assertEqual(pairs['--run-version'], 'test-run')
        self.assertEqual(pairs['--langident-root'], 's3://enrichment-test/custom/custom-run')
        self.assertEqual(pairs['--canonical-input-kind'], 'audios')
        self.assertEqual(pairs['--wip-max-age'], '7')
        self.assertEqual(pairs['--newspaper-list'], "list with ' quote.txt")
        self.assertEqual(pairs['--output-dir'], 'reports with spaces')
        self.assertEqual(pairs['--concurrency'], '3')
        self.assertEqual(pairs['--check-streams'], 'pages,audios')
        self.assertNotIn('--provider', args)

    def test_single_newspaper_years(self):
        result, calls = self.invoke('check-newspaper-completeness',
                                    ['PROVIDER=BL', 'NEWSPAPER=P', 'NEWSPAPER_YEARS=1900 1901'])
        self.assertEqual(result.returncode, 0, result.stderr)
        args = calls[0]
        self.assertEqual(args[args.index('--years') + 1], '1900 1901')
        self.assertEqual(args[args.index('--newspaper') + 1], 'P')
        self.assertEqual(args[args.index('--provider') + 1], 'BL')

    def test_providerless(self):
        result, calls = self.invoke('check-newspaper-completeness',
                                    ['NEWSPAPER_HAS_PROVIDER=0', 'NEWSPAPER=P', 'PROVIDER='])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('--provider', calls[0])
        self.assertNotIn('--years', calls[0])

    def test_auditor_failures_propagate(self):
        for status in (1, 2):
            with self.subTest(status=status):
                result, calls = self.invoke('check-collection-completeness', status=status)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(len(calls), 1)

    def test_include_guard_and_help(self):
        result, calls = self.invoke('check-newspaper-completeness', fixture=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 1)
        result, calls = self.invoke('help-completeness')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(calls)
        self.assertIn('make check-collection-completeness', result.stdout)
        self.assertIn('make check-newspaper-completeness', result.stdout)
        self.assertIn('COMPLETENESS_TASK=consolidatedcanonical', result.stdout)


if __name__ == '__main__':
    unittest.main()
