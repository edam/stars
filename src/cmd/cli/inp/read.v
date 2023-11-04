module inp

import util

const dow_names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

pub fn read_string(prompt string, init ?string) !string {
	mut input := Input{
		prompt: prompt
		val: init or { '' }.runes()
	}
	return input.read()
}

// pub fn read_template(prompt string, template string, init ?string) !string {
//	init_ = init or { '' }[0..template.len]
//	prompt_w := width(prompt)
//	term.cursor_forward(prompt_w)
//	print(init)
//	term.cursor_back(width(init) + prompt_w)
//	defer {
//		println('')
//	}
//	for {
//		input := Input{
//			prompt: prompt
//			emit_newline: false
//		}
//	}
//}

pub fn read_date(prompt string, init ?string) !string {
	// return util.sdate_check(read_template('dddd-dd-dd')!)!
	return read_string(prompt, init)!
}

pub fn read_int(prompt string, init ?int) !int {
	mut input := Input{
		prompt: prompt
		bind: {
			.insert: fn (mut i Input, action InputAction) {
				if ch := action.ch {
					if ch >= `0` && ch <= `9` {
						i.insert([ch])
					}
				}
			}
		}
	}
	if init_ := init {
		input.val = init_.str().runes()
	}
	return input.read()!.int()
}

pub fn read_opt(prompt string, init ?string, opts []string) !string {
	sel := read_string(prompt, init)!
	idx := inp.dow_names.index(sel)
	if idx == -1 {
		return error('bad selection')
	} else {
		return sel
	}
}
