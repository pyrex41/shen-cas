#!/usr/bin/env node
// Run shen-cas under ShenScript (Shen-for-JavaScript), a pure-npm Shen port.
//
// This makes the kernel + full test harness runnable with nothing but Node and
// the `shen-script` npm package -- no native Shen install, no GitHub access. It
// is the reference way to reproduce `ALL PASS` in a browser/CI/web environment
// and exercises exactly the portability the project cares about.
//
// Setup (once):
//   cd scripts && npm install shen-script@^0.17
// Run the whole suite (from the repo root):
//   node --stack-size=60000 scripts/shenscript-run.js
//   # (raise the OS stack first if needed:  ulimit -s unlimited)
// Run an arbitrary form after loading the kernel:
//   node --stack-size=60000 scripts/shenscript-run.js '(pretty-expr (reduce [[sym (protect Plus)] [int 2] [int 3]]))'
//
// Notes:
//   * The CAS evaluator is deeply recursive, so a large V8 stack is required
//     (--stack-size=60000 KB with `ulimit -s unlimited`). This mirrors the
//     256 MB stack the native ports use.
//   * ShenScript ships the rendered kernel but wires no file IO; we provide
//     openRead/openWrite + stdout streams so Shen's own (load ...) works.

const fs = require('fs');
const path = require('path');

const REPO = path.resolve(__dirname, '..');
// Resolve shen-script from scripts/node_modules or the repo root.
let Shen;
try { Shen = require('shen-script'); }
catch (e) {
  console.error('shen-script not installed. Run: (cd scripts && npm install shen-script@^0.17)');
  process.exit(2);
}

class InStream {
  constructor(buf) { this.buf = buf; this.pos = 0; this.name = 'file-in'; }
  read() { return this.pos < this.buf.length ? this.buf[this.pos++] : -1; }
  close() { return null; }
}
class OutStream {
  constructor(write) { this.write = b => (write(Buffer.from([b])), b); this.name = 'std-out'; }
  close() { return null; }
}

const stdout = new OutStream(b => process.stdout.write(b));

const options = {
  homeDirectory: '',
  InStream, OutStream,
  stoutput: stdout,
  sterror: stdout,
  openRead: p => {
    const fp = fs.existsSync(p) ? p : path.join(REPO, p);
    return new InStream(fs.readFileSync(fp));
  },
  openWrite: p => {
    const fp = path.isAbsolute(p) ? p : path.join(REPO, p);
    const fd = fs.openSync(fp, 'w');
    const s = new OutStream(b => fs.writeSync(fd, b));
    s.close = () => (fs.closeSync(fd), null);
    return s;
  },
};

process.chdir(REPO);
const form = process.argv[2] || '(load "load.shen")';

(async () => {
  try {
    const $ = await new Shen(options);
    await $.exec(form);
    process.stdout.write('\n');
  } catch (e) {
    console.error('\nERROR:', e && e.stack ? e.stack : e);
    process.exit(1);
  }
})();
