module store

import orm
import util

interface Store {
mut:
	db orm.Connection
	close() !
	create() !
	verify() !
	get_users() ![]User
	put_user(name string, psk string) !
	get_user(name string) !User
	delete_user(name string) !
	set_user_perms(name string, perms u32) !
	get_cur_prize() !Prize
	get_prize(prize_id u64) !Prize
	add_prize(starts string, first_dow int, goal int, star_val int) !
	end_prize(prize_id u64) !
	get_star_count(prize_id u64) !int
	get_stars(prize_id u64, from string, till string) ![]Star
	get_last_star(prize_id u64, typ int) !Star
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
	cur_prize   ?Prize
	session_exp int = 60
}

fn (mut s StoreImpl) create() ! {
	println('db: creating schema')
	conf := Conf{
		key: 'version'
		val: schema_version.str()
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

fn (mut s StoreImpl) get_users() ![]User {
	users := sql s.db {
		select from User
	}!
	return users.sorted_with_compare(fn (a &User, b &User) int {
		return if a.name < b.name {
			-1
		} else if a.name > b.name {
			1
		} else {
			0
		}
	})
}

fn (mut s StoreImpl) put_user(name string, psk string) ! {
	sql s.db {
		delete from User where name == name
	}!
	user := User{
		name: name
		psk: psk
	}
	sql s.db {
		insert user into User
	}!
}

fn (mut s StoreImpl) get_user(user string) !User {
	res := sql s.db {
		select from User where name == user
	}!
	if res.len > 0 {
		return res[0]
	} else {
		return not_found
	}
}

fn (mut s StoreImpl) delete_user(user string) ! {
	sql s.db {
		delete from User where name == user
	}!
}

fn (mut s StoreImpl) set_user_perms(name string, perms u32) ! {
	sql s.db {
		update User set perms = perms where name == name
	}!
}

fn (mut s StoreImpl) get_cur_prize() !Prize {
	if s.cur_prize == none {
		today := util.sdate_now()
		prizes := sql s.db {
			select from Prize where start <= today && end is none order by start
		}!
		if prizes.len == 0 {
			return not_found
		} else if prizes.len > 1 {
			return multiple
		}
		s.cur_prize = prizes.first()
	}
	return s.cur_prize or { Prize{} }
}

fn (mut s StoreImpl) get_prize(prize_id u64) !Prize {
	prizes := sql s.db {
		select from Prize where id == prize_id
	}!
	if prizes.len == 1 {
		return prizes.first()
	} else {
		return not_found
	}
}

fn (mut s StoreImpl) add_prize(starts string, first_dow int, goal int, star_val int) ! {
	prize := Prize{
		start: starts
		first_dow: first_dow
		goal: goal
		star_val: star_val
	}
	sql s.db {
		insert prize into Prize
	}!
}

fn (mut s StoreImpl) end_prize(prize_id u64) ! {
	now := util.sdate_now()
	sql s.db {
		update Prize set end = now where id == prize_id && end is none
	}!
	s.cur_prize = none
}

fn (mut s StoreImpl) get_star_count(prize_id u64) !int {
	count := sql s.db {
		select count from Star where prize_id == prize_id && got == true
	}!
	return count
}

fn (mut s StoreImpl) get_stars(prize_id u64, from string, till string) ![]Star {
	stars := sql s.db {
		select from Star where prize_id == prize_id && typ >= 0 && at >= from && at <= till order by at
	}!
	return stars.sorted_with_compare(fn (a &Star, b &Star) int {
		return if a.typ == b.typ {
			if a.at < b.at {
				-1
			} else if a.at > b.at {
				1
			} else {
				0
			}
		} else {
			a.typ - b.typ
		}
	})
}

fn (mut s StoreImpl) get_last_star(prize_id u64, typ int) !Star {
	stars := sql s.db {
		select from Star where prize_id == prize_id && typ == typ order by at desc limit 1
	}!
	return if stars.len > 0 { stars[0] } else { not_found }
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

fn (mut s StoreImpl) add_deposit(prize_id u64, at string, amount int, desc string) ! {
	deposit := Deposit{
		at: at
		amount: amount
		prize_id: prize_id
		desc: desc
	}
	sql s.db {
		insert deposit into Deposit
	}!
}

fn (mut s StoreImpl) update_deposit(deposit_id u64, at string, amount int, desc string) ! {
	sql s.db {
		update Deposit set at = at, amount = amount, desc = desc where id == deposit_id
	}!
}
