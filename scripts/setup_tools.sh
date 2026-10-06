#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
# Explicitly invoked maintenance setup; normal builds never install these tools.
PYTHON_EXECUTABLE="${PYTHON_EXECUTABLE:-python3}"
"$PYTHON_EXECUTABLE" -c 'import sys; assert sys.version_info >= (3, 11), "Python 3.11 or newer is required"'
"$PYTHON_EXECUTABLE" -m venv .venv
.venv/bin/python -m pip install -r requirements-assets.txt
mkdir -p .asset-cache/tools
.venv/bin/python - <<'PY'
from pathlib import Path
import urllib.request
path = Path('.asset-cache/tools/wwiser.pyz')
if not path.exists():
    url = 'https://github.com/bnnm/wwiser/releases/download/v20260808/wwiser.pyz'
    temporary = path.with_suffix('.download')
    urllib.request.urlretrieve(url, temporary)
    temporary.replace(path)
PY
VGMSTREAM_REVISION="7dc938fa2f210943b37c7b6511852b516ef432ab"
OGG_REVISION="fa80aae9d50096160f2b56ada35527d7aee3f746"
VORBIS_REVISION="2eac96b03ff67953354cb0a649c08aa3a23267ef"
.venv/bin/python - "$VGMSTREAM_REVISION" "$OGG_REVISION" "$VORBIS_REVISION" <<'PYTOOLS'
from pathlib import Path
import os
import sys
import tarfile
import urllib.request

tools = Path('.asset-cache/tools').resolve()
for repository, revision in zip(('vgmstream/vgmstream', 'xiph/ogg', 'xiph/vorbis'), sys.argv[1:]):
    project = repository.split('/')[1]
    source = tools / f'{project}-{revision}'
    if (source / 'CMakeLists.txt').exists():
        continue
    archive = tools / f'{project}-{revision}.tar.gz'
    if not archive.exists():
        url = f'https://codeload.github.com/{repository}/tar.gz/{revision}'
        print(f'Downloading pinned source: {repository} {revision}', flush=True)
        with urllib.request.urlopen(url, timeout=60) as response:
            payload = response.read()
        temporary = archive.with_suffix('.download')
        temporary.write_bytes(payload)
        temporary.replace(archive)
    with tarfile.open(archive) as bundle:
        for member in bundle.getmembers():
            destination = (tools / member.name).resolve()
            if not destination.is_relative_to(source):
                raise RuntimeError('Archive entry is outside the pinned source directory')
            if member.isdir():
                destination.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(bundle.extractfile(member).read())
                os.chmod(destination, member.mode & 0o777)
            else:
                raise RuntimeError('Unexpected non-file entry in source archive')
PYTOOLS
.venv/bin/cmake -S "$PWD/.asset-cache/tools/vgmstream-$VGMSTREAM_REVISION" -B .asset-cache/tools/vgmstream-build \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_CLI=ON -DBUILD_AUDACIOUS=OFF -DBUILD_V123=OFF \
    -DBUILD_FRAMEWORK=OFF -DBUILD_STATIC=OFF -DUSE_VORBIS=ON \
    -DOGG_PATH="$PWD/.asset-cache/tools/ogg-$OGG_REVISION" \
    -DVORBIS_PATH="$PWD/.asset-cache/tools/vorbis-$VORBIS_REVISION" \
    -DUSE_ATRAC9=OFF -DUSE_CELT=OFF -DUSE_FFMPEG=OFF -DUSE_G719=OFF \
    -DUSE_G7221=OFF -DUSE_MPEG=OFF -DUSE_SPEEX=OFF
.venv/bin/cmake --build .asset-cache/tools/vgmstream-build --config Release --target vgmstream_cli -j 4
print 'Maintenance tools ready. Run .venv/bin/python scripts/setup_assets.py --full'
