module store

import util

const schema_version = 1

[table: config]
pub struct Conf {
pub:
	key string [primary]
	val string
}

[table: prizes]
pub struct Prize {
pub:
	id        u64     [primary; sql: serial]
	star_val  int
	goal      int
	first_dow int
	start     ?string
	end       ?string
}

[table: stars]
pub struct Star {
pub:
	id       u64    [primary; sql: serial]
	at       string [unique: 'star']
	typ      int    [unique: 'star']
	prize_id u64    [fkey: prizes; unique: 'star']
	got      ?bool
}

[table: wins]
pub struct Win {
pub:
	id       u64    [primary; sql: serial]
	at       string [unique: 'win']
	prize_id u64    [fkey: prizes; unique: 'win']
	got      bool
}

[table: deposits]
pub struct Deposit {
pub:
	id       u64    [primary; sql: serial]
	at       string
	amount   int
	prize_id u64    [fkey: prizes]
	desc     string
}

[table: users]
pub struct User {
pub:
	id    u64    [primary; sql: serial]
	name  string
	psk   string
	perms u32
}

// --

fn (mut s StoreImpl) create() ! {
	println('db: creating schema')
	conf := Conf{
		key: 'version'
		val: store.schema_version.str()
	}
	sql s.db {
		create table Conf
		create table Prize
		create table Star
		create table Win
		create table Deposit
		create table User
		insert conf into Conf
	}!
}

fn (mut s StoreImpl) get_user(user string) !User {
	res := sql s.db {
		select from User where name == user
	}!
	if res.len > 0 {
		return res[0]
	} else {
		return error('user not found')
	}
}

fn (mut s StoreImpl) get_cur_prize() !Prize {
	if s.cur_prize == 0 {
		today := util.sdate_now()
		prizes := sql s.db {
			select from Prize where start <= today && end is none order by start
		}!
		if prizes.len != 1 {
			return error('no single current prize')
		}
		prize := prizes.first()
		s.cur_prize = prize.id
		s.prizes[prize.id] = prize
	}
	return s.prizes[s.cur_prize]
}

fn (mut s StoreImpl) get_prize(prize_id u64) !Prize {
	if prize_id !in s.prizes {
		prizes := sql s.db {
			select from Prize where id == prize_id
		}!
		if prizes.len == 1 {
			prize := prizes.first()
			s.prizes[prize.id] = prize
		} else {
			return error('bad prize_id')
		}
	}
	return s.prizes[prize_id]
}

fn (mut s StoreImpl) get_star_count(prize_id u64) !int {
	count := sql s.db {
		select count from Star where prize_id == prize_id && got == true
	}!
	return count
}

fn (mut s StoreImpl) get_stars(prize_id u64, from string, till string) ![]Star {
	stars := sql s.db {
		select from Star where prize_id == prize_id && at >= from && at <= till order by at
	}!
	return stars
}

fn (mut s StoreImpl) get_deposits(prize_id u64) ![]Deposit {
	deposits := sql s.db {
		select from Deposit where prize_id == prize_id
	}!
	return deposits
}

fn (mut s StoreImpl) set_star_got(prize_id u64, at string, typ int, got ?bool) !bool {
	stars := sql s.db {
		select from Star where prize_id == prize_id && at == at && typ == typ
	}!
	if stars.len != 1 {
		return false
	}
	sql s.db {
		update Star set got = got where prize_id == prize_id && at == at && typ == typ
	}!
	return true
}

fn (mut s StoreImpl) add_star(prize_id u64, at string, typ int, got ?bool) ! {
	stars := sql s.db {
		select from Star where prize_id == prize_id && at == at && typ == typ
	}!
	if stars.len > 0 {
		return
	}
	star := Star{
		prize_id: prize_id
		at: at
		typ: typ
		got: got
	}
	sql s.db {
		insert star into Star
	}!
}

fn (mut s StoreImpl) delete_star(prize_id u64, at string, typ int) ! {
	sql s.db {
		delete from Star where prize_id == prize_id && at == at && typ == typ
	}!
}

fn (mut s StoreImpl) get_wins(prize_id u64) ![]Win {
	return sql s.db {
		select from Win where prize_id == prize_id order by at
	}!
}

fn (mut s StoreImpl) set_win(prize_id u64, at string, got bool) ! {
	win := Win{
		at: at
		got: got
		prize_id: prize_id
	}
	sql s.db {
		insert win into Win
	}!
}

fn (mut s StoreImpl) delete_win(prize_id u64, at string) ! {
	sql s.db {
		delete from Win where prize_id == prize_id && at == at
	}!
}
