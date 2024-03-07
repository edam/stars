import { useContext } from 'react';
import { AuthContext } from '@/providers/Auth';
import { LoginPage } from './LoginPage';
import { MainPage } from './MainPage';

export function App() {
  const { loggedIn } = useContext( AuthContext );

  return (
    <div className="bg-stone-200 min-h-screen">
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
