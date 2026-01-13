/* SPDX-License-Identifier: MIT */
/* Copyright (c) 2026 Pacific Grove Software Distribution Foundation */

#include "l49_shim.h"

#include <l4/sys/ipc.h>
#include <l4/sys/utcb.h>
#include <l4/re/env.h>
#include <l4/sys/vcon.h>

#include <string.h>

static int
copy_in_words(void const *src, size_t src_len)
{
  l4_msg_regs_t *mr = l4_utcb_mr();
  unsigned words = (unsigned)((src_len + sizeof(l4_umword_t) - 1) / sizeof(l4_umword_t));

  if (words > L4_UTCB_GENERIC_DATA_SIZE)
    return -1;

  memset(mr->mr, 0, words * sizeof(l4_umword_t));
  memcpy(mr->mr, src, src_len);
  return (int)words;
}

static int
copy_out_words(void *dst, size_t dst_cap, size_t *out_len, l4_msgtag_t tag)
{
  l4_msg_regs_t *mr = l4_utcb_mr();
  unsigned words = l4_msgtag_words(tag);
  size_t bytes = (size_t)words * sizeof(l4_umword_t);

  if (bytes > dst_cap)
    bytes = dst_cap;

  memcpy(dst, mr->mr, bytes);
  if (out_len)
    *out_len = bytes;
  return 0;
}

void
l49_puts(char const *s)
{
  if (!s)
    return;

  size_t n = strlen(s);
  if (n > L4_VCON_WRITE_SIZE)
    n = L4_VCON_WRITE_SIZE;

  l4_vcon_send(L4_BASE_LOG_CAP, s, (int)n);
}

uint32_t
l49_get_cap(char const *name)
{
  if (!name)
    return 0;

  l4_cap_idx_t c = l4re_env_get_cap(name);
  if (l4_is_invalid_cap(c))
    return 0;

  return (uint32_t)c;
}

int
l49_ipc_send(uint32_t endpoint_cap, void const *msg, size_t msg_len)
{
  int words = copy_in_words(msg, msg_len);
  if (words < 0)
    return -1;

  l4_msgtag_t t = l4_msgtag(0, (unsigned)words, 0, 0);
  l4_msgtag_t r = l4_ipc_send((l4_cap_idx_t)endpoint_cap, l4_utcb(), t, L4_IPC_NEVER);

  return l4_ipc_error(r, l4_utcb()) ? -1 : 0;
}

int
l49_ipc_recv(uint32_t endpoint_cap, void *buf, size_t buf_cap, size_t *out_len)
{
  l4_msgtag_t r;

  if (endpoint_cap)
    r = l4_ipc_receive((l4_cap_idx_t)endpoint_cap, l4_utcb(), L4_IPC_NEVER);
  else {
    l4_umword_t label = 0;
    r = l4_ipc_wait(l4_utcb(), &label, L4_IPC_NEVER);
    (void)label;
  }

  if (l4_ipc_error(r, l4_utcb()))
    return -1;

  return copy_out_words(buf, buf_cap, out_len, r);
}

int
l49_ipc_reply(void const *msg, size_t msg_len)
{
  int words = copy_in_words(msg, msg_len);
  if (words < 0)
    return -1;

  l4_umword_t label = 0;
  l4_msgtag_t t = l4_msgtag(0, (unsigned)words, 0, 0);
  l4_msgtag_t r = l4_ipc_reply_and_wait(l4_utcb(), t, &label, L4_IPC_RECV_TIMEOUT_0);

  (void)label;

  /* Timeout on wait phase is fine, reply has already been sent. */
  return l4_ipc_error(r, l4_utcb()) ? 0 : 0;
}

int
l49_ipc_call(uint32_t endpoint_cap,
             void const *req, size_t req_len,
             void *rep, size_t rep_cap, size_t *out_len)
{
  int words = copy_in_words(req, req_len);
  if (words < 0)
    return -1;

  l4_msgtag_t t = l4_msgtag(0, (unsigned)words, 0, 0);
  l4_msgtag_t r = l4_ipc_call((l4_cap_idx_t)endpoint_cap, l4_utcb(), t, L4_IPC_NEVER);

  if (l4_ipc_error(r, l4_utcb()))
    return -1;

  return copy_out_words(rep, rep_cap, out_len, r);
}
