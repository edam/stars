module inp

import readline
import term
import encoding.utf8.east_asian
import math
import strings
import arrays

pub struct Input {
pub:
	// blanking string (must display 1 terminal character wide)
	blank string = ' '
	// display width limit
	width int = int(math.max_i32)
pub mut:
	// validation function
	validate_fn ?InputValidateFn
	// when user hits enter, emit newline
	emit_newline bool = true
	// function used to determine word endings
	is_word_rune_fn InputIsWordRuneFn = is_word_rune
	// bind map, of actions to handler functions, overriding default behaviour
	bind map[InputActionOp]InputBindFn
	// current value
	val []rune
	// current cursor position
	cur int = -1
}

pub struct InputAction {
	op InputActionOp
	ch ?rune
}

pub enum InputActionOp {
	nop
	insert
	bs
	del
	left
	right
	up
	down
	home
	end
	kill
	m_left
	m_right
	m_del
	m_bs
	tab
	s_tab
	enter
	l_limit
	r_limit
}

type InputBindFn = fn (mut Input, InputAction) !

type InputIsWordRuneFn = fn (Input, rune) bool

type InputValidateFn = fn (mut Input) !

// no operation, which can be used in bind map
pub fn nop(mut _ Input, _ InputActionOp, _ string) {
}

// get display width of runes (some runes are 2 terminal chars wide)
pub fn width(runes []rune) int {
	return east_asian.display_width(runes.string(), 2)
}

// get the display width of the current value
pub fn (mut i Input) val_width() int {
	return width(i.val)
}

