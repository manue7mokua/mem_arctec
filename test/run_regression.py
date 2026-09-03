#!/usr/bin/env python3
"""Compile and verify the cache hierarchy across supported configurations."""

from __future__ import annotations

from collections import Counter
import re
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COMMAND_TIMEOUT_SECONDS = 30
SOURCES = [
    "src/cpu.v",
    "src/cache_level.v",
    "src/l1_cache.v",
    "src/l2_cache.v",
    "src/main_memory.v",
    "src/top.v",
    "test/testbench.v",
]
CONFIGS = {
    "direct": ["-DCACHE_MAPPING_L1=0", "-DCACHE_MAPPING_L2=0"],
    "two_lru": [
        "-DCACHE_MAPPING_L1=1",
        "-DCACHE_MAPPING_L2=1",
        "-DREPLACEMENT_POLICY_L1=0",
        "-DREPLACEMENT_POLICY_L2=0",
    ],
    "two_random": [
        "-DCACHE_MAPPING_L1=1",
        "-DCACHE_MAPPING_L2=1",
        "-DREPLACEMENT_POLICY_L1=1",
        "-DREPLACEMENT_POLICY_L2=1",
    ],
    "four_lru": [
        "-DCACHE_MAPPING_L1=2",
        "-DCACHE_MAPPING_L2=2",
        "-DREPLACEMENT_POLICY_L1=0",
        "-DREPLACEMENT_POLICY_L2=0",
    ],
    "four_random": [
        "-DCACHE_MAPPING_L1=2",
        "-DCACHE_MAPPING_L2=2",
        "-DREPLACEMENT_POLICY_L1=1",
        "-DREPLACEMENT_POLICY_L2=1",
    ],
    "mixed": [
        "-DCACHE_MAPPING_L1=1",
        "-DCACHE_MAPPING_L2=2",
        "-DREPLACEMENT_POLICY_L1=0",
        "-DREPLACEMENT_POLICY_L2=1",
    ],
}
REQUIRED_RESULT_FIELDS = {
    "requests",
    "responses",
    "reads",
    "writes",
    "l1_hits",
    "l1_misses",
    "l2_hits",
    "l2_misses",
    "writebacks",
    "cycles",
    "stalls",
    "data_errors",
    "l1_fills",
    "l2_fills",
    "memory_reads",
    "memory_writes",
}


def execute(command: list[str]) -> str:
    try:
        completed = subprocess.run(
            command,
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
            timeout=COMMAND_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired as error:
        raise RuntimeError(
            f"Command timed out after {COMMAND_TIMEOUT_SECONDS}s: "
            f"{' '.join(command)}"
        ) from error
    if completed.returncode != 0:
        raise RuntimeError(
            f"Command failed ({completed.returncode}): {' '.join(command)}\n"
            f"{completed.stdout}{completed.stderr}"
        )
    return completed.stdout


def parse_result(output: str) -> dict[str, int]:
    matches = re.findall(r"^RESULT (.+)$", output, re.MULTILINE)
    if len(matches) != 1:
        raise AssertionError(
            f"Simulation emitted {len(matches)} RESULT lines; expected exactly one:\n"
            f"{output}"
        )
    fields = re.findall(r"(\w+)=(\d+)", matches[0])
    duplicate_fields = sorted(
        key for key, count in Counter(key for key, _ in fields).items() if count > 1
    )
    if duplicate_fields:
        raise AssertionError(f"RESULT line repeats fields: {duplicate_fields}")
    result = {key: int(value) for key, value in fields}
    missing_fields = REQUIRED_RESULT_FIELDS - result.keys()
    if missing_fields:
        raise AssertionError(f"RESULT line is missing fields: {sorted(missing_fields)}")
    return result


def assert_invariants(result: dict[str, int], expected_requests: int) -> None:
    assert result["requests"] == expected_requests, result
    assert result["responses"] == expected_requests, result
    assert result["reads"] + result["writes"] == expected_requests, result
    assert result["l1_hits"] + result["l1_misses"] == expected_requests, result
    assert result["l2_hits"] + result["l2_misses"] == result["l1_misses"], result
    assert result["cycles"] >= expected_requests, result
    assert result["stalls"] == result["cycles"] - expected_requests, result
    assert result["data_errors"] == 0, result
    assert result["l1_fills"] == result["l1_misses"], result
    assert result["l2_fills"] == result["memory_reads"], result
    assert result["memory_reads"] >= result["l2_misses"], result
    assert result["memory_writes"] <= result["writebacks"], result


def count_trace_requests(trace_path: str) -> int:
    lines = (ROOT / trace_path).read_text(encoding="utf-8").splitlines()
    return sum(
        1
        for line in lines
        if line.strip() and not line.lstrip().startswith("//")
    )


def main() -> None:
    rows: list[tuple[str, dict[str, int]]] = []
    with tempfile.TemporaryDirectory(prefix="mem_arctec_") as temp_dir:
        for name, defines in CONFIGS.items():
            simulation = str(Path(temp_dir) / name)
            execute(
                ["iverilog", "-g2012", "-o", simulation, "-I."]
                + defines
                + SOURCES
            )

            standard_output = execute(
                ["vvp", simulation, "+TRACE=test/test_trace.txt", "+CHECK_DATA"]
            )
            standard = parse_result(standard_output)
            assert_invariants(
                standard,
                expected_requests=count_trace_requests("test/test_trace.txt"),
            )

            data_output = execute(
                [
                    "vvp",
                    simulation,
                    "+TRACE=test/data_trace.txt",
                    "+CHECK_DATA",
                ]
            )
            assert_invariants(
                parse_result(data_output),
                expected_requests=count_trace_requests("test/data_trace.txt"),
            )

            offset_output = execute(
                [
                    "vvp",
                    simulation,
                    "+TRACE=test/offset_trace.txt",
                    "+CHECK_DATA",
                ]
            )
            assert_invariants(
                parse_result(offset_output),
                expected_requests=count_trace_requests("test/offset_trace.txt"),
            )

            full_line_output = execute(
                [
                    "vvp",
                    simulation,
                    "+TRACE=test/full_line_trace.txt",
                    "+CHECK_DATA",
                ]
            )
            assert_invariants(
                parse_result(full_line_output),
                expected_requests=count_trace_requests("test/full_line_trace.txt"),
            )
            rows.append((name, standard))

        latency_output = execute(
            [
                "vvp",
                str(Path(temp_dir) / "direct"),
                "+TRACE=test/latency_trace.txt",
                "+CHECK_DATA",
                "+VERBOSE",
            ]
        )
        observed_cycles = [
            int(value)
            for value in re.findall(r"REQUEST_COMPLETE .* cycles=(\d+)", latency_output)
        ]
        assert observed_cycles == [115, 1], observed_cycles

    print(
        "configuration  requests  l1_hits  l2_hits  writebacks  "
        "mem_reads  mem_writes  cycles  avg_cycles"
    )
    for name, result in rows:
        average = result["cycles"] / result["requests"]
        print(
            f"{name:<14} {result['requests']:>8} {result['l1_hits']:>8} "
            f"{result['l2_hits']:>8} {result['writebacks']:>11} "
            f"{result['memory_reads']:>9} {result['memory_writes']:>10} "
            f"{result['cycles']:>7} {average:>10.2f}"
        )
    print(
        "PASS: configuration, handshake, word-offset, full-line, latency, "
        "and writeback regressions"
    )


if __name__ == "__main__":
    main()
