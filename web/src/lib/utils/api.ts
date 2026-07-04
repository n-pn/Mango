import { goto } from '$app/navigation';

export interface ApiRequestInit extends Omit<RequestInit, 'body'> {
  body?: any;
}

export async function apiRequest<T = any>(
  path: string,
  options: ApiRequestInit = {}
): Promise<T> {
  const url = path.startsWith('/') ? path : `/${path}`;
  
  // Set JSON headers by default if request has body
  if (options.body && !(options.body instanceof FormData)) {
    options.headers = {
      'Content-Type': 'application/json',
      ...options.headers
    };
    if (typeof options.body === 'object') {
      options.body = JSON.stringify(options.body);
    }
  }

  try {
    const res = await fetch(url, options);
    
    if (res.status === 401) {
      // Session expired or unauthenticated
      goto('/login');
      throw new Error('Unauthorized');
    }
    
    if (!res.ok) {
      let message = `Request failed: ${res.statusText}`;
      try {
        const errJson = await res.json();
        if (errJson && errJson.error) {
          message = errJson.error;
        }
      } catch (e) {
        try {
          const text = await res.text();
          if (text) message = text;
        } catch (_) {}
      }
      throw new Error(message);
    }

    // Check content type before parsing JSON
    const contentType = res.headers.get('content-type');
    if (contentType && contentType.includes('application/json')) {
      return await res.json();
    }
    
    return {} as T;
  } catch (error: any) {
    if (error.message !== 'Unauthorized') {
      console.error(`API Error on ${url}:`, error);
    }
    throw error;
  }
}

export function getCoverUrl(tid: string, eid: string): string {
  return `/api/cover/${tid}/${eid}`;
}

export function getPageUrl(tid: string, eid: string, page: number): string {
  return `/api/page/${tid}/${eid}/${page}`;
}
