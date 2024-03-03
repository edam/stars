module main

import x.vweb
import util
import api
import rand
import crypto.sha256
import time

@['/api/auth/:username'; get]
pub fn (mut app App) route_auth(mut ctx Context, username string) vweb.Result {
	challenge := rand.uuid_v4()
	go app.async_route_auth(username, challenge)
	time.sleep(time.second)
	return ctx.json(api.ApiAuth{
		challenge: challenge
		session_ttl: app.args.session_ttl
		api_version: api.api_version
	})
}

fn (mut app App) async_route_auth(username string, challenge string) {
	if user := app.db.get_user(username) {
		session_id := sha256.hexhash('${user.psk}:${challenge}')
		app.sessions.add(session_id, user.id, user.perms) or { return }
	}
}

@['/api/ping'; get]
pub fn (mut app App) route_ping(mut ctx Context) vweb.Result {
	return ctx.json(api.ApiOk{})
}

@['/api/prize/cur'; get]
pub fn (mut app App) route_prize_cur(mut ctx Context) vweb.Result {
	return app.real_prize_cur(mut ctx) or { return ctx.server_error('') }
}

fn (mut app App) real_prize_cur(mut ctx Context) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	count := app.db.get_star_count(prize.id)!
	deposits := app.db.get_deposits(prize.id)!
	mut deposits_total := 0
	for deposit in deposits {
		deposits_total += deposit.amount
	}
	return ctx.json(api.ApiPrizeCur{
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

@['/api/prize/cur/deposits'; get]
pub fn (mut app App) route_prize_cur_deposits(mut ctx Context) vweb.Result {
	return app.real_prize_cur_deposits(mut ctx) or { return ctx.server_error('') }
}

fn (mut app App) real_prize_cur_deposits(mut ctx Context) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	deposits := app.db.get_deposits(prize.id)!
	return ctx.json(api.ApiDeposits{
		deposits: deposits.map(api.Api_Deposit{
			at: it.at
			amount: it.amount
			desc: it.desc
		})
	})
}

@['/api/prize/cur/week/:date'; get]
pub fn (mut app App) route_prize_cur_week(mut ctx Context, date string) vweb.Result {
	return app.real_prize_cur_week(mut ctx, date) or { return ctx.server_error('') }
}

fn (mut app App) real_prize_cur_week(mut ctx Context, date string) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	at := match true {
		date == 'cur' { util.sdate_now() }
		date == 'last' { util.sdate_sub(util.sdate_now(), 7)! }
		date == 'latest' { app.latest_star_at()! }
		else { util.sdate_check(date) or { return ctx.request_error('bad date') } }
	}
	sow := util.sdate_add(util.sdate_week_start(at)!, prize.first_dow - 1)!
	from := if sow > at { util.sdate_sub(sow, 7)! } else { sow }
	till := util.sdate_add(from, 6)!
	stars := app.db.get_stars(prize.id, from, till)!
	return ctx.json(api.ApiWeek{
		from: from
		till: till
		stars: stars.map(api.Api_Star{
			at: it.at
			got: it.got
			typ: it.typ
		})
	})
}

@['/api/prize/cur/stats/:num_stars'; get]
pub fn (mut app App) route_prize_cur_stats(mut ctx Context, num_stars int) vweb.Result {
	return app.real_prize_cur_stats(mut ctx, num_stars) or { return ctx.server_error('') }
}

pub fn (mut app App) real_prize_cur_stats(mut ctx Context, num_stars int) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	if num_stars < 1 {
		return ctx.request_error('bad num_stars')
	}
	stars := app.db.get_stars_n(prize.id, num_stars)!
	if stars.len == 0 {
		return ctx.not_found()
	}
	mut ngot := 0
	for star in stars {
		if got := star.got {
			if got {
				ngot++
			}
		}
	}
	return ctx.json(api.ApiStats{
		from: stars[0].at
		till: stars[stars.len - 1].at
		got: struct {
			stars: ngot * prize.star_val
		}
	})
}

