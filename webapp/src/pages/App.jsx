import { useContext } from 'react';
import { AuthContext } from '@/contexts/Auth';
import { LoginPage } from './LoginPage';
import { MainPage } from './MainPage';
import { Ping } from  '@/components/Ping';

export function App() {
  const { loggedIn, loading, sessionTtl } = useContext( AuthContext );

  const ping = loggedIn || ( loading && sessionTtl );
  return (
    <div>
      { ping && <Ping internval={ sessionTtl } /> }
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
