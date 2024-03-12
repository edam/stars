module cmds

import api
import time

pub fn (mut c Client) latest() ! {
	sw := time.new_stopwatch()
	c.auth()!
	draw_weekly_stars(latest, c.get[api.GetPrizesWeeks]('/api/prizes/cur/weeks/latest')!)
	draw_server_line(c.host, sw.elapsed().milliseconds())
}
