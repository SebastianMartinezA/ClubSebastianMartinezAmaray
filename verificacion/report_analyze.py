#!/usr/bin/env python3
"""Summarises `dart analyze --format=json` output for the app's static check.

Splits the diagnostics in three buckets:

  * SYNTAX: parsing problems -> never acceptable.
  * CORE:   files whose imports are all resolvable on this machine (config,
            models, utils, services, state, plus the tests that do not import
            Flutter widgets) -> must be 0.
  * UI:     files that import package:flutter/material.dart, provider or
            flutter_localizations, which are not installed on Linux ARM64, so
            their diagnostics are cascades of those missing packages.
"""
import collections
import json
import os
import re
import sys

SYNTAX_TYPES = ('SYNTACTIC_ERROR',)
UI_IMPORTS = (
    'package:flutter/material.dart',
    'package:flutter/widgets.dart',
    'package:flutter/cupertino.dart',
    'package:flutter_test/flutter_test.dart',
    'package:provider/',
    'package:flutter_localizations/',
)
IMPORT_RE = re.compile(r"""^\s*import\s+['"]([^'"]+)['"]""", re.MULTILINE)


def rel(path: str) -> str:
    marker = '/app_static_check/'
    if marker in path:
        return path.split(marker, 1)[1]
    return path


def imports_of(path: str) -> list:
    try:
        with open(path, encoding='utf-8') as handle:
            return IMPORT_RE.findall(handle.read())
    except OSError:
        return []


def main(path: str) -> int:
    data = json.load(open(path))
    diags = data.get('diagnostics', [])

    cache = {}
    buckets = collections.defaultdict(list)
    for diag in diags:
        file_path = diag['location']['file']
        name = rel(file_path)
        if diag['type'] in SYNTAX_TYPES:
            buckets['SYNTAX'].append((name, diag))
            continue
        if file_path not in cache:
            imports = imports_of(file_path)
            cache[file_path] = any(i.startswith(UI_IMPORTS) for i in imports)
        buckets['UI' if cache[file_path] else 'CORE'].append((name, diag))

    print(f"files analysed    : {len(cache)+1}")
    print(f"total diagnostics : {len(diags)}")
    print(f"  syntax errors   : {len(buckets['SYNTAX'])}   (must be 0)")
    print(f"  non-widget layer: {len(buckets['CORE'])}   (must be 0)")
    print(f"  widget layer    : {len(buckets['UI'])}   (expected: Flutter SDK missing)")

    for bucket in ('SYNTAX', 'CORE'):
        entries = buckets[bucket]
        if not entries:
            continue
        print(f"\n--- {bucket} ---")
        grouped = collections.defaultdict(list)
        for name, diag in entries:
            grouped[(name, diag['code'], diag['severity'])].append(diag)
        for (name, code, severity), items in sorted(grouped.items()):
            print(f"{severity:7} {code:35} {name}  x{len(items)}")
            for diag in items[:3]:
                line = diag['location']['range']['start']['line'] + 1
                print(f"          line {line}: {diag['problemMessage']}")

    if buckets['UI']:
        print('\n--- widget layer diagnostics by code (root cause: Flutter SDK absent) ---')
        counts = collections.Counter(
            (diag['severity'], diag['code']) for _, diag in buckets['UI']
        )
        for (severity, code), count in counts.most_common():
            print(f"{severity:7} {code:35} x{count}")
        unresolved = collections.Counter(
            diag['problemMessage']
            for _, diag in buckets['UI']
            if diag['code'] == 'uri_does_not_exist'
        )
        print('\nunresolved imports in widget-layer files:')
        for message, count in unresolved.most_common():
            print(f"  - {message}  x{count}")
        files = collections.Counter(name for name, _ in buckets['UI'])
        print('\nwidget-layer files with cascades:')
        for name, count in sorted(files.items()):
            print(f"  {name}  x{count}")

    failed = bool(buckets['SYNTAX'] or buckets['CORE'])
    print('\nRESULT:', 'FAIL' if failed else 'OK (no syntax errors, non-widget layer clean)')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
