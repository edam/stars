module cmds

import api
import term
import util
import inp
import rand
import crypto.aes
import crypto.sha256

const dow_names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

// helpers

fn menu_quit(mut c Client) ! {
	println('')
	return error('aborted')
}

fn menu_nop(mut c Client) ! {
	term.clear_previous_line()
	// on return, errors `return`, so previous menu needs to handle returns!
}

fn menu_sure(sure_fn MenuFn) MenuFn {
	return fn [sure_fn] (mut c Client) ! {
		do_menu(mut c, [
			MenuItem{'sure?', sure_fn},
		])!
	}
}

// --

pub fn (mut c Client) admin() ! {
	println(fg(.white) + '𝕊𝕋𝔸ℝ𝕊 𝔸𝔻𝕄𝕀ℕ ' + faint + '- ' + reset +
		fg(.blue) + '${c.username}@${c.host}' + reset)
	c.auth()!
	c.keep_alive()
	for {
		do_menu(mut c, [
			MenuItem{'set star', menu_stars_set(none)},
			MenuItem{'weekly win', menu_weeklywin},
			MenuItem{'setup week stars', menu_starweek()},
			MenuItem{'deposits', menu_deposit},
			MenuItem{'setup prizes', menu_prizes},
			MenuItem{'setup users', menu_users},
			MenuItem{'change password', menu_change_password(c.username)},
			MenuItem{'quit', menu_quit},
		]) or {
			if err.str() == 'back' || err.str() == 'aborted' {
				println('bye')
				return
			} else if err.str() == 'not found' {
				println(err.str())
			} else if err.str() != 'return' {
				return err
			}
		}
	}
}

fn menu_stars_set(when ?string) MenuFn {
	when_ := when or { 'latest' }
	return fn [when_] (mut c Client) ! {
		cur := c.get[api.GetPrizesWeeks]('/api/prizes/cur/weeks/${when_}')!
		mut menu := []MenuItem{}
		mut idx := -1
		for i, star in cur.stars {
			got := if got_ := star.got {
				if got_ { '⭐' } else { '❌' }
			} else {
				idx = if idx == -1 { i } else { idx }
				'❔'
			}
			dow := cmds.dow_names[util.sdate_dow(star.at)!]
			info := if star.typ > 0 { '-B${star.typ}' } else { ' ${star.at} ${dow}' }
			title := '${got}${info}'
			menu << MenuItem{title, menu_star_set(star.at, star.typ)}
		}
		idx = if idx == -1 { 0 } else { idx }
		if menu.len <= 0 {
			println('no week stars set up!')
		} else {
			do_menu_sel(mut c, menu, &idx)!
		}
	}
}

fn menu_star_set(date string, typ int) MenuFn {
	return fn [date, typ] (mut c Client) ! {
		do_menu(mut c, [
			MenuItem{'got', menu_star_got_set(typ, 'got', date)},
			MenuItem{'lost', menu_star_got_set(typ, 'lost', date)},
			MenuItem{'unset', menu_star_got_set(typ, 'unset', date)},
		])!
	}
}

fn menu_star_typ_set(typ int) MenuFn {
	return fn [typ] (mut c Client) ! {
		mut date := 'today'
		do_menu(mut c, [
			MenuItem{none, fn [date] (mut c Client) ! {
				println('date: ${date}')
			}},
			MenuItem{'got', menu_star_got_set(typ, 'got', &date)},
			MenuItem{'lost', menu_star_got_set(typ, 'lost', &date)},
			MenuItem{'unset', menu_star_got_set(typ, 'unset', &date)},
			MenuItem{'change date ', menu_star_date_set(&date)},
		])!
	}
}

// fn menu_set_star_daily(mut c Client) ! {
//	mut date := 'today'
//	do_menu(mut c, [
//		MenuItem{none, fn [date] (mut c Client) ! {
//			println('date: ${date}')
//		}},
//		MenuItem{'got', menu_star_got_set('got', &date)},
//		MenuItem{'lost', menu_star_got_set('lost', &date)},
//		MenuItem{'unset', menu_star_got_set('unset', &date)},
//		MenuItem{'change date ', menu_star_date_set(&date)},
//	])!
//}

fn menu_star_date_set(date &string) MenuFn {
	return fn [date] (mut c Client) ! {
		unsafe {
			*date = inp.read_date('enter a date: ', *date) or { 'today' }
		}
		term.clear_previous_line()
		return error('back')
	}
}

