module store

const schema_version = 2

@[table: config]
pub struct Conf {
pub:
	key string @[primary]
	val string
}

@[table: prizes]
pub struct Prize {
pub:
	id        u64     @[primary; sql: serial]
	star_val  int
	goal      int
	first_dow int
	start     ?string
	end       ?string
}

@[table: stars]
pub struct Star {
pub:
	id       u64    @[primary; sql: serial]
	at       string @[unique: 'star']
	typ      int    @[unique: 'star']
	prize_id u64    @[fkey: prizes; unique: 'star']
	got      ?bool
}

@[table: wins]
pub struct Win {
pub:
	id       u64    @[primary; sql: serial]
	at       string @[unique: 'win']
	prize_id u64    @[fkey: prizes; unique: 'win']
	got      bool
}

@[table: deposits]
pub struct Deposit {
pub:
	id       u64    @[primary; sql: serial]
	at       string
	amount   int
	prize_id u64    @[fkey: prizes]
	desc     string
}

@[table: users]
pub struct User {
pub:
	id       u64    @[primary; sql: serial]
	username string @[sql: 'name'] // TODO: update schema and rename
	psk      string
	perms    u32
}

// --

pub const not_found = error('not found')
pub const multiple_found = error('multiple found')
