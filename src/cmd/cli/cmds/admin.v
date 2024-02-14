module cmds

import api
import term
import util
import encoding.base64
import inp

const dow_names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

pub fn (mut c Client) admin() ! {
	println(fg(.white) + '𝕊𝕋𝔸ℝ𝕊 𝔸𝔻𝕄𝕀ℕ ' + faint + '- ' + reset +
		fg(.blue) + '${c.user}@${c.host}' + reset)
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

fn menu_quit(mut c Client) ! {
	println('')
	return error('aborted')
}

fn menu_nop(mut c Client) ! {
	term.clear_previous_line()
	// returns `return`, so previous menu needs to handle returns!
}

fn menu_stars_set(when ?string) MenuFn {
	when_ := when or { 'latest' }
	return fn [when_] (mut c Client) ! {
		cur := c.get[api.ApiWeek]('/api/prize/cur/week/${when_}')!
		mut menu := []MenuItem{}
		mut idx := -1
		for i, star in cur.stars {
			got := if got_ := star.got {
				if got_ { '⭐' } else { '❌' }
			} else {
				idx = if idx == -1 { i } else { idx }
				'❔'
			}
			info := if star.typ > 0 { '-B${star.typ}' } else { ' ${star.at}' }
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
		c.put[api.ApiOk]('/api/admin/prize/cur/star/${*date}/${typ}/${got}')!
	}
}

fn menu_weeklywin(mut c Client) ! {
	res := c.get[api.ApiWins]('/api/prize/cur/wins/all')!
	mut menu := []MenuItem{}
	mut last := ''
	if res.wins.len > 0 {
		mut week := ''
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
		menu << MenuItem{'Last wins:${week}', none}
	} else {
		menu << MenuItem{'No wins yet. Next win is based on prize start date and last day of week.', none}
	}

	next_dow := cmds.dow_names[util.sdate_to_dow(res.next)!]
	menu << MenuItem{'set next (${next_dow} ${res.next})', menu_weeklywin_next_set(res.next)}
	if last.len > 0 {
		last_dow := cmds.dow_names[util.sdate_to_dow(last)!]
		menu << MenuItem{'delete last (${last_dow} ${last})', menu_weeklywin_last_delete(last)}
	}
	do_menu(mut c, menu)!
}

fn menu_weeklywin_next_set(date string) MenuFn {
	return fn [date] (mut c Client) ! {
		do_menu(mut c, [
			MenuItem{'got', menu_weeklywin_next_set_got(date, 'got')},
			MenuItem{'lost', menu_weeklywin_next_set_got(date, 'lost')},
		])!
	}
}

fn menu_weeklywin_next_set_got(date string, got string) MenuFn {
	return fn [date, got] (mut c Client) ! {
		println('setting next win to ${got}')
		c.post[api.ApiOk]('/api/admin/prize/cur/win/${date}/${got}')!
	}
}

fn menu_weeklywin_last_delete(date string) MenuFn {
	return fn [date] (mut c Client) ! {
		do_menu(mut c, [
			MenuItem{'sure?', menu_weeklywin_last_delete_sure(date)},
		])!
	}
}

fn menu_weeklywin_last_delete_sure(date string) MenuFn {
	return fn [date] (mut c Client) ! {
		println('deleting last win')
		c.delete[api.ApiOk]('/api/admin/prize/cur/win/${date}')!
	}
}

// [][ date, got, typ ]
fn menu_starweek_parse_stars(from string, stars []api.Api_Star) ![][]string {
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
			prize_res := c.get[api.ApiPrizeCur]('/api/prize/cur')!
			res := c.get[api.ApiWeek]('/api/prize/cur/week/${*pwhen}')!
			unsafe {
				*pwhen = res.from
			}
			stars_fn := fn [pwhen] (mut c Client) ! {
				res := c.get[api.ApiWeek]('/api/prize/cur/week/${*pwhen}')!
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
				MenuItem{'prev', menu_starweek_move(pwhen, false, prize_res.start)},
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
		prize_res := c.get[api.ApiPrizeCur]('/api/prize/cur')!
		mut idx := 0
		for {
			res := c.get[api.ApiWeek]('/api/prize/cur/week/${*pwhen}')!
			mut menu := []MenuItem{}
			mut bonus_stars := ''
			mut bonus_num := 0
			for pair in menu_starweek_parse_stars(*pwhen, res.stars)! {
				if pair[2].int() == 0 {
					_, _, day := util.parse_sdate(pair[0])!
					dow := cmds.dow_names[util.sdate_to_dow(pair[0])!]
					entry := '${pair[1]} ${dow} ${day}${util.ordinal(day)}'
					if pair[1] == '--' {
						if pair[0] < prize_res.start {
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
		c.post[api.ApiOk]('/api/admin/prize/cur/star/${date}/${typ}')!
		unsafe {
			(*idx)++
		}
	}
}

fn menu_setup_week_delete(idx &int, typ int, date string) MenuFn {
	return fn [idx, typ, date] (mut c Client) ! {
		term.clear_previous_line()
		c.delete[api.ApiOk]('/api/admin/prize/cur/star/${date}/${typ}')!
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
				c.delete[api.ApiOk]('/api/admin/prize/cur/star/${date}/${typ}')!
			}
		} else if num > num_bonus {
			for typ := num_bonus + 1; typ <= num; typ++ {
				c.post[api.ApiOk]('/api/admin/prize/cur/star/${date}/${typ}')!
			}
		}
	}
}

fn menu_deposit(mut c Client) ! {
	do_menu(mut c, [
		MenuItem{'add deposit', menu_deposit_add},
		// MenuItem{'delete_deposit', menu_deposit_delete},
		// MenuItem{'edit_deposit', menu_deposit_edit()},
	])!
}

fn menu_deposit_add(mut c Client) ! {
	date := inp.read_date('when: ', util.sdate_now())!
	amount := inp.read_int('amount (in pence): ', none)!
	desc := base64.url_encode_str(inp.read_string('description: ', none)!)
	c.put[api.ApiOk]('/api/admin/prize/cur/deposit/${date}/${amount}/${desc}')!
}

fn menu_prizes(mut c Client) ! {
	mut menu := []MenuItem{}
	if res := c.get[api.ApiPrizeCur]('/api/prize/cur') {
		dow_s := cmds.dow_names[res.first_dow]
		dow_e := cmds.dow_names[(res.first_dow + 5) % 7 + 1]
		menu << MenuItem{'Cur prize: £${res.goal / 100:.2} (${res.stars} stars), week is ${dow_s}-${dow_e}, started ${res.start}', none}
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

fn menu_sure(sure_fn MenuFn) MenuFn {
	return fn [sure_fn] (mut c Client) ! {
		do_menu(mut c, [
			MenuItem{'sure?', sure_fn},
		])!
	}
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
	//	c.post[api.ApiOk]('/api/admin/prizes/${starts}/${first_dow}/${goal}/${star_val}')!
	//})(mut c)!
}

fn menu_prizes_add_sure(starts string, first_dow int, goal int, star_val int) MenuFn {
	return fn [starts, first_dow, goal, star_val] (mut c Client) ! {
		println('adding prize')
		c.post[api.ApiOk]('/api/admin/prizes/${starts}/${first_dow}/${goal}/${star_val}')!
	}
}

fn menu_prizes_end(mut c Client) ! {
	println('ending current prize')
	c.delete[api.ApiOk]('/api/admin/prize/cur')!
}

fn menu_users(mut c Client) ! {
	mut menu := []MenuItem{}
	res := c.get[api.ApiUsers]('/api/admin/users')!
	for user in res.users {
		menu << MenuItem{'🧑 ${user.name}', menu_user_edit(user)}
	}
	menu << MenuItem{'add user', menu_user_add}
	do_menu(mut c, menu)!
}

fn menu_user_edit(user api.Api_User) MenuFn {
	return fn [user] (mut c Client) ! {
		do_menu(mut c, [
			// MenuItem{'set password', menu_user_edit_password()},
			// MenuItem{'set permissions', menu_user_set_perms(user)},
			MenuItem{'delete', menu_sure(menu_user_delete(user))},
		])!
	}
}

fn menu_user_delete(user api.Api_User) MenuFn {
	return fn [user] (mut c Client) ! {
		println('deleting user ${user.name}')
		c.delete[api.ApiOk]('/api/admin/user/${user.name}')!
	}
}

fn menu_user_add(mut c Client) ! {
	println('not implemented')
}
