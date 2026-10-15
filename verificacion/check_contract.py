#!/usr/bin/env python3
"""Checks the app against the real API contract (backend/openapi.json).

It verifies, without running the app:

  1. every endpoint the app calls exists in the OpenAPI document with the same
     HTTP method (`http` verb of ApiClient: get/post/patch);
  2. every JSON field the app reads or writes (`json['field']`, `'field':` in a
     request body) is a property of some schema of the API, or a documented
     enum value;
  3. every error code the app knows about exists in the backend source
     (`backend/app/**/*.py`, `code="..."`).

Usage:  python3 verificacion/check_contract.py
"""
import json
import os
import re
import sys

ROOT = '/opt/data/workspace/tp-electiva2'
APP = os.path.join(ROOT, 'app')
BACKEND = os.path.join(ROOT, 'backend')

# Keys that are not API fields: local storage keys of shared_preferences.
LOCAL_STORAGE_KEYS = {'auth_token', 'auth_user'}

CALL_RE = re.compile(
    r"""\.(get|post|patch)(?:Map|Items)?\(\s*'([^']+)'""", re.MULTILINE
)
FIELD_READ_RE = re.compile(r"""\[['"]([a-z][a-z0-9_]*)['"]\]""")
FIELD_WRITE_RE = re.compile(r"""['"]([a-z][a-z0-9_]*)['"]\s*:""")
CODE_DEF_RE = re.compile(r"""static const String (\w+) = '([a-z0-9_]+)';""")


def normalize_path(path: str) -> str:
    """`/venues/$venueId` and `/venues/{venue_id}` -> `/venues/{param}`."""
    path = re.sub(r'\$\{[^}]+\}|\$[A-Za-z_][A-Za-z0-9_]*', '{param}', path)
    return re.sub(r'\{[^}]+\}', '{param}', path)


def dart_files(*relative_dirs: str) -> list:
    files = []
    for relative in relative_dirs:
        base = os.path.join(APP, relative)
        for dirpath, _dirnames, filenames in os.walk(base):
            for name in sorted(filenames):
                if name.endswith('.dart'):
                    files.append(os.path.join(dirpath, name))
    return files


def load_contract() -> dict:
    with open(os.path.join(BACKEND, 'openapi.json'), encoding='utf-8') as handle:
        spec = json.load(handle)

    paths = {}
    for path, methods in spec['paths'].items():
        paths[normalize_path(path)] = {
            verb.upper() for verb in methods if verb in ('get', 'post', 'patch')
        }

    schemas = spec['components']['schemas']
    fields = set()
    for schema in schemas.values():
        fields.update(schema.get('properties', {}).keys())
    enums = set()
    for schema in schemas.values():
        enum = schema.get('enum')
        if enum:
            enums.update(enum)
        for prop in schema.get('properties', {}).values():
            if prop.get('enum'):
                enums.update(prop['enum'])
    return {'paths': paths, 'fields': fields, 'enums': enums}


def backend_error_codes() -> set:
    """Error codes raised/documented by the backend.

    Two sources: the sources themselves and `docs/api.md`. In the sources the
    codes show up in three shapes: `code="..."`, `code = "..."` (class
    attributes, e.g. `ForbiddenError.code = "forbidden"`) and the
    `_STATUS_CODE_NAMES` map (`405: "method_not_allowed"`), which is what the
    generic handlers use for the codes no endpoint raises by hand.
    """
    codes = set()
    for dirpath, _dirnames, filenames in os.walk(BACKEND):
        if 'site-packages' in dirpath or '.venv' in dirpath:
            continue
        for name in filenames:
            if not name.endswith('.py'):
                continue
            with open(os.path.join(dirpath, name), encoding='utf-8') as handle:
                source = handle.read()
            codes.update(re.findall(r"""code\s*=\s*["']([a-z0-9_]+)["']""", source))
            codes.update(re.findall(r"""^\s*\d{3}\s*:\s*["']([a-z0-9_]+)["']""", source, re.M))

    docs = os.path.join(BACKEND, 'docs', 'api.md')
    if os.path.exists(docs):
        with open(docs, encoding='utf-8') as handle:
            content = handle.read()
        for line in content.splitlines():
            if line.startswith('| `'):
                codes.update(re.findall(r'`([a-z][a-z0-9_]{3,})`', line))
    return codes


