module inp

import term
import encoding.utf8.east_asian

struct Stage {
mut:
	cur int // new cur
	// off int // offset to buf
	// buf []rune
}

const global_stage = Stage{}

fn Stage.get() &Stage {
	return unsafe { &inp.global_stage }
}

// --

// get display width of runes (some runes are 2 terminal chars wide)
pub fn width(runes []rune) int {
	return east_asian.display_width(runes.string(), 2)
}

// -

// move cursor forward/backward
pub fn Stage.move(n int) {
	Stage.get().cur += n
}

// stage print
pub fn Stage.print(s string) {
	Stage.flush()
	print(s)
}

// stage print newline
pub fn Stage.newln() {
	println('')
}

// render stage to terminal
pub fn Stage.flush() {
	// stage := Stage.get()
	// if stage.off > 0 {
	//	term.cursor_forward(stage.off)
	//} else if stage.off < 0 {
	//	term.cursor_back(-stage.off)
	//}
	// print(stage.buf.string())
	// off := cur - width(buf) - off
	// if off > 0 {
	//    term.cursor_forward(off)
	//} else if stage.off < 0 {
	//    term.cursor_back(-off)
	//}
	stage := Stage.get()
	if stage.cur > 0 {
		term.cursor_forward(stage.cur)
	} else if stage.cur < 0 {
		term.cursor_back(-stage.cur)
	}
	Stage.reset()
}

pub fn Stage.reset() {
	mut stage := Stage.get()
	stage.cur = 0
	// stage.off = 0
	// stage.buf = []
}
