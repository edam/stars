module store

import db.sqlite

struct SqliteDB {
	StoreImpl
}

// pub fn SqliteD.new(path string) !&SqliteDB {
pub fn new_sqlite(path string) !&SqliteDB {
	db := sqlite.connect(path)!
	return &SqliteDB{
		db: db
	}
}

// pub fn (mut s SqliteDB) update() ! {
//	if mut s.db is sqlite.DB {
//		current := math.max(0, s.db.exec('PRAGMA user_version')![0].vals[0].int())
//		println('db: current schema version: ${current}')
//		for version := current + 1; version <= schema_version; version++ {
//			println('db: applying ${version:04}.sql')
//			file := os.resource_abs_path('./store/schema/${version:04}.sql')
//			mut raw_sql := ''
//			for line in os.read_lines(file)! {
//				part := line.trim_space()
//				if part.len > 0 && (part.len < 2 || part[0..2] != '--') {
//					raw_sql += if raw_sql.len > 0 { ' ${part}' } else { part }
//					if raw_sql#[-1..] == ';' {
//						s.db.exec(raw_sql)!
//						raw_sql = ''
//					}
//				}
//			}
//			if raw_sql != '' {
//				return error('missing ; at end of file')
//			}
//			s.db.exec('PRAGMA user_version=${version}')!
//			println('db: current schema version: ${version}')
//		}
//	}
//}

pub fn (mut s SqliteDB) close() ! {
	if mut s.db is sqlite.DB {
		s.db.close()!
	}
}
