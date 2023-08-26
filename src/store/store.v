module store

import orm

interface Store {
mut:
	db orm.Connection
	close() !
	update() !
	get_cur_prize() !Prize
	get_cur_star_count() !int
}

pub fn Store.new(path string) !&Store {
	return SqliteDB.new(path)!
}

struct StoreImpl {
mut:
	db    orm.Connection
	prize &Prize = unsafe { nil }
}
