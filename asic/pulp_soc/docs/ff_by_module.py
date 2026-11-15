#!/usr/bin/env python3
"""Count flip-flops / latches per hierarchy in a flattened Yosys netlist.

Usage:  python3 ff_by_module.py runs/syn_03/final/nl/pulp_soc.nl.v [depth]
Groups each sequential cell by the hierarchical name of the net on its Q pin.
"""
import re, sys, collections

nl = sys.argv[1]
depth = int(sys.argv[2]) if len(sys.argv) > 2 else 3
cell_re = re.compile(r'^\s*(sky130_fd_sc_\w+__(?:df|dl|sdf|edf)\w*)\s+\S+\s*\(', re.S)
q_re = re.compile(r'\.Q(?:_N)?\s*\(\s*(\\\S+|[^\s)]+)')

counts, kinds = collections.Counter(), collections.Counter()
text = open(nl, errors="ignore").read()
for stmt in text.split(';'):
    m = cell_re.match(stmt)
    if not m:
        continue
    kinds[m.group(1)] += 1
    q = q_re.search(stmt)
    name = q.group(1).lstrip('\\') if q else '<no Q>'
    name = re.sub(r'\[\d+\]$', '', name)
    if name.startswith('_') or name.startswith('<'):
        key = '<anonymous net>'
    else:
        key = '.'.join(re.sub(r'\[\d+\]', '[*]', name).split('.')[:depth])
    counts[key] += 1

total = sum(counts.values())
print(f"total sequential cells: {total}")
for k, v in kinds.most_common():
    print(f"  {k:32s} {v}")
print(f"\n{'count':>8} {'%':>6}  hierarchy (depth={depth})")
for k, v in counts.most_common(60):
    print(f"{v:8d} {100*v/total:6.1f}  {k}")
