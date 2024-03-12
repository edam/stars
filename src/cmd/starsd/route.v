module main

import x.vweb
import util
import api
import rand
import crypto.sha256
import crypto.aes
import time
import json
import pcre

const re_username = pcre.new_regex('^[a-zA-Z0-9_]{1,20}$', 0)!
const re_psk = pcre.new_regex('^[a-f0-9]{64}$', 0)!

@['/api/auth/:username'; get]
pub fn (mut app App) get_auth(mut ctx Context, username string) vweb.Result {
	challenge := rand.uuid_v4().replace('-', '')
	go app.async_get_auth(username, challenge)
	time.sleep(time.second)
	return ctx.json(api.GetAuth{
		challenge: challenge
		session_ttl: app.args.session_ttl
		api_version: api.api_version
	})
}

fn (mut app App) async_get_auth(username string, challenge string) {
	if user := app.db.get_user(username) {
		session_id := sha256.hexhash('${user.psk}:${challenge}')
		app.sessions.add(session_id, user.username, user.perms) or { return }
	}
}

@['/api/ping'; get]
pub fn (mut app App) get_ping(mut ctx Context) vweb.Result {
	return ctx.json(api.Ok{})
}

@['/api/prizes/cur'; get]
pub fn (mut app App) get_prizes_cur(mut ctx Context) vweb.Result {
	return app.real_get_prizes_cur(mut ctx) or { return ctx.server_error('') }
}

fn (mut app App) real_get_prizes_cur(mut ctx Context) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	count := app.db.get_star_count(prize.id)!
	deposits := app.db.get_deposits(prize.id)!
	mut deposits_total := 0
	for deposit in deposits {
		deposits_total += deposit.amount
	}
	return ctx.json(api.GetPrizesCur{
		prize: api.Prize{
			id: prize.id
			start: prize.start or { '' }
			goal: prize.goal
			first_dow: prize.first_dow
			star_val: prize.star_val
		}
		stars: count
		got: struct {
			stars: count * prize.star_val
			deposits: deposits_total
		}
	})
}

@['/api/prizes/cur/deposits'; get]
pub fn (mut app App) get_prizes_cur_deposits(mut ctx Context) vweb.Result {
	return app.real_get_prizes_cur_deposits(mut ctx) or { return ctx.server_error('') }
}

fn (mut app App) real_get_prizes_cur_deposits(mut ctx Context) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	deposits := app.db.get_deposits(prize.id)!
	return ctx.json(api.GetPrizesDeposits{
		deposits: deposits.map(api.Deposit{
			id: it.id
			at: it.at
			amount: it.amount
			desc: it.desc
		})
	})
}

@['/api/prizes/cur/weeks/:date'; get]
pub fn (mut app App) get_prizes_cur_weeks(mut ctx Context, date string) vweb.Result {
	return app.real_get_prizes_cur_weeks(mut ctx, date) or { return ctx.server_error('') }
}

fn (mut app App) real_get_prizes_cur_weeks(mut ctx Context, date string) !vweb.Result {
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
	return ctx.json(api.GetPrizesWeeks{
		from: from
		till: till
		stars: stars.map(api.Star{
			at: it.at
			got: it.got
			typ: it.typ
		})
	})
}

@['/api/prizes/cur/stats/:num_stars'; get]
pub fn (mut app App) get_prizes_cur_stats(mut ctx Context, num_stars int) vweb.Result {
	return app.real_get_prizes_cur_stats(mut ctx, num_stars) or { return ctx.server_error('') }
}

pub fn (mut app App) real_get_prizes_cur_stats(mut ctx Context, num_stars int) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	if num_stars < 1 {
		return ctx.request_error('bad num_stars')
	}
	stars := app.db.get_stars_n(prize.id, num_stars)!
	if stars.len == 0 {
		return ctx.json(api.GetPrizesStats{})
	}
	mut ngot := 0
	for star in stars {
		if got := star.got {
			if got {
				ngot++
			}
		}
	}
	return ctx.json(api.GetPrizesStats{
		from: stars[0].at
		till: stars[stars.len - 1].at
		got: struct {
			stars: ngot * prize.star_val
		}
	})
}

