module cmds

import time
import api
import math

pub fn (mut c Client) info() ! {
	sw := time.new_stopwatch()
	c.auth()!

	res1 := c.get[api.ApiPrizeCur]('/api/prize/cur')!
	res2 := c.get[api.ApiWeek]('/api/week/cur')!
	res3 := c.get[api.ApiWins]('/api/prize/cur/wins')!

	prt('')
	prt(lcr(faint + '~', fg(.white) + stars_title, faint + '~'))

	draw_grand_prize(res1)
	draw_weekly_stars(true, res2)
	prt('')
	prt(lcr('ᴍᴏɴᴛʜʟʏ ᴍᴇᴅᴀʟꜱ', '', 'ʙᴏɴᴜꜱ '))
	draw_month_of_wins('', res3.wins, false)
	draw_server_line(c.host, sw.elapsed().milliseconds())
}

fn draw_grand_prize(res api.ApiPrizeCur) {
	star_width := width * res.got.stars / res.goal
	dep_width := width * res.got.deposits / res.goal
	rem_width := width - star_width - dep_width

	tline := bg(.yellow) + '▔'.repeat(star_width) + bg(.green) + '▔'.repeat(dep_width) + reset +
		'▔'.repeat(rem_width) + ' 🏆'
	bline := '▔'.repeat(width)

	info1 := ra(['${res.stars} stars', 'deposits'])
	info2 := ra(['${res.got.stars / 100}', '${res.got.deposits / 100}'])
	perc := 100.0 * f64(res.got.stars + res.got.deposits) / f64(res.goal)

	prt('')
	prt(lcr('ɢʀᴀɴᴅ ᴩʀɪᴢᴇ', '', '${perc:.0}%'))
	prt('${tline}')
	prt('${bline}')

	start := time.parse('${res.start} 00:00:00') or { time.now() }
	so_far := time.now() - start
	est_days := so_far.days() * 100.0 / perc
	est_end := start.add_days(int(est_days))
	eta := '${est_end.day} ${month_names[est_end.month]}'

	prt(lcr(fg(.yellow) + '${info1[0]} = £${info2[0]}' + reset, '', 'total ' + fg(.white) +
		'£${(res.got.stars + res.got.deposits) / 100} / £${res.goal / 100}'))
	prt(lcr(fg(.green) + '${info1[1]} = £${info2[1]}' + reset, '', 'ETA: ${eta}'))
}

fn draw_star(got ?bool, total &int, avail &int) string {
	if got_ := got {
		if got_ {
			(*total)++
			return '⭐'
		} else {
			return '❌'
		}
	} else {
		(*avail)++
		return '❔'
	}
}

fn draw_weekly_stars(this bool, res api.ApiWeek) {
	mut regular := 0
	mut bonus := 0
	for star in res.stars {
		if star.typ == 0 {
			regular++
		} else {
			bonus++
		}
	}

	week := if this { 'ᴛʜɪꜱ ᴡᴇᴇᴋ' } else { 'ʟᴀꜱᴛ ᴡᴇᴇᴋ' }
	nweek := math.max(9, 2 + 4 * regular)

	info1 := la([week, '▔'.repeat(nweek)])
	info2 := la(['ʙᴏɴᴜꜱ', '▔▔▔▔▔▔'])

	mut total := 0
	mut avail := 0
	mut sline := '  ' +
		res.stars.filter(it.typ == 0).map(draw_star(it.got, &total, &avail)).join('  ')
	for typ in [1, 2] {
		bstars := res.stars.filter(it.typ == typ)
		if bstars.len == 1 {
			sline += '      ' + draw_star(bstars[0].got, &total, &avail)
		}
	}
	lost := res.stars.len - total - avail

	from := time.parse('${res.from} 00:00:00') or { panic(err) }
	till := time.parse('${res.till} 23:59:59') or { panic(err) }
	when := '${from.day} ${month_names[from.month]} - ${till.day} ${month_names[till.month]}'
	lostinfo := if lost > 0 { 'lost ${res.stars.len - total - avail} :(' } else { '' }

	prt('')
	prt(info1[0] + '  ${info2[0]}'.repeat(bonus))
	prt(lcr(info1[1] + '  ${info2[1]}'.repeat(bonus), '', when))
	prt(lcr(sline, '', fg(.white) + '${total} / ${res.stars.len}' + reset + ' stars'))
	prt(lcr('', '', fg(.red) + lostinfo))
	prt(info1[1] + '  ${info2[1]}'.repeat(bonus))
}
