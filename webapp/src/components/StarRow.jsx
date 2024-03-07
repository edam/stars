export const StarRow = props => {
	const {
		children,
	} = props;
	
	const style = {
		border: "1px black solid",
		display: "flex",
	};

	return (
		<div style={ style }>
			{ children }
		</div>
	);
};
