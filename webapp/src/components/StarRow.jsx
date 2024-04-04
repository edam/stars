export function StarRow( { children } ) {

  const style = {
	border: "1px black solid",
	display: "flex",
  };

  return (
	<div style={ style }>
	  { children }
	</div>
  );
}
