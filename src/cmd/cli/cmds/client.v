module cmds

import net.http
import json
import api
import crypto.sha256
import edam.ggetopt { die }
import time
import defaults
import math

pub struct Client {
	host      string
	port      int
	user      string
	pw        string
	eta_stars int
mut:
	session_id  ?string
	session_ttl int
}

fn (mut c Client) auth() ! {
	if c.user == '' || c.pw == '' {
		die('username and pre-shared key required')
	}
	res := c.get[api.ApiAuth]('/api/auth/${c.user}')!

	if res.api_version < api.api_version {
		return error('server is out of date')
	} else if res.api_version > api.api_version {
		return error('server is newer than client')
	}

	c.session_ttl = if res.session_ttl > 0 { res.session_ttl } else { defaults.session_ttl }

	psk := sha256.hexhash(c.pw)
	c.session_id = sha256.hexhash('${psk}:${res.challenge}')
}

fn (mut c Client) keep_alive() {
	go fn [mut c] () {
		for {
			time.sleep(time.second * math.max(0, c.session_ttl - 5))
			c.get[api.ApiOk]('/api/ping') or { break }
		}
	}()
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
	lock {
		$if trace_stars ? {
			verb := method.str().to_upper()
			eprintln('${verb} ${url}')
		}
		res := http.fetch(
			method: method
			url: url
			cookies: cookies
		)!
		match res.status_code {
			200 {
				$if trace_stars ? {
					eprintln(res.body)
				}
				return json.decode(T, res.body)!
			}
			403 {
				return error('not authorised')
			}
			404 {
				return error('not found')
			}
			else {
				return error('bad response: ${res.status_code}')
			}
		}
	}
}