@['/api/prizes/cur/wins/:kind'; get]
pub fn (mut app App) get_prizes_cur_wins_kind(mut ctx Context, kind string) vweb.Result {
	return app.real_get_prizes_cur_wins_kind(mut ctx, kind) or { return ctx.server_error('') }
}

fn (mut app App) real_get_prizes_cur_wins_kind(mut ctx Context, kind string) !vweb.Result {
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
	return ctx.json(api.GetPrizesWins{
		wins: wins.map(api.Win{
			at: it.at
			got: it.got
		})
		next: next_win(wins, prize.start or { '' }, prize.first_dow)!
	})
}

@['/api/prizes/cur/wins'; get]
pub fn (mut app App) get_prizes_cur_wins(mut ctx Context) vweb.Result {
	return app.real_get_prizes_cur_wins(mut ctx) or { return ctx.server_error('') }
}

fn (mut app App) real_get_prizes_cur_wins(mut ctx Context) !vweb.Result {
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
	return ctx.json(api.GetPrizesWins{
		wins: wins[start..].map(api.Win{
			at: it.at
			got: it.got
		})
	})
}

// -- admin

@['/api/admin/prizes/cur'; delete]
pub fn (mut app App) delete_admin_prizes_cur(mut ctx Context) vweb.Result {
	return app.real_delete_admin_prizes_cur(mut ctx) or { return ctx.server_error('') }
}

fn (mut app App) real_delete_admin_prizes_cur(mut ctx Context) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	app.db.end_prize(prize.id)!
	return ctx.json(api.Ok{})
}

@['/api/admin/prizes/cur/stars/:date/:typ/:got'; put]
pub fn (mut app App) put_admin_prizes_cur_stars(mut ctx Context, date string, typ int, got string) vweb.Result {
	return app.real_put_admin_prizes_cur_stars(mut ctx, date, typ, got) or {
		return ctx.server_error('')
	}
}

fn (mut app App) real_put_admin_prizes_cur_stars(mut ctx Context, date string, typ int, got string) !vweb.Result {
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
		return ctx.json(api.Ok{})
	}
}

@['/api/admin/prizes/cur/stars/:date/:typ'; post]
pub fn (mut app App) post_admin_prizes_cur_stars(mut ctx Context, date string, typ int) vweb.Result {
	return app.real_post_admin_prizes_cur_stars(mut ctx, date, typ) or {
		return ctx.server_error('')
	}
}

fn (mut app App) real_post_admin_prizes_cur_stars(mut ctx Context, date string, typ int) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	util.sdate_check(date) or { return ctx.request_error('bad date') }
	if start := prize.start {
		if date < start {
			return ctx.request_error('bad date')
		}
	}
	app.db.add_star(prize.id, date, typ, none)!
	return ctx.json(api.Ok{})
}

@['/api/admin/prizes/cur/stars/:date/:typ'; delete]
pub fn (mut app App) delete_admin_prizes_cur_stars(mut ctx Context, date string, typ int) vweb.Result {
	return app.real_delete_admin_prizes_cur_stars(mut ctx, date, typ) or {
		return ctx.server_error('')
	}
}

fn (mut app App) real_delete_admin_prizes_cur_stars(mut ctx Context, date string, typ int) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	util.sdate_check(date) or { return ctx.request_error('bad date') }
	if start := prize.start {
		if date < start {
			return ctx.request_error('bad date')
		}
	}
	app.db.delete_star(prize.id, date, typ)!
	return ctx.json(api.Ok{})
}

