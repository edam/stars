module main

import os
import vweb
import lambdas

struct App {
	vweb.Context
pub:
	middlewares map[string][]vweb.Middleware
}

fn App.new() &App {
	mut app := &App{
		middlewares: {
			'/api/': [middleware_auth]
		}
	}
	app.mount_static_folder_at(os.resource_abs_path('../public'), '/')
	return app
}

pub fn (mut app App) not_found() vweb.Result {
	app.set_status(404, 'Not Found')
	return app.html('<h1>Page not found</h1>')
}

pub fn (mut app App) index() vweb.Result {
	return app.redirect('/index.html')
}

fn (mut app App) handle(err IError) vweb.Result {
	match err {
		lambdas.WebError {
			app.set_status(err.status, err.message)
			return app.text('')
		}
		lambdas.Redirect {
			return app.redirect(err.uri)
		}
		else {
			app.set_status(500, 'Internal server error')
			return app.text('')
		}
	}
}
