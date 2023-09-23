module cmds

import math

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
		} else if c in [`⭐`, `❌`, `❔`] {
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

fn draw_server_line(host string, ms i64) {
	prt(lcr('', '', cmds.faint + 'from ${host} in ~${ms}ms'))
}
