module api

pub const api_version = 3

pub struct ApiAuth {
pub:
	challenge   string
	session_ttl int
	api_version int
}

pub struct ApiPrizeCur {
pub:
	prize Api_Prize
	stars int
	got   struct {
	pub:
		stars    int
		deposits int
	}
}

pub struct ApiWeek {
pub:
	stars []Api_Star

	from string
	till string
}

pub struct ApiOk {}

pub struct ApiDeposits {
pub:
	deposits []Api_Deposit
}

pub struct ApiWins {
pub:
	wins []Api_Win
	next string
}

pub struct ApiUsers {
pub:
	users []Api_User
}

pub struct ApiStats {
pub:
	from string
	till string
	got  struct {
	pub:
		stars int
	}
}

// objects

pub struct Api_Prize {
pub:
	id        u64
	star_val  int
	goal      int
	first_dow int
	start     string
}

pub struct Api_Star {
pub:
	at  string
	typ int
	got ?bool
}

pub struct Api_Deposit {
pub:
	at     string
	amount int
	desc   string
}

pub struct Api_Win {
pub:
	at  string
	got bool
}

pub struct Api_User {
pub:
	name  string
	perms Api_UserPerms
}

pub struct Api_UserPerms {
pub:
	admin bool
}
