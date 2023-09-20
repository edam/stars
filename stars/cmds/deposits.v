module cmds

import time
import api

fn draw_deposits(res api.ApiDeposits) {
	prt('')
	prt('ᴅᴇᴩᴏꜱɪᴛꜱ')
	prt('▔'.repeat(width))
	mut amounts := ra(res.deposits.map('${it.amount / 100}'))
	for i, deposit in res.deposits {
		colour := if i & 1 == 0 { fg(.yellow) } else { fg(.green) }
		prt(lcr(colour + deposit.desc, '', faint + deposit.at + reset + '    £${amounts[i]}'))
		prt('')
	}
	prt('▔'.repeat(width))
}

pub fn (mut c Client) deposits() ! {
	sw := time.new_stopwatch()
	c.auth()!
	res := c.get[api.ApiDeposits]('/api/prize/cur/deposits')!
	draw_deposits(res)
	draw_server_line(c.host, sw.elapsed().milliseconds())
}
