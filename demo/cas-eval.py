#!/usr/bin/env python3
"""Evaluate shen-cas demo forms and print only clean, deterministic output.

Loads the kernel (load.shen, which also runs the harness), then loads the demo
forms from a temp file. File loading uses Shen's robust file reader and does NOT
echo return values, so output is clean. Only the text between the markers is
shown, and nondeterministic 'run time:' lines are stripped, so the output is
byte-stable for `showboat verify`.

Usage: cas-eval.py '<one or more shen (output ...) forms>'
"""
import subprocess, sys, os, tempfile

SHEN = '/Users/reuben/projects/shen/shen-go/shen'
REPO = '/Users/reuben/projects/shen/shen-cas'

forms = sys.argv[1]
fd, path = tempfile.mkstemp(suffix='.shen', prefix='casdemo_')
try:
    with os.fdopen(fd, 'w') as f:
        f.write('(output "@@@D@@@~%")\n')
        f.write(forms + '\n')
        f.write('(output "@@@E@@@~%")\n')
    prog = '(load "load.shen")\n(load "demo/dsl.shen")\n(load "%s")\n' % path
    p = subprocess.run([SHEN], input=prog, text=True, capture_output=True, timeout=180, cwd=REPO)
finally:
    os.unlink(path)

out = p.stdout
i, j = out.find("@@@D@@@"), out.find("@@@E@@@")
body = out[i + len("@@@D@@@"):j] if (i >= 0 and j >= 0) else out
clean = [l.rstrip() for l in body.splitlines()
         if l.strip() and 'run time:' not in l and not l.lstrip().startswith('"')]
print("\n".join(clean))
