module lambdas

struct GetStarsResponse {
	count int
	max   int
}

pub fn get_stars() !GetStarsResponse {
	return GetStarsResponse{2, 150}
}

struct GetWeeksResponseEntry {
	date string
	got  ?bool
}

struct GetWeeksResponse {
	entries []GetWeeksResponseEntry
}

pub fn get_week(date string) !GetWeeksResponse {
	return WebError.new(501)
}
