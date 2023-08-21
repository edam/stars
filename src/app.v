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
	return app.error_response(404)
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

pub fn (mut app App) error_response(status int) vweb.Result {
	real_status := if status in status_messages { status } else { 500 }
	message := status_messages[real_status]
	app.set_status(real_status, message)
	return app.html('<html><h1>${message}</h1></html>')
}
