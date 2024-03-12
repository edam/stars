import { AuthProvider } from '@/providers/Auth';
import { QueryProvider } from '@/providers/Query';
import { App } from '@/pages/App';

export default function Index() {
	return (
      <QueryProvider>
	    <AuthProvider>
          <App />
	    </AuthProvider>
      </QueryProvider>
	);
}
