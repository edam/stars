import edam.ggetopt
import os
import toml

const (
	default_conf        = '~/.starsrc'
	default_port        = 8070
	default_session_ttl = 60
)

[heap]
pub struct Args {
pub mut:
	conf        string = default_conf
	db          ?string
	create      bool
	port        int = default_port
	session_ttl int = default_session_ttl
}

const options = [
	ggetopt.text('Usage: ${ggetopt.prog()} [OPTION]...'),
	ggetopt.text(''),
	ggetopt.text('Options:'),
	ggetopt.opt('conf', none).arg('FILE', true)
		.help('configuration file (${default_conf})'),
	ggetopt.opt('db', none).arg('FILE', true)
		.help('sqlite database file'),
	ggetopt.opt('create', none)
		.help('create database schema'),
	ggetopt.opt('port', `p`).arg('PORT', true)
		.help('listening port (${default_port})'),
	ggetopt.opt('session-ttl', none).arg('S', true)
		.help('auth sessions TTL (${default_session_ttl})'),
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
		'db' {
			a.db = val
		}
		'create' {
			a.create = true
		}
		'port', 'p' {
			a.port = val or { '' }.int()
			if a.port <= 1024 {
				return error('--port: port must be > 1024')
			}
		}
		'session-ttl' {
			a.session_ttl = val or { '' }.int()
			if a.session_ttl < 1 {
				return error('--session-ttl: must > 0')
			}
		}
		else {}
	}
}

fn (mut a Args) load_conf() ! {
	file := os.expand_tilde_to_home(a.conf)
	if os.is_file(file) {
		conf := toml.parse_file(file) or { return error('error parsing ${file}\n${err}') }
		if val := conf.value_opt('port') {
			if val.int() > 1024 {
				a.port = val.int()
			} else {
				return error('port must be > 1024')
			}
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
		ggetopt.die('extra arguments on commandline')
	}
	if args.db == none {
		ggetopt.die('database required')
	}
	return args
}
