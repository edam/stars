module main

import vweb
import util
import api
import rand
import crypto.sha256

['/api/auth/:username'; get]
pub fn (mut app App) route_auth(username string) !vweb.Result {
	challenge := rand.uuid_v4()
	if user := app.db.get_user(username) {
		session_id := sha256.hexhash('${user.psk}:${challenge}')
		app.sessions.add(session_id, user.id, user.perms)!
	}
	return app.json(api.ApiAuth{
		challenge: challenge
	})
}

[middleware: check_auth]
['/api/prize/cur'; get]
pub fn (mut app App) route_prize_cur() !vweb.Result {
	prize := app.db.get_cur_prize()!
	count := app.db.get_cur_star_count()!
	deposits := app.db.get_cur_deposits()!
	return app.json(api.ApiPrizeCur{
		prize_id: prize.id
		start: prize.start or { '' }
		stars: count
		goal: prize.goal
		got: struct {
			stars: count * prize.star_val
			deposits: deposits
		}
	})
}

[middleware: check_auth]
['/api/week/cur'; get]
pub fn (mut app App) route_week_cur() !vweb.Result {
	prize := app.db.get_cur_prize()!
	date := util.sdate_now()
	return app.route_week_prize_date(prize.id, date)!
}

[middleware: check_auth]
['/api/week/last'; get]
pub fn (mut app App) route_week_last() !vweb.Result {
	prize := app.db.get_cur_prize()!
	date := util.sdate_sub(util.sdate_now(), 7)!
	return app.route_week_prize_date(prize.id, date)!
}

[middleware: check_auth]
['/api/week/:prize_id/:date'; get]
pub fn (mut app App) route_week_prize_date(prize_id u64, date string) !vweb.Result {
	sow := util.sdate_week_start(date)!
	from := util.sdate_sub(sow, 2)!
	till := util.sdate_add(from, 6)!
	stars := app.db.get_stars(prize_id, from, till)!
	return app.json(api.ApiWeek{
		from: from
		till: till
		stars: stars.map(api.ApiWeek_Star{
			at: it.at
			got: it.got
			typ: it.typ
		})
	})
}