@['/api/admin/prizes/cur/wins/:date/:got'; post]
pub fn (mut app App) post_admin_prizes_cur_wins(mut ctx Context, date string, got string) vweb.Result {
	return app.real_post_admin_prizes_cur_wins(mut ctx, date, got) or {
		return ctx.server_error('')
	}
}

fn (mut app App) real_post_admin_prizes_cur_wins(mut ctx Context, date string, got string) !vweb.Result {
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
	return ctx.json(api.Ok{})
}

@['/api/admin/prizes/cur/goals/:goal'; put]
pub fn (mut app App) put_admin_prizes_cur_goals(mut ctx Context, goal int) vweb.Result {
	return app.real_put_admin_prizes_cur_goals(mut ctx, goal) or { return ctx.server_error('') }
}

fn (mut app App) real_put_admin_prizes_cur_goals(mut ctx Context, goal int) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	app.db.set_prize_goal(prize.id, goal)!
	return ctx.json(api.Ok{})
}

@['/api/admin/prizes'; post]
pub fn (mut app App) post_admin_prizes(mut ctx Context) vweb.Result {
	return app.real_post_admin_prizes(mut ctx) or { return ctx.server_error('') }
}

fn (mut app App) real_post_admin_prizes(mut ctx Context) !vweb.Result {
	prize := json.decode(api.Prize, ctx.form['json']!)!
	util.parse_sdate(prize.start) or { return ctx.request_error('bad date') }
	if prize.goal < 1 {
		return ctx.request_error('bad goal')
	}
	if prize.star_val < 1 {
		return ctx.request_error('bad star_val')
	}
	if prize.first_dow < 1 || prize.first_dow > 7 {
		return ctx.request_error('bad first_dow')
	}
	if _ := app.db.get_cur_prize() {
		return ctx.request_error('prize active')
	}
	app.db.add_prize(prize.start, prize.first_dow, prize.goal, prize.star_val)!
	return ctx.json(api.Ok{})
}

@['/api/admin/prizes/cur/deposits'; post]
pub fn (mut app App) post_admin_prizes_cur_deposits(mut ctx Context) vweb.Result {
	return app.real_post_admin_prizes_cur_deposits(mut ctx) or { return ctx.server_error('') }
}

fn (mut app App) real_post_admin_prizes_cur_deposits(mut ctx Context) !vweb.Result {
	deposit := json.decode(api.Deposit, ctx.form['json']!)!
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	util.parse_sdate(deposit.at) or { return ctx.request_error('bad date') }
	if deposit.amount < 1 {
		return ctx.request_error('bad amount')
	}
	app.db.add_deposit(prize.id, deposit.at, deposit.amount, deposit.desc)!
	return ctx.json(api.Ok{})
}

@['/api/admin/prizes/cur/deposits/:id'; delete]
pub fn (mut app App) delete_admin_prizes_cur_deposits(mut ctx Context, id u64) vweb.Result {
	return app.real_delete_admin_prizes_cur_deposits(mut ctx, id) or { return ctx.server_error('') }
}

fn (mut app App) real_delete_admin_prizes_cur_deposits(mut ctx Context, id u64) !vweb.Result {
	prize := app.db.get_cur_prize() or { return check_404(mut ctx, err)! }
	app.db.delete_deposit(prize.id, id)!
	return ctx.json(api.Ok{})
}

@['/api/admin/prizes/cur/wins/:date'; delete]
pub fn (mut app App) delete_admin_prizes_cur_wins(mut ctx Context, date string) vweb.Result {
	return app.real_delete_admin_prizes_cur_wins(mut ctx, date) or { return ctx.server_error('') }
}

fn (mut app App) real_delete_admin_prizes_cur_wins(mut ctx Context, date string) !vweb.Result {
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
	return ctx.json(api.Ok{})
}

@['/api/admin/users'; get]
pub fn (mut app App) get_admin_users(mut ctx Context) vweb.Result {
	return app.real_get_admin_users(mut ctx) or { return ctx.server_error('') }
}