fn menu_star_got_set(typ int, got string, date &string) MenuFn {
	return fn [typ, got, date] (mut c Client) ! {
		typ_name := if typ > 0 { 'B${typ}' } else { 'daily' }
		println('setting ${typ_name} star for \'${*date}\' to ${got}')
		c.put[api.Ok]('/api/admin/prizes/cur/stars/${*date}/${typ}/${got}')!
	}
}

fn menu_weeklywin(mut c Client) ! {
	mut date := ''
	pdate := &date
	for {
		res := c.get[api.GetPrizesWins]('/api/prizes/cur/wins/all')!
		mut last := ''
		mut week := ''
		if res.wins.len > 0 {
			mut count := 0
			for win in res.wins {
				if count % 4 == 0 {
					week = ''
				}
				week += if win.got { ' 🏅' } else { ' ❌' }
				count += if win.got { 1 } else { 0 }
			}
			//		week = week#[..-1] + '>' + week#[-1..]
			week += ' ❔'.repeat((4 - count % 4) % 4)
			last = res.wins#[-1..][0].at
		}
		if date.len == 0 {
			date = res.next
		}
		next_dow := cmds.dow_names[util.sdate_dow(res.next)!]

		mut menu := []MenuItem{}
		if last.len > 0 {
			menu << MenuItem{'Last win: ${week}', none}
		} else {
			menu << MenuItem{'Last win: none (basing next win on prize start date and last day of week)', none}
		}
		menu << MenuItem{'set next (${next_dow} ${*pdate})', menu_weeklywin_next_set(pdate)}
		if last.len > 0 {
			last_dow := cmds.dow_names[util.sdate_dow(last)!]
			menu << MenuItem{'delete last (${last_dow} ${last})', menu_sure(menu_weeklywin_last_delete(pdate,
				last))}
		}
		do_menu(mut c, menu) or {
			if err.str() != 'return' {
				return err
			}
		}
	}
}

fn menu_weeklywin_next_set(pdate &string) MenuFn {
	return fn [pdate] (mut c Client) ! {
		do_menu(mut c, [
			MenuItem{'got', menu_weeklywin_next_set_got(pdate, 'got')},
			MenuItem{'lost', menu_weeklywin_next_set_got(pdate, 'lost')},
			MenuItem{'skip', menu_weeklywin_skip(pdate)},
		])!
	}
}

fn menu_weeklywin_skip(pdate &string) MenuFn {
	return fn [pdate] (mut c Client) ! {
		unsafe {
			*pdate = util.sdate_add(*pdate, 7)!
		}
		menu_nop(mut c)!
	}
}

fn menu_weeklywin_next_set_got(pdate &string, got string) MenuFn {
	return fn [pdate, got] (mut c Client) ! {
		println('setting next win to ${got}')
		c.post[api.Ok]('/api/admin/prizes/cur/wins/${*pdate}/${got}')!
		unsafe {
			*pdate = ''
		}
	}
}

fn menu_weeklywin_last_delete(pdate &string, date string) MenuFn {
	return fn [pdate, date] (mut c Client) ! {
		println('deleting last win')
		c.delete[api.Ok]('/api/admin/prizes/cur/wins/${date}')!
		unsafe {
			*pdate = ''
		}
	}
}

// [][ date, got, typ ]
fn menu_starweek_parse_stars(from string, stars []api.Star) ![][]string {
	mut typs := [0]
	for star in stars {
		if star.typ !in typs {
			typs << star.typ
		}
	}
	typs.sort(a < b)
	till := util.sdate_add(from, 6)!
	mut ret := [][]string{}
	for typ in typs {
		mut any_found := false
		for date := from; date <= till; {
			mut found := false
			for star in stars {
				if star.at == date && star.typ == typ {
					got := if got_ := star.got {
						if got_ { '⭐' } else { '❌' }
					} else {
						'❔'
					}
					ret << [date, got, typ.str()]
					any_found = true
					found = true
				}
			}
			if !found && typ == 0 {
				ret << [date, '--', '0']
			}
			date = util.sdate_add(date, 1)!
		}
		if !any_found && typ in [1, 2] {
			ret << [till, '--', typ.str()]
		}
	}
	return ret
}

