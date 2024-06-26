import { StarRow } from "./StarRow";

export const Star = props => {
	const {
		got,
		unknown,
	} = props;

	const star = unknown? "☆" : got? "★" : "✘";
	const style = {
		border: "1px red dashed",
	};

	return (
		<div style={ style }>
			<h1>{ star }</h1>
		</div>
	);
};
