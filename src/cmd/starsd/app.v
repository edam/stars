module main

import x.vweb
import edam.ggetopt { die }
import store
import rand
import crypto.sha256

const admin_user = 'admin'

pub struct Context {
	vweb.Context
pub mut:
	session         ?Session
	skip_auth_check bool
}

@[heap]
pub struct App {
	vweb.Middleware[Context]
mut:
	db       &store.IStore = unsafe { nil }
	sessions &Sessions     = unsafe { nil }
	args     &Args = unsafe { nil }
}

fn App.new() &App {
	return &App{}
}

pub fn (mut app App) run() {
	app.args = Args.from_cli_and_conf()

	match app.args.db.backend {
		'sqlite' {
			file := app.args.db.file or { '' }
			println('store: sqlite:///${file}')
			app.db = store.new_sqlite(file) or { die('db: ${err}') }
		}
		'pgsql' {
			host := app.args.db.host or { '' }
			port := app.args.db.port or { 0 }
			username := app.args.db.username or { '' }
			password := app.args.db.password or { '' }
			name := app.args.db.name or { '' }
			println('store: pgsql://${username}@${host}:${port}/${name}')
			app.db = store.new_pgsql(host, port, username, password, name) or { die('db: ${err}') }
		}
		else {
			die('store: unsupported database')
		}
	}
	defer {
		app.db.close() or { die('db: ${err}') }
	}

	if app.args.create {
		println('creating database')
		app.db.create() or { die('db: ${err}') }
	}
	app.db.verify() or { die('db: ${err}') }
	if app.args.create || app.args.reset_admin {
		println('resetting admin account')
		pw := rand.u64().str()
		psk := sha256.hexhash(pw)
		app.db.put_user(admin_user, psk) or { die('db: ${err}') }
		app.db.set_user_perms(admin_user, u32(-1)) or { die('db: ${err}') }
		println('created user ${admin_user}:${pw}')
		exit(0)
	}

	println('conf: session_ttl = ${app.args.session_ttl}')
	app.sessions = Sessions.new(app.args.session_ttl) or { die('sessions init fail') }

	app.use(vweb.cors[Context](vweb.CorsOptions{
		origins: ['*']
		allowed_methods: [.get, .head, .patch, .put, .post, .delete]
	}))

	app.route_use('/api/auth/:username', handler: app.skip_auth_check)
	app.route_use('/api/:path...', handler: app.check_auth)
	app.route_use('/api/admin/:path...', handler: app.check_admin)

	vweb.run[App, Context](mut app, app.args.port)
}

// middleware

fn (mut app App) skip_auth_check(mut ctx Context) bool {
	ctx.skip_auth_check = true
	return true
}

fn (mut app App) check_auth(mut ctx Context) bool {
	if ctx.skip_auth_check {
		return true
	}
	if session_id := ctx.req.header.get_custom('x-stars-auth') {
		if session := app.sessions.get(session_id) {
			ctx.session = session
		}
	}
	if ctx.session == none {
		ctx.res.set_status(.unauthorized)
		ctx.send_response_to_client('text/plain', 'Unauthorized')
		return false
	} else {
		return true
	}
}

fn (mut app App) check_admin(mut ctx Context) bool {
	if session := ctx.session {
		if session.perms & perm_admin != 0 {
			return true
		}
	}
	ctx.forbidden()
	return false
}

// helper

fn check_404(mut ctx Context, err IError) !vweb.Result {
	if err == store.not_found {
		return ctx.not_found()
	}
	return err
}

pub fn (mut app App) index(mut ctx Context) vweb.Result {
	return ctx.file('../public/index.html')
}

// send an error 403
pub fn (mut ctx Context) forbidden() vweb.Result {
	ctx.res.set_status(.forbidden)
	return ctx.send_response_to_client('text/plain', 'Forbidden')
}
