import edam.ggetopt

[heap]
pub struct Args {
pub mut:
	port int = 8070
	db   ?string
}

const options = [
	ggetopt.text('Usage: ${ggetopt.prog()} [OPTION]...'),
	ggetopt.text(''),
	ggetopt.text('Options:'),
	ggetopt.opt('db', none).arg('FILE', true)
		.help('sqlite database file'),
	ggetopt.opt('port', `p`).arg('PORT', true)
		.help('listening port (8070)'),
	ggetopt.opt_help(),
]

fn (mut args Args) process_arg(arg string, val ?string) ! {
	match arg {
		'db' {
			args.db = val
		}
		'port', 'p' {
			args.port = val or { '' }.int()
			if args.port <= 1024 {
				return error('--port: port must be > 1024')
			}
		}
		'help' {
			ggetopt.print_help(options)
			exit(0)
		}
		else {}
	}
}

fn Args.from_cli() &Args {
	mut args := &Args{}
	rest := ggetopt.getopt_long_cli(options, args.process_arg) or { exit(1) }
	if rest.len > 0 {
		ggetopt.die('extra arguments on commandline')
	}
	if args.db == none {
		ggetopt.die('database required')
	}
	return args
}
