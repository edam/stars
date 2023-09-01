module main

import time
import vweb
import util

const prize_id = 1

struct RoutePrizeCur {
	prize_id u64
	count    int
	pot      int
	goal     int
}

['/api/prize/cur'; get]
pub fn (mut app App) route_prize_cur() vweb.Result {
	prize := app.db.get_cur_prize() or { return app.error_result(500) }
	count := app.db.get_cur_star_count() or { return app.error_result(500) }
	return app.json(RoutePrizeCur{
		prize_id: prize.id
		count: count
		pot: count * prize.starval
		goal: prize.goal
	})
}

['/api/week/cur'; get]
pub fn (mut app App) route_week_cur() vweb.Result {
	prize := app.db.get_cur_prize() or { return app.error_result(500) }
	date := time.now().get_fmt_date_str(.hyphen, .yyyymmdd)
	return app.route_week_prize_date(prize.id, date)
}

struct RouteWeekStar {
	at  string
	got bool
}

struct RouteWeek {
	stars []RouteWeekStar
	from  string
	till  string
}

['/api/week/:prize_id/:date'; get]
pub fn (mut app App) route_week_prize_date(prize_id u64, date string) vweb.Result {
	sow := util.sdate_week_start(date) or { return app.error_result(500) }
	from := util.sdate_add(sow, 4) or { '' }
	till := util.sdate_add(from, 6) or { '' }
	stars := app.db.get_stars(prize_id, from, till) or { return app.error_result(500) }
	mut sstars := []RouteWeekStar{}
	for star in stars {
		sstars << RouteWeekStar{
			at: star.at
			got: star.got
		}
	}
	return app.json(RouteWeek{
		from: from
		till: till
		stars: sstars
	})
}