fn (mut app App) real_get_admin_users(mut ctx Context) !vweb.Result {
	users := app.db.get_users()!
	return ctx.json(api.GetAdminUsers{
		users: users.map(api.User{
			username: it.username
			perms: api.UserPerms{
				admin: it.perms & perm_admin != 0
			}
		})
	})
}

@['/api/admin/users'; post]
pub fn (mut app App) post_admin_users(mut ctx Context) vweb.Result {
	return app.real_post_admin_users(mut ctx) or { return ctx.server_error('') }
}

fn (mut app App) real_post_admin_users(mut ctx Context) !vweb.Result {
	user := json.decode(api.User, ctx.form['json']!)!
	re_username.match_str(user.username, 0, 0) or { return ctx.request_error('bad username') }
	pskenc := if psk := user.psk {
		if psk.len != 64 {
			return ctx.request_error('bad psk')
		}
		util.unhex(psk) or { return ctx.request_error('bad psk') }
	} else {
		return ctx.request_error('bad psk')
	}

	// use current user's psk (a 32-byte sha256) as aes256 key to decrypt new
	// user's psk (an sha256)
	session := ctx.session or { return ctx.server_error('') }
	cur_user := app.db.get_user(session.username)!
	if cur_user.psk.len != 64 {
		return ctx.server_error('bad cipher key')
	}
	cipher := aes.new_cipher(util.unhex(cur_user.psk)!)
	mut pskclear := []u8{len: pskenc.len, cap: pskenc.len}
	cipher.decrypt(mut pskclear, pskenc)
	cipher.decrypt(mut pskclear[16..], pskenc[16..])
	psk := pskclear.hex()
	re_psk.match_str(psk, 0, 0) or { return ctx.request_error('bad psk') }
	perms := u32(if user.perms.admin { perm_admin } else { 0 })

	app.db.add_user(user.username, psk, perms)!
	return ctx.json(api.Ok{})
}

@['/api/admin/users/:username'; put]
pub fn (mut app App) put_admin_users(mut ctx Context, username string) vweb.Result {
	return app.real_put_admin_users(mut ctx, username) or { return ctx.server_error('') }
}

fn (mut app App) real_put_admin_users(mut ctx Context, username string) !vweb.Result {
	req := json.decode(api.PutAdminUsersReq, ctx.form['json']!)!
	session := ctx.session or { return ctx.server_error('') }
	self := session.username == username

	if pskenc_ := req.psk {
		if !self && session.perms & perm_admin == 0 {
			return ctx.forbidden()
		}
		re_psk.match_str(pskenc_, 0, 0) or { return ctx.request_error('bad psk') }
		pskenc := util.unhex(pskenc_)!

		// use current user's psk (a 32-byte sha256) as aes256 key to decrypt new
		// user's psk (an sha256)
		cur_user := app.db.get_user(session.username)!
		if cur_user.psk.len != 64 {
			return ctx.server_error('bad cipher key')
		}
		cipher := aes.new_cipher(util.unhex(cur_user.psk)!)
		mut pskclear := []u8{len: pskenc.len, cap: pskenc.len}
		cipher.decrypt(mut pskclear, pskenc)
		cipher.decrypt(mut pskclear[16..], pskenc[16..])
		psk := pskclear.hex()
		re_psk.match_str(psk, 0, 0) or { return ctx.request_error('bad psk') }

		app.db.set_user_psk(username, psk)!
	}

	return ctx.json(api.Ok{})
}

@['/api/admin/users/:username'; delete]
pub fn (mut app App) delete_admin_users(mut ctx Context, username string) vweb.Result {
	return app.real_delete_admin_users(mut ctx, username) or { return ctx.server_error('') }
}

fn (mut app App) real_delete_admin_users(mut ctx Context, username string) !vweb.Result {
	app.db.delete_user(username)!
	return ctx.json(api.Ok{})
}
