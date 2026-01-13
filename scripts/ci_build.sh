# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Pacific Grove Software Distribution Foundation

#!/bin/sh
set -eu
scripts/zig_check.sh
zig test tests/unit/p9_codec_walk_test.zig
zig test tests/unit/p9_codec_version_test.zig
echo "ok: unit tests passed"
