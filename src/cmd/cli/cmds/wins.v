module cmds

import time
import api
import math

pub fn (mut c Client) wins() ! {
	sw := time.new_stopwatch()
	c.auth()!

	res := c.get[api.GetPrizesWins]('/api/prizes/cur/wins/all')!

	prt('')
	prt(lcr('ᴍᴏɴᴛʜʟʏ ᴍᴇᴅᴀʟꜱ', '', 'ʙᴏɴᴜꜱ '))
	mut wins := []api.Win{}
	mut count := 0
	for win in res.wins {
		wins << win
		if win.got {
			count++
		}
		if count == 4 {
			draw_month_of_wins(wins, win.at)
			wins = []
			count = 0
		}
	}
	draw_month_of_wins(wins, none)
	draw_server_line(c.host, sw.elapsed().milliseconds())
}

fn draw_month_of_wins(wins []api.Win, bonus_at ?string) {
	num_got := wins.filter(it.got).len
	num := wins.len + (4 - num_got)
	bonus := if at := bonus_at { faint + '  ${at} ' + reset } else { '' }
	win_width := math.min(6, ((width - 8 - num + 1 - len(bonus)) / num) & 0xffffe)

	pad_left := (win_width - 2) / 2
	pad_right := (win_width - 2) - pad_left
	mut last := false
	mut line := ''
	mut bline := ''
	mut tline := ''
	for i := 0; i < num; i++ {
		got := if i < wins.len { wins[i].got } else { false }
		lost := if i < wins.len { !wins[i].got } else { false }
		medal := if got {
			'🏅'
		} else if lost {
			'❌'
		} else {
			'  '
		}
		lfaint := if got { '' } else { faint } // if lost { faint } else { '' }
		lreset := if got { reset } else { '' } // if lost { '' } else { reset }
		tline += if i > 0 {
			if got {
				if last { '┳' } else { reset + '┲' }
			} else {
				if last { '┱' + lfaint } else { lreset + '┬' + lfaint }
			}
		} else {
			if got { '┏' } else { lfaint + '┌' }
		}
		bline += if i > 0 {
			if got {
				if last { '┻' } else { reset + '┺' }
			} else {
				if last { '┹' + lfaint } else { lreset + '┴' + lfaint }
			}
		} else {
			if got { '┗' } else { lfaint + '└' }
		}
		line += if last || got { reset + '┃' } else { lreset + lfaint + '│' }
		tline += if got { '━' } else { '─' }.repeat(win_width)
		bline += if got { '━' } else { '─' }.repeat(win_width)
		line += ' '.repeat(pad_left) + medal + ' '.repeat(pad_right) + lreset + lfaint
		last = got
	}
	tline += if last { '┓' } else { '┐' }
	bline += if last { '┛' } else { '┘' }
	line += if last { '┃' } else { '│' }
	tmid_pad := ' '.repeat(width - win_width * num - num - 1 - 6)
	lmid_pad := ' '.repeat(width - len(bonus) - win_width * num - num - 1 - 6)
	prt(tline + tmid_pad + reset + '▔'.repeat(6))
	prt(line + lmid_pad + bonus + '  ' + if len(bonus) > 0 { '⭐' } else { '❔' })
	prt(bline)
}
