module cmds

import api
import time

pub fn (mut c Client) latest() ! {
	sw := time.new_stopwatch()
	c.auth()!
	draw_weekly_stars(latest, c.get[api.ApiWeek]('/api/prize/cur/week/latest')!)
	draw_server_line(c.host, sw.elapsed().milliseconds())
}
