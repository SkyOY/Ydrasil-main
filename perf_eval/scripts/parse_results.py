#!/usr/bin/env python3
import json
import os
import re
from pathlib import Path


EVAL_ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = EVAL_ROOT / "out"
LOG_DIR = OUT_DIR / "logs"
VIVADO_RESULTS = EVAL_ROOT / "vivado" / "reports" / "fmax_results.json"
CPU_MHZ = float(os.environ.get("CPU_MHZ", "150"))

METRIC_RE = re.compile(
    r"PERF_METRIC:\s+NAME=(?P<name>\S+)\s+STATUS=(?P<status>\S+)\s+"
    r"CYCLES=(?P<cycles>\d+)\s+INSTS=(?P<insts>\d+)\s+IPC=(?P<ipc>[0-9.]+)\s+TOHOST=(?P<tohost>0x[0-9a-fA-F]+)"
    r"(?:\s+PC=(?P<pc>0x[0-9a-fA-F]+))?"
)


def parse_metadata() -> dict[str, str]:
    meta = {}
    path = OUT_DIR / "metadata.env"
    if not path.exists():
        return meta
    for line in path.read_text(errors="replace").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            meta[key] = value
    return meta


def parse_logs() -> list[dict]:
    rows = []
    for log in sorted(LOG_DIR.glob("*.log")):
        text = log.read_text(errors="replace")
        match = None
        for candidate in METRIC_RE.finditer(text):
            match = candidate
        if not match:
            continue
        row = match.groupdict()
        row["cycles"] = int(row["cycles"])
        row["insts"] = int(row["insts"])
        row["ipc"] = float(row["ipc"])
        row["log"] = str(log.relative_to(EVAL_ROOT))
        row["reason"] = failure_reason(row)
        if row["name"] == "coremark":
            row["coremark"] = parse_coremark(text, row["cycles"])
        rows.append(row)
    return rows


def failure_reason(row: dict) -> str | None:
    if row["status"] == "PASS":
        return None
    if row["tohost"].lower() == "0xfffffffe":
        return "invalid_pc"
    if row["tohost"].lower() == "0xffffffff":
        return "timeout"
    return "non_pass_tohost"


def parse_coremark(text: str, cycles: int) -> dict:
    def grab(pattern: str):
        m = re.search(pattern, text)
        return m.group(1).strip() if m else None

    iterations = grab(r"Iterations\s*:\s*(\d+)")
    ticks = grab(r"Total ticks\s*:\s*(\d+)")
    validated = "Correct operation validated" in text and "Errors detected" not in text
    result = {
        "validated": validated,
        "iterations": int(iterations) if iterations else None,
        "reported_ticks": int(ticks) if ticks else None,
    }
    if result["iterations"] and cycles:
        result["coremark_per_mhz"] = result["iterations"] * 1_000_000.0 / cycles
        result["coremark_at_150mhz"] = result["coremark_per_mhz"] * 150.0
    return result


def parse_vivado() -> dict:
    if not VIVADO_RESULTS.exists():
        return {"status": "not_run", "reason": "vivado results not found"}
    try:
        data = json.loads(VIVADO_RESULTS.read_text())
    except json.JSONDecodeError as exc:
        return {"status": "parse_error", "reason": str(exc)}
    for point in data.get("points", []):
        freq = str(point.get("freq_mhz"))
        if freq.endswith(".0"):
            freq = freq[:-2]
        util_path = EVAL_ROOT / "vivado" / "reports" / f"utilization_{freq}.rpt"
        timing_path = EVAL_ROOT / "vivado" / "reports" / f"timing_{freq}.rpt"
        if util_path.exists():
            point["resources"] = parse_utilization_report(util_path)
            point["utilization_report"] = str(util_path.relative_to(EVAL_ROOT))
        if timing_path.exists():
            point["timing_report"] = str(timing_path.relative_to(EVAL_ROOT))
    passing = [p for p in data.get("points", []) if p.get("status") == "pass"]
    if passing:
        data["fmax_mhz"] = max(float(p["freq_mhz"]) for p in passing)
    return data


