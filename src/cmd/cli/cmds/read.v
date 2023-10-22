module cmds

import readline
import util
import term

enum GetReadCharAction {
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
	xleft
	xright
	enter
}

fn get_read_char(r readline.Readline) !(GetReadCharAction, string) {
	ch1 := r.read_char() or { panic(err) }
	$if read_debug ? {
		print('1[${ch1}]')
	}
	match ch1 {
		1 {
			return GetReadCharAction.home, '' // C-a
		}
		2 {
			return GetReadCharAction.right, '' // C-b
		}
		5 {
			return GetReadCharAction.end, '' // C-e
		}
		6 {
			return GetReadCharAction.right, '' // C-f
		}
		11 {
			return GetReadCharAction.kill, '' // C-k
		}
		13 {
			return GetReadCharAction.enter, ''
		}
		127 {
			return GetReadCharAction.bs, ''
		}
		27 {
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

			if ch2 == 91 {
				ch3 := r.read_char() or { panic(err) }
				$if read_debug ? {
					print('3[${ch3}]')
				}
				match ch3 {
					66 { return GetReadCharAction.down, '' }
					65 { return GetReadCharAction.up, '' }
					68 { return GetReadCharAction.left, '' }
					67 { return GetReadCharAction.right, '' }
					72 { return GetReadCharAction.home, '' }
					70 { return GetReadCharAction.end, '' }
					98 { return GetReadCharAction.xleft, '' } // M-left
					102 { return GetReadCharAction.xright, '' } // M-right
					else {}
				}
				if ch3 == 51 {
					ch4 := r.read_char() or { panic(err) }
					$if read_debug ? {
						print('4[${ch4}]')
					}
					match ch4 {
						126 { return GetReadCharAction.del, '' }
						else {}
					}
				}
			}
		}
		32...126 {
			return GetReadCharAction.insert, [u8(ch1)].bytestr()
		}
		else {}
	}
	return GetReadCharAction.nop, ''
}

fn read_string(prompt string, init ?string) !string {
	mut r := readline.Readline{}
	r.enable_raw_mode_nosig()
	defer {
		r.disable_raw_mode()
	}
	print(prompt)

	mut val := init or { '' }
	mut cur := len(val)
	print(val)
	for {
		action, ch := get_read_char(r)!
		match action {
			.insert {
				print(ch)
				l := len(val[cur..])
				if l > 0 {
					print(val[cur..])
					term.cursor_back(l)
				}
				val = val[0..cur] + ch + val[cur..]
				cur++
			}
			.left {
				if cur > 0 {
					term.cursor_back(1)
					cur--
				}
			}
			.right {
				if cur < len(val) {
					term.cursor_forward(1)
					cur++
				}
			}
			.home {
				if cur > 0 {
					term.cursor_back(cur)
					cur = 0
				}
			}
			.end {
				if cur < len(val) {
					term.cursor_forward(len(val) - cur)
					cur = len(val)
				}
			}
			.del {
				if cur < len(val) {
					print(val[cur + 1..] + ' ')
					term.cursor_back(len(val) - cur)
					val = val[0..cur] + val[cur + 1..len(val)]
				}
			}
			.bs {
				if cur > 0 {
					term.cursor_back(1)
					print(val[cur..] + ' ')
					term.cursor_back(1 + len(val) - cur)
					val = val[0..cur - 1] + val[cur..]
					cur--
				}
			}
			.kill {
				if cur < len(val) {
					print(' '.repeat(len(val) - cur))
					term.cursor_back(len(val) - cur)
					val = val[0..cur]
				}
			}
			.enter {
				println('')
				break
			}
			else {}
		}
	}
	return val
}

fn read_date(prompt string, init ?string) !string {
	date := read_string(prompt, init)!
	util.sdate_check(date)!
	return date
}

fn read_int(prompt string, init ?int) !int {
	mut number := ''
	if init_ := init {
		number = read_string(prompt, init_.str())!
	} else {
		number = read_string(prompt, none)!
	}
	if number.int() == 0 && number != '0' {
		return error('invalid integer')
	}
	return number.int()
}
