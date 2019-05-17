/* SPDX-License-Identifier: GPL-2.0 */
#undef TRACE_SYSTEM
#define TRACE_SYSTEM devfreq

#if !defined(_TRACE_DEVFREQ_H) || defined(TRACE_HEADER_MULTI_READ)
#define _TRACE_DEVFREQ_H

#include <linux/devfreq.h>
#include <linux/tracepoint.h>

TRACE_EVENT(devfreq_monitor,
	TP_PROTO(const char *dev_name, unsigned long freq,
		 unsigned int polling_ms, unsigned long busy_time,
		 unsigned long total_time),

	TP_ARGS(dev_name, freq, polling_ms, busy_time, total_time),

	TP_STRUCT__entry(
		__string(dev_name, dev_name)
		__field(unsigned long, freq)
		__field(unsigned int, polling_ms)
		__field(unsigned int, load)
	),

	TP_fast_assign(
		__assign_str(dev_name, dev_name);
		__entry->freq = freq;
		__entry->polling_ms = polling_ms;
		__entry->load = (100 * busy_time) / total_time;
	),

	TP_printk("dev_name=%s freq=%lu polling_ms=%u load=%u",
		__get_str(dev_name), __entry->freq, __entry->polling_ms,
		__entry->load)
);
#endif /* _TRACE_DEVFREQ_H */

/* This part must be outside protection */
#include <trace/define_trace.h>