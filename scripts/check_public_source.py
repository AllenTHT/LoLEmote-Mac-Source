#!/usr/bin/env python3
"""Verify the public file allowlist in the Git index and every local commit."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FIXED = {
    '.gitignore', 'LICENSE', 'README.md', 'THIRD_PARTY_NOTICES.md', 'Package.swift', 'requirements-assets.txt',
    'Resources/Info.plist', 'Resources/emotes.json',
    'research_assets/expansion-catalog.json', 'research_assets/audio-release.json',
    'research_assets/animation-textures.json', 'research_assets/target-events.json',
}


def allowed(name):
    path = Path(name)
    if name in FIXED:
        return True
    if path.parts[0] in ('Sources', 'Tests'):
        return path.suffix == '.swift'
    if path.parts[0] == 'scripts':
        return path.suffix in ('.swift', '.py', '.sh')
    return path.parts[0] == 'docs' and path.suffix == '.md'


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])


def main():
    if not (ROOT / '.git').exists():
        # Download ZIPs have no Git metadata: inspect all nonignored public paths.
        names = [str(p.relative_to(ROOT)) for p in ROOT.rglob('*') if p.is_file() and
                 not any(part in ('.build', '.venv', '.asset-cache', 'dist', '__pycache__', 'Verification') for part in p.relative_to(ROOT).parts) and
                 not str(p.relative_to(ROOT)).startswith(('Resources/Emotes/', 'Resources/Sounds/', 'Resources/Animations/')) and
                 str(p.relative_to(ROOT)) not in ('Resources/asset-sources.json', 'research_assets/expansion-sources.json', 'research_assets/expansion-events.json', 'research_assets/animation-build.json') and
                 not str(p.relative_to(ROOT)).startswith('research_assets/audio-events/')]
        failures = [name for name in names if not allowed(name)]
    else:
        if Path(git('rev-parse', '--show-toplevel').decode().strip()).resolve() != ROOT.resolve():
            raise SystemExit('FAIL: initialize an independent Git repository in this source directory')
        names = git('ls-files', '--cached', '--others', '--exclude-standard', '-z').decode().split('\0')
        failures = [name for name in names if name and not allowed(name)]
        for revision in git('rev-list', '--all').decode().splitlines():
            history = git('ls-tree', '-r', '--name-only', '-z', revision).decode().split('\0')
            failures.extend(f'{revision[:7]}: {name}' for name in history if name and not allowed(name))
    if failures:
        print('FAIL: paths outside the public source allowlist:', *sorted(set(failures)), sep='\n')
        return 1
    print('PASS public allowlist: only code, docs and selected reference configuration; no tracked game media/history.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
