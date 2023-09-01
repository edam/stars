module store

const schema_version = 1

[table: 'prizes']
struct Prize {
pub:
	id      u64    [primary; sql: serial]
	starval int    [nonull]
	goal    int    [nonull]
	start   string
	end     string
}

[table: 'stars']
struct Star {
pub:
	id       u64    [primary; sql: serial]
	at       string [nonull]
	got      bool
	prize_id u64    [nonull]
}

// --

fn (mut s StoreImpl) get_cur_prize() !Prize {
	if s.prize == unsafe { nil } {
		prizes := sql s.db {
			select from Prize where id == 1
            // where start is not null && end is none
		}!
		prize := prizes.first()
		s.prize = &prize
	}
	return *(s.prize)
}

fn (mut s StoreImpl) get_cur_star_count() !int {
	prize := s.get_cur_prize()!
	count := sql s.db {
		select count from Star where prize_id == prize.id && got == true
	}!
	return count
}

fn (mut s StoreImpl) get_stars(prize_id u64, from string, till string) ![]Star {
    stars := sql s.db {
        select from Star where prize_id == prize_id && at >= from && at <= till order by at
    }!
    return stars
}
