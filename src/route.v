module main

import time
import vweb
import util

const prize_id = 1

['/api/cur-prize'; get]
pub fn (mut app App) route_api_get_stars() vweb.Result {
	prize := app.db.get_cur_prize() or { return app.error_result(500) }
	count := app.db.get_cur_star_count() or { return app.error_result(500) }
	return app.json({
		'prize_id': int(prize.id)
		'count':    count
		'pot':      count * prize.starval
		'goal':     prize.goal
	})
}

['/api/get-week'; get]
pub fn (mut app App) route_app_get_week() vweb.Result {
	date := time.now().get_fmt_date_str(.hyphen, .yyyymmdd)
	return app.route_app_get_week_date(date)
}

['/api/get-week/:date'; get]
pub fn (mut app App) route_app_get_week_date(date string) vweb.Result {
	// date := util.start_of_week(date)
	sow := util.sdate_week_start(date) or { return app.error_result(500) }
	println(sow)
	return app.error_result(501)
}
