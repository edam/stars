module lambdas

interface Response {}

pub struct WebError {
	Error
pub:
	status  int
	message string
}

const status_messages = {
	400: 'Bad Request'
	401: 'Unauthorised'
	403: 'Forbidden'
	404: 'Not Found'
	405: 'Method Not Allowed'
	406: 'Not Acceptable'
	408: 'Request Timeout'
	500: 'Internal Server Error'
	501: 'Not Implemented'
	503: 'Service Unavailable'
}

fn WebError.new(status int) WebError {
	st := if status in lambdas.status_messages { status } else { 500 }
	return WebError{
		status: st
		message: lambdas.status_messages[status]
	}
}

pub struct Redirect {
	Error
pub:
	uri string
}

fn Redirect.new(uri string) Redirect {
	return Redirect{
		uri: uri
	}
}
