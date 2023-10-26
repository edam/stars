module cmds

import api
import term
import util
import encoding.base64

const dow_names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

pub fn (mut c Client) admin() ! {
	println(fg(.white) + '𝕊𝕋𝔸ℝ𝕊 𝔸𝔻𝕄𝕀ℕ ' + faint + '- ' + reset +
		fg(.blue) + '${c.user}@${c.host}' + reset)
	c.auth()!
	for {
		do_menu(mut c, [
			MenuItem{'set star', menu_stars},
			MenuItem{'weekly win', menu_weekly_win},
			MenuItem{'setup week stars', menu_setup_week_stars()},
			MenuItem{'deposits', menu_deposit},
			MenuItem{'setup prizes', menu_prizes},
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

fn menu_stars(mut c Client) ! {
	cur := c.get[api.ApiWeek]('/api/prize/cur/week/cur')!
	mut stars := []api.Api_Star{}
	if cur.stars.len > 0 && cur.stars[0].got == none {
		// TODO: go back further!
		last := c.get[api.ApiWeek]('/api/prize/cur/week/last')!
		for star in last.stars {
			if star.got == none {
				unsafe {
					stars = last.stars
				}
				break
			}
		}
		if stars.len == 0 {
			unsafe {
				stars = cur.stars
			}
		}
	} else {
		unsafe {
			stars = cur.stars
		}
	}
	mut menu := []MenuItem{}
	mut idx := -1
	for i, star in stars {
		got := if got_ := star.got {
			if got_ { '⭐' } else { '❌' }
		} else {
			idx = if idx == -1 { i } else { idx }
			'❔'
		}
		info := if star.typ > 0 { '-B${star.typ}' } else { ' ${star.at}' }
		title := '${got}${info}'
		menu << MenuItem{title, menu_set_star(star.at, star.typ)}
	}
	idx = if idx == -1 { 0 } else { idx }
	if menu.len <= 0 {
		println('no stars set up!')
	} else {
		do_menu_sel(mut c, menu, &idx)!
	}
}

fn menu_set_star(date string, typ int) MenuFn {
	return fn [date, typ] (mut c Client) ! {
		do_menu(mut c, [
			MenuItem{'got', menu_set_star_got(typ, 'got', date)},
			MenuItem{'lost', menu_set_star_got(typ, 'lost', date)},
			MenuItem{'unset', menu_set_star_got(typ, 'unset', date)},
		])!
	}
}

fn menu_set_typ_star(typ int) MenuFn {
	return fn [typ] (mut c Client) ! {
		mut date := 'today'
		do_menu(mut c, [
			MenuItem{none, fn [date] (mut c Client) ! {
				println('date: ${date}')
			}},
			MenuItem{'got', menu_set_star_got(typ, 'got', &date)},
			MenuItem{'lost', menu_set_star_got(typ, 'lost', &date)},
			MenuItem{'unset', menu_set_star_got(typ, 'unset', &date)},
			MenuItem{'change date ', menu_set_star_date(&date)},
		])!
	}
}

// fn menu_set_star_daily(mut c Client) ! {
//	mut date := 'today'
//	do_menu(mut c, [
//		MenuItem{none, fn [date] (mut c Client) ! {
//			println('date: ${date}')
//		}},
//		MenuItem{'got', menu_set_star_got('got', &date)},
//		MenuItem{'lost', menu_set_star_got('lost', &date)},
//		MenuItem{'unset', menu_set_star_got('unset', &date)},
//		MenuItem{'change date ', menu_set_star_date(&date)},
//	])!
//}

fn menu_set_star_date(date &string) MenuFn {
	return fn [date] (mut c Client) ! {
		unsafe {
			*date = read_date('enter a date: ', *date) or { 'today' }
		}
		term.clear_previous_line()
		return error('back')
	}
}

fn menu_set_star_got(typ int, got string, date &string) MenuFn {
	return fn [typ, got, date] (mut c Client) ! {
		typ_name := if typ > 0 { 'B${typ}' } else { 'daily' }
		println('setting ${typ_name} star for \'${*date}\' to ${got}')
		c.put[api.ApiOk]('/api/admin/prize/cur/star/${*date}/${typ}/${got}')!
	}
}

fn menu_weekly_win(mut c Client) ! {
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
	menu << MenuItem{'set next (${next_dow} ${res.next})', menu_set_next_win(res.next)}
	if last.len > 0 {
		last_dow := cmds.dow_names[util.sdate_to_dow(last)!]
		menu << MenuItem{'delete last (${last_dow} ${last})', menu_delete_last_win(last)}
	}
	do_menu(mut c, menu)!
}

fn menu_set_next_win(date string) MenuFn {
	return fn [date] (mut c Client) ! {
		do_menu(mut c, [
			MenuItem{'got', menu_set_next_win_got(date, 'got')},
			MenuItem{'lost', menu_set_next_win_got(date, 'lost')},
		])!
	}
}

fn menu_set_next_win_got(date string, got string) MenuFn {
	return fn [date, got] (mut c Client) ! {
		println('setting next win to ${got}')
		c.post[api.ApiOk]('/api/admin/prize/cur/win/${date}/${got}')!
	}
}

fn menu_delete_last_win(date string) MenuFn {
	return fn [date] (mut c Client) ! {
		do_menu(mut c, [
			MenuItem{'for sure', menu_delete_last_win_sure(date)},
		])!
	}
}

fn menu_delete_last_win_sure(date string) MenuFn {
	return fn [date] (mut c Client) ! {
		println('deleting last win')
		c.delete[api.ApiOk]('/api/admin/prize/cur/win/${date}')!
	}
}

// [][ date, got, typ ]
fn menu_setup_parse_stars(from string, stars []api.Api_Star) ![][]string {
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

fn menu_setup_week_stars() MenuFn {
	mut when := 'cur'
	pwhen := &when
	return fn [pwhen] (mut c Client) ! {
		for {
			res := c.get[api.ApiWeek]('/api/prize/cur/week/${*pwhen}')!
			unsafe {
				*pwhen = res.from
			}
			stars_fn := fn [pwhen] (mut c Client) ! {
				res := c.get[api.ApiWeek]('/api/prize/cur/week/${*pwhen}')!
				mut stars := ''
				for pair in menu_setup_parse_stars(*pwhen, res.stars)! {
					info := if pair[2].int() > 0 { '-B${pair[2]}' } else { '' }
					stars += '  ${pair[1]}${info}'
				}
				println('Stars: ${stars}')
			}
			do_menu(mut c, [
				MenuItem{none, stars_fn},
				MenuItem{'edit ${res.from} - ${res.till}', menu_setup_week_edit(pwhen)},
				MenuItem{'next', menu_setup_week_move(pwhen, true)},
				MenuItem{'prev', menu_setup_week_move(pwhen, false)},
			]) or {
				if err.str() != 'return' {
					return err
				}
			}
		}
	}
}

fn menu_setup_week_move(pwhen &string, next bool) MenuFn {
	return fn [pwhen, next] (mut c Client) ! {
		unsafe {
			*pwhen = util.sdate_add(*pwhen, if next { 7 } else { -7 })!
			term.clear_previous_line()
		}
	}
}

fn menu_setup_week_edit(pwhen &string) MenuFn {
	return fn [pwhen] (mut c Client) ! {
		mut idx := 0
		for {
			res := c.get[api.ApiWeek]('/api/prize/cur/week/${*pwhen}')!
			mut menu := []MenuItem{}
			mut bonus_stars := ''
			mut bonus_num := 0
			for pair in menu_setup_parse_stars(*pwhen, res.stars)! {
				if pair[2].int() == 0 {
					when := cmds.dow_names[util.sdate_to_dow(pair[0])!]
					entry := '${pair[1]} ${when}'
					if pair[1] == '--' {
						menu << MenuItem{'add ${entry}', menu_setup_week_add(&idx, pair[2].int(),
							pair[0])}
					} else if pair[1] == '❔' {
						menu << MenuItem{'del ${entry}', menu_setup_week_delete(&idx,
							pair[2].int(), pair[0])}
					} else {
						menu << MenuItem{faint + 'del' + reset + ' ${entry}', menu_setup_week_nop}
					}
				} else if pair[2].int() > 0 {
					bonus_stars = bonus_stars + ' ${pair[1]}-B${pair[2]}'
					bonus_num = pair[2].int()
				}
			}
			menu << MenuItem{'bonus stars: ${bonus_stars}', menu_setup_week_bonus_stars(res.till,
				bonus_num)}
			do_menu_sel(mut c, menu, &idx) or {
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
		num := read_int('num bonus stars: ', suggested)!
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

fn menu_setup_week_nop(mut c Client) ! {
	term.clear_previous_line()
}

fn menu_deposit(mut c Client) ! {
	do_menu(mut c, [
		MenuItem{'add deposit', menu_deposit_add},
		// MenuItem{'delete_deposit', menu_deposit_delete},
		// MenuItem{'edit_deposit', menu_deposit_edit()},
	])!
}

fn menu_deposit_add(mut c Client) ! {
	date := read_date('when: ', util.sdate_now())!
	amount := read_int('amount (in pence): ', none)!
	desc := base64.url_encode_str(read_string('description: ', none)!)
	c.put[api.ApiOk]('/api/admin/prize/cur/deposit/${date}/${amount}/${desc}')!
}

fn menu_prizes(mut c Client) ! {
	mut menu := []MenuItem{}
	if res := c.get[api.ApiPrizeCur]('/api/prize/cur') {
		dow_s := cmds.dow_names[res.first_dow]
		dow_e := cmds.dow_names[(res.first_dow + 5) % 7 + 1]
		menu << MenuItem{'Cur prize: £${res.goal / 100:.2} (${res.stars} stars), week is ${dow_s}-${dow_e} since ${res.start}', none}
		menu << MenuItem{'end', menu_prizes_end}
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
	starts := read_date('starts: ', util.sdate_now())!
	first_dow := read_opt('first dow: ', '', cmds.dow_names)!
	goal := read_int('goal (pence): ', none)!
	star_val := read_int('star_val (pence): ', 200)!
}

fn menu_prizes_end(mut c Client) ! {
}
