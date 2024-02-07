module inp

import util
import arrays

// validate routines

pub fn validate_zero_pad(mut i Input) ! {
	if i.val.len > 0 {
		missing := i.width - width(i.val)
		old_len := i.val.len
		i.val = arrays.flatten([`0`.repeat(missing).runes(), i.val])
		if old_len < i.val.len {
			i.cur += i.val.len - old_len
		}
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

pub fn insert_and_validate(mut i Input, action InputAction) ! {
	default_bind_action(mut i, action)!
	i.validate()!
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
	ret := row.read()!#[1..-1]
	util.parse_sdate(ret)!
	return ret
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
	ret := input.read()!
	if ret == '' {
		return error('bad int')
	} else {
		return ret.int()
	}
}

fn validate_opts(opts []string) InputValidateFn {
	return fn [opts] (mut i Input) ! {
		for n := 0; n < i.val.len; n++ {
			mat := i.val[..n + 1].string().to_lower()
			rem := opts.filter(it.to_lower().starts_with(mat))
			if rem.len == 0 {
				i.val = i.val[..n]
				i.cur = i.val.len
				return
			} else if rem.len == 1 {
				i.val = rem[0].runes()
				i.cur = i.val.len
				return
			} else {
				i.val[n] = rem[0][n]
			}
		}
	}
}

pub fn read_opt(prompt string, init ?string, opts []string) !string {
	print(prompt)
	mut input := Input{
		val: init or { '' }.runes()
		validate_fn: validate_opts(opts)
		bind: {
			.insert: insert_and_validate
		}
	}
	sel := input.read()!
	idx := opts.index(sel)
	if sel == '' || idx == -1 {
		return error('bad selection')
	} else {
		return sel
	}
}