fn menu_starweek() MenuFn {
	mut when := 'cur'
	pwhen := &when
	mut idx := 0
	pidx := &idx
	return fn [pwhen, pidx] (mut c Client) ! {
		for {
			prize_res := c.get[api.GetPrizesCur]('/api/prizes/cur')!
			res := c.get[api.GetPrizesWeeks]('/api/prizes/cur/weeks/${*pwhen}')!
			unsafe {
				*pwhen = res.from
			}
			stars_fn := fn [pwhen] (mut c Client) ! {
				res := c.get[api.GetPrizesWeeks]('/api/prizes/cur/weeks/${*pwhen}')!
				mut stars := ''
				for pair in menu_starweek_parse_stars(*pwhen, res.stars)! {
					info := if pair[2].int() > 0 { '-B${pair[2]}' } else { '' }
					stars += '  ${pair[1]}${info}'
				}
				println('Stars: ${stars}')
			}
			// TODO: make 'set star' feint!
			//
			// This can be done by going `feint+"set star"+reset`, but it would
			// need to be redrawn each time.  The problem is that `back` returns
			// to the previous do_menu() loop and we're never given a chance to
			// redefine the menu.  To fix this, do_menu should take an array or
			// MenuRows, which is a sumtype of MenuItem and some other types.
			// E.g., MenuText could be used to render static (unselectable)
			// text.  Also, more complex types can be defined which call
			// function to redefine themselves.  But there would still be a
			// problem: in this menu, the top stars info row, the edit row and
			// the set starrow would all need to fetch stars to render/redefine.
			// This should be fetched one and held at a higher level which the
			// menu rows all have access to.  How to do that?  Maybe we could
			// add an invisible MenuData row, which doesn't render and to which
			// the other rows can access?
			do_menu_sel(mut c, [
				MenuItem{none, stars_fn},
				MenuItem{'edit ${res.from} - ${res.till}', menu_setup_week_edit(pwhen)},
				MenuItem{'next', menu_starweek_move(pwhen, true, none)},
				MenuItem{'prev', menu_starweek_move(pwhen, false, prize_res.prize.start)},
				MenuItem{'set star', menu_stars_set(*pwhen)},
			], pidx) or {
				if err.str() != 'return' {
					return err
				}
			}
		}
	}
}

fn menu_starweek_move(pwhen &string, next bool, prize_start ?string) MenuFn {
	start := prize_start or { '' }
	return fn [pwhen, next, start] (mut c Client) ! {
		if start.len == 0 || *pwhen > start {
			unsafe {
				*pwhen = util.sdate_add(*pwhen, if next { 7 } else { -7 })!
			}
		}
		menu_nop(mut c)!
	}
}

fn menu_setup_week_edit(pwhen &string) MenuFn {
	return fn [pwhen] (mut c Client) ! {
		prize_res := c.get[api.GetPrizesCur]('/api/prizes/cur')!
		mut idx := 0
		for {
			res := c.get[api.GetPrizesWeeks]('/api/prizes/cur/weeks/${*pwhen}')!
			mut menu := []MenuItem{}
			mut bonus_stars := ''
			mut bonus_num := 0
			for pair in menu_starweek_parse_stars(*pwhen, res.stars)! {
				if pair[2].int() == 0 {
					_, _, day := util.parse_sdate(pair[0])!
					dow := cmds.dow_names[util.sdate_dow(pair[0])!]
					entry := '${pair[1]} ${dow} ${day}${util.ordinal(day)}'
					if pair[1] == '--' {
						if pair[0] < prize_res.prize.start {
							menu << MenuItem{faint + 'add ${entry}' + reset, menu_nop}
						} else {
							menu << MenuItem{'add ${entry}', menu_setup_week_add(&idx,
								pair[2].int(), pair[0])}
						}
					} else if pair[1] == '❔' {
						menu << MenuItem{'del ${entry}', menu_setup_week_delete(&idx,
							pair[2].int(), pair[0])}
					} else {
						menu << MenuItem{faint + 'del' + reset + ' ${entry}', menu_nop}
					}
				} else if pair[2].int() > 0 {
					bonus_stars = bonus_stars + ' ${pair[1]}-B${pair[2]}'
					bonus_num = pair[2].int()
				}
			}
			menu << MenuItem{'bonus stars: ${bonus_stars}', menu_setup_week_bonus_stars(res.till,
				bonus_num)}
			do_menu_sel(mut c, menu, &idx) or {
				// if err.str() == 'back' {
				//	return error('return') // menu has no "completion" otherwise
				//} else
				if err.str() != 'return' {
					return err
				}
			}
		}
	}
}

