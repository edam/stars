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
	sow := util.sdate_add(util.sdate_week_start(date)!, app.args.first_dow - 1)!
	from := if sow > date { util.sdate_sub(sow, 7)! } else { sow }
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

[middleware: check_auth_admin]
['/api/admin/prize/cur/star/:date/:typ/:got'; post]
pub fn (mut app App) route_admin_prize_cur_star_typ_got_date(date string, typ string, got string) !vweb.Result {
	prize := app.db.get_cur_prize()!
	typ_ := match typ {
		'daily', '0' { 0 }
		'bonus1', '1' { 1 }
		'bonus2', '2' { 2 }
		else { return app.server_error(400) }
	}
	date_ := match date {
		'today' { util.sdate_now() }
		else { util.sdate_check(date)! }
	}
	mut found := false
	match got {
		'got' { found = app.db.set_star_got(prize.id, date_, typ_, true)! }
		'lost' { found = app.db.set_star_got(prize.id, date_, typ_, false)! }
		'unset' { found = app.db.set_star_got(prize.id, date_, typ_, none)! }
		else { return app.server_error(400) }
	}
	if !found {
		return app.server_error(404)
	} else {
		return app.json(api.ApiOk{})
	}
}
