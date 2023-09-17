module cmds

import time
import api

pub fn (mut c Client) info() ! {
	sw := time.new_stopwatch()
	c.auth()!

	// done := chan bool{}
	// errs := chan IError{}
	// res1 := api.ApiPrizeCur{}
	// res2 := api.ApiWeek{}
	// go fn (res &api.ApiPrizeCur, mut c Client, done chan bool, errs chan IError) {
	//	tmp := c.get[api.ApiPrizeCur]('/api/prize/cur') or {
	//		errs <- err
	//		return
	//	}
	//	unsafe {
	//		*res = tmp
	//	}
	//	done <- true
	//}(&res1, mut c, done, errs)
	// go fn (res &api.ApiWeek, mut c Client, done chan bool, errs chan IError) {
	//	tmp := c.get[api.ApiWeek]('/api/week/cur') or {
	//		errs <- err
	//		return
	//	}
	//	unsafe {
	//		*res = tmp
	//	}
	//	done <- true
	//}(&res2, mut c, done, errs)
	// mut back := 0
	// for back < 2 {
	//	select {
	//		_ := <-done {
	//			back++
	//		}
	//		e := <-errs {
	//			return e
	//		}
	//	}
	//}

	res1 := c.get[api.ApiPrizeCur]('/api/prize/cur')!
	res2 := c.get[api.ApiWeek]('/api/week/cur')!

	draw_title()
	draw_grand_prize(res1)
	draw_weekly_stars(true, res2)
	draw_server_line(c.host, sw.elapsed().milliseconds())
}
