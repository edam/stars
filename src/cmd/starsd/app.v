module main

import vweb
import edam.ggetopt { die }
import store

struct App {
	vweb.Context
pub:
	middlewares map[string][]vweb.Middleware
mut:
	db       &store.Store = unsafe { nil }
	sessions &Sessions    [vweb_global] = unsafe { nil }
	args     &Args        [vweb_global]     = unsafe { nil }
	session  ?Session
}

fn App.new() &App {
	return &App{
		middlewares: {
			'/api/': []
		}
	}
}

pub fn (mut app App) run() {
	app.args = Args.from_cli_and_conf()

	app.db = match app.args.db.backend {
		'sqlite' {
			store.new_sqlite(app.args.db.file or { '' }) or { die('db: ${err}') }
		}
		'pgsql' {
			store.new_pgsql(app.args.db.host or { '' }, app.args.db.port or { 0 }, app.args.db.username or {
				''
			}, app.args.db.password or { '' }, app.args.db.name or { '' }) or { die('db: ${err}') }
		}
		else {
			die('unsupported database')
		}
	}
	defer {
		app.db.close() or { die('db: ${err}') }
	}

	if app.args.create {
		app.db.create() or { die('db: ${err}') }
	}
	app.db.update() or { die('db: ${err}') }

	app.sessions = Sessions.new(app.args.session_ttl) or { die('sessions init fail') }

	vweb.run_at(app, vweb.RunParams{
		port: app.args.port
	}) or { panic(err) }
}

fn (mut app App) check_auth() bool {
	if session_id := app.req.cookies['session'] {
		if session := app.sessions.get(session_id) {
			app.session = session
		}
	}
	if app.session == none {
		app.error_result(403)
		return false
	} else {
		return true
	}
}

fn (mut app App) check_auth_admin() bool {
	if !app.check_auth() {
		return false
	}
	if session := app.session {
		if session.perms & perm_admin != 0 {
			return true
		}
	}
	app.error_result(403)
	return false
}

pub fn (mut app App) not_found() vweb.Result {
	return app.error_result(404)
}

fn check_404(mut app App, err IError) !vweb.Result {
	if err == store.not_found {
		return app.not_found()
	}
	return err
}

pub fn (mut app App) index() vweb.Result {
	return app.file('../public/index.html')
}

const status_messages = {
	400: 'Bad Request'
	401: 'Unauthorised'
	403: 'Forbidden'
	404: 'Not Found'
	408: 'Request Timeout'
	500: 'Internal Server Error'
	501: 'Not Implemented'
	503: 'Service Unavailable'
	507: 'Insufficient Storage'
}

pub fn (mut app App) error_result(status int) vweb.Result {
	real_status := if status in status_messages { status } else { 500 }
	message := status_messages[real_status]
	app.set_status(real_status, message)
	return app.html('<html><h1>${message}</h1></html>')
}