@['/api/prize/cur/wins/:kind'; get]
pub fn (mut app App) route_prize_cur_wins_kind(mut ctx Context, kind string) vweb.Result {
	return app.real_prize_cur_wins_kind(mut ctx, kind) or { return ctx.server_error('') }
}

fn (mut app App) real_prize_cur_wins_kind(mut ctx Context, kind string) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	limit := match kind {
		'all' { ?int(none) }
		'latest' { ?int(1) }
		else { return ctx.request_error('bad kind') } // return has no effect!!!
	}
	// TODO: remove once bug with match yielding option-values is fixed:
	if limit_ := limit {
		if limit_ == 0 {
			return ctx.request_error('bad kind')
		}
	}
	wins := app.db.get_wins(prize.id, limit)!
	return ctx.json(api.ApiWins{
		wins: wins.map(api.Api_Win{
			at: it.at
			got: it.got
		})
		next: next_win(wins, prize.start or { '' }, prize.first_dow)!
	})
}

@['/api/prize/cur/wins'; get]
pub fn (mut app App) route_prize_cur_wins(mut ctx Context) vweb.Result {
	return app.real_prize_cur_wins(mut ctx) or { return ctx.server_error('') }
}

fn (mut app App) real_prize_cur_wins(mut ctx Context) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	wins := app.db.get_wins(prize.id, none)!
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
	return ctx.json(api.ApiWins{
		wins: wins[start..].map(api.Api_Win{
			at: it.at
			got: it.got
		})
	})
}

@['/api/admin/prize/cur'; delete]
pub fn (mut app App) route_delete_admin_prize_cur(mut ctx Context) vweb.Result {
	return app.real_delete_admin_prize_cur(mut ctx) or { return ctx.server_error('') }
}

fn (mut app App) real_delete_admin_prize_cur(mut ctx Context) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	app.db.end_prize(prize.id)!
	return ctx.json(api.ApiOk{})
}

@['/api/admin/prize/cur/star/:date/:typ/:got'; put]
pub fn (mut app App) route_put_admin_prize_cur_star(mut ctx Context, date string, typ int, got string) vweb.Result {
	return app.real_put_admin_prize_cur_star(mut ctx, date, typ, got) or {
		return ctx.server_error('')
	}
}

fn (mut app App) real_put_admin_prize_cur_star(mut ctx Context, date string, typ int, got string) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	date_ := match date {
		'today' { util.sdate_now() }
		else { util.sdate_check(date)! }
	}
	mut found := false
	match got {
		'got' { found = app.db.set_star_got(prize.id, date_, typ, true)! }
		'lost' { found = app.db.set_star_got(prize.id, date_, typ, false)! }
		'unset' { found = app.db.set_star_got(prize.id, date_, typ, none)! }
		else { return ctx.request_error('bad got') }
	}
	if !found {
		return ctx.not_found()
	} else {
		return ctx.json(api.ApiOk{})
	}
}

@['/api/admin/prize/cur/star/:date/:typ'; post]
pub fn (mut app App) route_post_admin_prize_cur_star(mut ctx Context, date string, typ int) vweb.Result {
	return app.real_post_admin_prize_cur_star(mut ctx, date, typ) or { return ctx.server_error('') }
}

fn (mut app App) real_post_admin_prize_cur_star(mut ctx Context, date string, typ int) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	util.sdate_check(date) or { return ctx.request_error('bad date') }
	if start := prize.start {
		if date < start {
			return ctx.request_error('bad date')
		}
	}
	app.db.add_star(prize.id, date, typ, none)!
	return ctx.json(api.ApiOk{})
}

@['/api/admin/prize/cur/star/:date/:typ'; delete]
pub fn (mut app App) route_delete_admin_prize_cur_star(mut ctx Context, date string, typ int) vweb.Result {
	return app.real_delete_admin_prize_cur_star(mut ctx, date, typ) or {
		return ctx.server_error('')
	}
}

fn (mut app App) real_delete_admin_prize_cur_star(mut ctx Context, date string, typ int) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	util.sdate_check(date) or { return ctx.request_error('bad date') }
	if start := prize.start {
		if date < start {
			return ctx.request_error('bad date')
		}
	}
	app.db.delete_star(prize.id, date, typ)!
	return ctx.json(api.ApiOk{})
}

