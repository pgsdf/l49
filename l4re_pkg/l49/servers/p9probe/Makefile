# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Pacific Grove Software Distribution Foundation

PKGDIR ?= .
L4DIR  ?= $(PKGDIR)/../../../..

TARGET  = p9probe
MODE    = static

SRC_C   = ../../shim/l49_shim.c
CFLAGS  += -I../../shim

SRC_O   = \
  zig/zig-out/obj/p9probe_main.o \
  zig/zig-out/obj/p9_codec.o \
  zig/zig-out/obj/p9probe.o

all:: zig_objs

zig_objs:
	$(MAKE) -C zig obj

clean::
	$(MAKE) -C zig clean

include $(L4DIR)/mk/prog.mk
