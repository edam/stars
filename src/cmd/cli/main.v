module main

import edam.ggetopt { die, prog }
import cmds

fn main() {
	args := Args.from_cli_and_conf()

	mut client := cmds.Client{
		host: args.host
		port: args.port
		user: args.user
		pw: args.pw
	}

	match args.cmd or { '' } {
		'stars', '' {
			client.info() or { die(err) }
		}
		'last' {
			client.last() or { die(err) }
		}
		'latest' {
			client.latest() or { die(err) }
		}
		'admin' {
			client.admin() or { die(err) }
		}
		'deps', 'deposits' {
			client.deposits() or { die(err) }
		}
		'wins', 'medals' {
			client.wins() or { die(err) }
		}
		'help', '?' {
			ggetopt.print_help(options)
			exit(0)
		}
		else {
			die('unknown command, try `${prog()} --help`')
		}
	}
}
