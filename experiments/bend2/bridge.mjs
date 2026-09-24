#!/usr/bin/env node
// A bounded, explicit offload experiment: ground Plus trees of small integers.
// Usage: node experiments/bend2/bridge.mjs /path/to/bun /path/to/bend2/main.ts [depth]
// No Bend dependency is checked into shen-cas. Pin the upstream checkout.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { performance } from 'node:perf_hooks';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const [bun, bend, depthRaw = '4'] = process.argv.slice(2);
const depth = Number(depthRaw);
if (!bun || !bend || !Number.isInteger(depth) || depth < 0 || depth > 7) {
  console.error('usage: node bridge.mjs /path/to/bun /path/to/bend2/main.ts [depth 0..7]');
  process.exit(2);
}

// The same tree is passed to each backend through its respective source form.
// Restricting construction here avoids assuming arbitrary CAS symbols or
// numeric types have an equivalent Bend representation.
const tree = d => d === 0
  ? { tag: 'int', value: 1 }
  : { tag: 'Plus', args: [tree(d - 1), tree(d - 1)] };
const expr = tree(depth);
const shen = node => node.tag === 'int'
  ? `[int ${node.value}]`
  : `[[sym (protect Plus)] ${node.args.map(shen).join(' ')}]`;
const bendExpr = node => node.tag === 'int'
  ? `Lit{${node.value}}`
  : `Add{${node.args.map(bendExpr).join(', ')}}`;

function run(label, command, args) {
  const begin = performance.now();
  const result = spawnSync(command, args, {
    cwd: root, encoding: 'utf8', timeout: 180000, maxBuffer: 8 * 1024 * 1024,
    env: { ...process.env, BEND_NO_UPDATE: '1' },
  });
  const ms = Math.round(performance.now() - begin);
  if (result.error || result.status !== 0) {
    throw new Error(`${label} failed (${result.status}): ${result.error || result.stderr.slice(-1200)}`);
  }
  return { output: result.stdout, ms };
}

const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'shen-cas-bend2-'));
try {
  const conversionBegin = performance.now();
  const template = fs.readFileSync(path.join(root, 'experiments/bend2/closed-add.bend'), 'utf8');
  const marker = 'eval(Add{Lit{1}, Lit{2}})';
  if (template.split(marker).length !== 2) throw new Error('Bend template changed');
  const source = path.join(scratch, 'case.bend');
  const output = path.join(scratch, 'case.js');
  fs.writeFileSync(source, template.replace(marker, `eval(${bendExpr(expr)})`));
  const conversionMs = Math.round(performance.now() - conversionBegin);

  const checked = run('Bend check', bun, [bend, source, '--check-only']);
  if (!checked.output.includes('All terms check.')) throw new Error('Bend did not confirm checking');
  const emitted = run('Bend compile to JS', bun, [bend, source, '-o', output]);
  const executed = run('Bend generated JS', process.execPath, [output]);
  const bendValue = Number(executed.output.trim());

  // Use the source loader's module list, excluding its test harness. Measure
  // evaluation inside Shen after loading; separately record cold process time.
  const loader = fs.readFileSync(path.join(root, 'load.shen'), 'utf8');
  const moduleLoads = loader.split('\n').filter(line => /^\(load "src\/[^\"]+"\)/.test(line));
  if (moduleLoads.length < 10) throw new Error('CAS module loader changed');
  const referenceSource = path.join(scratch, 'reference.shen');
  fs.writeFileSync(referenceSource, moduleLoads.join('\n') + '\n' +
    `(let Begin (get-time run)\n` +
    `     Result (normal-form ${shen(expr)})\n` +
    `     End (get-time run)\n` +
    `     (do (output "EXPERIMENT_RESULT=~A~%" Result)\n` +
    `         (output "EXPERIMENT_EVAL_SECONDS=~A~%" (- End Begin))))\n`);
  const referenceForm = `(load "${referenceSource}")`;
  const reference = run('ShenScript reference', process.execPath,
    ['--stack-size=60000', 'scripts/shenscript-run.js', referenceForm]);
  const match = reference.output.match(/EXPERIMENT_RESULT=\[int (\d+)\]/);
  if (!match) throw new Error('CAS produced no integer result');
  const hot = reference.output.match(/EXPERIMENT_EVAL_SECONDS=([\d.]+)/);
  if (!hot) throw new Error('CAS produced no evaluation duration');
  const casValue = Number(match[1]);
  if (casValue !== bendValue) throw new Error(`mismatch: CAS ${casValue}, Bend ${bendValue}`);

  const result = {
    fragment: 'closed positive integer Plus tree', depth, nodes: 2 ** (depth + 1) - 1,
    casValue, bendValue, equal: true,
    milliseconds: {
      bridgeGenerate: conversionMs, bendCheck: checked.ms, bendEmitJS: emitted.ms, bendRunJS: executed.ms,
      bendTotalIncludingConversion: conversionMs + checked.ms + emitted.ms + executed.ms,
      casColdLoadAndEval: reference.ms,
      casEvalAfterLoad: Math.round(Number(hot[1]) * 1000),
    },
    caveat: 'CAS in-process evaluation and Bend generated JS startup measure different boundaries; these timings do not establish a speedup.',
  };
  console.log(JSON.stringify(result, null, 2));
} finally {
  fs.rmSync(scratch, { recursive: true, force: true });
}
