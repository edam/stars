module inp

import term

type InputRow = Input | string

type Pos = int

fn (mut row []InputRow) read() !string {
	mut inps := []int{}
	mut sel := -1
	mut next := 0
	for i, mut elem in row {
		if elem is Input {
			inps << i
		}
	}
	mut selp := &sel
	mut nextp := &next
	mut tab_fn := fn [mut selp, inps, mut nextp] (mut i Input, action InputAction) ! {
		if action.op in [.tab, .r_limit] && *selp < inps.len - 1 {
			i.validate()!
			unsafe {
				*nextp = *selp + 1
			}
			return error('next')
		} else if action.op in [.s_tab, .l_limit] && *selp > 0 {
			i.validate()!
			unsafe {
				*nextp = *selp - 1
			}
			return error('next')
		}
	}

	mut xs := []int{}
	mut x := 0
	for i, mut elem in row {
		xs << x
		match mut elem {
			Input {
				inps << i
				x += elem.width
				elem.emit_newline = false
				elem.bind[.tab] = tab_fn
				elem.bind[.s_tab] = tab_fn
				elem.bind[.l_limit] = tab_fn
				elem.bind[.r_limit] = tab_fn
				elem.bind[.insert] = fn (mut i Input, action InputAction) ! {
					if ch := action.ch {
						if ch >= `0` && ch <= `9` {
							i.insert(ch)
						}
					}
				}
				print(elem.blank.repeat(elem.width))
			}
			string {
				x += width(elem.runes())
				print(elem)
			}
		}
	}
	term.cursor_back(x)
	defer {
		println('')
	}

	for {
		now := if sel < 0 { 0 } else { xs[inps[sel]] }
		move := xs[inps[next]] - now
		if move > 0 {
			term.cursor_forward(move)
		} else if move < 0 {
			term.cursor_back(-move)
		}
		sel = next

		mut i := row[inps[sel]]
		if mut i is Input {
			i.read() or {
				if err.str() != 'next' {
					return err
				}
				continue
			}
			break
		} else {
			break
		}
	}

	mut res := ''
	for elem in row {
		match elem {
			Input { res += elem.val.string() }
			string { res += elem }
		}
	}
	return res
}
