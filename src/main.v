module main

import vweb

fn main() {
	vweb.run_at(App.new(), vweb.RunParams{
		port: 8090
	}) or { panic(err) }
}