fn menu_setup_week_add(idx &int, typ int, date string) MenuFn {
	return fn [idx, typ, date] (mut c Client) ! {
		term.clear_previous_line()
		c.post[api.Ok]('/api/admin/prizes/cur/stars/${date}/${typ}')!
		unsafe {
			(*idx)++
		}
	}
}

fn menu_setup_week_delete(idx &int, typ int, date string) MenuFn {
	return fn [idx, typ, date] (mut c Client) ! {
		term.clear_previous_line()
		c.delete[api.Ok]('/api/admin/prizes/cur/stars/${date}/${typ}')!
		unsafe {
			(*idx)++
		}
	}
}

fn menu_setup_week_bonus_stars(date string, num_bonus int) MenuFn {
	return fn [date, num_bonus] (mut c Client) ! {
		suggested := if num_bonus == 0 { 2 } else { num_bonus }
		num := inp.read_int('num bonus stars: ', suggested)!
		if num < num_bonus {
			for typ := num_bonus; typ > num; typ-- {
				c.delete[api.Ok]('/api/admin/prizes/cur/stars/${date}/${typ}')!
			}
		} else if num > num_bonus {
			for typ := num_bonus + 1; typ <= num; typ++ {
				c.post[api.Ok]('/api/admin/prizes/cur/stars/${date}/${typ}')!
			}
		}
	}
}

fn menu_deposit(mut c Client) ! {
	do_menu(mut c, [
		MenuItem{'add deposit', menu_deposit_add},
		// MenuItem{'edit_deposit', menu_deposit_edit()},
		MenuItem{'delete deposit', menu_deposit_delete},
	])!
}

fn menu_deposit_add(mut c Client) ! {
	date := inp.read_date('when: ', util.sdate_now())!
	amount := inp.read_int('amount (in pence): ', none)!
	desc := inp.read_string('description: ', none)!
	println('adding deposit')
	c.post_json[api.Ok, api.Deposit]('/api/admin/prizes/cur/deposits', api.Deposit{
		at: date
		amount: amount
		desc: desc
	})!
}

fn menu_deposit_delete(mut c Client) ! {
	deps := c.get[api.GetPrizesDeposits]('/api/prizes/cur/deposits')!
	if deps.deposits.len == 0 {
		println('no deposits')
		return
	}
	mut menu := []MenuItem{}
	for dep in deps.deposits {
		menu << MenuItem{'delete £${dep.amount / 100:.2} "${dep.desc}" (${dep.at})', menu_sure(menu_deposit_delete_id(dep.id))}
	}
	do_menu(mut c, menu)!
}

fn menu_deposit_delete_id(id u64) MenuFn {
	return fn [id] (mut c Client) ! {
		println('deleting deposit')
		c.delete[api.Ok]('/api/admin/prizes/cur/deposits/${id}')!
	}
}

fn menu_prizes(mut c Client) ! {
	mut menu := []MenuItem{}
	if res := c.get[api.GetPrizesCur]('/api/prizes/cur') {
		dow_s := cmds.dow_names[res.prize.first_dow]
		dow_e := cmds.dow_names[(res.prize.first_dow + 5) % 7 + 1]
		got := res.got.deposits + res.got.stars
		menu << MenuItem{'Cur prize: £${res.prize.goal / 100:.2} (got £${got / 100:.2}), week is ${dow_s}-${dow_e}, started ${res.prize.start}', none}
		menu << MenuItem{'modify goal', menu_prizes_modify_goal(res.prize.goal, got)}
		menu << MenuItem{'end', menu_sure(menu_prizes_end)}
	} else {
		if err.str() != 'not found' {
			return err
		} else {
			menu << MenuItem{'Cur prize: none', none}
			menu << MenuItem{'add', menu_prizes_add}
		}
	}
	do_menu(mut c, menu)!
}

fn menu_prizes_add(mut c Client) ! {
	starts := inp.read_date('starts: ', util.sdate_now())!
	dow := inp.read_opt('first dow: ', '', cmds.dow_names)!
	first_dow := cmds.dow_names.index(dow)
	goal := inp.read_int('goal (pence): ', none)!
	star_val := inp.read_int('star_val (pence): ', 200)!
	// TODO: use inline closure, when it doesn't create cc error
	menu_sure(menu_prizes_add_sure(starts, first_dow, goal, star_val))(mut c)!
	// menu_sure(fn [starts, first_dow, goal, star_val] (mut c Client) ! {
	//	println('adding prize')
	//	c.post[api.Ok]('/api/admin/prizes/${starts}/${first_dow}/${goal}/${star_val}')!
	//})(mut c)!
}

