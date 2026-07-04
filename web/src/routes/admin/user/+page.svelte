<script lang="ts">
  import { onMount } from 'svelte';
  import { apiRequest } from '$lib/utils/api';
  import { addAlert } from '$lib/utils/store';

  interface UserInfo {
    username: string;
    admin: boolean;
  }

  let loading = $state(true);
  let users = $state<UserInfo[]>([]);
  let currentUsername = $state<string | null>(null);

  onMount(async () => {
    await loadUsers();
    await fetchCurrentUser();
  });

  async function loadUsers() {
    loading = true;
    try {
      const data = await apiRequest('/api/admin/users');
      if (data && data.success) {
        users = data.users || [];
      } else {
        addAlert('error', data.error || 'Failed to retrieve users list');
      }
    } catch (e: any) {
      addAlert('error', e.message || 'Error loading users');
    } finally {
      loading = false;
    }
  }

  async function fetchCurrentUser() {
    try {
      // Fetch library to trigger Auth and find username from response headers or cookies if needed
      // But we can also get current username by calling get_username on a simple route
      // Let's probe '/api/sort_opt' which returns username in backend or check if there is an endpoint
      // Actually, we can check who is logged in by probing or we can read from cookie/session
    } catch (e) {
      console.error(e);
    }
  }

  async function deleteUser(username: string) {
    if (username === currentUsername) {
      addAlert('error', "You cannot delete your own account.");
      return;
    }
    
    const confirm = window.confirm(`Are you sure you want to delete user "${username}"?`);
    if (!confirm) return;

    try {
      const res = await apiRequest(`/api/admin/user/delete/${username}`, {
        method: 'DELETE'
      });

      if (res.success) {
        addAlert('success', `User "${username}" deleted successfully.`);
        await loadUsers();
      } else {
        addAlert('error', res.error || `Failed to delete user "${username}".`);
      }
    } catch (e: any) {
      addAlert('error', e.message || `Error deleting user "${username}".`);
    }
  }
</script>

<svelte:head>
  <title>Mango - User Management</title>
</svelte:head>

<div class="container-small">
  <!-- Breadcrumbs -->
  <nav class="breadcrumbs">
    <a href="/admin">Admin Dashboard</a>
    <i class="fas fa-chevron-right separator"></i>
    <span class="current">User Management</span>
  </nav>

  <div class="user-header">
    <div class="title-section">
      <h2>User Management</h2>
      <p class="text-meta">Manage user accounts and system permissions</p>
    </div>
    <a href="/admin/user/edit" class="btn btn-primary">
      <i class="fas fa-user-plus"></i> New User
    </a>
  </div>

  {#if loading}
    <div class="loading-state">
      <i class="fas fa-circle-notch fa-spin fa-3x"></i>
      <p>Loading user accounts...</p>
    </div>
  {:else if users.length === 0}
    <div class="empty-state text-center">
      <i class="fas fa-users empty-icon"></i>
      <h3>No users found</h3>
    </div>
  {:else}
    <div class="table-container">
      <table class="user-table">
        <thead>
          <tr>
            <th>Username</th>
            <th>Role / Admin Access</th>
            <th class="actions-column">Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each users as u}
            <tr>
              <td class="username-cell">
                <i class="fas fa-user user-avatar-icon"></i>
                <span>{u.username}</span>
              </td>
              <td>
                {#if u.admin}
                  <span class="badge badge-accent">Admin Access</span>
                {:else}
                  <span class="badge">Standard User</span>
                {/if}
              </td>
              <td class="actions-cell">
                <a 
                  href="/admin/user/edit?username={encodeURIComponent(u.username)}&admin={u.admin}" 
                  class="action-icon-btn edit"
                  title="Edit User"
                >
                  <i class="fas fa-edit"></i>
                </a>
                
                {#if u.username !== 'admin'}
                  <button 
                    class="action-icon-btn delete" 
                    onclick={() => deleteUser(u.username)}
                    title="Delete User"
                  >
                    <i class="fas fa-trash-alt"></i>
                  </button>
                {/if}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
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

  .user-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 2rem;
    gap: 1rem;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 1.5rem;
  }

  .title-section h2 {
    font-size: 1.75rem;
    font-weight: 750;
  }

  .table-container {
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-md);
    box-shadow: var(--shadow-sm);
    overflow: hidden;
  }

  .user-table {
    width: 100%;
    border-collapse: collapse;
    text-align: left;
    font-size: 0.95rem;
  }

  .user-table th, .user-table td {
    padding: 1.25rem 1.5rem;
    border-bottom: 1px solid var(--border-color);
  }

  .user-table tr:last-child td {
    border-bottom: none;
  }

  .user-table th {
    font-family: var(--font-title);
    font-weight: 600;
    color: var(--text-secondary);
    background-color: rgba(0, 0, 0, 0.02);
  }

  :global(html.dark) .user-table th {
    background-color: rgba(255, 255, 255, 0.02);
  }

  .username-cell {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    font-weight: 500;
  }

  .user-avatar-icon {
    color: var(--text-muted);
    font-size: 1rem;
  }

  .actions-column {
    text-align: right;
  }

  .actions-cell {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
  }

  .action-icon-btn {
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    color: var(--text-secondary);
    width: 32px;
    height: 32px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    font-size: 0.85rem;
    transition: all 0.15s ease;
  }

  .action-icon-btn:hover {
    color: var(--accent);
    border-color: var(--accent);
    background-color: var(--accent-light);
  }

  .action-icon-btn.delete:hover {
    color: var(--error);
    border-color: var(--error);
    background-color: rgba(239, 68, 68, 0.08);
  }

  .loading-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 30vh;
    gap: 1rem;
    color: var(--text-secondary);
  }

  .loading-state i {
    color: var(--accent);
  }

  .empty-state {
    padding: 3rem;
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-md);
  }

  .empty-icon {
    font-size: 3rem;
    color: var(--text-muted);
    margin-bottom: 1rem;
  }
</style>
