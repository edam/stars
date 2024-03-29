module store

import db.pg

struct PgsqlDB {
	Store
}

// pub fn PgsqlDB.new(path string) !&PgsqlDB {
pub fn new_pgsql(host string, port int, username string, password string, dbname string) !&IStore {
	db := pg.connect(pg.Config{
		host: host
		port: port
		user: username
		password: password
		dbname: dbname
	})!
	return &PgsqlDB{
		db: db
	}
}

pub fn (mut s PgsqlDB) close() ! {
	if mut s.db is pg.DB {
		s.db.close()
	}
}
