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
	get_prize(prize_id u64) !Prize
	get_star_count(prize_id u64) !int
	get_stars(prize_id u64, from string, till string) ![]Star
	get_deposits(prize_id u64) ![]Deposit
	set_star_got(prize_id u64, at string, typ int, got ?bool) !bool
	add_star(prize_id u64, at string, typ int, got ?bool) !
	delete_star(prize_id u64, at string, typ int) !
	get_wins(prize_id u64) ![]Win
	set_win(prize_id u64, at string, got bool) !
	delete_win(prize_id u64, at string) !
	add_deposit(prize_id u64, at string, amount int, desc string) !
	update_deposit(deposit_id u64, at string, amount int, desc string) !
}

struct StoreImpl {
mut:
	db          orm.Connection
	cancel      chan int
	prizes      map[u64]Prize
	cur_prize   u64
	session_exp int = 60
}