def main() -> int:
    contract = load_contract()
    app_files = dart_files('lib')
    service_files = dart_files('lib/services')
    print(f"app dart files scanned : {len(app_files)}")
    print(f"paths in openapi.json  : {len(contract['paths'])}")
    print(f"schemas fields         : {len(contract['fields'])}")

    problems = []

    # 1. endpoints -----------------------------------------------------------
    calls = []
    for path in service_files:
        with open(path, encoding='utf-8') as handle:
            for verb, raw_path in CALL_RE.findall(handle.read()):
                calls.append((verb.upper(), raw_path, normalize_path(raw_path), path))

    print(f"\nendpoint calls found   : {len(calls)}")
    seen = set()
    for verb, raw_path, normalized, path in sorted(calls, key=lambda item: item[2]):
        key = (verb, normalized)
        if key in seen:
            continue
        seen.add(key)
        declared = contract['paths'].get(normalized)
        if declared is None:
            problems.append(f"endpoint not in openapi.json: {verb} {raw_path}")
            status = 'MISSING'
        elif verb not in declared:
            problems.append(
                f"method mismatch for {raw_path}: app uses {verb}, "
                f"API declares {sorted(declared)}"
            )
            status = 'METHOD MISMATCH'
        else:
            status = 'ok'
        print(f"  {status:16} {verb:5} {raw_path}")

    # 2. JSON fields ---------------------------------------------------------
    unknown = {}
    used = set()
    for path in app_files:
        with open(path, encoding='utf-8') as handle:
            content = handle.read()
        names = set(FIELD_READ_RE.findall(content)) | set(FIELD_WRITE_RE.findall(content))
        for name in names:
            used.add(name)
            known = (
                name in contract['fields']
                or name in contract['enums']
                or name in LOCAL_STORAGE_KEYS
            )
            if not known:
                unknown.setdefault(name, []).append(os.path.relpath(path, APP))

    print(f"\nJSON field names used  : {len(used)}")
    print(f"  traced to openapi    : {len(used) - len(unknown)}")
    print(f"  not traced           : {len(unknown)}")
    for name, files in sorted(unknown.items()):
        problems.append(f"field '{name}' is not in openapi.json ({', '.join(files)})")
        print(f"  UNKNOWN {name} ({', '.join(files)})")

    # 3. error codes ---------------------------------------------------------
    with open(os.path.join(APP, 'lib/models/api_error.dart'), encoding='utf-8') as handle:
        declared_codes = dict(CODE_DEF_RE.findall(handle.read()))
    client_side = {
        'network_error',
        'timeout_error',
        'unexpected_error',
    }
    backend_codes = backend_error_codes()
    print(f"\nerror codes in the app : {len(declared_codes)}")
    unmatched = []
    for name, value in sorted(declared_codes.items()):
        if value in backend_codes or value in client_side:
            continue
        unmatched.append((name, value))
    print(f"  found in the backend : {len(declared_codes) - len(unmatched) - len(client_side)}")
    print(f"  client side only     : {len(client_side)}")
    for name, value in unmatched:
        # Codes of the OpenAPI schema that the backend raises elsewhere.
        problems.append(f"error code '{value}' ({name}) not found in backend/app")
        print(f"  UNMATCHED {value} ({name})")

    print('\nbackend error codes    :', len(backend_codes))
    print('result:', 'FAIL' if problems else 'OK (app matches the API contract)')
    if problems:
        print('\nproblems:')
        for problem in problems:
            print(' -', problem)
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
