<script lang="ts">
  import { onMount } from 'svelte';
  import { apiRequest } from '$lib/utils/api';
  import { addAlert } from '$lib/utils/store';

  interface MangaPlugin {
    id: string;
    title: string;
    description?: string;
  }

  interface SubscriptionFilter {
    key: string;
    type: string;
    value: string | number;
  }

  interface MangaSubscription {
    id: string;
    plugin_id: string;
    manga_id: string;
    manga_title: string;
    name: string;
    created_at: number;
    last_checked: number;
    filters?: SubscriptionFilter[];
  }

  let loading = $state(true);
  let actionLoading = $state(false);
  let plugins = $state<MangaPlugin[]>([]);
  let selectedPid = $state('');
  let subscriptions = $state<MangaSubscription[]>([]);

  // Modal details
  let selectedSub = $state<MangaSubscription | null>(null);
  let showModal = $state(false);

  onMount(async () => {
    await loadPlugins();
  });

  async function loadPlugins() {
    loading = true;
    try {
      const data = await apiRequest('/api/admin/plugin');
      if (data && data.success) {
        plugins = data.plugins || [];
        
        // Retrieve last active plugin selection from localStorage
        const savedPid = localStorage.getItem('active_plugin_id');
        if (savedPid && plugins.some(p => p.id === savedPid)) {
          selectedPid = savedPid;
        } else if (plugins.length > 0) {
          selectedPid = plugins[0].id;
        }
        
        if (selectedPid) {
          await loadSubscriptions(selectedPid);
        }
      } else {
        addAlert('error', data.error || 'Failed to list plugins.');
      }
    } catch (e: any) {
      addAlert('error', e.message || 'Error loading plugins.');
    } finally {
      loading = false;
    }
  }

  async function loadSubscriptions(pid: string) {
    if (!pid) return;
    try {
      const data = await apiRequest(`/api/admin/plugin/subscriptions?plugin=${encodeURIComponent(pid)}`);
      if (data && data.success) {
        subscriptions = data.subscriptions || [];
      } else {
        addAlert('error', data.error || 'Failed to load subscriptions.');
      }
    } catch (e: any) {
      addAlert('error', e.message || 'Error loading subscriptions.');
    }
  }

  async function handlePluginChange() {
    localStorage.setItem('active_plugin_id', selectedPid);
    await loadSubscriptions(selectedPid);
  }

  async function deleteSubscription(subId: string) {
    const confirm = window.confirm('Are you sure you want to delete this subscription? This action cannot be undone.');
    if (!confirm) return;

    actionLoading = true;
    try {
      const res = await apiRequest(`/api/admin/plugin/subscriptions?plugin=${encodeURIComponent(selectedPid)}&subscription=${encodeURIComponent(subId)}`, {
        method: 'DELETE'
      });

      if (res.success) {
        addAlert('success', 'Subscription deleted successfully.');
        await loadSubscriptions(selectedPid);
      } else {
        addAlert('error', res.error || 'Failed to delete subscription.');
      }
    } catch (e: any) {
      addAlert('error', e.message || 'Error deleting subscription.');
    } finally {
      actionLoading = false;
    }
  }

  async function checkUpdates(subId: string) {
    actionLoading = true;
    try {
      const res = await apiRequest(`/api/admin/plugin/subscriptions/update?plugin=${encodeURIComponent(selectedPid)}&subscription=${encodeURIComponent(subId)}`, {
        method: 'POST'
      });

      if (res.success) {
        addAlert('success', `Checking updates for subscription "${subId}". Logs will update in background.`);
        await loadSubscriptions(selectedPid);
      } else {
        addAlert('error', res.error || 'Failed to trigger check.');
      }
    } catch (e: any) {
      addAlert('error', e.message || 'Error updating subscription.');
    } finally {
      actionLoading = false;
    }
  }

  function openDetails(sub: MangaSubscription) {
    selectedSub = sub;
    showModal = true;
  }

  function formatTime(timestamp: number): string {
    if (!timestamp) return 'Never';
    // Timestamp from backend is in seconds
    const date = new Date(timestamp * 1000);
    return date.toLocaleString();
  }

  function formatFilterType(type: string): string {
    switch (type) {
      case 'number-min': return 'Minimum Number';
      case 'number-max': return 'Maximum Number';
      case 'date-min': return 'Minimum Date';
      case 'date-max': return 'Maximum Date';
      default: return type;
    }
  }

  function formatFilterValue(type: string, val: any): string {
    if (type.startsWith('date') && val) {
      const d = new Date(Number(val));
      return d.toLocaleDateString();
    }
    return String(val);
  }
