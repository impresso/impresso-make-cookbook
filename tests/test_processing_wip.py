"""Execute real Make recipes with fake Python CLIs; no S3 or models required."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PIPELINES = ['mediasources', 'content_item_classification', 'nel', 'newsagencies', 'bboxqa', 'TEMPLATE']
MOCK = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
if 'impresso_cookbook.manage_s3_wip' in args:
    stage = 'acquire' if 'acquire' in args else 'release'
elif 'impresso_cookbook.local_to_s3' in args:
    stage = 'preflight' if '--s3-file-exists' in args else 'upload'
else:
    stage = 'process'
with open(os.environ['CALLS'], 'a') as f:
    f.write(json.dumps([stage, args]) + '\n')
if stage == 'process':
    pathlib.Path(args[args.index('--output')+1]).write_text('output')
    pathlib.Path(args[args.index('--log-file')+1]).write_text('log')
status = int(os.environ.get(stage.upper() + '_STATUS', '0'))
if stage == 'acquire' and status == 2 and '--force' in args:
    status = 0
sys.exit(status)
'''

class ProcessingWipTests(unittest.TestCase):
    def run_case(self, name, statuses=None, options=None, existing=False):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            (d/'input').mkdir()
            (d/'input'/'paper-1900.jsonl.bz2').touch()
            (d/'input'/'paper-1900.stamp').touch()
            # The shim uses the real interpreter to avoid recursive PATH lookup.
            shim = MOCK.replace('#!/usr/bin/env python3', '#!' + sys.executable)
            (d/'python3').write_text(shim)
            (d/'python3').chmod(0o755)
            target = d/'out'/'paper-1900.jsonl.bz2'
            if existing:
                target.parent.mkdir()
                target.write_text('original')
                os.utime(target, (1,1))
            config = '''SHELL := /bin/bash
.SHELLFLAGS := -ec
export SHELLOPTS := errexit:pipefail
PYTHON := python3
LOGGING_LEVEL := INFO
GIT_VERSION := test
MAKE_SILENCE_RECIPE := @
NEWSPAPER_YEAR_SORTING := cat
filter_newspaper_year_files = $(1)
LocalToS3 = s3://test/$(notdir $(1))
PROCESSING_KEEP_TIMESTAMP_ONLY_OPTION := --keep-timestamp-only
'''
            config += f'LOCAL_PATH_REBUILT := {d}/input\nLOCAL_PATH_CANONICAL_PAGES := {d}/input\n'
            for pipeline in PIPELINES:
                path_name = pipeline if pipeline == 'content_item_classification' else pipeline.upper()
                config += f'LOCAL_PATH_{path_name} := {d}/out\n'
            config += f'include {ROOT}/processing_{name}.mk\n'
            (d/'Makefile').write_text(config)
            env = dict(os.environ, PATH=str(d)+os.pathsep+os.environ['PATH'], CALLS=str(d/'calls'))
            env.update({k.upper()+'_STATUS':str(v) for k,v in (statuses or {}).items()})
            args = ['remake', '--no-print-directory', '-f', str(d/'Makefile'), str(target)]
            args += [f'{name.upper()}_{k}={v}' for k,v in (options or {}).items()]
            result = subprocess.run(args, cwd=d, env=env, text=True, capture_output=True)
            calls = [json.loads(l) for l in (d/'calls').read_text().splitlines()] if (d/'calls').exists() else []
            return result, calls, target.read_text() if target.exists() else None, Path(str(target)+'.log.gz').exists()

    def test_lifecycle_matrix(self):
        scenarios = [
            ({}, {}, ['acquire','process','upload','release'], 0),
            ({'acquire':2}, {}, ['acquire'], 0),
            ({'acquire':3}, {}, ['acquire'], 0),
            ({'acquire':5}, {}, ['acquire'], 2),
            ({'acquire':2}, {'FORCE_OVERWRITE_OPTION':'--force-overwrite'}, ['acquire','process','upload','release'], 0),
            ({'acquire':2}, {'UPLOAD_IF_NEWER_OPTION':'--upload-if-newer'}, ['acquire','process','upload','release'], 0),
            ({'acquire':3}, {'FORCE_OVERWRITE_OPTION':'--force-overwrite'}, ['acquire'], 0),
            ({}, {'WIP_ENABLED':''}, ['preflight','process','upload'], 0),
            ({'preflight':2}, {'WIP_ENABLED':''}, ['preflight'], 0),
            ({'preflight':3}, {'WIP_ENABLED':''}, ['preflight'], 2),
            ({}, {'WIP_ENABLED':'','FORCE_OVERWRITE_OPTION':'--force-overwrite'}, ['process','upload'], 0),
            ({}, {'WIP_ENABLED':'','UPLOAD_IF_NEWER_OPTION':'--upload-if-newer'}, ['process','upload'], 0),
            ({'process':42,'release':5}, {}, ['acquire','process','release'], 2),
            ({'upload':7,'release':5}, {}, ['acquire','process','upload','release'], 2),
            ({'release':5}, {}, ['acquire','process','upload','release'], 2),
        ]
        for name in PIPELINES:
            for statuses, options, expected, code in scenarios:
                with self.subTest(name=name, statuses=statuses, options=options):
                    result, calls, output, log = self.run_case(name,statuses,options)
                    self.assertEqual(result.returncode,code,result.stdout+result.stderr)
                    self.assertEqual([c[0] for c in calls],expected)
                    if 'process' not in expected:
                        self.assertIsNone(output)
                    elif 'process' in statuses or 'upload' in statuses:
                        self.assertIsNone(output)
                        self.assertTrue(log)
                        failure = statuses.get('process',statuses.get('upload'))
                        self.assertIn(str(failure),result.stdout+result.stderr)
                    else:
                        self.assertEqual(output,'output')
                    for stage,args in calls:
                        if stage == 'upload':
                            for key in ['FORCE_OVERWRITE_OPTION','UPLOAD_IF_NEWER_OPTION']:
                                if key in options: self.assertIn(options[key],args)
                            if name == 'bboxqa':
                                self.assertIn('--keep-timestamp-only',args)
                                self.assertIn('--set-timestamp',args)
                        if stage == 'acquire':
                            self.assertEqual('--force' in args, bool(options.get('FORCE_OVERWRITE_OPTION') or options.get('UPLOAD_IF_NEWER_OPTION')))

    def test_existing_target_skip_and_failed_rebuild(self):
        for name in PIPELINES:
            for statuses in [{'acquire':2},{'acquire':3},{'process':42}]:
                with self.subTest(name=name,statuses=statuses):
                    result,calls,output,log = self.run_case(name,statuses,existing=True)
                    self.assertEqual(output,None if 'process' in statuses else 'original')
                    self.assertEqual(result.returncode,2 if 'process' in statuses else 0)

if __name__ == '__main__':
    unittest.main()
