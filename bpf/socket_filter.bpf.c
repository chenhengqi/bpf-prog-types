// SPDX-License-Identifier: (LGPL-2.1 OR BSD-2-Clause)
/* Copyright (c) 2021 Hengqi Chen */
#include <vmlinux.h>
#include <bpf/bpf_helpers.h>

SEC("socket")
int socket_filter(struct __sk_buff* skb)
{
	if (skb->protocol == IPPROTO_UDP)
		return skb->len;
	return 0;
}

char LICENSE[] SEC("license") = "Dual BSD/GPL";
