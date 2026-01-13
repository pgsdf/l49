# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Pacific Grove Software Distribution Foundation

#!/bin/sh
set -eu
REQ="0.15.2"
ZIG="${ZIG:-zig}"
V="$($ZIG version)"
if [ "$V" != "$REQ" ]; then
  echo "error: Zig $V found, but $REQ is required"
  exit 1
fi
echo "ok: Zig $V"
