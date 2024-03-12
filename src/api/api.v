module api

pub const api_version = 4

pub struct Ok {}

pub struct GetAuth {
pub:
	challenge   string
	session_ttl int
	api_version int
}

pub struct GetPrizesCur {
pub:
	prize Prize
	stars int
	got   struct {
	pub:
		stars    int
		deposits int
	}
}

pub struct GetPrizesWeeks {
pub:
	stars []Star

	from string
	till string
}

pub struct GetPrizesDeposits {
pub:
	deposits []Deposit
}

pub struct GetPrizesWins {
pub:
	wins []Win
	next string
}

pub struct GetPrizesStats {
pub:
	from string
	till string
	got  struct {
	pub:
		stars int
	}
}

pub struct GetAdminUsers {
pub:
	users []User
}

pub struct PutAdminUsersReq {
pub:
	psk ?string
}

// objects

pub struct Prize {
pub:
	id        u64
	star_val  int
	goal      int
	first_dow int
	start     string
}

pub struct Star {
pub:
	at  string
	typ int
	got ?bool
}

pub struct Deposit {
pub:
	id     u64
	at     string
	amount int
	desc   string
}

pub struct Win {
pub:
	at  string
	got bool
}

pub struct User {
pub:
	username string
	psk      ?string
	perms    UserPerms
}

pub struct UserPerms {
pub:
	admin bool
}
