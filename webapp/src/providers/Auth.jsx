import { createContext, useState } from 'react';

export const AuthContext = createContext({});

export function AuthProvider({ children }) {

  const value = {
    loading: false,
    loggedIn: false,
    username: '',
  };

  return (
    <AuthContext.Provider value={ value }>
      { children }
    </AuthContext.Provider>
  );
}
