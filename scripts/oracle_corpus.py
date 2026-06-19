#!/usr/bin/env python3
"""Optional cross-oracle helper for expanding the shen-cas corpus.

The default mode is dependency-free classification of candidate cases. Passing
--compare-sympy opts into both Python SymPy and a local Shen executable.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CASES = REPO_ROOT / "scripts" / "oracle-cases.sample.json"
DEFAULT_SHEN = os.environ.get("SHEN", "/Users/reuben/projects/shen/shen-go/shen")
KERNEL_LOADS = [
    "src/expr.shen",
    "src/pattern.shen",
    "src/num.shen",
    "src/db.shen",
    "src/rule.shen",
    "src/attrs.shen",
    "src/query.shen",
    "src/warn.shen",
    "src/match.shen",
    "src/match-seq.shen",
    "src/match-ac.shen",
    "src/calc-helpers.shen",
    "src/poly.shen",
    "src/polyalg.shen",
    "src/solve.shen",
    "src/series.shen",
    "src/core.shen",
    "src/scope.shen",
    "src/read.shen",
    "src/print.shen",
]


@dataclass(frozen=True)
class Candidate:
    id: str
    source: str
    feature: str
    mode: str
    shen_input: str
    sympy_expr: str | None = None
    variable: str = "x"
    notes: str = ""


def load_cases(path: Path) -> list[Candidate]:
    data = json.loads(path.read_text())
    if not isinstance(data, list):
        raise ValueError(f"{path} must contain a JSON list of cases")
    return [candidate_from_json(item, path) for item in data]


def candidate_from_json(item: Any, path: Path) -> Candidate:
    if not isinstance(item, dict):
        raise ValueError(f"{path}: each case must be a JSON object")
    required = ["id", "source", "feature", "mode", "shen_input"]
    missing = [key for key in required if key not in item]
    if missing:
        raise ValueError(f"{path}: case is missing required keys: {', '.join(missing)}")
    return Candidate(
        id=str(item["id"]),
        source=str(item["source"]),
        feature=str(item["feature"]),
        mode=str(item["mode"]),
        shen_input=str(item["shen_input"]),
        sympy_expr=str(item["sympy_expr"]) if item.get("sympy_expr") is not None else None,
        variable=str(item.get("variable", "x")),
        notes=str(item.get("notes", "")),
    )


def classify(case: Candidate) -> str:
    if case.mode not in {"pass", "inert", "unsupported"}:
        return "unsupported"
    return case.mode


def shen_quote(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def run_shen(cases: list[Candidate], shen_path: str, timeout: int) -> dict[str, dict[str, str]]:
    executable = Path(shen_path)
    if executable.is_absolute() and not executable.exists():
        raise RuntimeError(f"Shen executable not found: {shen_path}")

    runnable = [case for case in cases if classify(case) != "unsupported"]
    helper = [
        "(define oracle-emit",
        "  Label Input -> (trap-error",
        "    (let Expr (parse-expr-string Input)",
        "         (let Got (print-expr (reduce Expr))",
        '              (output "@@CASE@@~A@@OK@@~A~%" Label Got)))',
        '    (/. E (output "@@CASE@@~A@@ERROR@@~A~%" Label E))))',
        "",
        '(output "@@ORACLE_BEGIN@@~%")',
    ]
    for case in runnable:
        helper.append(f'(oracle-emit "{shen_quote(case.id)}" "{shen_quote(case.shen_input)}")')
    helper.append('(output "@@ORACLE_END@@~%")')

    temp_path = None
    try:
        with tempfile.NamedTemporaryFile("w", suffix=".shen", prefix="cas_oracle_", delete=False) as temp:
            temp.write("\n".join(helper))
            temp.write("\n")
            temp_path = temp.name

        load_program = "\n".join(f'(load "{path}")' for path in KERNEL_LOADS)
        program = f'{load_program}\n(demo-register-calculus)\n(load "{shen_quote(temp_path)}")\n'
        proc = subprocess.run(
            [shen_path],
            input=program,
            text=True,
            capture_output=True,
            cwd=REPO_ROOT,
            timeout=timeout,
        )
    finally:
        if temp_path:
            Path(temp_path).unlink(missing_ok=True)

    results: dict[str, dict[str, str]] = {}
    for line in proc.stdout.splitlines():
        if not line.startswith("@@CASE@@"):
            continue
        rest = line[len("@@CASE@@") :]
        if "@@OK@@" in rest:
            case_id, output = rest.split("@@OK@@", 1)
            results[case_id] = {"status": "ok", "output": output}
        elif "@@ERROR@@" in rest:
            case_id, output = rest.split("@@ERROR@@", 1)
            results[case_id] = {"status": "error", "output": output}

    missing = [case.id for case in runnable if case.id not in results]
    if missing:
        stderr = proc.stderr.strip()
        hint = f"; stderr: {stderr}" if stderr else ""
        raise RuntimeError(f"Shen did not return oracle markers for: {', '.join(missing)}{hint}")
    return results


def load_sympy():
    try:
        import sympy as sp  # type: ignore
        from sympy.parsing.sympy_parser import (  # type: ignore
            convert_xor,
            implicit_multiplication_application,
            parse_expr,
            standard_transformations,
        )
    except ImportError as exc:
        raise RuntimeError("SymPy is not installed; rerun without --compare-sympy") from exc
    transformations = standard_transformations + (implicit_multiplication_application, convert_xor)
    return sp, parse_expr, transformations


def sympy_locals(sp: Any, variable: str) -> dict[str, Any]:
    names = {
        variable,
        "x",
        "y",
        "z",
        "a",
        "b",
        "c",
    }
    local: dict[str, Any] = {name: sp.Symbol(name) for name in names}
    local.update(
        {
            "Sin": sp.sin,
            "Cos": sp.cos,
            "Tan": sp.tan,
            "Sec": lambda value: 1 / sp.cos(value),
            "Exp": sp.exp,
            "Log": sp.log,
            "Sqrt": sp.sqrt,
            "ArcTan": sp.atan,
            "ArcSin": sp.asin,
            "ArcCos": sp.acos,
        }
    )
    return local


def parse_sympy(text: str, sp: Any, parse_expr: Any, transformations: Any, variable: str) -> Any:
    return parse_expr(text, local_dict=sympy_locals(sp, variable), transformations=transformations)


def shen_output_to_sympy(text: str, sp: Any, parse_expr: Any, transformations: Any, variable: str) -> Any:
    pythonish = re.sub(r"\b([A-Za-z][A-Za-z0-9]*)\[", r"\1(", text).replace("]", ")")
    return parse_sympy(pythonish, sp, parse_expr, transformations, variable)


def sympy_oracle(case: Candidate, sp: Any, parse_expr: Any, transformations: Any) -> Any:
    if case.sympy_expr is None:
        raise ValueError(f"{case.id}: pass cases need sympy_expr for --compare-sympy")
    expr = parse_sympy(case.sympy_expr, sp, parse_expr, transformations, case.variable)
    var = sp.Symbol(case.variable)
    if case.feature == "simplify":
        return sp.simplify(expr)
    if case.feature == "expand":
        return sp.expand(expr)
    if case.feature == "factor":
        return sp.factor(expr)
    if case.feature == "diff":
        return sp.diff(expr, var)
    if case.feature == "integrate":
        return sp.integrate(expr, var)
    raise ValueError(f"{case.id}: no SymPy oracle for feature {case.feature!r}")


def equivalent(case: Candidate, shen_output: str, sp: Any, parse_expr: Any, transformations: Any) -> tuple[bool, str]:
    got = shen_output_to_sympy(shen_output, sp, parse_expr, transformations, case.variable)
    expected = sympy_oracle(case, sp, parse_expr, transformations)
    var = sp.Symbol(case.variable)
    if case.feature == "integrate":
        ok = sp.simplify(sp.diff(got - expected, var)) == 0
    else:
        ok = sp.simplify(got - expected) == 0
    return bool(ok), str(expected)


def outer_head(expr: str) -> str:
    match = re.match(r"\s*([A-Za-z][A-Za-z0-9]*)\[", expr)
    return match.group(1) if match else ""


def compare_cases(cases: list[Candidate], shen_path: str, timeout: int) -> list[dict[str, str]]:
    sp, parse_expr, transformations = load_sympy()
    shen_results = run_shen(cases, shen_path, timeout)
    rows: list[dict[str, str]] = []
    for case in cases:
        mode = classify(case)
        if mode == "unsupported":
            rows.append({"id": case.id, "mode": mode, "status": "skip", "detail": "unsupported"})
            continue

        shen = shen_results[case.id]
        if shen["status"] != "ok":
            rows.append({"id": case.id, "mode": mode, "status": "error", "detail": shen["output"]})
            continue

        if mode == "inert":
            head = outer_head(case.shen_input)
            ok = bool(head and shen["output"].startswith(f"{head}["))
            rows.append(
                {
                    "id": case.id,
                    "mode": mode,
                    "status": "ok" if ok else "mismatch",
                    "detail": shen["output"],
                }
            )
            continue

        try:
            ok, expected = equivalent(case, shen["output"], sp, parse_expr, transformations)
            rows.append(
                {
                    "id": case.id,
                    "mode": mode,
                    "status": "ok" if ok else "mismatch",
                    "detail": f"shen={shen['output']} sympy={expected}",
                }
            )
        except Exception as exc:  # noqa: BLE001 - this is an exploratory oracle runner.
            rows.append({"id": case.id, "mode": mode, "status": "error", "detail": str(exc)})
    return rows


def classify_rows(cases: list[Candidate]) -> list[dict[str, str]]:
    return [
        {
            "id": case.id,
            "source": case.source,
            "feature": case.feature,
            "mode": classify(case),
            "input": case.shen_input,
        }
        for case in cases
    ]


def print_text(rows: list[dict[str, str]], compare: bool) -> None:
    if compare:
        for row in rows:
            print(f"{row['status']:9} {row['mode']:11} {row['id']} :: {row['detail']}")
        bad = sum(1 for row in rows if row["status"] in {"mismatch", "error"})
        skipped = sum(1 for row in rows if row["status"] == "skip")
        ok = sum(1 for row in rows if row["status"] == "ok")
        print(f"summary: ok={ok} skipped={skipped} bad={bad} total={len(rows)}")
    else:
        for row in rows:
            print(f"{row['mode']:11} {row['source']:6} {row['feature']:10} {row['id']} :: {row['input']}")
        counts: dict[str, int] = {}
        for row in rows:
            counts[row["mode"]] = counts.get(row["mode"], 0) + 1
        print(
            "summary: "
            + " ".join(f"{key}={counts.get(key, 0)}" for key in ["pass", "inert", "unsupported"])
            + f" total={len(rows)}"
        )


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cases", type=Path, default=DEFAULT_CASES, help="JSON candidate case file")
    parser.add_argument("--compare-sympy", action="store_true", help="run Shen and compare pass cases with SymPy")
    parser.add_argument("--shen", default=DEFAULT_SHEN, help="Shen executable for --compare-sympy")
    parser.add_argument("--timeout", type=int, default=240, help="Shen subprocess timeout in seconds")
    parser.add_argument("--format", choices=["text", "json"], default="text")
    args = parser.parse_args(argv)

    try:
        cases = load_cases(args.cases)
        rows = compare_cases(cases, args.shen, args.timeout) if args.compare_sympy else classify_rows(cases)
    except Exception as exc:  # noqa: BLE001 - CLI should report concise actionable errors.
        print(f"oracle_corpus.py: {exc}", file=sys.stderr)
        return 2

    if args.format == "json":
        print(json.dumps(rows, indent=2, sort_keys=True))
    else:
        print_text(rows, compare=args.compare_sympy)

    if args.compare_sympy and any(row["status"] in {"mismatch", "error"} for row in rows):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
