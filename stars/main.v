module main

import edam.ggetopt { die }
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
		else {
			die('unknown command')
		}
	}
}
