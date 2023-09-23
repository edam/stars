module store

import util

const schema_version = 1

[table: config]
struct Conf {
pub:
	key string [primary]
	val string
}

[table: prizes]
struct Prize {
pub:
	id       u64     [primary; sql: serial]
	star_val int
	goal     int
	start    ?string
	end      ?string
}

[table: stars]
struct Star {
pub:
	id       u64    [primary; sql: serial]
	at       string
	typ      int
	prize_id u64    [fkey: prizes]
	got      ?bool
}

[table: wins]
struct Win {
pub:
	id       u64    [primary; sql: serial]
	at       string
	typ      int
	prize_id u64    [fkey: prizes]
	got      ?bool
}

[table: deposits]
struct Deposit {
pub:
	id       u64    [primary; sql: serial]
	at       string
	amount   int
	prize_id u64    [fkey: prizes]
	desc     string
}

[table: users]
struct User {
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
	if s.prize == unsafe { nil } {
		today := util.sdate_now()
		prizes := sql s.db {
			select from Prize where start <= today && end is none order by start
		}!
		if prizes.len == 0 {
			return error('no active prizes')
		}
		prize := prizes.first()
		s.prize = &prize
	}
	return *(s.prize)
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

fn (mut s StoreImpl) set_star_got(prize_id u64, date string, typ int, got ?bool) !bool {
	stars := sql s.db {
		select from Star where prize_id == prize_id && at == date && typ == typ
	}!
	if stars.len != 1 {
		return false
	}
	sql s.db {
		update Star set got = got where prize_id == prize_id && at == date && typ == typ
	}!
	return true
}

fn (mut s StoreImpl) get_wins(prize_id u64) ![]Win {
	return sql s.db {
		select from Win where prize_id == prize_id order by at
	}!
}
