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

fn (mut c Client) post[T](uri string) !T {
	return c.fetch[T](uri, .post)!
}

fn (mut c Client) delete[T](uri string) !T {
	return c.fetch[T](uri, .delete)!
}

fn (mut c Client) put[T](uri string) !T {
	return c.fetch[T](uri, .put)!
}

fn (mut c Client) fetch[T](uri string, method http.Method) !T {
	mut cookies := map[string]string{}
	if session_id := c.session_id {
		cookies['session'] = session_id
	}
	url := 'http://${c.host}:${c.port}${uri}'
	$if trace_stars ? {
		verb := method.str().to_upper()
		eprintln('${verb} ${url}')
	}
	resp := http.fetch(
		method: method
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
		404 {
			return error('not found')
		}
		else {
			return error('bad response: ${resp.status_code}')
		}
	}
}
