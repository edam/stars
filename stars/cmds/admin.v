module cmds

import api
import term

const star_types = ['daily', '1st bonus', '2nd bonus']

pub fn (mut c Client) admin() ! {
	println(fg(.white) + '𝕊𝕋𝔸ℝ𝕊 𝔸𝔻𝕄𝕀ℕ' + fg(.blue) + ' [${c.user}]' +
		reset)
	c.auth()!
	for {
		do_menu(mut c, [
			MenuItem{'set star', menu_stars},
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

fn menu_stars(mut c Client) ! {
	stars := c.get[api.ApiWeek]('/api/week/cur')!
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
			MenuItem{'err', menu_error},
		])!
	}
}

fn menu_error(mut c Client) ! {
	return error('no')
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
