module main

import vweb
import util
import api
import rand
import crypto.sha256
import encoding.base64

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
	prize := app.db.get_cur_prize() or { return check_404(mut app, err)! }
	count := app.db.get_star_count(prize.id)!
	deposits := app.db.get_deposits(prize.id)!
	mut deposits_total := 0
	for deposit in deposits {
		deposits_total += deposit.amount
	}
	return app.json(api.ApiPrizeCur{
		prize_id: prize.id
		start: prize.start or { '' }
		stars: count
		goal: prize.goal
		first_dow: prize.first_dow
		got: struct {
			stars: count * prize.star_val
			deposits: deposits_total
		}
	})
}

[middleware: check_auth]
['/api/prize/cur/deposits'; get]
pub fn (mut app App) route_prize_cur_deposits() !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut app, err)! }
	deposits := app.db.get_deposits(prize.id)!
	return app.json(api.ApiDeposits{
		deposits: deposits.map(api.Api_Deposit{
			at: it.at
			amount: it.amount
			desc: it.desc
		})
	})
}

[middleware: check_auth]
['/api/prize/cur/week/:date'; get]
pub fn (mut app App) route_prize_cur_week(date string) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut app, err)! }
	at := match true {
		date == 'cur' { util.sdate_now() }
		date == 'last' { util.sdate_sub(util.sdate_now(), 7)! }
		else { util.sdate_check(date) or { return app.server_error(400) } }
	}
	sow := util.sdate_add(util.sdate_week_start(at)!, prize.first_dow - 1)!
	from := if sow > at { util.sdate_sub(sow, 7)! } else { sow }
	till := util.sdate_add(from, 6)!
	stars := app.db.get_stars(prize.id, from, till)!
	return app.json(api.ApiWeek{
		from: from
		till: till
		stars: stars.map(api.Api_Star{
			at: it.at
			got: it.got
			typ: it.typ
		})
	})
}

[middleware: check_auth]
['/api/prize/cur/wins/all'; get]
pub fn (mut app App) route_prize_cur_wins_all() !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut app, err)! }
	wins := app.db.get_wins(prize.id)!
	return app.json(api.ApiWins{
		wins: wins.map(api.Api_Win{
			at: it.at
			got: it.got
		})
		next: next_win(wins, prize.start or { '' }, prize.first_dow)!
	})
}

[middleware: check_auth]
['/api/prize/cur/wins'; get]
pub fn (mut app App) route_prize_cur_wins() !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut app, err)! }
	wins := app.db.get_wins(prize.id)!
	mut start := 0
	mut count := 0
	for i, win in wins {
		if win.got {
			count++
		}
		if count == 4 {
			start = i + 1
			count = 0
		}
	}
	return app.json(api.ApiWins{
		wins: wins[start..].map(api.Api_Win{
			at: it.at
			got: it.got
		})
	})
}

[middleware: check_auth_admin]
['/api/admin/prize/cur/star/:date/:typ/:got'; put]
pub fn (mut app App) route_put_admin_prize_cur_star(date string, typ int, got string) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut app, err)! }
	date_ := match date {
		'today' { util.sdate_now() }
		else { util.sdate_check(date)! }
	}
	mut found := false
	match got {
		'got' { found = app.db.set_star_got(prize.id, date_, typ, true)! }
		'lost' { found = app.db.set_star_got(prize.id, date_, typ, false)! }
		'unset' { found = app.db.set_star_got(prize.id, date_, typ, none)! }
		else { return app.server_error(400) }
	}
	if !found {
		return app.server_error(404)
	} else {
		return app.json(api.ApiOk{})
	}
}

[middleware: check_auth_admin]
['/api/admin/prize/cur/star/:date/:typ'; post]
pub fn (mut app App) route_post_admin_prie_cur_star(date string, typ int) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut app, err)! }
	util.sdate_check(date) or { return app.server_error(400) }
	if start := prize.start {
		if date < start {
			return app.server_error(400)
		}
	}
	app.db.add_star(prize.id, date, typ, none)!
	return app.json(api.ApiOk{})
}

[middleware: check_auth_admin]
['/api/admin/prize/cur/star/:date/:typ'; delete]
pub fn (mut app App) route_delete_admin_prie_cur_star(date string, typ int) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut app, err)! }
	util.sdate_check(date) or { return app.server_error(400) }
	if start := prize.start {
		if date < start {
			return app.server_error(400)
		}
	}
	app.db.delete_star(prize.id, date, typ)!
	return app.json(api.ApiOk{})
}

[middleware: check_auth_admin]
['/api/admin/prize/cur/win/:date/:got'; post]
pub fn (mut app App) route_post_admin_prize_cur_win(date string, got string) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut app, err)! }
	wins := app.db.get_wins(prize.id)!
	next := next_win(wins, prize.start or { '' }, prize.first_dow)!
	if next != date {
		return app.server_error(400)
	}
	if got == 'got' {
		mut count := 0
		for win in wins {
			if win.got {
				count++
			}
		}
		if count % 4 == 3 {
			app.db.add_star(prize.id, date, -1, true)!
		}
	}
	match got {
		'got' { app.db.set_win(prize.id, date, true)! }
		'lost' { app.db.set_win(prize.id, date, false)! }
		else { return app.server_error(400) }
	}
	return app.json(api.ApiOk{})
}

[middleware: check_auth_admin]
['/api/admin/prize/cur/win/:date'; delete]
pub fn (mut app App) route_delete_admin_prize_cur_win(date string) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut app, err)! }
	wins := app.db.get_wins(prize.id)!
	if wins.len == 0 {
		return app.server_error(400)
	}
	if wins#[-1..][0].at != date {
		return app.server_error(400)
	}
	app.db.delete_star(prize.id, date, -1)!
	app.db.delete_win(prize.id, date)!
	return app.json(api.ApiOk{})
}

[middleware: check_auth_admin]
['/api/admin/prize/cur/deposit/:date/:amount/:desc'; put]
pub fn (mut app App) route_put_admin_prize_cur_deposit(date string, amount int, desc string) !vweb.Result {
	prize := app.db.get_cur_prize()!
	if util.sdate_check(date)! < prize.start or { '' } || amount < 1 {
		return app.server_error(400)
	}
	app.db.add_deposit(prize.id, date, amount, base64.url_decode(desc).bytestr())!
	return app.json(api.ApiOk{})
}
