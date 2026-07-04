export interface AlertMessage {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info';
  text: string;
}

class AppState {
  theme = $state<'light' | 'dark' | 'system'>('system');
  alerts = $state<AlertMessage[]>([]);
  isAdmin = $state<boolean>(false);

  addAlert = (type: AlertMessage['type'], text: string, duration = 6000) => {
    const id = Math.random().toString(36).substring(2, 9);
    this.alerts = [...this.alerts, { id, type, text }];
    
    if (duration > 0) {
      setTimeout(() => {
        this.removeAlert(id);
      }, duration);
    }
  };

  removeAlert = (id: string) => {
    this.alerts = this.alerts.filter(a => a.id !== id);
  };
}

export const appState = new AppState();

// Helper functions for easy import/backwards compatibility
export function addAlert(type: AlertMessage['type'], text: string, duration = 6000) {
  appState.addAlert(type, text, duration);
}

export function removeAlert(id: string) {
  appState.removeAlert(id);
}
