
import { createContext, useState, useMemo, useContext, useCallback } from 'react';
import { useQuery } from 'react-query';
import { unstable_batchedUpdates } from 'react-dom';
import { sha256 } from 'js-sha256';
import { ApiContext } from '@/contexts/Api';

export const AuthContext = createContext({});

const hostname = process.env.NEXT_PUBLIC_HOSTNAME;

export function AuthProvider( { children } ) {
  const [ loading, setLoading ] = useState( false );
  const [ loggedIn, setLoggedIn ] = useState( false );
  const [ credentials, setCredentials ] = useState( {} );
  const [ error, setError ] = useState();
  const [ sessionTtl, setSessionTtl ] = useState();

  const { api, setSessionId, apiVersion } = useContext( ApiContext );

  const setLoggedInX = ( yes ) => {
    console.log(`SET LOGGED IN ${yes}`);
    setLoggedIn( yes );
  };

  const psk = useMemo( () => {
    return credentials.password? sha256( credentials.password ) : '';
  }, [ credentials.password ] );

  useQuery( {
    queryKey: [ 'auth', credentials.username, psk ],
    enabled: !!credentials.username && !!psk && !error && !sessionTtl,
    retry: false,
    gcTime: Infinity,
    queryFn: () => {
      return api.get( `auth/${credentials.username}` )
        .then( res => {
          const { session_ttl, api_version, challenge } = res.data;
          if( api_version != apiVersion ) {
            throw new Error( 'Server API version mismatch' );
          }
          unstable_batchedUpdates( () => {
            setSessionId( sha256(`${psk}:${res.data.challenge}`) );
            setSessionTtl( session_ttl );
          } );
        } )
        .catch( err => {
          completeLogin( `Error: ${err.message}` );
        } );
    },
  } );

  function beginLogin( username, password ) {
    setLoggedInX( false );
    setLoading( true );
    setCredentials( { username, password } );
    setError( null );
    setSessionTtl( null );
  }

  function completeLogin( error ) {
    console.log( `COMPLETE when LI-${loggedIn} E-${!!error}: ${error}` )
    setError( error );
    setLoggedInX( !error );
    setLoading( false );
    if( error ) setSessionTtl( null );
  }

  const confirmLogout = useCallback( ev => {
    const message = loggedIn?
          'You have been logged out' : 'Bad username or password';
    if( !error ) completeLogin( message );
  }, [ loggedIn, error ] )

  const value = useMemo( () => {
    return {
      loading: loading,
      loggedIn: loggedIn,
      username: credentials.username,
      error: error,
      sessionTtl: sessionTtl,
      login: beginLogin,
      confirmLogin: () => completeLogin(),
      confirmLogout: confirmLogout,
    }
  }, [ loading, loggedIn, credentials.username, error, sessionTtl ] );

  return (
    <AuthContext.Provider value={ value }>
      { children }
    </AuthContext.Provider>
  );
}
