import { createContext, useState, useMemo } from 'react';
import axios from 'axios';

export const ApiContext = createContext( {} );

const hostname = process.env.NEXT_PUBLIC_HOSTNAME;

const apiVersion = 4;

export function ApiProvider( { children } ) {
  const [ sessionId, setSessionId ] = useState();

  const api = useMemo( () => {
    return axios.create( {
      baseURL: `http://${hostname}/api`,
      headers: sessionId? { 'X-Stars-Auth': sessionId } : {},
    } );
  }, [ sessionId ] );

  const value = {
    api: api,
    apiVersion: apiVersion,
    setSessionId: setSessionId,
  };

  return (
    <ApiContext.Provider value={ value }>
      { children }
    </ApiContext.Provider>
  );
}
