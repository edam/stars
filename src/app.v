module main

import vweb

struct App {
	vweb.Context
pub:
	middlewares map[string][]vweb.Middleware
}

fn App.new() &App {
	return &App{
		middlewares: {
			'/api/': [middleware_auth]
		}
	}
}

pub fn middleware_auth(mut ctx vweb.Context) bool {
	// app.redirect( '/login' )
	return true
}

pub fn (mut app App) not_found() vweb.Result {
	app.set_status(404, 'Not Found')
	return app.html('<h1>Page not found</h1>')
}

pub fn (mut app App) index() vweb.Result {
	return app.file('../public/index.html')
}
