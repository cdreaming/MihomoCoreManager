#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import sys


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def build_manifest(app: Path) -> dict:
    app = app.resolve()
    if not app.is_dir() or app.suffix != '.app':
        raise SystemExit(f'not an .app bundle: {app}')

    entries: list[dict] = []
    for current, dirs, files in os.walk(app, followlinks=False):
        current_path = Path(current)

        # os.walk will list symlinked directories in dirs; hash their targets
        # instead of walking through them.
        keep_dirs: list[str] = []
        for name in sorted(dirs):
            p = current_path / name
            rel = p.relative_to(app).as_posix()
            if p.is_symlink():
                entries.append({
                    'path': rel,
                    'type': 'symlink',
                    'target': os.readlink(p),
                })
            else:
                keep_dirs.append(name)
        dirs[:] = keep_dirs

        for name in sorted(files):
            p = current_path / name
            rel = p.relative_to(app).as_posix()
            if p.is_symlink():
                entries.append({
                    'path': rel,
                    'type': 'symlink',
                    'target': os.readlink(p),
                })
            elif p.is_file():
                entries.append({
                    'path': rel,
                    'type': 'file',
                    'size': p.stat().st_size,
                    'sha256': sha256_file(p),
                })

    entries.sort(key=lambda item: (item['path'], item['type']))
    digest = hashlib.sha256(
        json.dumps(entries, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode('utf-8')
    ).hexdigest()
    return {
        'format': 1,
        'bundle': app.name,
        'entry_count': len(entries),
        'tree_sha256': digest,
        'entries': entries,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description='Create a deterministic content manifest for a macOS .app bundle.'
    )
    parser.add_argument('app', type=Path)
    parser.add_argument('--output', '-o', type=Path)
    args = parser.parse_args()

    payload = json.dumps(build_manifest(args.app), ensure_ascii=False, indent=2, sort_keys=True) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload, encoding='utf-8')
    else:
        sys.stdout.write(payload)


if __name__ == '__main__':
    main()
