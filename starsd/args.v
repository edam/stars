import edam.ggetopt
import os
import toml

const (
	db_regex              = r'^([a-z]+)://(?:([^:@/]+)(?::([^@]+))?@)?([-a-z.]+)(?::([0-9]+))?(?:/([-a-z.]+)?)?$'
	db_kinds              = ['sqlite', 'pgsql']
	days_of_week          = ['', 'mo', 'tu', 'we', 'th', 'fr', 'sa', 'su']

	default_conf          = '~/.starsrc'
	default_port          = 8070
	default_session_ttl   = 60
	default_db_kind       = 'sqlite'
	default_first_dow     = 1
	default_first_dow_str = 'Monday'
)

[heap]
pub struct Args {
pub mut:
	conf string = default_conf
	db   struct {
	pub mut:
		kind string = default_db_kind
		host ?string
		port ?int
		user ?string
		pass ?string
		file ?string
	}

	create      bool
	port        int = default_port
	session_ttl int = default_session_ttl
	first_dow   int = default_first_dow
}

const options = [
	ggetopt.text('Usage: ${ggetopt.prog()} [OPTION]...'),
	ggetopt.text(''),
	ggetopt.text('Options:'),
	ggetopt.opt('conf', `c`).arg('FILE', true)
		.help('configuration file [${default_conf}]'),
	ggetopt.opt('db', none).arg('FILE', true)
		.help('sqlite database file'),
	ggetopt.opt('create', none)
		.help('create database schema'),
	ggetopt.opt('port', `p`).arg('PORT', true)
		.help('listening port [${default_port}]'),
	ggetopt.opt('session-ttl', none).arg('S', true)
		.help('auth sessions TTL [${default_session_ttl}]'),
	ggetopt.opt('first-dow', none).arg('DOW', true)
		.help('set first day of week [${default_first_dow_str}]'),
	ggetopt.opt('last-dow', none).arg('DOW', true)
		.help('set last day of week instead'),
	ggetopt.opt_help(),
	ggetopt.text(''),
	ggetopt.text('Database options:'),
	// ggetopt.opt('db', none).arg('URL', true)
	//	.help('whole database spec\nformat: TYPE://USER:PASS@HOST:PORT/FILE'),
	ggetopt.opt('db-type', none).arg('TYPE', true)
		.help('database selection [${default_db_kind}]\noptions are: ${db_kinds.join(', ')}'),
	ggetopt.opt('db-host', none).arg('HOST', true)
		.help('database host'),
	ggetopt.opt('db-port', none).arg('PORT', true)
		.help('database port'),
	ggetopt.opt('db-user', none).arg('USER', true)
		.help('database username'),
	ggetopt.opt('db-pass', none).arg('PASS', true)
		.help('database password'),
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
		'session-ttl' {
			a.session_ttl = val or { '' }.int()
			if a.session_ttl < 1 {
				return error('--session-ttl: must be > 0')
			}
		}
		'first-dow' {
			a.first_dow = days_of_week.index(val or { '' }[0..2].to_lower())
			if a.first_dow < 1 {
				return error('--first-dow: invalid day of week')
			}
		}
		'last-dow' {
			last_dow := days_of_week.index(val or { '' }[0..2].to_lower())
			if last_dow < 1 {
				return error('--last-dow: invalid day of week')
			}
			a.first_dow = if last_dow == 7 { 1 } else { last_dow + 1 }
		}
		//'db' {
		//	mut re := regex.regex_opt(db_regex)!
		//	println(re.get_code())
		//	mut str := val or { '' }
		//	if !re.matches_string(str) {
		//		return error('--db: invalid format')
		//	}
		//	kind := re.get_group_by_id(str, 0)
		//	user := re.get_group_by_id(str, 1)
		//	pass := re.get_group_by_id(str, 2)
		//	host := re.get_group_by_id(str, 3)
		//	port := re.get_group_by_id(str, 4).int()
		//	file := re.get_group_by_id(str, 5)
		//	println(re.get_group_list())
		//	println('kind[${kind}] user[${user}] pass[${pass}] host[${host}] port[${port}] file[${file}]')
		//}
		'db-type' {
			sval := val or { '' }
			if sval !in db_kinds {
				return error('--db-type: invalid TYPE, options are: ' + db_kinds.join(', '))
			}
			a.db.kind = sval
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
		'db-user' {
			a.db.user = val or { '' }
		}
		'db-pass' {
			a.db.pass = val or { '' }
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
				return error('[server] port must be > 1024')
			}
			a.port = ival
		}
		if val := conf.value_opt('server.first-dow') {
			ival := days_of_week.index(val.string()[0..2].to_lower())
			if ival < 1 {
				return error('[server.first-dow] invalid day of week')
			}
			a.first_dow = ival
		}
		if val := conf.value_opt('server.last-dow') {
			ival := days_of_week.index(val.string()[0..2].to_lower())
			if ival < 1 {
				return error('[server.last-dow] invalid day of week')
			}
			a.first_dow = if ival == 7 { 1 } else { ival + 1 }
		}
		if val := conf.value_opt('server.db.type') {
			sval := val.string()
			if sval !in db_kinds {
				return error('[server.db] type: invalid, options are: ' + db_kinds.join(', '))
			}
			a.db.kind = sval
		}
		if val := conf.value_opt('server.db.host') {
			sval := val.string()
			if sval == '' {
				return error('[server.db] host: empty')
			}
			a.db.host = sval
		}
		if val := conf.value_opt('server.db.port') {
			ival := val.int()
			if ival <= 0 || ival > 65535 {
				return error('[server.db] port: invalid PORT')
			}
			a.db.port = ival
		}
		if val := conf.value_opt('server.db.user') {
			sval := val.string()
			if sval == '' {
				return error('[server.db] user: empty')
			}
			a.db.user = sval
		}
		if val := conf.value_opt('server.db.pass') {
			sval := val.string()
			if sval == '' {
				return error('[server.db] pass: empty')
			}
			a.db.pass = sval
		}
		if val := conf.value_opt('server.db.file') {
			sval := val.string()
			if sval == '' {
				return error('[server.db] file: empty')
			}
			a.db.file = sval
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
	match args.db.kind {
		'sqlite' {
			if args.db.file == none {
				ggetopt.die('sqlite FILE required')
			}
		}
		'pgsql' {
			if args.db.host == none || args.db.port == none {
				ggetopt.die('pgsql HOST and PORT required')
			}
			if args.db.user == none || args.db.pass == none {
				ggetopt.die('pgsql USER and PASS required')
			}
		}
		else {}
	}
	return args
}
