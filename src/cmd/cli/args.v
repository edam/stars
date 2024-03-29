import edam.ggetopt
import os
import toml

const default_conf = '~/.starsrc'
const default_port = 8070
const default_eta_stars = 30

@[heap]
pub struct Args {
pub mut:
	cmd       ?string
	cmd_args  []string
	conf      string = default_conf
	host      string
	port      int = default_port
	user      string
	pw        string
	eta_stars int = default_eta_stars
}

const options = [
	ggetopt.text('Usage: ${ggetopt.prog()} [OPTION]... [COMMAND]'),
	ggetopt.text(''),
	ggetopt.text('Options:'),
	ggetopt.opt('eta-stars', `e`).arg('NUM', true)
		.help('base estimates on NUM last stars (${default_eta_stars})'),
	ggetopt.opt('conf', `c`).arg('FILE', true)
		.help('configuration file (${default_conf})'),
	ggetopt.opt('host', `h`).arg('HOST', true)
		.help('hostname to connect to'),
	ggetopt.opt('port', `p`).arg('PORT', true)
		.help('port to connect to (${default_port})'),
	ggetopt.opt('username', none).arg('USER', true)
		.help('username to authenticate with'),
	ggetopt.opt('password', none).arg('PASS', true)
		.help('password for authentication. For security, it is not recommended that you pass password on the commandline.'),
	ggetopt.opt_help(),
	ggetopt.text(''),
	ggetopt.text('Commands:'),
	ggetopt.text('  stars     Grand prize, daily stars and medals overview (default)'),
	ggetopt.text("  last      Last (latest) week's stars"),
	ggetopt.text('  medals    Weekly wins and monthly medals'),
	ggetopt.text('  deposits  Show deposit details'),
	ggetopt.text('  admin     Admin menu'),
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
		'username' {
			a.user = val or { '' }
		}
		'password' {
			a.pw = val or { '' }
		}
		'eta-stars', 'e' {
			a.eta_stars = val or { '' }.int()
			if a.eta_stars < 2 {
				return error('--eta-stars: must be >= 2')
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
			a.port = val.int()
			if a.port > 1024 {
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
			a.pw = val.string()
		}
		if val := conf.value_opt('client.eta-stars') {
			a.eta_stars = val.int()
			if a.eta_stars < 1 {
				return error('num must be > 0')
			}
		}
	}
}

fn Args.from_cli_and_conf() &Args {
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
	if args.user == '' || args.pw == '' {
		ggetopt.die('please specify USER and PASS')
	}
	return args
}
