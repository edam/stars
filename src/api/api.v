module api

pub struct ApiAuth {
pub:
	challenge   string
	session_ttl int
}

pub struct ApiPrizeCur {
pub:
	prize_id  u64
	start     string
	stars     int
	goal      int
	first_dow int
	got       struct {
	pub:
		stars    int
		deposits int
	}
}

pub struct Api_Star {
pub:
	at  string
	typ int
	got ?bool
}

pub struct ApiWeek {
pub:
	stars []Api_Star

	from string
	till string
}

pub struct ApiOk {}

pub struct Api_Deposit {
pub:
	at     string
	amount int
	desc   string
}

pub struct ApiDeposits {
pub:
	deposits []Api_Deposit
}

pub struct Api_Win {
pub:
	at  string
	got bool
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

pub struct Api_User {
pub:
	name  string
	perms Api_UserPerms
}

pub struct Api_UserPerms {
pub:
	admin bool
}