// insert a rune at cursor position in current value
pub fn (mut i Input) insert(ch rune) {
	if i.width < 0 || width(i.val) + width([ch]) <= i.width {
		print(ch)
		rem := i.val[i.cur..]
		rem_w := width(rem)
		if rem_w > 0 {
			print(rem.string())
			term.cursor_back(rem_w)
		}
		i.val = arrays.flatten([i.val#[..i.cur], [ch], i.val#[i.cur..]])
		i.cur++
	}
}

// set cursor position, taking into account any format, and update terminal
pub fn (mut i Input) move(pos int) ! {
	if pos < 0 {
		if f := i.bind[.l_limit] {
			f(mut i, InputAction{.l_limit, none})!
		}
	} else if pos > width(i.val) {
		if f := i.bind[.r_limit] {
			f(mut i, InputAction{.r_limit, none})!
		}
	} else {
		if pos > i.cur {
			term.cursor_forward(width(i.val[i.cur..pos]))
		} else if pos < i.cur {
			term.cursor_back(width(i.val[pos..i.cur]))
		}
		i.cur = pos
	}
}

// delete n chars at cursor
pub fn (mut i Input) del(n int) {
	n_ := math.max(0, math.min(n, i.val.len - i.cur))
	if n_ > 0 {
		rem := i.val[i.cur + n_..]
		cut_w := width(i.val[i.cur..i.cur + n_])
		print(rem.string() + strings.repeat_string(i.blank, cut_w))
		term.cursor_back(cut_w + width(rem))
		i.val.delete_many(i.cur, n_)
	}
}

// backspace n chars at cursor
pub fn (mut i Input) bs(n int) {
	n_ := math.max(0, math.min(n, i.cur))
	if n_ > 0 {
		term.cursor_back(n_)
		rem := i.val[i.cur..]
		print(rem.string() + strings.repeat_string(i.blank, n_))
		term.cursor_back(n_ + width(rem))
		i.cur -= n_
		i.val.delete_many(i.cur, n_)
	}
}

// default function to determine word starts/ends
fn is_word_rune(_ Input, ch rune) bool {
	return ch !in [` `, `\t`, `\r`, `\n`, `.`, `:`, `,`, `;`, `<`, `>`, `?`, `!`]
}

// get pos of next word start, based on current is_word_rune_fn
pub fn (mut i Input) next_word_start_pos() int {
	mut in_word := false
	mut pos := i.cur
	for ; pos > 0; pos-- {
		in_word_next := i.is_word_rune_fn(i, i.val[pos - 1])
		if !in_word_next && in_word {
			break
		}
		in_word = in_word_next
	}
	return pos
}

// get pos of next word end, based on current is_word_rune_fn
pub fn (mut i Input) next_word_end_pos() int {
	w := width(i.val)
	mut was_in_word := false
	mut pos := i.cur
	for ; pos < w; pos++ {
		in_word := i.is_word_rune_fn(i, i.val[pos])
		if !in_word && was_in_word {
			break
		}
		was_in_word = in_word
	}
	return pos
}

// validate the input
pub fn (mut i Input) validate() ! {
	old_val := i.val.clone()
	old_cur := i.cur
	if validate_fn := i.validate_fn {
		validate_fn(mut i)!
	}
	if i.val != old_val {
		move := width(old_val#[..old_cur])
		if move > 0 {
			term.cursor_back(move)
		}
		print(i.val.string())
		old_w := width(old_val)
		val_w := width(i.val)
		if old_w > val_w {
			print(i.blank.repeat(old_w - val_w))
			term.cursor_back(old_w)
		} else {
			term.cursor_back(val_w)
		}
		if i.cur > 0 {
			term.cursor_forward(width(i.val#[..i.cur]))
		}
	}
}

// read input
pub fn (mut i Input) read() !string {
	mut r := readline.Readline{}
	r.enable_raw_mode_nosig()
	defer {
		r.disable_raw_mode()
	}

	print(i.val.string())
	defer {
		if i.emit_newline {
			println('')
		} else {
			w := width(i.val#[..i.cur])
			//			println('-${w}-')
			if w > 0 {
				term.cursor_back(w)
			}
		}
	}
	val_w := width(i.val)
	if i.cur < 0 {
		i.cur = val_w
	} else if i.cur < val_w {
		term.cursor_back(val_w - i.cur)
	}

	for {
		action := get_read_char(r)!
		if f := i.bind[action.op] {
			f(mut i, action)!
		} else {
			match action.op {
				// defaults
				.insert { i.insert(action.ch or { ` ` }) }
				.left { i.move(i.cur - 1)! }
				.right { i.move(i.cur + 1)! }
				.home { i.move(0)! }
				.end { i.move(width(i.val))! }
				.del { i.del(1) }
				.bs { i.bs(1) }
				.kill { i.del(i.val.len - i.cur) }
				.m_left { i.move(i.next_word_start_pos())! }
				.m_right { i.move(i.next_word_end_pos())! }
				.m_del { i.del(i.next_word_end_pos() - i.cur) }
				.m_bs { i.bs(i.cur - i.next_word_start_pos()) }
				.enter { break }
				else {}
			}
		}
	}
	i.validate()!
	return i.val.string()
}

// --

fn get_read_char(r readline.Readline) !InputAction {
	ch1 := r.read_char() or { panic(err) }
	$if read_debug ? {
		print('1[${ch1}]')
	}
	match ch1 {
		1 { return InputAction{.home, none} } // C-a
		2 { return InputAction{.right, none} } // C-b
		5 { return InputAction{.end, none} } // C-e
		6 { return InputAction{.right, none} } // C-f
		9 { return InputAction{.tab, none} }
		11 { return InputAction{.kill, none} } // C-k
		13 { return InputAction{.enter, none} }
		127 { return InputAction{.bs, none} }
		32...126 { return InputAction{.insert, [u8(ch1)].bytestr().runes()[0]} }
		else {}
	}
	if ch1 == 27 {
		// non-blocking stdin
		old_fdfl := C.fcntl(0, C.F_GETFL, 0)
		C.fcntl(0, C.F_SETFL, old_fdfl | C.O_NONBLOCK)
		defer {
			C.fcntl(0, C.F_SETFL, old_fdfl)
		}

		ch2 := r.read_char() or {
			if err.str() == 'none' {
				return error('back')
			}
			panic(err)
		}
		$if read_debug ? {
			print('2[${ch2}]')
		}
		match ch2 {
			98 { return InputAction{.m_left, none} } // M-left
			100 { return InputAction{.m_del, none} } // M-del
			102 { return InputAction{.m_right, none} } // M-right
			127 { return InputAction{.m_bs, none} } // M-backspace
			else {}
		}
		if ch2 == 91 {
			ch3 := r.read_char() or { panic(err) }
			$if read_debug ? {
				print('3[${ch3}]')
			}
			match ch3 {
				66 { return InputAction{.down, none} }
				65 { return InputAction{.up, none} }
				68 { return InputAction{.left, none} }
				67 { return InputAction{.right, none} }
				72 { return InputAction{.home, none} }
				70 { return InputAction{.end, none} }
				90 { return InputAction{.s_tab, none} } // S-tab
				else {}
			}
			if ch3 == 51 {
				ch4 := r.read_char() or { panic(err) }
				$if read_debug ? {
					print('4[${ch4}]')
				}
				match ch4 {
					126 { return InputAction{.del, none} }
					else {}
				}
			}
		}
	}
	return InputAction{.nop, none}
}
