import edam.ggetopt
import os
import toml
import defaults

const db_regex = r'^([a-z]+)://(?:([^:@/]+)(?::([^@]+))?@)?([-a-z.]+)(?::([0-9]+))?(?:/([-a-z.]+)?)?$'
const db_backends = ['sqlite', 'pgsql']
const days_of_week = ['', 'mo', 'tu', 'we', 'th', 'fr', 'sa', 'su']

const default_conf = '~/.starsrc'
const default_port = 8070
const default_db_kind = 'sqlite'
const default_first_dow = 1
const default_first_dow_str = 'Monday'

@[heap]
pub struct Args {
pub mut:
	conf string = default_conf
	db   struct {
	pub mut:
		backend  string = default_db_kind
		host     ?string
		port     ?int
		username ?string
		password ?string
		name     ?string
		file     ?string
	}

	create      bool
	reset_admin bool
	port        int = default_port
	session_ttl int = defaults.session_ttl
	first_dow   int = default_first_dow
}

const options = [
	ggetopt.text('Usage: ${ggetopt.prog()} [OPTION]...'),
	ggetopt.text(),
	ggetopt.text('Options:'),
	ggetopt.opt('conf', `c`).arg('FILE', true)
		.help('configuration file [${default_conf}]'),
	ggetopt.opt('db', none).arg('FILE', true)
		.help('sqlite database file'),
	ggetopt.opt('create', none)
		.help('create database schema (implies --reset-admin)'),
	ggetopt.opt('port', `p`).arg('PORT', true)
		.help('listening port [${default_port}]'),
	ggetopt.opt('reset-admin', none)
		.help('reset admin account/password and exit'),
	ggetopt.opt('session-ttl', none).arg('S', true)
		.help('auth sessions TTL [${defaults.session_ttl}]'),
	ggetopt.opt_help(),
	ggetopt.text(),
	ggetopt.text('Database options:'),
	// ggetopt.opt('db', none).arg('URL', true)
	//	.help('whole database spec\nformat: TYPE://USER:PASS@HOST:PORT/FILE'),
	ggetopt.opt('db-type', none).arg('TYPE', true)
		.help('database selection [${default_db_kind}]\noptions are: ${db_backends.join(', ')}'),
	ggetopt.opt('db-host', none).arg('HOST', true)
		.help('database host'),
	ggetopt.opt('db-port', none).arg('PORT', true)
		.help('database port [default]'),
	ggetopt.opt('db-username', none).arg('USER', true)
		.help('database username'),
	ggetopt.opt('db-password', none).arg('PASS', true)
		.help('database password'),
	ggetopt.opt('db-name', none).arg('NAME', true)
		.help('database name'),
	ggetopt.opt('db-file', none).arg('FILE', true)
		.help('database file'),
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
		'create' {
			a.create = true
		}
		'port', 'p' {
			a.port = val or { '' }.int()
			if a.port <= 1024 {
				return error('--port: PORT must be > 1024')
			}
		}
		'reset-admin' {
			a.reset_admin = true
		}
		'session-ttl' {
			a.session_ttl = val or { '' }.int()
			if a.session_ttl < 1 {
				return error('--session-ttl: must be > 0')
			}
		}
		//'db' {
		//	mut re := regex.regex_opt(db_regex)!
		//	println(re.get_code())
		//	mut str := val or { '' }
		//	if !re.matches_string(str) {
		//		return error('--db: invalid format')
		//	}
		//	backend := re.get_group_by_id(str, 0)
		//	username := re.get_group_by_id(str, 1)
		//	password := re.get_group_by_id(str, 2)
		//	host := re.get_group_by_id(str, 3)
		//	port := re.get_group_by_id(str, 4).int()
		//	file := re.get_group_by_id(str, 5)
		//	println(re.get_group_list())
		//	println('backend[${backend}] username[${username}] password[${password}] host[${host}] port[${port}] file[${file}]')
		//}
		'db-type' {
			sval := val or { '' }
			if sval !in db_backends {
				return error('--db-type: invalid TYPE, options are: ' + db_backends.join(', '))
			}
			a.db.backend = sval
		}
		'db-host' {
			a.db.host = val or { '' }
		}
		'db-port' {
			ival := val or { '' }.int()
			if ival <= 0 || ival > 65535 {
				return error('--db-port: invalid PORT')
			}
			a.db.port = ival
		}
		'db-username' {
			a.db.username = val or { '' }
		}
		'db-password' {
			a.db.password = val or { '' }
		}
		'db-name' {
			a.db.name = val or { '' }
		}
		'db-file' {
			a.db.file = val or { '' }
		}
		else {}
	}
}

fn (mut a Args) load_conf() ! {
	file := os.expand_tilde_to_home(a.conf)
	if os.is_file(file) {
		conf := toml.parse_file(file) or { return error('error parsing ${file}\n${err}') }
		if val := conf.value_opt('server.port') {
			ival := val.int()
			if ival > 1024 {
				return error('[server.port] must be > 1024')
			}
			a.port = ival
		}
		if val := conf.value_opt('server.session-ttl') {
			ival := val.int()
			if ival < 10 {
				return error('[server.session-ttl] must be > 15 (seconds)')
			} else {
				a.session_ttl = ival
			}
		}
		if val := conf.value_opt('db.type') {
			sval := val.string()
			if sval !in db_backends {
				return error('[db.type] invalid, options are: ' + db_backends.join(', '))
			}
			a.db.backend = sval
		}
		if val := conf.value_opt('db.host') {
			sval := val.string()
			if sval == '' {
				return error('[db.host] empty')
			}
			a.db.host = sval
		}
		if val := conf.value_opt('db.port') {
			ival := val.int()
			if ival <= 0 || ival > 65535 {
				return error('[db.port] invalid')
			}
			a.db.port = ival
		}
		if val := conf.value_opt('db.username') {
			sval := val.string()
			if sval == '' {
				return error('[db.username] empty')
			}
			a.db.username = sval
		}
		if val := conf.value_opt('db.password') {
			sval := val.string()
			if sval == '' {
				return error('[db.password] empty')
			}
			a.db.password = sval
		}
		if val := conf.value_opt('db.name') {
			sval := val.string()
			if sval == '' {
				return error('[db.name] empty')
			}
			a.db.name = sval
		}
		if val := conf.value_opt('db.file') {
			sval := val.string()
			if sval == '' {
				return error('[db.file] empty')
			}
			a.db.file = sval
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
		ggetopt.die('extra arguments on commandline')
	}
	match args.db.backend {
		'sqlite' {
			if args.db.file == none {
				ggetopt.die('sqlite FILE required')
			}
		}
		'pgsql' {
			if args.db.host == none {
				ggetopt.die('pgsql HOST required')
			}
			if args.db.port == none {
				args.db.port = 5432
			}
			if args.db.name == none {
				ggetopt.die('pgsql NAME required')
			}
			if args.db.username == none || args.db.password == none {
				ggetopt.die('pgsql USER and PASS required')
			}
		}
		else {}
	}
	return args
}
