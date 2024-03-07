import { Star } from "@/components/Star";
import { StarRow } from "@/components/StarRow";

export function MainPage() {
	return (
	  <>
		<div>
		  <h1>Daily-ARSE-Stars!</h1>
		  <h3> sorry he has toretts</h3>
		</div>
		<StarRow>
		  <Star got={ true } />
		  <Star got={ false } />
		  <Star unknown={ true } />
		  <Star unknown={ true } />
		  <Star unknown={ true } />
		</StarRow>
	  </>
	);
}
