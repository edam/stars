import { useContext } from 'react';
import { AuthContext } from '@/providers/Auth';
import { LoginPage } from './LoginPage';
import { MainPage } from './MainPage';

export function App() {
  const { loggedIn } = useContext( AuthContext );

  return (
    <div>
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
