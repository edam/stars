module cmds

import readline
import term

const date_re = r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'

type MenuFn = fn (mut c Client) !

struct MenuItem {
	text    ?string
	handler ?MenuFn
}

// errors thrown by do_menu:
// * back -- returns up into previous do_menu(), which redraws and re-runs
// * return -- returns up until the last return handler, w/o erasing lines
// * aborted -- returns up to the top menu (should be handled there)

fn do_menu(mut c Client, menu []MenuItem) ! {
	mut idx := 0
    do_menu_sel(mut c, menu, &idx)!
}

fn do_menu_sel(mut c Client, menu []MenuItem, idx &int) ! {
	for {
		sel := do_menu_sel_(mut c, idx, menu)!
	    println('▶ ${menu[sel].text or {''}}')
        if handler := menu[sel].handler {
	        handler(mut c) or {
                if err.str() in [ 'back', 'aborted' ] {
		            term.clear_previous_line()
                }
			    if err.str() == 'back' {
				    continue
			    }
			    return err
		    }
		    return error('return') // if handler doesn't return any error
        }
        assert false, "selected non-entry menu"
	}
}

fn do_menu_sel_(mut c Client, idx_ &int, menu []MenuItem) !int {
    mut idxs := []int{}
	for i, item in menu {
        if handler := item.handler {
            if text := item.text {
		    println('  ${text}')
            idxs << i

            } else {
            handler(mut c)!
            }
        } else if text := item.text {
            println(text)
        }
	}
    assert idxs.len > 0
	mut idx :=  (*idx_ + idxs.len) % idxs.len

	mut cur_line := menu.len
	mut r := readline.Readline{}
	r.enable_raw_mode_nosig()
	defer {
		r.disable_raw_mode()
		    if cur_line > 0 {
			    term.cursor_up(cur_line)
		    }
		    for _ in 0 .. menu.len {
			    term.erase_line_clear()
			    term.cursor_down(1)
		    }
		    term.cursor_up(menu.len)
		unsafe {
			    *idx_ = idx
		}
	}
	for {
        idx_line := idxs[idx]
		if cur_line - idx_line < 0 {
			term.cursor_down(idx_line - cur_line)
		} else if cur_line - idx_line > 0 {
			term.cursor_up(cur_line - idx_line)
		}
		cur_line = idx_line

		print('>')
		term.cursor_back(1)

		ch := do_menu_read_char(r)
		match ch {
			`n`.bytes()[0] { idx++ }
			`p`.bytes()[0] { idx-- }
			`q`.bytes()[0] { return error('aborted') }
			`b`.bytes()[0], 127 { return error('back') }
			`f`.bytes()[0], 13 { break }
			`s`.bytes()[0] { idx = 0 }
			`e`.bytes()[0] { idx = -1 }
			else { /*println(ch)*/ }
		}
		idx = (idx + idxs.len) % idxs.len

		print(' ')
		term.cursor_back(1)
	}
	return idxs[idx]
}

fn do_menu_read_char(r readline.Readline) int {
	ch1 := r.read_char() or { panic(err) }
	if ch1 != 27 {
		return ch1
	}

	// non-blocking stdin
	old_fdfl := C.fcntl(0, C.F_GETFL, 0)
	C.fcntl(0, C.F_SETFL, old_fdfl | C.O_NONBLOCK)
	defer {
		C.fcntl(0, C.F_SETFL, old_fdfl)
	}

	ch2 := r.read_char() or {
		if err.str() == 'none' {
			return `b`.bytes()[0]
		}
		panic(err)
	}
	if ch2 != 91 {
		return 0
	}

	ch3 := r.read_char() or { panic(err) }
	return match ch3 {
		66 { `n`.bytes()[0] }
		65 { `p`.bytes()[0] }
		68 { `b`.bytes()[0] }
		67 { `f`.bytes()[0] }
		72 { `s`.bytes()[0] }
		70 { `e`.bytes()[0] }
		else { 0 }
	}
}
