<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { apiRequest } from '$lib/utils/api';
  import { addAlert } from '$lib/utils/store';

  // Retrieve parameters from URL
  let originalUsername = $state('');
  let isNew = $state(true);

  // Form states
  let username = $state('');
  let password = $state('');
  let admin = $state(false);
  let showPasswordForm = $state(false);
  let saving = $state(false);
  let errorMessage = $state('');

  onMount(() => {
    const queryUsername = $page.url.searchParams.get('username') || '';
    const queryAdmin = $page.url.searchParams.get('admin') === 'true';
    
    if (queryUsername) {
      originalUsername = queryUsername;
      username = queryUsername;
      admin = queryAdmin;
      isNew = false;
      showPasswordForm = false;
    } else {
      isNew = true;
      showPasswordForm = true;
    }
  });

  async function handleSave(e: Event) {
    e.preventDefault();
    if (!username.trim()) {
      errorMessage = 'Username is required';
      return;
    }

    if (isNew && !password) {
      errorMessage = 'Password is required for new users';
      return;
    }

    saving = true;
    errorMessage = '';

    try {
      let res;
      if (isNew) {
        res = await apiRequest('/api/admin/user/new', {
          method: 'POST',
          body: { username, password, admin }
        });
      } else {
        // Send blank password if they choose not to update it
        const updatePass = showPasswordForm ? password : '';
        res = await apiRequest(`/api/admin/user/update/${originalUsername}`, {
          method: 'POST',
          body: { username, password: updatePass, admin }
        });
      }

      if (res.success) {
        addAlert('success', `User ${isNew ? 'created' : 'updated'} successfully.`);
        goto('/admin/user');
      } else {
        errorMessage = res.error || 'Failed to save user details';
      }
    } catch (err: any) {
      errorMessage = err.message || 'Error occurred while saving user';
    } finally {
      saving = false;
    }
  }
</script>

<svelte:head>
  <title>Mango - {isNew ? 'New User' : `Edit User: ${originalUsername}`}</title>
</svelte:head>

<div class="container-small">
  <!-- Breadcrumbs -->
  <nav class="breadcrumbs">
    <a href="/admin">Admin Dashboard</a>
    <i class="fas fa-chevron-right separator"></i>
    <a href="/admin/user">User Management</a>
    <i class="fas fa-chevron-right separator"></i>
    <span class="current">{isNew ? 'New User' : 'Edit User'}</span>
  </nav>

  <div class="edit-header">
    <h2>{isNew ? 'Create New User' : `Edit User: ${originalUsername}`}</h2>
    <p class="text-meta">Specify username, access levels, and credentials</p>
  </div>

  {#if errorMessage}
    <div class="alert alert-error">
      <span>{errorMessage}</span>
    </div>
  {/if}

  <form onsubmit={handleSave} class="user-edit-form">
    <div class="form-group">
      <label class="form-label" for="username">Username</label>
      <input
        id="username"
        type="text"
        class="input"
        placeholder="Enter username"
        bind:value={username}
        disabled={saving}
        required
      />
    </div>

    <div class="form-group">
      <label class="checkbox-group" for="admin-access">
        <input
          id="admin-access"
          type="checkbox"
          class="checkbox"
          bind:checked={admin}
          disabled={saving || (originalUsername === 'admin')}
        />
        <span>Grant Administrative Privileges (Full system access)</span>
      </label>
      {#if originalUsername === 'admin'}
        <span class="field-meta">The default 'admin' account must retain admin access.</span>
      {/if}
    </div>

    {#if isNew}
      <div class="form-group">
        <label class="form-label" for="password">Password</label>
        <input
          id="password"
          type="password"
          class="input"
          placeholder="Enter password"
          bind:value={password}
          disabled={saving}
          required
        />
      </div>
    {:else}
      <div class="password-toggle-zone">
        {#if !showPasswordForm}
          <button 
            type="button" 
            class="btn btn-secondary" 
            onclick={() => showPasswordForm = true}
            disabled={saving}
          >
            <i class="fas fa-key"></i> Change Password
          </button>
        {:else}
          <div class="form-group change-pass-group">
            <div class="change-pass-header">
              <label class="form-label" for="new-password">New Password</label>
              <button 
                type="button" 
                class="cancel-pass-btn" 
                onclick={() => { showPasswordForm = false; password = ''; }}
                disabled={saving}
              >
                Cancel Change
              </button>
            </div>
            <input
              id="new-password"
              type="password"
              class="input"
              placeholder="Enter new password"
              bind:value={password}
              disabled={saving}
              required
            />
          </div>
        {/if}
      </div>
    {/if}

    <hr class="form-divider" />

    <div class="form-actions">
      <a href="/admin/user" class="btn btn-secondary">Cancel</a>
      <button type="submit" class="btn btn-primary" disabled={saving}>
        {#if saving}
          <i class="fas fa-spinner fa-spin"></i> Saving...
        {:else}
          Save User
        {/if}
      </button>
    </div>
  </form>
</div>

<style>
  /* Breadcrumbs */
  .breadcrumbs {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.9rem;
    margin-bottom: 1.5rem;
    color: var(--text-secondary);
  }

  .breadcrumbs a {
    color: var(--text-secondary);
  }

  .breadcrumbs a:hover {
    color: var(--accent);
  }

  .breadcrumbs .separator {
    font-size: 0.7rem;
    color: var(--text-muted);
  }

  .breadcrumbs .current {
    font-weight: 600;
    color: var(--text-primary);
  }

  .edit-header {
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 1.5rem;
    margin-bottom: 2rem;
  }

  .edit-header h2 {
    font-size: 1.75rem;
    font-weight: 750;
  }

  .user-edit-form {
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-md);
    padding: 2rem;
    box-shadow: var(--shadow-sm);
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .field-meta {
    font-size: 0.8rem;
    color: var(--text-muted);
    display: block;
    margin-top: 0.25rem;
  }

  .password-toggle-zone {
    margin-top: 0.5rem;
  }

  .change-pass-group {
    background-color: var(--bg-primary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-sm);
    padding: 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .change-pass-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .cancel-pass-btn {
    background: transparent;
    border: none;
    color: var(--error);
    font-size: 0.85rem;
    font-weight: 500;
    cursor: pointer;
    padding: 0.25rem 0.5rem;
  }

  .cancel-pass-btn:hover {
    text-decoration: underline;
  }

  .form-divider {
    border: none;
    border-top: 1px solid var(--border-color);
    margin: 0.5rem 0;
  }

  .form-actions {
    display: flex;
    justify-content: flex-end;
    gap: 0.75rem;
  }
</style>
