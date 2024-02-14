module inp

type InputRow = Input | string

type Pos = int

fn (mut row []InputRow) read() !string {
	mut inps := []int{}
	mut sel := -1
	mut next := 0
	mut newcur := 0
	mut max_sel := 0
	for elem in row {
		if elem is Input {
			max_sel++
		}
	}
	mut selp := &sel
	mut nextp := &next
	mut newcurp := &newcur
	mut tab_fn := fn [mut selp, max_sel, mut nextp, mut newcurp] (mut i Input, action InputAction) ! {
		delta := match action.op {
			.tab, .r_limit { 1 }
			.s_tab, .l_limit { -1 }
			else { 0 }
		}
		newcur := match action.op {
			.tab, .s_tab, .l_limit { -1 }
			else { 0 }
		}
		if delta != 0 && *selp + delta >= 0 && *selp + delta < max_sel {
			i.validate()!
			unsafe {
				*nextp = *selp + delta
				*newcurp = newcur
			}
			return error('switch')
		}
	}

	Stage.reset()
	mut xs := []int{}
	mut x := 0
	mut next_fixed := false
	for i, mut elem in row {
		xs << x
		match mut elem {
			Input {
				if !next_fixed {
					if elem.val.len == 0 {
						next = inps.len
						newcur = 0
						next_fixed = true
					} else {
						next = inps.len
						newcur = -1
					}
				}
				inps << i
				x += elem.width
				elem.emit_newline = false
				elem.bind[.tab] = tab_fn
				elem.bind[.s_tab] = tab_fn
				elem.bind[.l_limit] = tab_fn
				elem.bind[.r_limit] = tab_fn
				f := elem.bind[.bs] or { default_bind_action }
				elem.bind[.bs] = fn [f] (mut i Input, action InputAction) ! {
					if i.val.len == 0 {
						i.perform(InputAction{.l_limit, action.ch})!
					} else {
						f(mut i, action)!
					}
				}
				elem.validate()!
				Stage.print(elem.val.string())
				Stage.print(elem.blank.repeat(elem.width - width(elem.val)))
			}
			string {
				x += width(elem.runes())
				Stage.print(elem)
			}
		}
	}

	// for .insert inter-input single runes (e.g., `-` in "2024-01-01"), do .tab
	mut short := ?rune(none)
	for i := row.len - 1; i >= 0; i-- {
		mut elem := unsafe { &row[i] }
		if elem is string && (elem as string).len == 1 {
			short = (elem as string)[0]
		} else if s := short {
			if mut elem is Input {
				f := elem.bind[.insert] or { default_bind_action }
				elem.bind[.insert] = fn [s, f] (mut i Input, action InputAction) ! {
					if ch := action.ch {
						if ch == s {
							i.perform(InputAction{.tab, none})!
							return
						}
					}
					f(mut i, action)!
				}
			}
			short = none
		}
	}

	Stage.move(-x)
	defer {
		Stage.newln()
	}

	for {
		now := if sel < 0 { 0 } else { xs[inps[sel]] }
		move := xs[inps[next]] - now
		$if debug_inp ? {
			println('')
			if move > 0 {
				println('=row_f${move}=')
			} else if move < 0 {
				println('=row_b${-move}=')
			}
		} $else {
			Stage.move(move)
		}
		sel = next

		mut i := row[inps[sel]]
		if mut i is Input {
			i.cur = newcur
			i.read() or {
				if err.str() != 'switch' {
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
