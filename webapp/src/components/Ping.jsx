import { useContext, useEffect, useCallback } from 'react';
import { ApiContext } from '@/contexts/Api';
import { AuthContext } from '@/contexts/Auth';

export const Ping = ( { interval, children } ) => {
  const { api } = useContext( ApiContext );
  const { confirmLogin, confirmLogout, sessionTtl } = useContext( AuthContext );


  const ping = useCallback( () => {
    api.get( 'ping' )
      .then( res => {
        confirmLogin();
      } )
      .catch( err => {
        if( err.response && err.response.status == 401 ) {
          confirmLogout();
        }
      } );
  }, [ confirmLogin, confirmLogout ] );

  useEffect(() => {
    if( sessionTtl ) {
      console.log(`MOUNT ${sessionTtl}`);
      ping();
      const timer = setInterval( ping, ( sessionTtl + 1 ) * 1000 );
      return () => {
        console.log("UNMOUNT");
        clearInterval( timer );
      }
    }
  }, [ sessionTtl ]);

  return (
    <>
      { children }
    </>
  );
}
