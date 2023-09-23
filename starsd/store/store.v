module store

import orm

interface Store {
mut:
	db orm.Connection
	close() !
	create() !
	update() !
	get_user(username string) !User
	get_cur_prize() !Prize
	get_star_count(prize_id u64) !int
	get_stars(prize_id u64, from string, till string) ![]Star
	get_deposits(prize_id u64) ![]Deposit
	set_star_got(prize_id u64, date string, typ int, got ?bool) !bool
	get_wins(prize_id u64) ![]Win
}

struct StoreImpl {
mut:
	db          orm.Connection
	cancel      chan int
	prize       &Prize = unsafe { nil }
	session_exp int    = 60
}
