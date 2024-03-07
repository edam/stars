import { AuthProvider } from '@/providers/Auth';
import { App } from '@/pages/App';

export default function Index() {
	return (
	  <AuthProvider>
        <App />
	  </AuthProvider>
	);
}
