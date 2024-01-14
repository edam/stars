module store

import crypto.sha256

fn (mut s StoreImpl) verify() ! {
	println('db: checking schema')
	conf := sql s.db {
		select from Conf where key == 'version'
	}!
	if conf.len != 1 {
		return error('can not read schema version')
	}
	mut version := conf[0].val.int()
	if version < 1 || version > schema_version {
		return error('unknown schema version')
	}
	for {
		println('db: schema at version ${version}')
		if version >= schema_version {
			break
		}
		version++
		println('db: upgrading schema to version ${version}')
		// db.begin()
		s.upgrade(version)!
		sql s.db {
			update Conf set val = version where key == 'version'
		}!
		// db.commit()
	}
}

fn (mut s StoreImpl) upgrade(version int) ! {
	match version {
		2 { s.upgrade_2()! }
		else { return error('unknown version: ${version}') }
	}
}

fn (mut s StoreImpl) upgrade_2() ! {
	users := sql s.db {
		select from User
	}!
	for user in users {
		psk := sha256.hexhash(user.psk)
		sql s.db {
			update User set psk = psk where id == user.id
		}!
	}
}
