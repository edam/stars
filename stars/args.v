import edam.ggetopt
import os
import toml

const (
	default_conf = '~/.starsrc'
	default_port = 8070
)

[heap]
pub struct Args {
pub mut:
	cmd      ?string
	cmd_args []string
	conf     string = default_conf
	host     string
	port     int = default_port
	user     string
	psk      string
}

const options = [
	ggetopt.text('Usage: ${ggetopt.prog()} [OPTION]... COMMAND'),
	ggetopt.text(''),
	ggetopt.text('Options:'),
	ggetopt.opt('conf', `c`).arg('FILE', true)
		.help('configuration file (${default_conf})'),
	ggetopt.opt('host', `h`).arg('HOST', true)
		.help('hostname to connect to'),
	ggetopt.opt('port', `p`).arg('PORT', true)
		.help('port to connect to (${default_port})'),
	ggetopt.opt_help(),
]

fn (mut a Args) pre_process_arg(arg string, val ?string) ! {
	match arg {
		'conf', 'c' {
			a.conf = val or { '' }
		}
		'help' {
			ggetopt.print_help(options)
			exit(0)
		}
		else {}
	}
}

fn (mut a Args) process_arg(arg string, val ?string) ! {
	match arg {
		'host', 'h' {
			a.host = val or { '' }
		}
		'port', 'p' {
			a.port = val or { '' }.int()
			if a.port <= 1024 {
				return error('--port: port must be > 1024')
			}
		}
		else {}
	}
}

fn (mut a Args) load_conf() ! {
	file := os.expand_tilde_to_home(a.conf)
	if os.is_file(file) {
		conf := toml.parse_file(file) or { return error('error parsing ${file}\n${err}') }
		if val := conf.value_opt('server.port') {
			if val.int() > 1024 {
				a.port = val.int()
			} else {
				return error('port must be > 1024')
			}
		}
		if val := conf.value_opt('server.host') {
			a.host = val.string()
		}
		if val := conf.value_opt('client.username') {
			a.user = val.string()
		}
		if val := conf.value_opt('client.password') {
			a.psk = val.string()
		}
	}
}

fn Args.from_cli() &Args {
	mut args := &Args{}
	ggetopt.getopt_long_cli(options, args.pre_process_arg) or { exit(1) }
	args.load_conf() or {
		eprintln('config: ${err}')
		exit(1)
	}
	rest := ggetopt.getopt_long_cli(options, args.process_arg) or { exit(1) }
	if rest.len > 0 {
		args.cmd = rest[0]
	}
	if rest.len > 1 {
		args.cmd_args = rest[1..]
	}
	if args.host == '' {
		ggetopt.die('please specify a hostname')
	}
	return args
}
