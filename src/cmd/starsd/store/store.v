module store

import orm
import util

interface IStore {
mut:
	db orm.Connection
	close() !
	create() !
	verify() !
	get_users() ![]User
	put_user(username string, psk string) !
	get_user(username string) !User
	add_user(username string, psk string, perms u32) !
	delete_user(username string) !
	set_user_perms(username string, perms u32) !
	set_user_psk(username string, psk string) !
	get_cur_prize() !Prize
	get_prize(prize_id u64) !Prize
	add_prize(starts string, first_dow int, goal int, star_val int) !
	end_prize(prize_id u64) !
	set_prize_goal(prize_id u64, goal int) !
	get_star_count(prize_id u64) !int
	get_stars(prize_id u64, from string, till string) ![]Star
	get_stars_n(prize_id u64, n int) ![]Star
	get_last_star(prize_id u64, typ int) !Star
	get_deposits(prize_id u64) ![]Deposit
	add_deposit(prize_id u64, at string, amount int, desc string) !
	delete_deposit(prize_id u64, deposit_id u64) !
	update_deposit(deposit_id u64, at string, amount int, desc string) !
	set_star_got(prize_id u64, at string, typ int, got ?bool) !bool
	add_star(prize_id u64, at string, typ int, got ?bool) !
	delete_star(prize_id u64, at string, typ int) !
	get_wins(prize_id u64, limit ?int) ![]Win
	set_win(prize_id u64, at string, got bool) !
	delete_win(prize_id u64, at string) !
}

struct Store {
mut:
	db          orm.Connection
	cancel      chan int
	cur_prize   ?Prize
	session_exp int = 60
}

fn (mut s Store) create() ! {
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

fn (mut s Store) get_users() ![]User {
	users := sql s.db {
		select from User
	}!
	return users.sorted_with_compare(fn (a &User, b &User) int {
		return if a.username < b.username {
			-1
		} else if a.username > b.username {
			1
		} else {
			0
		}
	})
}

fn (mut s Store) put_user(username string, psk string) ! {
	sql s.db {
		delete from User where username == username
	}!
	user := User{
		username: username
		psk: psk
	}
	sql s.db {
		insert user into User
	}!
}

fn (mut s Store) get_user(username string) !User {
	res := sql s.db {
		select from User where username == username
	}!
	if res.len > 0 {
		return res[0]
	} else {
		return not_found
	}
}

fn (mut s Store) add_user(username string, psk string, perms u32) ! {
	user := User{
		username: username
		psk: psk
		perms: perms
	}
	sql s.db {
		insert user into User
	}!
}

fn (mut s Store) delete_user(username string) ! {
	sql s.db {
		delete from User where username == username
	}!
}

fn (mut s Store) set_user_perms(username string, perms u32) ! {
	sql s.db {
		update User set perms = perms where username == username
	}!
}

fn (mut s Store) set_user_psk(username string, psk string) ! {
	sql s.db {
		update User set psk = psk where username == username
	}!
}

fn (mut s Store) get_cur_prize() !Prize {
	if s.cur_prize == none {
		today := util.sdate_now()
		prizes := sql s.db {
			select from Prize where start <= today && end is none order by start
		}!
		if prizes.len == 0 {
			return not_found
		} else if prizes.len > 1 {
			return multiple_found
		}
		s.cur_prize = prizes.first()
	}
	return s.cur_prize or { Prize{} }
}

fn (mut s Store) get_prize(prize_id u64) !Prize {
	prizes := sql s.db {
		select from Prize where id == prize_id
	}!
	if prizes.len == 1 {
		return prizes.first()
	} else {
		return not_found
	}
}

fn (mut s Store) add_prize(starts string, first_dow int, goal int, star_val int) ! {
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

fn (mut s Store) end_prize(prize_id u64) ! {
	now := util.sdate_now()
	sql s.db {
		update Prize set end = now where id == prize_id && end is none
	}!
	s.cur_prize = none // invalidate cache
}

fn (mut s Store) set_prize_goal(prize_id u64, goal int) ! {
	sql s.db {
		update Prize set goal = goal where id == prize_id
	}!
	s.cur_prize = none // invalidate cache
}

fn (mut s Store) get_star_count(prize_id u64) !int {
	count := sql s.db {
		select count from Star where prize_id == prize_id && got == true
	}!
	return count
}

// fetch positive-type stars in time range in "star order"
fn (mut s Store) get_stars(prize_id u64, from string, till string) ![]Star {
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

// fetch latest n got/lost (not null) stars of any type in date order
fn (mut s Store) get_stars_n(prize_id u64, n int) ![]Star {
	stars := sql s.db {
		select from Star where prize_id == prize_id && got !is none order by at desc limit n
	}!
	return stars.sorted(a.at < b.at)
}

// fetch latest got/lost (not null) star of type
fn (mut s Store) get_last_star(prize_id u64, typ int) !Star {
	stars := sql s.db {
		select from Star where prize_id == prize_id && typ == typ && got !is none order by at desc limit 1
	}!
	return if stars.len > 0 { stars[0] } else { not_found }
}

fn (mut s Store) get_deposits(prize_id u64) ![]Deposit {
	deposits := sql s.db {
		select from Deposit where prize_id == prize_id order by at
	}!
	return deposits
}

fn (mut s Store) add_deposit(prize_id u64, at string, amount int, desc string) ! {
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

fn (mut s Store) delete_deposit(prize_id u64, deposit_id u64) ! {
	sql s.db {
		delete from Deposit where id == deposit_id && prize_id == prize_id
	}!
}

fn (mut s Store) update_deposit(deposit_id u64, at string, amount int, desc string) ! {
	sql s.db {
		update Deposit set at = at, amount = amount, desc = desc where id == deposit_id
	}!
}

fn (mut s Store) set_star_got(prize_id u64, at string, typ int, got ?bool) !bool {
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

fn (mut s Store) add_star(prize_id u64, at string, typ int, got ?bool) ! {
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

fn (mut s Store) delete_star(prize_id u64, at string, typ int) ! {
	sql s.db {
		delete from Star where prize_id == prize_id && at == at && typ == typ
	}!
}

fn (mut s Store) get_wins(prize_id u64, limit ?int) ![]Win {
	if limit_ := limit {
		return sql s.db {
			select from Win where prize_id == prize_id order by at desc limit limit_
		}!
	} else {
		return sql s.db {
			select from Win where prize_id == prize_id order by at
		}!
	}
}

fn (mut s Store) set_win(prize_id u64, at string, got bool) ! {
	win := Win{
		at: at
		got: got
		prize_id: prize_id
	}
	sql s.db {
		insert win into Win
	}!
}

fn (mut s Store) delete_win(prize_id u64, at string) ! {
	sql s.db {
		delete from Win where prize_id == prize_id && at == at
	}!
}