fn menu_prizes_add_sure(starts string, first_dow int, goal int, star_val int) MenuFn {
	return fn [starts, first_dow, goal, star_val] (mut c Client) ! {
		println('adding prize')
		c.post_json[api.Ok, api.Prize]('/api/admin/prizes', api.Prize{
			star_val: star_val
			goal: goal
			first_dow: first_dow
			start: starts
		})!
	}
}

fn menu_prizes_end(mut c Client) ! {
	println('ending current prize')
	c.delete[api.Ok]('/api/admin/prizes/cur')!
}

fn menu_prizes_modify_goal(goal int, got int) MenuFn {
	return fn [goal, got] (mut c Client) ! {
		new_goal := inp.read_int('new goal (pence): ', goal)!
		if new_goal < got {
			println('WARNING: new goal has already been achieved')
		}
		menu_sure(menu_prize_modify_goal_sure(new_goal))(mut c)!
	}
}

fn menu_prize_modify_goal_sure(new_goal int) MenuFn {
	return fn [new_goal] (mut c Client) ! {
		println('setting goal')
		c.put[api.Ok]('/api/admin/prizes/cur/goals/${new_goal}')!
	}
}

fn menu_users(mut c Client) ! {
	mut menu := []MenuItem{}
	res := c.get[api.GetAdminUsers]('/api/admin/users')!
	for user in res.users {
		icon := if user.perms.admin { '🧔‍♂️' } else { '👦' }
		menu << MenuItem{'${icon} ${user.username}', menu_user_edit(user)}
	}
	menu << MenuItem{'add user', menu_user_add}
	do_menu(mut c, menu)!
}

fn menu_user_edit(user api.User) MenuFn {
	return fn [user] (mut c Client) ! {
		do_menu(mut c, [
			MenuItem{'set password', menu_change_password(user.username)},
			// MenuItem{'set permissions', menu_user_set_perms(user)},
			MenuItem{'delete', menu_sure(menu_user_delete(user))},
		])!
	}
}

fn menu_user_delete(user api.User) MenuFn {
	return fn [user] (mut c Client) ! {
		println('deleting user ${user.username}')
		c.delete[api.Ok]('/api/admin/users/${user.username}')!
	}
}

fn menu_user_add(mut c Client) ! {
	username := inp.read_string('username: ', none)!
	admin := inp.read_opt('admin? [y/N] ', none, ['y', 'n', ''])! == 'y'
	// TODO: embed, once closures work here...
	menu_sure(menu_user_add_sure(username, admin))(mut c)!
}

fn menu_user_add_sure(username string, admin bool) MenuFn {
	return fn [username, admin] (mut c Client) ! {
		password := rand.uuid_v4().replace('-', '')#[-12..]
		println('adding ${username}, password ${password}')
		pskclear := sha256.sum(password.bytes())
		// use current user's psk (a 32-byte sha256 of password) as aes256 key
		// to encrypt new user's psk (a sha256 of password)
		cipher := aes.new_cipher(sha256.sum(c.password.bytes()))
		mut pskenc := []u8{len: pskclear.len, cap: pskclear.len}
		cipher.encrypt(mut pskenc, pskclear)
		cipher.encrypt(mut pskenc[16..], pskclear[16..])
		c.post_json[api.Ok, api.User]('/api/admin/users', api.User{
			username: username
			psk: pskenc.hex()
			perms: api.UserPerms{
				admin: admin
			}
		})!
	}
}

fn menu_change_password(username string) MenuFn {
	return fn [username] (mut c Client) ! {
		println('user: ${username}')
		password := inp.read_password('new password: ')!
		confirm := inp.read_password('confirm password: ')!
		if password != confirm {
			println('passwords do not match')
			return
		}
		pskclear := sha256.sum(password.bytes())
		println('psk ${pskclear.hex()}')
		// use current user's psk (a 32-byte sha256 of password) as aes256 key
		// to encrypt new user's psk (a sha256 of password)
		cipher := aes.new_cipher(sha256.sum(c.password.bytes()))
		mut pskenc := []u8{len: pskclear.len, cap: pskclear.len}
		cipher.encrypt(mut pskenc, pskclear)
		cipher.encrypt(mut pskenc[16..], pskclear[16..])
		c.put_json[api.Ok, api.PutAdminUsersReq]('/api/admin/users/${username}', api.PutAdminUsersReq{
			psk: pskenc.hex()
		})!
		// update client
		if username == c.username {
			c.password = password
		}
	}
}
