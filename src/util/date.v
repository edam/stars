module util

import regex
import time

// references
// https://artofmemory.com/blog/how-to-calculate-the-day-of-the-week/

// get day ordinal in english
pub fn ordinal(n int) string {
	return match true {
		n < 1 { 'th' }
		n % 100 in [11, 12, 13] { 'th' }
		n % 10 == 1 { 'st' }
		n % 10 == 2 { 'nd' }
		n % 10 == 3 { 'rd' }
		else { 'th' }
	}
}

// is julian date?
pub fn is_julian(y int, m int, d int) bool {
	return y < 1752 || (y == 1752 && (m < 9 || (m == 9 && d < 14)))
}

// is the date a leap year?
pub fn is_leap_year(y int) bool {
	ly := y % 4 == 0
	return if y < 1752 { ly } else { ly && (y % 100 != 0 || y % 400 == 0) }
}

const dim = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

// get the number of days (1-31) in a month (1-12) for the year
pub fn month_days(y int, m int) !int {
	if m < 1 || m > 12 {
		return error('bad month')
	}
	return if m == 2 && is_leap_year(y) { 29 } else { util.dim[m - 1] }
}

const madj = [0, 3, 3, 6, 1, 4, 6, 2, 5, 0, 3, 5] // month adjust

const cadj = [4, 2, 0, 6, 4, 2, 0] // century adjust (1700-2399)

// calc day of week from date
pub fn date_to_dow(y int, m int, d int) !int {
	if y < 1100 || y > 2399 || m < 1 || m > 12 || d < 1 || d > month_days(y, m)! {
		return error('bad date')
	}
	yl, yh := y % 100, y / 100
	yc := (yl + (yl / 4)) % 7
	mc := util.madj[m - 1]
	cc := if is_julian(y, m, d) { (18 - yh) % 7 } else { util.cadj[yh - 17] }
	lyc := if m <= 2 && is_leap_year(y) { -1 } else { 0 }
	return (yc + mc + cc + d + lyc + 6) % 7 + 1
}

// add small number of days to a date
pub fn date_add(y int, m int, d int, days int) !(int, int, int) {
	if days > 0 {
		md := month_days(y, m)!
		if d + days <= md {
			return y, m, d + days
		}
		yy := if m == 12 { y + 1 } else { y }
		mm := if m == 12 { 1 } else { m + 1 }
		dd := d + days - md
		return yy, mm, dd
	} else if days < 0 {
		if d > -days {
			return y, m, d + days
		}
		mm := if m > 1 { m - 1 } else { 12 }
		yy := if m > 1 { y } else { y - 1 }
		dd := d + month_days(yy, mm)! + days
		return yy, mm, dd
	} else {
		return y, m, d
	}
}

@[inline]
pub fn date_sub(y int, m int, d int, days int) !(int, int, int) {
	return date_add(y, m, d, -days)!
}

// get date at start of week
pub fn week_start(y int, m int, d int) !(int, int, int) {
	dow := date_to_dow(y, m, d)!
	return date_sub(y, m, d, dow - 1)!
}

// sdates (YYYY-MM-DD string dates)

// make an sdate
pub fn sdate(y int, m int, d int) string {
	return '${y:04}-${m:02}-${d:02}'
}

// convert sdate to y, m, d
pub fn parse_sdate(date string) !(int, int, int) {
	mut re := regex.regex_opt(r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$') or { panic(err) }
	if !re.matches_string(date) {
		return error('bad sdate')
	}
	y := re.get_group_by_id(date, 0).int()
	m := re.get_group_by_id(date, 1).int()
	d := re.get_group_by_id(date, 2).int()
	return y, m, d
}

// today's date
pub fn sdate_now() string {
	return time.now().get_fmt_date_str(.hyphen, .yyyymmdd)
}

// calc day of week (1-7) from sdate
pub fn sdate_dow(date string) !int {
	y, m, d := parse_sdate(date)!
	return date_to_dow(y, m, d)!
}

// get sdate from at start of week
pub fn sdate_week_start(date string) !string {
	y, m, d := parse_sdate(date)!
	yy, mm, dd := week_start(y, m, d)!
	return sdate(yy, mm, dd)
}

// add a few days to an sdate
pub fn sdate_add(date string, days int) !string {
	y, m, d := parse_sdate(date)!
	yy, mm, dd := date_add(y, m, d, days)!
	return sdate(yy, mm, dd)
}

// subtract a few days to an sdate
@[inline]
pub fn sdate_sub(date string, days int) !string {
	return sdate_add(date, -days)!
}

// check date is valid
pub fn sdate_check(date string) !string {
	parse_sdate(date)!
	return date
}
