import { useContext } from 'react';
import { AuthContext } from '@/contexts/Auth';
import { LoginPage } from './LoginPage';
import { MainPage } from './MainPage';
import { Ping } from  '@/components/Ping';

export function App() {
  const { loggedIn, sessionTtl } = useContext( AuthContext );

  return (
    <div>
      { sessionTtl && <Ping internval={ sessionTtl } /> }
      {
        loggedIn? (
          <MainPage />
        ) : (
          <LoginPage />
        )
      }
    </div>
  )
}
