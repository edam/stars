module store

import orm

interface Store {
mut:
	db orm.Connection
	close() !
	update() !
	get_cur_prize() !Prize
	get_cur_star_count() !int
	get_stars(prize_id u64, from string, till string) ![]Star
}

pub fn Store.new(path string) !&Store {
	return SqliteDB.new(path)!
}

struct StoreImpl {
mut:
	db    orm.Connection
	prize &Prize = unsafe { nil }
}
