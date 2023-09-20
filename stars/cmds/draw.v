module cmds

import api
import math
import time

const (
	stars_title = '𝔻 𝔸 𝕀 𝕃 𝕐   𝕊 𝕋 𝔸 ℝ 𝕊'
	padding     = '  '
	width       = 80 - 2 * padding.len - 3
	month_names = ['', 'ᴊᴀɴ', 'ꜰᴇʙ', 'ᴍᴀʀ', 'ᴀᴩʀ', 'ᴍᴀʏ', 'ᴊᴜɴ',
		'ᴊᴜʟ', 'ᴀᴜɢ', 'ꜱᴇᴩ', 'ᴏᴄᴛ', 'ɴᴏᴠ', 'ᴅᴇᴄ']
	reset       = '\e[0m'
	faint       = '\e[2m'
	underline   = '\e[4m'
	invert      = '\e[7m'
)

enum Colour {
	black
	red
	green
	yellow
	blue
	magenta
	cyan
	white
}

enum Align {
	left
	right
}

fn fg(c Colour) string {
	return match c {
		.black { '\e[1;30m' }
		.red { '\e[0;31m' }
		.green { '\e[1;32m' }
		.yellow { '\e[1;33m' }
		.blue { '\e[1;34m' }
		.magenta { '\e[1;35m' }
		.cyan { '\e[1;36m' }
		.white { '\e[1;37m' }
	}
}

fn bg(c Colour) string {
	return match c {
		.black { '\e[1;40m' }
		.red { '\e[1;41m' }
		.green { '\e[1;42m' }
		.yellow { '\e[1;43m' }
		.blue { '\e[1;44m' }
		.magenta { '\e[1;45m' }
		.cyan { '\e[1;46m' }
		.white { '\e[1;47m' }
	}
}

fn len(str string) int {
	mut ret := 0
	mut in_esc := false
	for c in str.runes() {
		if in_esc {
			if c == `m` {
				in_esc = false
			}
		} else if c == `\e` {
			in_esc = true
		} else if c in [`⭐`, `❌`, `❔`, `🌟`] {
			ret += 2
		} else {
			ret++
		}
	}
	return ret
}

fn ra(strs []string) []string {
	return al(strs, .right)
}

fn la(strs []string) []string {
	return al(strs, .left)
}

fn al(strs []string, align Align) []string {
	mut ws := []int{}
	mut mw := 0
	for str in strs {
		w := len(str)
		ws << w
		mw = math.max(mw, w)
	}
	mut out := []string{}
	for i, str in strs {
		p := ' '.repeat(mw - ws[i])
		out << match align {
			.left { '${str}${p}' }
			.right { '${p}${str}' }
		}
	}
	return out
}

fn lcr(left string, centre string, right string) string {
	rem := cmds.width - len(left) - len(centre) - len(right)
	pad1 := ' '.repeat(rem / 2)
	pad2 := ' '.repeat(rem - (rem / 2))
	return '${left}${cmds.reset}${pad1}${centre}${pad2}${cmds.reset}${right}'
}

fn prt[T](args ...T) {
	if args.len == 1 && args[0] == '' {
		println('')
	} else {
		println(cmds.padding + args.map(it.str()).join('') + cmds.reset)
	}
}

// --

fn draw_title() {
	prt('')
	prt(lcr(cmds.faint + '~', fg(.white) + cmds.stars_title, cmds.faint + '~'))
}

fn draw_grand_prize(res api.ApiPrizeCur) {
	star_width := cmds.width * res.got.stars / res.goal
	dep_width := cmds.width * res.got.deposits / res.goal
	rem_width := cmds.width - star_width - dep_width

	tline := bg(.yellow) + '▔'.repeat(star_width) + bg(.green) + '▔'.repeat(dep_width) +
		cmds.reset + '▔'.repeat(rem_width) + ' 🏆'
	bline := '▔'.repeat(cmds.width)

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
	eta := '${est_end.day} ${cmds.month_names[est_end.month]}'

	prt(lcr(fg(.yellow) + '${info1[0]} = £${info2[0]}' + cmds.reset, '', 'total ' + fg(.white) +
		'£${(res.got.stars + res.got.deposits) / 100} / £${res.goal / 100}'))
	prt(lcr(fg(.green) + '${info1[1]} = £${info2[1]}' + cmds.reset, '', 'ETA: ${eta}'))
}

fn draw_star(star api.ApiWeek_Star, total &int, avail &int) string {
	if got := star.got {
		if got {
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
	mut sline := '  ' + res.stars.filter(it.typ == 0).map(draw_star(it, &total, &avail)).join('  ')
	for typ in [1, 2] {
		bstars := res.stars.filter(it.typ == typ)
		if bstars.len == 1 {
			sline += '      ' + draw_star(bstars[0], &total, &avail)
		}
	}
	lost := res.stars.len - total - avail

	from := time.parse('${res.from} 00:00:00') or { panic(err) }
	till := time.parse('${res.till} 23:59:59') or { panic(err) }
	when := '${from.day} ${cmds.month_names[from.month]} - ${till.day} ${cmds.month_names[till.month]}'
	lostinfo := if lost > 0 { 'lost ${res.stars.len - total - avail} :(' } else { '' }

	prt('')
	prt(info1[0] + '  ${info2[0]}'.repeat(bonus))
	prt(lcr(info1[1] + '  ${info2[1]}'.repeat(bonus), '', when))
	prt(lcr(sline, '', fg(.white) + '${total} / ${res.stars.len}' + cmds.reset + ' stars'))
	prt(lcr('', '', fg(.red) + lostinfo))
	prt(info1[1] + '  ${info2[1]}'.repeat(bonus))
}

fn draw_server_line(host string, ms i64) {
	prt(lcr('', '', cmds.faint + 'from ${host} in ~${ms}ms'))
}
