import { createContext, useState, useMemo } from 'react';
import { useQuery } from 'react-query';
import { unstable_batchedUpdates } from 'react-dom';
import { sha256 } from 'js-sha256';

export const AuthContext = createContext({});

const hostname = process.env.NEXT_PUBLIC_HOSTNAME;

export function AuthProvider( { children } ) {
  const [ credentials, setCredentials ] = useState( {} );
  const [ remember, setRemember ] = useState( false );
  const [ loggedIn, setLoggedIn ] = useState( false );
  const [ authInfo, setAuthInfo ] = useState( {} );
  const [ authError, setAuthError ] = useState();
  const [ attempt, setAttempt ] = useState( 0 );

  const psk = useMemo( () => {
    return credentials.password? sha256(credentials.password) : '';
  }, [ credentials ] );

  const {
    isLoading: authLoading,
  } = useQuery( {
    queryKey: [ 'auth', credentials.username, psk, attempt ],
    enabled: !!credentials.username && !!psk && !authError,
    retry: false,
    gcTime: Infinity,
    queryFn: () => {
      return fetch( `http://${hostname}/api/auth/${credentials.username}` )
        .then( res => {
          if( !res.ok ) {
            throw new Error( `${res.status} ${res.statusText}` );
          }
          return res.json();
        } )
        .then( data => {
          const { session_ttl: sessionTtl, api_version: apiVersion, challenge } = data;
          setAuthInfo( { sessionTtl, apiVersion, challenge } );
        } )
        .catch( err => {
          setAuthError( `${err}` );
        } );
    },
  } );

  const {
    isLoading: pingLoading,
  } = useQuery( {
    queryKey: [ 'authPing', psk, authInfo.challenge ],
    enabled: !!authInfo.challenge && !authError,
    retry: false,
    queryFn: () => {
	  const authResp = sha256(`${psk}:${authInfo.challenge}`)
      return fetch( `http://${hostname}/api/ping`, {
        headers: {
          "X-Stars-Auth": `${authResp}`,
        } } )
        .then( res => {
          if( !res.ok ) {
            if( res.status == 401 && !loggedIn ) {
              throw "Bad username or password";
            } else {
              throw new Error( `${res.status} ${res.statusText}` );
            }
          }
          return res.json();
        } )
        .then( data => {
          setLoggedIn( true );
        } )
        .catch( err => {
          setAuthError( `${err}` );
        } );
    },
  } )

  const value = {
    loading: authLoading || ( !loggedIn && pingLoading ), // logging in
    loggedIn: loggedIn,
    username: credentials.username,
    authError: authError,
    login: ( username, password, remember ) => {
      unstable_batchedUpdates( () => {
        setAttempt( attempt + 1 )
        setRemember( remember );
        setLoggedIn( false );
        setAuthInfo( {} );
        setAuthError( null );
        setCredentials( {
          username: username,
          password: password,
        });
      } )
    },
  };

  return (
    <AuthContext.Provider value={ value }>
      { children }
    </AuthContext.Provider>
  );
}
