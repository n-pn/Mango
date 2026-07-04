<script lang="ts">
  import { apiRequest } from '$lib/utils/api';
  import { appState, addAlert } from '$lib/utils/store.svelte';
  import { goto } from '$app/navigation';

  let username = $state('');
  let password = $state('');
  let loading = $state(false);
  let errorMessage = $state('');

  async function handleLogin(e: Event) {
    e.preventDefault();
    if (!username || !password) {
      errorMessage = 'Please enter both username and password';
      return;
    }

    loading = true;
    errorMessage = '';

    try {
      const data = await apiRequest('/api/login', {
        method: 'POST',
        body: { username, password }
      });

      if (data.success) {
        appState.isAdmin = !!data.is_admin;
        addAlert('success', 'Logged in successfully!');
        
        // Redirect to home or callback
        goto('/');
      } else {
        errorMessage = data.error || 'Invalid credentials';
      }
    } catch (err: any) {
      errorMessage = err.message || 'An error occurred during login. Please try again.';
    } finally {
      loading = false;
    }
  }
</script>

<svelte:head>
  <title>Mango - Log In</title>
</svelte:head>

<div class="login-wrapper">
  <div class="login-card">
    <div class="login-header">
      <img src="/img/icons/icon.png" alt="Mango Logo" class="login-logo" />
      <h2>Welcome to Mango</h2>
      <p>Please enter your credentials to log in</p>
    </div>

    {#if errorMessage}
      <div class="login-error">
        <i class="fas fa-exclamation-circle"></i> {errorMessage}
      </div>
    {/if}

    <form onsubmit={handleLogin} class="login-form">
      <div class="form-group">
        <label class="form-label" for="username">Username</label>
        <div class="input-icon-wrapper">
          <i class="fas fa-user input-icon"></i>
          <input
            id="username"
            class="input with-icon"
            type="text"
            placeholder="Enter username"
            bind:value={username}
            disabled={loading}
            required
          />
        </div>
      </div>

      <div class="form-group">
        <label class="form-label" for="password">Password</label>
        <div class="input-icon-wrapper">
          <i class="fas fa-lock input-icon"></i>
          <input
            id="password"
            class="input with-icon"
            type="password"
            placeholder="Enter password"
            bind:value={password}
            disabled={loading}
            required
          />
        </div>
      </div>

      <button type="submit" class="btn btn-primary login-btn" disabled={loading}>
        {#if loading}
          <i class="fas fa-spinner fa-spin"></i> Logging in...
        {:else}
          Log In
        {/if}
      </button>
    </form>
  </div>
</div>

<style>
  .login-wrapper {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: var(--bg-primary);
    padding: 1.5rem;
    transition: background-color var(--transition-speed) ease;
  }

  .login-card {
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-lg);
    box-shadow: var(--shadow-lg);
    width: 100%;
    max-width: 400px;
    padding: 2.5rem 2rem;
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .login-header {
    text-align: center;
  }

  .login-logo {
    height: 72px;
    width: 72px;
    margin-bottom: 1rem;
  }

  .login-header h2 {
    font-family: var(--font-title);
    font-weight: 800;
    font-size: 1.5rem;
    margin-bottom: 0.25rem;
  }

  .login-header p {
    font-size: 0.875rem;
    color: var(--text-secondary);
  }

  .login-error {
    background-color: rgba(239, 68, 68, 0.1);
    border: 1px solid rgba(239, 68, 68, 0.2);
    color: var(--error);
    padding: 0.75rem 1rem;
    border-radius: var(--border-radius-sm);
    font-size: 0.875rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .login-form {
    display: flex;
    flex-direction: column;
  }

  .input-icon-wrapper {
    position: relative;
    width: 100%;
  }

  .input-icon {
    position: absolute;
    left: 0.875rem;
    top: 50%;
    transform: translateY(-50%);
    color: var(--text-muted);
  }

  .input.with-icon {
    padding-left: 2.25rem;
  }

  .login-btn {
    margin-top: 1rem;
    padding: 0.75rem;
    font-size: 1rem;
  }
</style>
