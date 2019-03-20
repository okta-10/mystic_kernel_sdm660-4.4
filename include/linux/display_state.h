/* SPDX-License-Identifier: GPL-2.0
 *
 * Copyright (C) 2019 Danny Lin <danny@kdrag0n.dev>.
 * Copyright (C) 2019 Brian Dashore (kingbri) <bdashore3@gmail.com>
 */

#ifndef _DISPLAY_STATE_H_
#define _DISPLAY_STATE_H_

#ifdef CONFIG_FB_MSM_MDSS
bool is_display_on(void);
#else
static inline bool is_display_on(void)
{
	return true;
}
#endif

#endif /* _DISPLAY_STATE_H_ */
