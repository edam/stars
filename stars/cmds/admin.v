module cmds

import api
import term
import util

const star_types = ['daily', '1st bonus', '2nd bonus', 'monthly bonus']

const dow_names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

pub fn (mut c Client) admin() ! {
	println(fg(.white) + '𝕊𝕋𝔸ℝ𝕊 𝔸𝔻𝕄𝕀ℕ' + fg(.blue) + ' [${c.user}]' +
		reset)
	c.auth()!
	for {
		do_menu(mut c, [
			MenuItem{'set star', menu_stars},
			MenuItem{'weekly win', menu_weekly_win},
			MenuItem{'setup week stars', menu_setup_week_stars()},
			MenuItem{'quit', menu_quit},
		]) or {
			if err.str() == 'back' || err.str() == 'aborted' {
				println('bye')
				return
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
	stars := c.get[api.ApiWeek]('/api/prize/cur/week/cur')!
	mut menu := []MenuItem{}
	mut idx := -1
	for i, star in stars.stars {
		got := if got_ := star.got {
			if got_ { '⭐' } else { '❌' }
		} else {
			idx = if idx == -1 { i } else { idx }
			'❔'
		}
		title := '${got} ${star.at} (${cmds.star_types[star.typ]})'
		menu << MenuItem{title, menu_set_star(star.at, star.typ)}
	}
	idx = if idx == -1 { 0 } else { idx }
	do_menu_sel(mut c, menu, &idx)!
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
			*date = do_get_date() or { 'today' }
		}
		term.clear_previous_line()
		return error('back')
	}
}

fn menu_set_star_got(typ int, got string, date &string) MenuFn {
	return fn [typ, got, date] (mut c Client) ! {
		println('setting ${cmds.star_types[typ]} star for \'${*date}\' to ${got}')
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
	till := util.sdate_add(from, 6)!
	mut ret := [][]string{}
	for typ := 0; typ <= 3; typ++ {
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
					info := if pair[2].int() > 0 { 'B${pair[2]}-' } else { '' }
					stars += '  ${info}${pair[1]}'
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
			for pair in menu_setup_parse_stars(*pwhen, res.stars)! {
				bonus := if pair[2].int() > 0 {
					'B${pair[2]}'
				} else {
					cmds.dow_names[util.sdate_to_dow(pair[0])!]
				}
				entry := '${pair[1]} ${bonus}'
				if pair[1] == '--' {
					menu << MenuItem{'add ${entry}', menu_setup_week_add(&idx, pair[2].int(),
						pair[0])}
				} else if pair[1] == '❔' {
					menu << MenuItem{'del ${entry}', menu_setup_week_delete(&idx, pair[2].int(),
						pair[0])}
				} else {
					menu << MenuItem{faint + 'del' + reset + ' ${entry}', menu_setup_week_nop}
				}
			}
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

fn menu_setup_week_nop(mut c Client) ! {
	term.clear_previous_line()
}
