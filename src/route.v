module main

import time
import vweb

['/api/get-stars'; get]
pub fn (mut app App) route_api_get_stars() vweb.Result {
	return app.json({
		'count': 2
		'max':   150
	})
}

['/api/get-week'; get]
pub fn (mut app App) route_app_get_week() vweb.Result {
	date := time.now().get_fmt_date_str(.hyphen, .yyyymmdd)
	return app.route_app_get_week_date(date)
}

['/api/get-week/:date'; get]
pub fn (mut app App) route_app_get_week_date(date string) vweb.Result {
	return app.error_response(501)
}