@['/api/admin/prize/cur/win/:date/:got'; post]
pub fn (mut app App) route_post_admin_prize_cur_win(mut ctx Context, date string, got string) vweb.Result {
	return app.real_post_admin_prize_cur_win(mut ctx, date, got) or { return ctx.server_error('') }
}

fn (mut app App) real_post_admin_prize_cur_win(mut ctx Context, date string, got string) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	wins := app.db.get_wins(prize.id, none)!
	next := next_win(wins, prize.start or { '' }, prize.first_dow)!
	util.sdate_check(date) or { return ctx.request_error('bad date') }
	if date < next || util.sdate_dow(date)! != util.sdate_dow(next)! {
		return ctx.request_error('bad date')
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
		else { return ctx.request_error('bad got') }
	}
	return ctx.json(api.ApiOk{})
}

@['/api/admin/prizes/:starts/:first_dow/:goal/:star_val'; post]
pub fn (mut app App) route_post_admin_prizes(mut ctx Context, starts string, first_dow int, goal int, star_val int) vweb.Result {
	return app.real_post_admin_prizes(mut ctx, starts, first_dow, goal, star_val) or {
		return ctx.server_error('')
	}
}

fn (mut app App) real_post_admin_prizes(mut ctx Context, starts string, first_dow int, goal int, star_val int) !vweb.Result {
	util.parse_sdate(starts) or { return ctx.request_error('bad date') }
	if goal < 1 {
		return ctx.request_error('bad goal')
	}
	if star_val < 1 {
		return ctx.request_error('bad star_val')
	}
	if first_dow < 1 || first_dow > 7 {
		return ctx.request_error('bad first_dow')
	}
	if _ := app.db.get_cur_prize() {
		return ctx.request_error('prize active')
	}
	app.db.add_prize(starts, first_dow, goal, star_val)!
	return ctx.json(api.ApiOk{})
}

@['/api/admin/prize/cur/win/:date'; delete]
pub fn (mut app App) route_delete_admin_prize_cur_win(mut ctx Context, date string) vweb.Result {
	return app.real_delete_admin_prize_cur_win(mut ctx, date) or { return ctx.server_error('') }
}

fn (mut app App) real_delete_admin_prize_cur_win(mut ctx Context, date string) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	wins := app.db.get_wins(prize.id, none)!
	if wins.len == 0 {
		return ctx.request_error('no wins')
	}
	if wins#[-1..][0].at != date {
		return ctx.request_error('bad date')
	}
	app.db.delete_star(prize.id, date, -1)!
	app.db.delete_win(prize.id, date)!
	return ctx.json(api.ApiOk{})
}

@['/api/admin/users'; get]
pub fn (mut app App) route_admin_user(mut ctx Context) vweb.Result {
	return app.real_admin_user(mut ctx) or { return ctx.server_error('') }
}

fn (mut app App) real_admin_user(mut ctx Context) !vweb.Result {
	users := app.db.get_users()!
	return ctx.json(api.ApiUsers{
		users: users.map(api.Api_User{
			name: it.name
			perms: api.Api_UserPerms{
				admin: it.perms & perm_admin != 0
			}
		})
	})
}

@['/api/admin/user/:username'; put]
pub fn (mut app App) route_put_admin_user(mut ctx Context, username string) vweb.Result {
	return app.real_put_admin_user(mut ctx, username) or { return ctx.server_error('') }
}

fn (mut app App) real_put_admin_user(mut ctx Context, username string) !vweb.Result {
	return ctx.json(api.ApiOk{})
}

@['/api/admin/user/:username'; delete]
pub fn (mut app App) route_delete_admin_user(mut ctx Context, username string) vweb.Result {
	return app.real_delete_admin_user(mut ctx, username) or { return ctx.server_error('') }
}

fn (mut app App) real_delete_admin_user(mut ctx Context, username string) !vweb.Result {
	app.db.delete_user(username)!
	return ctx.json(api.ApiOk{})
}
