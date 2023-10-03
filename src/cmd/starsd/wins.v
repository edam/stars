import store
import util

fn next_win(wins []store.Win, prize_start string, first_dow int) !string {
	if wins.len > 0 {
		last := wins#[-1..][0].at
		return util.sdate_add(last, 7)!
	} else {
		start_dow := util.sdate_to_dow(prize_start)!
		first_dow_ := first_dow + if first_dow > start_dow { 0 } else { 7 }
		diff_dow := first_dow_ - start_dow - 1 // win is 6 days ahead of first dow
		return util.sdate_add(prize_start, diff_dow)!
	}
}
