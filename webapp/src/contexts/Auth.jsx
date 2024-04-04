import { createContext, useState, useMemo, useContext, useReducer } from 'react';
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
        error: null,
        sessionTtl: null,
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
    return {
      loading: false,
      loggedIn: false,
      error: action.error || state.loggedIn?
        'You have been logged out' : 'Bad username or password',
      sessionTtl: null,
    };
  case 'logout':
    if( state.loggedIn )
      return { ...state, loggedIn: false, sessionTtl: null };
    break;
  }
  return state;
}

export function AuthProvider( { children } ) {
  const [ credentials, setCredentials ] = useState( {} );
  const [ state, stateDispatch ] = useReducer( stateReducer, {
    loading: false,
    loggedIn: false,
    error: null,
    sessionTtl: null,
  } );

  const { api, setSessionId, apiVersion } = useContext( ApiContext );

  const psk = useMemo( () => {
    return credentials.password? sha256( credentials.password ) : null;
  }, [ credentials ] );

  useQuery( {
    queryKey: [ 'auth', credentials.username, psk ],
    enabled: !!psk && state.loading && !state.sessionTtl,
    retry: false,
    gcTime: Infinity,
    queryFn: () => {
      return api.get( `auth/${credentials.username}` )
        .then( res => {
          const { session_ttl, api_version, challenge } = res.data;
          if( api_version != apiVersion )
            throw new Error( 'Server API version mismatch' );
          setSessionId( sha256(`${psk}:${res.data.challenge}`) );
          stateDispatch( { type: 'session', sessionTtl: session_ttl } );
        } )
        .catch( err => {
          stateDispatch( { type: 'fail', error: `Error: ${err.message}` } );
        } );
    },
  } );

  function beginLogin( username, password ) {
    setCredentials( { username, password } );
    stateDispatch( { type: 'login' } );
  }

  const value = {
    loading: state.loading,
    loggedIn: state.loggedIn,
    username: credentials.username,
    error: state.error,
    sessionTtl: state.sessionTtl,
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
