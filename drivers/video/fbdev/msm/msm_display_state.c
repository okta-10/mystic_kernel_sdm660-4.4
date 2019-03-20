// SPDX-License-Identifier: GPL-2.0
/*
 * Simple display state tracker
 *
 * Copyright (C) 2019 Danny Lin <danny@kdrag0n.dev>.
 * Copyright (C) 2019 Brian Dashore (kingbri) <bdashore3@gmail.com>
 */

#define pr_fmt(fmt) "display_state: " fmt

#include <linux/moduleparam.h>
#include <linux/fb.h>

static bool display_on = true;
module_param(display_on, bool, 0444);

bool is_display_on(void)
{
	return display_on;
}

static int fb_notifier_cb(struct notifier_block *nb,
			       unsigned long event, void *data)
{
	struct fb_event *evdata = data;
	unsigned int blank;

	if (event != FB_EVENT_BLANK && event != FB_EARLY_EVENT_BLANK)
		return NOTIFY_DONE;

	if (!evdata || !evdata->data)
		return NOTIFY_DONE;

	blank = *(unsigned int *)evdata->data;

	switch (blank) {
	case FB_BLANK_POWERDOWN:
		if (event == FB_EARLY_EVENT_BLANK)
			display_on = false;
		break;
	case FB_BLANK_UNBLANK:
		if (event == FB_EVENT_BLANK)
			display_on = true;
		break;
	}

	return NOTIFY_OK;
}

static struct notifier_block display_state_nb __ro_after_init = {
	.notifier_call = fb_notifier_cb,
};

static int __init display_state_init(void)
{
	int ret;

	ret = fb_register_client(&display_state_nb);
	if (ret)
		pr_err("Failed to register msm_drm notifier, err: %d\n", ret);

	return ret;
}
late_initcall(display_state_init);
