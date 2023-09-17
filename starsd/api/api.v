module api

pub struct ApiAuth {
pub:
	challenge string
}

pub struct ApiPrizeCur {
pub:
	prize_id u64
	start    string
	stars    int
	goal     int
	got      struct {
	pub:
		stars    int
		deposits int
	}
}

pub struct ApiWeek_Star {
pub:
	at  string
	typ int
	got ?bool
	//    special ?string
}

pub struct ApiWeek {
pub:
	stars []ApiWeek_Star

	from string
	till string
}