def parse_utilization_report(path: Path) -> dict:
    resource_names = {
        "CLB LUTs": "lut",
        "Slice LUTs": "lut",
        "CLB Registers": "ff",
        "Slice Registers": "ff",
        "Block RAM Tile": "bram_tile",
        "Block RAM Tiles": "bram_tile",
        "RAMB36/FIFO": "ramb36",
        "RAMB18": "ramb18",
        "DSPs": "dsp",
        "DSP48E1": "dsp",
    }
    resources = {}
    for line in path.read_text(errors="replace").splitlines():
        if "|" not in line:
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 2:
            continue
        key = resource_names.get(cells[0])
        if not key:
            continue
        used = re.sub(r"[^0-9.]", "", cells[1])
        if used:
            resources[key] = float(used) if "." in used else int(used)
    return resources


def summarize(rows: list[dict]) -> dict:
    passed = [r for r in rows if r["status"] == "PASS" and r["name"] != "coremark"]
    by_group: dict[str, list[dict]] = {}
    for row in passed:
        group = row["name"].split("_", 1)[0]
        by_group.setdefault(group, []).append(row)
    groups = {}
    for group, items in by_group.items():
        groups[group] = {
            "count": len(items),
            "avg_ipc": sum(r["ipc"] for r in items) / len(items),
            "min_ipc": min(r["ipc"] for r in items),
            "max_ipc": max(r["ipc"] for r in items),
            "mips_at_150mhz": (sum(r["ipc"] for r in items) / len(items)) * CPU_MHZ,
        }
    return {
        "pass_count": len([r for r in rows if r["status"] == "PASS"]),
        "fail_count": len([r for r in rows if r["status"] != "PASS"]),
        "groups": groups,
    }


def write_report(results: dict) -> None:
    rows = results["benchmarks"]
    summary = results["summary"]
    core = next((r for r in rows if r["name"] == "coremark"), None)
    lines = [
        "# Ydrasil Performance Evaluation",
        "",
        "## Environment",
    ]
    for key, value in sorted(results["metadata"].items()):
        lines.append(f"- `{key}`: {value}")
    lines.extend(
        [
            "",
            "## Throughput",
            "",
            f"- Pass: {summary['pass_count']}",
            f"- Fail: {summary['fail_count']}",
            "",
            "| Group | Count | Avg IPC | Min IPC | Max IPC | MIPS @150MHz |",
            "| --- | ---: | ---: | ---: | ---: | ---: |",
        ]
    )
    for group, item in sorted(summary["groups"].items()):
        lines.append(
            f"| {group} | {item['count']} | {item['avg_ipc']:.4f} | "
            f"{item['min_ipc']:.4f} | {item['max_ipc']:.4f} | {item['mips_at_150mhz']:.2f} |"
        )
    lines.extend(["", "## Benchmarks", "", "| Name | Status | Reason | Cycles | Insts | IPC | Log |", "| --- | --- | --- | ---: | ---: | ---: | --- |"])
    for row in rows:
        lines.append(
            f"| {row['name']} | {row['status']} | {row.get('reason') or ''} | {row['cycles']} | {row['insts']} | "
            f"{row['ipc']:.4f} | `{row['log']}` |"
        )
    lines.extend(["", "## CoreMark"])
    if core and "coremark" in core:
        cm = core["coremark"]
        lines.append(f"- Validation: {'PASS' if cm.get('validated') else 'FAIL'}")
        lines.append(f"- Iterations: {cm.get('iterations')}")
        lines.append(f"- Cycles: {core['cycles']}")
        if cm.get("coremark_per_mhz") is not None:
            lines.append(f"- CoreMark/MHz: {cm['coremark_per_mhz']:.4f}")
            lines.append(f"- CoreMark @150MHz: {cm['coremark_at_150mhz']:.2f}")
    else:
        lines.append("- Not run")
    lines.extend(["", "## Fmax / FPGA Resources"])
    vivado = results["vivado"]
    if vivado.get("status") == "not_run":
        lines.append(f"- Not run: {vivado.get('reason')}")
    else:
        lines.append("```json")
        lines.append(json.dumps(vivado, indent=2))
        lines.append("```")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "report.md").write_text("\n".join(lines) + "\n")


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    results = {
        "metadata": parse_metadata(),
        "benchmarks": parse_logs(),
        "vivado": parse_vivado(),
    }
    results["summary"] = summarize(results["benchmarks"])
    (OUT_DIR / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    write_report(results)
    print(OUT_DIR / "report.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
