/* SPDX-License-Identifier: MIT */
/* Copyright (c) 2026 Pacific Grove Software Distribution Foundation */

#pragma once
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void l49_puts(char const *s);
uint32_t l49_get_cap(char const *name);

int l49_ipc_send(uint32_t endpoint_cap, void const *msg, size_t msg_len);
int l49_ipc_recv(uint32_t endpoint_cap, void *buf, size_t buf_cap, size_t *out_len);
int l49_ipc_reply(void const *msg, size_t msg_len);

/* Optional call helper used by p9root to talk to p9cons */
int l49_ipc_call(uint32_t endpoint_cap,
                 void const *req, size_t req_len,
                 void *rep, size_t rep_cap, size_t *out_len);

#ifdef __cplusplus
}
#endif
