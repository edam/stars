module inp

import readline
import strings
import arrays
import math

pub struct Input {
pub:
	// blanking string (must display 1 terminal character wide)
	blank string = ' '
	// display width limit
	width int = int(max_i32)
	// can be empty?
	required bool
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

// -- bind actions

pub fn default_bind_action(mut i Input, action InputAction) ! {
	match action.op {
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
		.enter { return error('enter') }
		else {}
	}
}

// no operation, which can be used in bind map
pub fn nop(mut _ Input, _ InputActionOp, _ string) {
}

// insert a rune at cursor position in current value
pub fn (mut i Input) insert(ch rune) {
	if i.width < 0 || width(i.val) + width([ch]) <= i.width {
		Stage.print(ch.str())
		rem := i.val[i.cur..]
		Stage.print(rem.string())
		Stage.move(-width(rem))
		i.val = arrays.flatten([i.val#[..i.cur], [ch], i.val#[i.cur..]])
		i.cur++
	}
}

fn clamp[T](x T, a T, b T) T {
	return if x < a {
		a
	} else if x > b {
		b
	} else {
		x
	}
}

// set cursor position, taking into account any format, and update terminal
pub fn (mut i Input) move(pos int) ! {
	if pos < 0 {
		f := i.bind[.l_limit] or { default_bind_action }
		f(mut i, InputAction{.l_limit, none})!
	} else if pos > i.val.len {
		f := i.bind[.r_limit] or { default_bind_action }
		f(mut i, InputAction{.r_limit, none})!
	} else {
		pos_ := clamp(pos, 0, i.val.len)
		if pos_ > i.cur {
			Stage.move(width(i.val[i.cur..pos]))
		} else if pos_ < i.cur {
			Stage.move(-width(i.val[pos..i.cur]))
		}
		i.cur = pos_
	}
}

// delete n chars at cursor
pub fn (mut i Input) del(n int) {
	n_ := math.max(0, math.min(n, i.val.len - i.cur))
	if n_ > 0 {
		rem := i.val[i.cur + n_..]
		cut_w := width(i.val[i.cur..i.cur + n_])
		Stage.print(rem.string() + strings.repeat_string(i.blank, cut_w))
		Stage.move(-cut_w - width(rem))
		i.val.delete_many(i.cur, n_)
	}
}

// backspace n chars at cursor
pub fn (mut i Input) bs(n int) {
	n_ := math.max(0, math.min(n, i.cur))
	if n_ > 0 {
		Stage.move(-n_)
		rem := i.val[i.cur..]
		Stage.print(rem.string() + strings.repeat_string(i.blank, n_))
		Stage.move(-n_ - width(rem))
		i.cur -= n_
		i.val.delete_many(i.cur, n_)
	}
}

// -- end of bind actions

// get the display width of the current value
pub fn (mut i Input) val_width() int {
	return width(i.val)
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
	for width(i.val) > i.width {
		i.val = i.val#[..-1]
	}
	if validate_fn := i.validate_fn {
		validate_fn(mut i)!
	}
	if i.val != old_val {
		move := width(old_val#[..old_cur])
		$if !debug_inp ? {
			Stage.move(-move)
		}
		Stage.print(i.val.string())
		$if debug_inp ? {
			print('=V_')
			if move > 0 {
				print('b${move}')
			}
			print('p${width(i.val)}')
		}
		old_w := width(old_val)
		val_w := width(i.val)
		if old_w > val_w {
			$if debug_inp ? {
				print('s${old_w - val_w}')
				print('b${old_w}')
			} $else {
				Stage.print(i.blank.repeat(old_w - val_w))
				Stage.move(-old_w)
			}
		} else {
			$if debug_inp ? {
				print('b${val_w}')
			} $else {
				Stage.move(-val_w)
			}
		}
		$if debug_inp ? {
			print('f${width(i.val#[..i.cur])}')
		} $else {
			Stage.move(width(i.val#[..i.cur]))
		}
		$if debug_inp ? {
			println('=')
		}
	} else {
		i.cur = old_cur
	}
}

// perform bind aciton
pub fn (mut i Input) perform(action InputAction) ! {
	f := i.bind[action.op] or { default_bind_action }
	f(mut i, action)!
}

// read input
pub fn (mut i Input) read() !string {
	mut r := readline.Readline{}
	r.enable_raw_mode_nosig()
	defer {
		Stage.flush()
		r.disable_raw_mode()
	}

	Stage.print(i.val.string())
	$if debug_inp ? {
		print('=R_p${width(i.val)}=')
		defer {
			if i.emit_newline {
				Stage.newln()
			} else {
				w := width(i.val#[..i.cur])
				Stage.newln()
				println('=/R_m${-w}=')
			}
		}
	} $else {
		defer {
			if i.emit_newline {
				Stage.newln()
			} else {
				w := width(i.val#[..i.cur])
				Stage.move(-w)
			}
		}
	}
	val_w := width(i.val)
	if i.cur < 0 {
		i.cur = val_w
	} else if i.cur < val_w {
		Stage.move(i.cur - val_w)
	}

	for {
		Stage.flush()
		action := get_input(r)!
		i.perform(action) or {
			if err.str() == 'enter' {
				break
			} else {
				return err
			}
		}
	}
	i.validate()!
	return i.val.string()
}

// --

fn get_input(r readline.Readline) !InputAction {
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
