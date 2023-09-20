module main

import edam.ggetopt { die, prog }
import cmds

fn main() {
	args := Args.from_cli()

	mut client := cmds.Client{
		host: args.host
		port: args.port
		user: args.user
		psk: args.psk
	}

	match args.cmd or { '' } {
		'info', '' {
			client.info() or { die(err) }
		}
		'last' {
			client.last() or { die(err) }
		}
		'admin' {
			client.admin() or { die(err) }
		}
		'deposits' {
			client.deposits() or { die(err) }
		}
		'help' {
			println('Usage: ${prog()} [COMMAND]')
			println('')
			println('Commands:')
			println('  info      Prize pot and daily stars overview (default)')
			println("  last      Last week's stars")
			println('  deposits  Deposit details')
			println('  admin     Admin menu')
		}
		else {
			die('unknown command')
		}
	}
}
