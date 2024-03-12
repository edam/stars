module util

fn hexval(c u8) u8 {
	return match c {
		48...57 { c - 48 } // 0-9
		65...69 { c - 65 + 10 } // A-F
		97...102 { c - 97 + 10 } // a-f
		else { 255 }
	}
}

pub fn unhex(s &string) ![]u8 {
	if s.len == 0 {
		return []u8{}
	}
	if s.len & 1 > 0 {
		return error('invalid hex')
	}
	buflen := s.len / 2
	mut buf := []u8{len: buflen, cap: buflen}
	for i := 0; i < s.len; i += 2 {
		unsafe {
			hb := hexval(*(s.str + i))
			lb := hexval(*(s.str + i + 1))
			if hb == 255 || lb == 255 {
				return error('invalid hex')
			}
			byt := hb << 4 + lb
			buf[i >> 1] = byt
		}
	}
	return buf
}
