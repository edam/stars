import store
import util

fn next_win(wins []store.Win, prize_start string, first_dow int) !string {
	if wins.len > 0 {
		last := wins#[-1..][0].at
		return util.sdate_add(last, 7)!
	} else {
		start_dow := util.sdate_dow(prize_start)!
		first_dow_ := first_dow + if first_dow > start_dow { 0 } else { 7 }
		diff_dow := first_dow_ - start_dow - 1 // win is 6 days ahead of first dow
		return util.sdate_add(prize_start, diff_dow)!
	}
}

fn (mut app App) latest_star_at() !string {
	prize := app.db.get_cur_prize()!
	if star := app.db.get_last_star(prize.id, 0) {
		next_day := util.sdate_add(star.at, 1)!
		if util.sdate_dow(next_day)! == prize.first_dow {
			next_week_end := util.sdate_add(next_day, 6)!
			next_week := app.db.get_stars(prize.id, next_day, next_week_end)!
			if next_week.len > 0 {
				return next_week[0].at
			}
		}
		return star.at
	} else {
		return prize.start or { '' }
	}
}
