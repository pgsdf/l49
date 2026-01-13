# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Pacific Grove Software Distribution Foundation

ZIG ?= zig
REQ_ZIG_VERSION := 0.15.2

check_zig:
	@v=`$(ZIG) version`; \
	if [ "$$v" != "$(REQ_ZIG_VERSION)" ]; then \
		echo "error: Zig $$v found, but $(REQ_ZIG_VERSION) is required"; \
		exit 1; \
	fi

obj: check_zig
	$(ZIG) build -Demit-obj=true

clean:
	rm -rf zig-out .zig-cache
