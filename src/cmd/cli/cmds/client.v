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
	username  string
	eta_stars int
mut:
	password    string
	session_id  ?string
	session_ttl int
}

fn (mut c Client) auth() ! {
	if c.username == '' || c.password == '' {
		die('username and pre-shared key required')
	}
	res := c.get[api.GetAuth]('/api/auth/${c.username}')!

	if res.api_version < api.api_version {
		return error('api mismatch: client is newer than server')
	} else if res.api_version > api.api_version {
		return error('api mismatch: server is newer than client')
	}

	c.session_ttl = if res.session_ttl > 0 { res.session_ttl } else { defaults.session_ttl }

	psk := sha256.hexhash(c.password)
	c.session_id = sha256.hexhash('${psk}:${res.challenge}')
}

fn (mut c Client) keep_alive() {
	go fn [mut c] () {
		for {
			time.sleep(time.second * math.max(0, c.session_ttl - 5))
			c.get[api.Ok]('/api/ping') or { break }
		}
	}()
}

fn (mut c Client) get[T](uri string) !T {
	return c.fetch[T](uri, .get, none)!
}

fn (mut c Client) post[T](uri string) !T {
	return c.fetch[T](uri, .post, none)!
}

fn (mut c Client) post_json[T, U](uri string, data U) !T {
	return c.fetch[T](uri, .post, json.encode(data))!
}

fn (mut c Client) delete[T](uri string) !T {
	return c.fetch[T](uri, .delete, none)!
}

fn (mut c Client) put[T](uri string) !T {
	return c.fetch[T](uri, .put, none)!
}

fn (mut c Client) put_json[T, U](uri string, data U) !T {
	return c.fetch[T](uri, .put, json.encode(data))!
}

fn (mut c Client) fetch[T](uri string, method http.Method, data ?string) !T {
	mut header := http.Header{}
	if session_id := c.session_id {
		header.set_custom('X-Stars-Auth', session_id)!
	}
	url := 'http://${c.host}:${c.port}${uri}'
	$if trace_stars ? {
		verb := method.str().to_upper()
		eprintln('${verb} ${url}')
		if data_ := data {
			eprintln('-> ${data_}')
		}
	}
	lock {
		res := if data_ := data {
			header.set(.content_type, 'application/json')
			http.fetch(
				method: method
				url: url
				header: header
				data: data_
			)!
		} else {
			http.fetch(
				method: method
				url: url
				header: header
			)!
		}
		$if trace_stars ? {
			if res.status_code == 200 {
				eprintln('<- ${res.body}')
			} else {
				eprintln('<- ${res.status_code} ${res.body}')
			}
		}
		match res.status_code {
			200 {
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