</script>

<svelte:head>
  <title>Mango - Subscriptions</title>
</svelte:head>

<div class="container">
  <!-- Breadcrumbs -->
  <nav class="breadcrumbs">
    <a href="/admin">Admin Dashboard</a>
    <i class="fas fa-chevron-right separator"></i>
    <span class="current">Subscription Manager</span>
  </nav>

  <div class="subs-header">
    <div class="title-section">
      <h2>Subscription Manager</h2>
      <p class="text-meta">Manage scheduled automatic plugin downloads and updates</p>
    </div>
  </div>

  {#if loading}
    <div class="loading-state">
      <i class="fas fa-circle-notch fa-spin fa-3x"></i>
      <p>Loading plugin metadata...</p>
    </div>
  {:else if plugins.length === 0}
    <div class="empty-state text-center">
      <i class="fas fa-plug empty-icon"></i>
      <h3>No plugins found</h3>
      <p>Please place plugin files in your server's plugin folder to configure subscriptions.</p>
      <a href="https://github.com/hkalexling/mango-plugins" target="_blank" class="btn btn-primary margin-top">
        Browse Official Plugins
      </a>
    </div>
  {:else}
    <div class="plugin-selector-card">
      <div class="form-group">
        <label class="form-label" for="plugin-select">Select Active Plugin</label>
        <select 
          id="plugin-select" 
          class="select plugin-dropdown" 
          bind:value={selectedPid} 
          onchange={handlePluginChange}
        >
          {#each plugins as p}
            <option value={p.id}>{p.title} ({p.id})</option>
          {/each}
        </select>
      </div>
    </div>

    <div class="subs-section margin-top">
      {#if subscriptions.length === 0}
        <div class="empty-state text-center">
          <i class="fas fa-rss empty-icon"></i>
          <h3>No subscriptions found</h3>
          <p>Subscribe to manga feeds within plugin screens to auto-download chapters.</p>
        </div>
      {:else}
        <div class="table-container">
          <table class="subs-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Manga Title</th>
                <th>Created At</th>
                <th>Last Checked</th>
                <th class="actions-column">Actions</th>
              </tr>
            </thead>
            <tbody>
              {#each subscriptions as sub (sub.id)}
                <!-- svelte-ignore a11y_click_events_have_key_events -->
                <!-- svelte-ignore a11y_no_static_element_interactions -->
                <tr onclick={() => openDetails(sub)} class="clickable-row">
                  <td class="bold-cell">{sub.name}</td>
                  <td>{sub.manga_title}</td>
                  <td class="time-cell">{formatTime(sub.created_at)}</td>
                  <td class="time-cell">{formatTime(sub.last_checked)}</td>
                  <td class="actions-cell">
                    <button 
                      class="action-icon-btn check" 
                      onclick={(e) => { e.stopPropagation(); checkUpdates(sub.id); }}
                      disabled={actionLoading}
                      title="Check updates"
                    >
                      <i class="fas fa-sync"></i>
                    </button>
                    <button 
                      class="action-icon-btn delete" 
                      onclick={(e) => { e.stopPropagation(); deleteSubscription(sub.id); }}
                      disabled={actionLoading}
                      title="Delete subscription"
                    >
                      <i class="fas fa-trash-alt"></i>
                    </button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {/if}
    </div>
  {/if}
</div>

<!-- Details Modal -->
{#if showModal && selectedSub}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="modal-overlay" onclick={() => showModal = false}>
    <div class="modal-content" onclick={e => e.stopPropagation()}>
      <div class="modal-header">
        <h3 class="modal-title">Subscription Details</h3>
        <button class="modal-close" onclick={() => showModal = false}>&times;</button>
      </div>
      <div class="modal-body">
        <dl class="details-list">
          <div class="detail-item">
            <dt>Name</dt>
            <dd>{selectedSub.name}</dd>
          </div>
          <div class="detail-item">
            <dt>Subscription ID</dt>
            <dd><code>{selectedSub.id}</code></dd>
          </div>
          <div class="detail-item">
            <dt>Plugin ID</dt>
            <dd><code>{selectedSub.plugin_id}</code></dd>
          </div>
          <div class="detail-item">
            <dt>Manga Title</dt>
            <dd>{selectedSub.manga_title}</dd>
          </div>
          <div class="detail-item">
            <dt>Manga ID</dt>
            <dd><code>{selectedSub.manga_id}</code></dd>
          </div>
        </dl>

        {#if selectedSub.filters && selectedSub.filters.length > 0}
          <h4 class="section-subtitle margin-top">Filters</h4>
          <div class="table-container mini">
            <table class="filters-table">
              <thead>
                <tr>
                  <th>Key</th>
                  <th>Type</th>
                  <th>Value</th>
                </tr>
              </thead>
              <tbody>
                {#each selectedSub.filters as f}
                  <tr>
                    <td><code>{f.key}</code></td>
                    <td>{formatFilterType(f.type)}</td>
                    <td>{formatFilterValue(f.type, f.value)}</td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" onclick={() => showModal = false}>OK</button>
      </div>
    </div>
  </div>
{/if}

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

  .subs-header {
    margin-bottom: 2rem;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 1.5rem;
  }

  .title-section h2 {
    font-size: 1.75rem;
    font-weight: 750;
  }

  .plugin-selector-card {
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-md);
    padding: 1.5rem;
    box-shadow: var(--shadow-sm);
  }

  .plugin-selector-card .form-group {
    margin-bottom: 0;
  }

  .plugin-dropdown {
    max-width: 400px;
  }

  .table-container {
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-md);
    box-shadow: var(--shadow-sm);
    overflow: hidden;
  }

  .subs-table {
    width: 100%;
    border-collapse: collapse;
    text-align: left;
    font-size: 0.9rem;
  }

  .subs-table th, .subs-table td {
    padding: 1.1rem 1.25rem;
    border-bottom: 1px solid var(--border-color);
  }

  .subs-table tr:last-child td {
    border-bottom: none;
  }

  .subs-table th {
    font-family: var(--font-title);
    font-weight: 600;
    color: var(--text-secondary);
    background-color: rgba(0, 0, 0, 0.02);
  }

  :global(html.dark) .subs-table th {
    background-color: rgba(255, 255, 255, 0.02);
  }

  .clickable-row {
    cursor: pointer;
    transition: background-color 0.15s ease;
  }

  .clickable-row:hover {
    background-color: var(--bg-tertiary);
  }

  .bold-cell {
    font-weight: 600;
  }

  .time-cell {
    color: var(--text-secondary);
    font-size: 0.85rem;
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

  /* Details list style inside modal */
  .details-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .detail-item {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .detail-item dt {
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--text-muted);
    font-weight: 600;
  }

  .detail-item dd {
    font-size: 0.95rem;
    color: var(--text-primary);
  }

  .section-subtitle {
    font-family: var(--font-title);
    font-size: 1.05rem;
    font-weight: 600;
    color: var(--text-primary);
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 0.25rem;
  }

  .filters-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.85rem;
    text-align: left;
  }

  .filters-table th, .filters-table td {
    padding: 0.625rem 0.875rem;
    border-bottom: 1px solid var(--border-color);
  }

  .filters-table th {
    background-color: var(--bg-tertiary);
    color: var(--text-secondary);
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
    max-width: 500px;
    margin: 2rem auto;
  }

  .empty-icon {
    font-size: 3rem;
    color: var(--text-muted);
    margin-bottom: 1rem;
  }
</style>
