import { createContext, useState, useEffect, useContext, useReducer } from 'react';
import { useQuery } from 'react-query';
import { sha256 } from 'js-sha256';
import { ApiContext } from '@/contexts/Api';

export const AuthContext = createContext( {} );

const hostname = process.env.NEXT_PUBLIC_HOSTNAME;

function stateReducer( state, action ) {
  console.log(action);
  switch( action.type ) {
  case 'login':
    if( !state.loading ) {
      return {
        loading: true,
        loggedIn: false,
        loggedOut: false,
        error: null,
        sessionTtl: null,
        recalled: !!action.recalled,
      };
    }
    break;
  case 'session':
    if( state.loading )
      return { ...state, sessionTtl: action.sessionTtl };
    break;
  case 'confirm':
    if( state.loading )
      return { ...state, loading: false, loggedIn: true };
    break;
  case 'fail':
    const error = action.error ||
      ( !state.loggedIn? 'Bad username or password' : null );
    if( error ) localStorage.removeItem( 'psk' );
    return {
      loading: false,
      loggedIn: false,
      error: error,
      loggedOut: !error,
    };
  case 'logout':
    if( state.loggedIn ) {
      localStorage.removeItem( 'psk' );
      return { ...state, loggedIn: false };
    }
    break;
  }
  return state;
}

export function AuthProvider( { children } ) {
  const [ credentials, setCredentials ] = useState( {} );
  const [ state, stateDispatch ] = useReducer( stateReducer, {
    loading: false,
    loggedIn: false,
    loggedOut: false,
    error: null,
    sessionTtl: null,
    recalled: false,
  } );

  const { api, setSessionId, apiVersion } = useContext( ApiContext );

  useEffect( () => {
    const username = localStorage.getItem( 'username' );
    const psk = localStorage.getItem( 'psk' );
    //console.log( `GOT ${username}:${psk}` );
    if( username && !credentials.username && !credentials.psk &&
        !state.loading && !state.loggedIn && !state.error ) {
      setCredentials( creds => ( { username, psk: psk || creds.psk } ) );
      if( psk ) stateDispatch( { type: 'login' } );
    }
    if( !!username && !!psk && state.loggedOut && !state.error ) {
      setCredentials( creds => ( { username, psk: psk || creds.psk } ) );
      if( psk ) stateDispatch( { type: 'login', recalled: true } );
    }
  }, [ credentials, state ] );

  useQuery( {
    queryKey: [ 'auth', credentials ],
    enabled: !!credentials.psk && state.loading && !state.sessionTtl,
    retry: false,
    gcTime: Infinity,
    queryFn: () => {
      return api.get( `auth/${credentials.username}` )
        .then( res => {
          const { session_ttl, api_version, challenge } = res.data;
          if( api_version != apiVersion )
            throw new Error( 'Server API version mismatch' );
          setSessionId( sha256(`${credentials.psk}:${res.data.challenge}`) );
          stateDispatch( { type: 'session', sessionTtl: session_ttl } );
        } )
        .catch( err => {
          stateDispatch( { type: 'fail', error: `Error: ${err.message}` } );
          localStorage.removeItem( 'psk' );
        } );
    },
  } );

  function beginLogin( username, password, rememberMe ) {
    if( !!username && !!password ) {
      const psk = sha256( password );
      setCredentials( { username, psk } );
      stateDispatch( { type: 'login' } );
      localStorage.setItem( 'username', username );
      if( rememberMe ) localStorage.setItem( 'psk', psk );
    }
  }

  const value = {
    username: credentials.username,
    loading: state.loading,
    loggedIn: state.loggedIn,
    loggedOut: state.loggedOut,
    error: state.error,
    sessionTtl: state.sessionTtl,
    recalled: state.recalled,
    login: beginLogin,
    logout: () => stateDispatch( { type: 'logout' } ),
    confirmLogin: () => stateDispatch( { type: 'confirm' } ),
    confirmLogout: () => stateDispatch( { type: 'fail' } ),
  };

  return (
    <AuthContext.Provider value={ value }>
      { children }
    </AuthContext.Provider>
  );
}
