module cmds

import api
import term
import util

const star_types = ['daily', '1st bonus', '2nd bonus']

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
	for star in stars.stars {
		got := if got_ := star.got {
			if got_ { '⭐' } else { '❌' }
		} else {
			'❔'
		}
		title := '${got} ${star.at} (${cmds.star_types[star.typ]})'
		menu << MenuItem{title, menu_set_star(star.at, star.typ)}
	}
	do_menu(mut c, menu)!
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
		c.post[api.ApiOk]('/api/admin/prize/cur/star/${*date}/${typ}/${got}')!
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

fn menu_setup_week_stars() MenuFn {
	mut when := 'cur'
	mut idx := 0
	pwhen := &when
	return fn [idx, pwhen] (mut c Client) ! {
		for {
			println('FETCH ${*pwhen}')
			stars := c.get[api.ApiWeek]('/api/prize/cur/week/${*pwhen}')!
			println('GOT ${stars}')
			unsafe {
				*pwhen = stars.from
			}
			do_menu_sel(mut c, [
				MenuItem{'Week: ${stars.from} - ${stars.till}', none},
				MenuItem{'prev', menu_setup_week_move(pwhen, -7)},
				MenuItem{'next', menu_setup_week_move(pwhen, 7)},
			], &idx) or {
				if err.str() != 'return' {
					return err
				}
			}
		}
	}
}

fn menu_setup_week_move(pwhen &string, days int) MenuFn {
	return fn [pwhen, days] (mut c Client) ! {
		unsafe {
			*pwhen = util.sdate_add(*pwhen, days)!
			term.clear_previous_line()
		}
	}
}
