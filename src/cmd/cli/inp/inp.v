module inp

import readline
import term
import encoding.utf8.east_asian
import math

pub struct Input {
pub:
	prompt          ?string
	bind            map[InputActionOp]InputBindFn
	max_width       int = -1
	is_word_rune_fn InputIsWordRuneFn = is_word_rune
	blank           rune = ` `
	emit_newline    bool = true
pub mut:
	val []rune
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
}

type InputBindFn = fn (mut Input, InputAction)

type InputIsWordRuneFn = fn (Input, rune) bool

pub fn nop(mut _ Input, _ InputActionOp, _ string) {
}

pub fn width(runes []rune) int {
	return east_asian.display_width(runes.string(), 2)
}

pub fn (mut i Input) insert(runes []rune) {
	if i.max_width < 0 || width(i.val) + width(runes) <= i.max_width {
		print(runes.string())
		rem := i.val[i.cur..]
		rem_w := width(rem)
		if rem_w > 0 {
			print(rem.string())
			term.cursor_back(rem_w)
		}
		i.val.insert(i.cur, runes)
		// i.val = i.val[0..i.cur] + ch + i.val[i.cur..]
		i.cur += runes.len
	}
}

pub fn (mut i Input) move(pos int) {
	if pos >= 0 && pos <= width(i.val) {
		if pos > i.cur {
			term.cursor_forward(width(i.val[i.cur..pos]))
		} else if pos < i.cur {
			term.cursor_back(width(i.val[pos..i.cur]))
		}
		i.cur = pos
	}
}

pub fn (mut i Input) del(n int) {
	n_ := math.max(0, math.min(n, i.val.len - i.cur))
	if n_ > 0 {
		rem := i.val[i.cur + n_..]
		cut_w := width(i.val[i.cur..i.cur + n_])
		print(rem.string() + i.blank.repeat(cut_w))
		term.cursor_back(cut_w + width(rem))
		// i.val = i.val[0..i.cur] + rem
		i.val.delete_many(i.cur, n_)
	}
}

pub fn (mut i Input) bs(n int) {
	n_ := math.max(0, math.min(n, i.cur))
	if n_ > 0 {
		term.cursor_back(n_)
		rem := i.val[i.cur..]
		print(rem.string() + i.blank.repeat(n_))
		term.cursor_back(n_ + width(rem))
		// i.val = i.val[0..i.cur - n_] + rem
		i.cur -= n_
		i.val.delete_many(i.cur, n_)
	}
}

fn is_word_rune(_ Input, ch rune) bool {
	return ch !in [` `, `\t`, `\r`, `\n`, `.`, `:`, `,`, `;`, `<`, `>`, `?`, `!`]
}

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

pub fn (mut i Input) read() !string {
	mut r := readline.Readline{}
	r.enable_raw_mode_nosig()
	defer {
		r.disable_raw_mode()
	}

	if prompt := i.prompt {
		print(prompt)
	}
	print(i.val.string())
	if i.emit_newline {
		defer {
			println('')
		}
	}

	if i.cur < 0 {
		i.cur = width(i.val)
	}

	for {
		action := get_read_char(r)!
		if f := i.bind[action.op] {
			f(mut i, action)
		} else {
			match action.op {
				// defaults
				.insert { i.insert([action.ch or { ` ` }]) }
				.left { i.move(i.cur - 1) }
				.right { i.move(i.cur + 1) }
				.home { i.move(0) }
				.end { i.move(width(i.val)) }
				.del { i.del(1) }
				.bs { i.bs(1) }
				.kill { i.del(i.val.len - i.cur) }
				.m_left { i.move(i.next_word_start_pos()) }
				.m_right { i.move(i.next_word_end_pos()) }
				.m_del { i.del(i.next_word_end_pos() - i.cur) }
				.m_bs { i.bs(i.cur - i.next_word_start_pos()) }
				.enter { break }
				else {}
			}
		}
	}
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
