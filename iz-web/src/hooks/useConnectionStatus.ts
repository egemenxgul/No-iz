'use client';
import { useEffect, useState } from 'react';
import { wsManager } from '@/lib/websocket';

export type ConnectionStatus = 'connected' | 'disconnected' | 'reconnecting';

export function useConnectionStatus(): ConnectionStatus {
  const [status, setStatus] = useState<ConnectionStatus>(
    wsManager.isConnected() ? 'connected' : 'disconnected'
  );

  useEffect(() => {
    const offConnected = wsManager.on('__connected', () => setStatus('connected'));
    const offDisconnected = wsManager.on('__disconnected', () => {
      // Give a short grace period before marking as "reconnecting"
      // so brief drops don't flash the banner
      setTimeout(() => {
        if (!wsManager.isConnected()) setStatus('reconnecting');
      }, 2000);
    });

    return () => {
      offConnected();
      offDisconnected();
    };
  }, []);

  return status;
}
