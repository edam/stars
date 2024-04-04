import { useContext, useEffect, useCallback } from 'react';
import { ApiContext } from '@/contexts/Api';
import { AuthContext } from '@/contexts/Auth';

export const Ping = ( { interval, children } ) => {
  const { api } = useContext( ApiContext );
  const { confirmLogin, confirmLogout, sessionTtl } = useContext( AuthContext );


  function ping() {
    api.get( 'ping' )
      .then( res => {
        confirmLogin();
      } )
      .catch( err => {
        if( err.response && err.response.status == 401 ) {
          confirmLogout();
        }
      } );
  }

  useEffect(() => {
    if( sessionTtl ) {
      ping();
      const timer = setInterval( ping, ( sessionTtl - 10 ) * 1000 );
      return () => {
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
