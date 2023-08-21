module main

import vweb
import lambdas
import time

struct GetStarsResponse {
	count int
	max   int
}

['/api/get-stars'; get]
pub fn (mut app App) route_api_get_stars() vweb.Result {
	if res := lambdas.get_stars() {
		return app.json(res)
	} else {
		return app.handle(err)
	}
}

['/api/get-week'; get]
pub fn (mut app App) route_app_get_week() vweb.Result {
	date := time.now().get_fmt_date_str(.hyphen, .yyyymmdd)
	return app.route_app_get_week_date(date)
}

['/api/get-week/:date'; get]
pub fn (mut app App) route_app_get_week_date(date string) vweb.Result {
	if res := lambdas.get_week(date) {
		return app.json(res)
	} else {
		return app.handle(err)
	}
}
