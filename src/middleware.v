module main

import vweb

pub fn middleware_auth(mut ctx vweb.Context) bool {
	// app.redirect( '/login' )
	return true
}
