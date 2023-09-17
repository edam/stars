module cmds

import net.http
import json
import api
import crypto.sha256
import edam.ggetopt { die }

pub struct Client {
	host string
	port int
	user string
	psk  string
mut:
	session_id ?string
}

enum Verb {
	get
}

const (
	verbs = {
		Verb.get: 'GET'
	}
)

fn (mut c Client) auth() ! {
	if c.user == '' || c.psk == '' {
		die('username and pre-shared key required')
	}
	resp := c.get[api.ApiAuth]('/api/auth/${c.user}')!
	c.session_id = sha256.hexhash('${c.psk}:${resp.challenge}')
}

fn (mut c Client) get[T](uri string) !T {
	return c.fetch[T](uri, .get)!
}

fn (mut c Client) fetch[T](uri string, verb Verb) !T {
	mut cookies := map[string]string{}
	if session_id := c.session_id {
		cookies['session'] = session_id
	}
	url := 'http://${c.host}:${c.port}/${uri}'
	$if trace_stars ? {
		eprintln('${cmds.verbs[verb]} ${url}')
	}
	resp := http.fetch(
		method: .get
		url: url
		cookies: cookies
	)!
	match resp.status_code {
		200 {
			$if trace_stars ? {
				eprintln(resp.body)
			}
			return json.decode(T, resp.body)!
		}
		403 {
			return error('not authorised')
		}
		else {
			return error('bad response: ${resp.status_code}')
		}
	}
}
