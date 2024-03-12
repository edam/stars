module cmds

import api
import time

pub fn (mut c Client) last() ! {
	sw := time.new_stopwatch()
	c.auth()!
	draw_weekly_stars(last_week, c.get[api.GetPrizesWeeks]('/api/prizes/cur/weeks/last')!)
	draw_server_line(c.host, sw.elapsed().milliseconds())
}
