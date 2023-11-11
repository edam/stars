module inp

import util
import arrays

const dow_names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

// validate routines

pub fn validate_zero_pad(mut i Input) ! {
	if i.val.len > 0 {
		missing := i.width - width(i.val)
		i.val = arrays.flatten([`0`.repeat(missing).runes(), i.val])
		i.cur = i.width
	}
}

// insert routines

pub fn insert_digits_only(mut i Input, action InputAction) ! {
	if ch := action.ch {
		if ch >= `0` && ch <= `9` {
			i.insert(ch)
		}
	}
}

// read routines

pub fn read_string(prompt string, init ?string) !string {
	print(prompt)
	mut input := Input{
		val: init or { '' }.runes()
	}
	return input.read()
}

pub fn read_date(prompt string, init ?string) !string {
	print(prompt)
	mut y, mut m, mut d := 0, 0, 0
	if date := init {
		y, m, d = util.parse_sdate(date)!
	}
	mut row := []InputRow{}
	row << '['
	row << Input{
		val: if y > 0 { '${y:04}' } else { '' }.runes()
		width: 4
		validate_fn: validate_zero_pad
		bind: {
			.insert: insert_digits_only
		}
	}
	row << '-'
	row << Input{
		val: if m > 0 { '${m:02}' } else { '' }.runes()
		width: 2
		validate_fn: validate_zero_pad
		bind: {
			.insert: insert_digits_only
		}
	}
	row << '-'
	row << Input{
		val: if d > 0 { '${d:02}' } else { '' }.runes()
		width: 2
		validate_fn: validate_zero_pad
		bind: {
			.insert: insert_digits_only
		}
	}
	row << ']'
	return row.read()!#[1..-1]
}

pub fn read_int(prompt string, init ?int) !int {
	print(prompt)
	mut input := Input{
		bind: {
			.insert: insert_digits_only
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
