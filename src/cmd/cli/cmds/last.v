module cmds

import api
import time

pub fn (mut c Client) last() ! {
	sw := time.new_stopwatch()
	c.auth()!
	draw_weekly_stars(false, c.get[api.ApiWeek]('/api/prize/cur/week/last')!)
	draw_server_line(c.host, sw.elapsed().milliseconds())
}
