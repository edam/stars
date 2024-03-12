import db.sqlite
import time

const cleanup_expired_every = 1 * time.hour

@[heap]
struct Sessions {
	db     sqlite.DB
	cancel chan bool
	expire int
}

fn Sessions.new(expire int) !&Sessions {
	mut s := &Sessions{
		db: sqlite.connect(':memory:')!
		expire: expire
	}
	sql s.db {
		create table Session
	}!
	go s.session_clean()
	return s
}

fn (mut s Sessions) session_clean() {
	for {
		select {
			_ := <-s.cancel {
				break
			}
			cleanup_expired_every {
				s.cleanup() or {}
			}
		}
	}
}

fn (mut s Sessions) close() {
	s.cancel <- true
}

// --

const perm_admin = 1

@[table: sessions]
struct Session {
pub:
	id       string    @[primary]
	username string
	at       time.Time
	perms    u32
}

fn (mut s Sessions) add(session_id string, username string, perms u32) ! {
	session := Session{
		id: session_id
		username: username
		at: time.now()
		perms: perms
	}
	sql s.db {
		insert session into Session
	}!
}

fn (mut s Sessions) cleanup() ! {
	exp := time.now().add_seconds(-s.expire)
	sql s.db {
		delete from Session where at <= exp
	}!
}

fn (mut s Sessions) get(session_id string) !Session {
	exp := time.now().add_seconds(-s.expire)
	res := sql s.db {
		select from Session where id == session_id && at > exp
	}!
	if res.len > 0 {
		sql s.db {
			update Session set at = time.now() where id == session_id
		}!
		return res[0]
	}
	return error('no session')
}
