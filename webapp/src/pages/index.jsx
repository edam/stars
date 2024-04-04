import { ApiProvider } from '@/contexts/Api';
import { AuthProvider } from '@/contexts/Auth';
import { QueryProvider } from '@/contexts/Query';
import { App } from '@/pages/App';

export default function Index() {
  return (
    <ApiProvider>
      <QueryProvider>
	    <AuthProvider>
          <App />
	    </AuthProvider>
      </QueryProvider>
    </ApiProvider>
  );
}
