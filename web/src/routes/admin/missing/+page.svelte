<script lang="ts">
  import { onMount } from 'svelte';
  import { apiRequest } from '$lib/utils/api';
  import { addAlert } from '$lib/utils/store.svelte';

  interface MissingItem {
    id: string;
    path: string;
    signature?: string;
  }

  let loading = $state(true);
  let titles = $state<MissingItem[]>([]);
  let entries = $state<MissingItem[]>([]);
  const empty = $derived(titles.length === 0 && entries.length === 0);

  onMount(async () => {
    await loadMissingItems();
  });

  async function loadMissingItems() {
    loading = true;
    try {
      const [titleData, entryData] = await Promise.all([
        apiRequest('/api/admin/titles/missing'),
        apiRequest('/api/admin/entries/missing')
      ]);

      // Wait, let's make sure the response format matches (either direct array or wrapper object)
      // The old JS says: `this.titles = data.titles` and `this.entries = data.entries`
      titles = Array.isArray(titleData) ? titleData : (titleData.titles || []);
      entries = Array.isArray(entryData) ? entryData : (entryData.entries || []);
    } catch (e: any) {
      console.error(e);
      addAlert('error', e.message || 'Failed to load missing items');
    } finally {
      loading = false;
    }
  }

  async function removeSingle(type: 'title' | 'entry', id: string, path: string) {
    const confirm = window.confirm(`Remove metadata for missing ${type} at path "${path}"?`);
    if (!confirm) return;

    try {
      const url = `/api/admin/${type === 'title' ? 'titles' : 'entries'}/missing/${id}`;
      const res = await apiRequest(url, { method: 'DELETE' });
      
      if (res.success || !res.error) {
        addAlert('success', `Metadata removed successfully.`);
        await loadMissingItems();
      } else {
        addAlert('error', res.error || 'Failed to remove metadata.');
      }
    } catch (e: any) {
      addAlert('error', e.message || 'Error removing item.');
    }
  }

  async function removeAll() {
    const confirm = window.confirm(
      'Are you sure? All metadata associated with these items, including their tags and thumbnails, will be deleted from the database.'
    );
    if (!confirm) return;

    try {
      // Delete all titles and entries
      await apiRequest('/api/admin/titles/missing', { method: 'DELETE' });
      await apiRequest('/api/admin/entries/missing', { method: 'DELETE' });
      
      addAlert('success', 'Successfully cleaned all missing items.');
      await loadMissingItems();
    } catch (e: any) {
      addAlert('error', e.message || 'Error cleaning missing items.');
    }
  }
</script>

<svelte:head>
  <title>Mango - Missing Items</title>
</svelte:head>

<div class="container">
  <!-- Breadcrumbs -->
  <nav class="breadcrumbs">
    <a href="/admin">Admin Dashboard</a>
    <i class="fas fa-chevron-right separator"></i>
    <span class="current">Missing Items</span>
  </nav>

  <div class="missing-header">
    <div class="title-section">
      <h2>Missing Library Items</h2>
      <p class="text-meta">
        {#if loading}
          Checking library files...
        {:else}
          Found {titles.length} missing folder(s) and {entries.length} missing chapter file(s)
        {/if}
      </p>
    </div>
    
    {#if !empty && !loading}
      <button class="btn btn-danger" onclick={removeAll}>
        <i class="fas fa-trash-alt"></i> Clean All Database References
      </button>
    {/if}
  </div>

  {#if loading}
    <div class="loading-state">
      <i class="fas fa-circle-notch fa-spin fa-3x"></i>
      <p>Loading missing library items...</p>
    </div>
  {:else if empty}
    <div class="empty-state text-center">
      <i class="fas fa-check-circle empty-icon text-success"></i>
      <h3>No missing items found</h3>
      <p>Your database metadata is completely in sync with your local library files.</p>
      <a href="/admin" class="btn btn-secondary margin-top">Back to Dashboard</a>
    </div>
  {:else}
    <div class="missing-desc-card">
      <i class="fas fa-info-circle info-icon"></i>
      <p>
        The following files/folders were previously indexed in your library but are no longer present. 
        If they were deleted accidentally, recover them and rescan. 
        Otherwise, you can safely delete their database entries to clear unused tags, covers, and details.
      </p>
    </div>

    <div class="table-container">
      <table class="missing-table">
        <thead>
          <tr>
            <th>Type</th>
            <th>Relative Path</th>
            <th>ID</th>
            <th class="actions-column">Action</th>
          </tr>
        </thead>
        <tbody>
          <!-- Missing Titles -->
          {#each titles as title}
            <tr>
              <td>
                <span class="badge badge-accent"><i class="fas fa-folder"></i> Folder</span>
              </td>
              <td class="path-cell"><code>{title.path}</code></td>
              <td class="id-cell"><code>{title.id}</code></td>
              <td class="actions-cell">
                <button 
                  class="action-icon-btn delete" 
                  onclick={() => removeSingle('title', title.id, title.path)}
                  title="Remove reference"
                >
                  <i class="fas fa-trash-alt"></i>
                </button>
              </td>
            </tr>
          {/each}

          <!-- Missing Entries -->
          {#each entries as entry}
            <tr>
              <td>
                <span class="badge"><i class="fas fa-file-archive"></i> Archive</span>
              </td>
              <td class="path-cell"><code>{entry.path}</code></td>
              <td class="id-cell"><code>{entry.id}</code></td>
              <td class="actions-cell">
                <button 
                  class="action-icon-btn delete" 
                  onclick={() => removeSingle('entry', entry.id, entry.path)}
                  title="Remove reference"
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

  .missing-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.5rem;
    gap: 1rem;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 1.5rem;
  }

  @media (max-width: 600px) {
    .missing-header {
      flex-direction: column;
      align-items: stretch;
      text-align: center;
    }
  }

  .title-section h2 {
    font-size: 1.75rem;
    font-weight: 750;
  }

  .missing-desc-card {
    background-color: var(--accent-light);
    border: 1px solid rgba(255, 107, 0, 0.2);
    border-radius: var(--border-radius-md);
    padding: 1.25rem 1.5rem;
    margin-bottom: 1.5rem;
    display: flex;
    align-items: flex-start;
    gap: 1rem;
    font-size: 0.9rem;
    line-height: 1.5;
    color: var(--text-primary);
  }

  .info-icon {
    font-size: 1.25rem;
    color: var(--accent);
    margin-top: 0.1rem;
  }

  .table-container {
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-md);
    box-shadow: var(--shadow-sm);
    overflow: hidden;
  }

  .missing-table {
    width: 100%;
    border-collapse: collapse;
    text-align: left;
    font-size: 0.9rem;
  }

  .missing-table th, .missing-table td {
    padding: 1rem 1.25rem;
    border-bottom: 1px solid var(--border-color);
  }

  .missing-table tr:last-child td {
    border-bottom: none;
  }

  .missing-table th {
    font-family: var(--font-title);
    font-weight: 600;
    color: var(--text-secondary);
    background-color: rgba(0, 0, 0, 0.02);
  }

  :global(html.dark) .missing-table th {
    background-color: rgba(255, 255, 255, 0.02);
  }

  .path-cell code {
    word-break: break-all;
    white-space: pre-wrap;
  }

  .id-cell code {
    color: var(--text-muted);
  }

  .actions-column {
    text-align: right;
  }

  .actions-cell {
    display: flex;
    justify-content: flex-end;
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

  .action-icon-btn.delete:hover {
    color: var(--error);
    border-color: var(--error);
    background-color: rgba(239, 68, 68, 0.08);
  }

  .text-success {
    color: var(--success);
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
    margin-bottom: 1rem;
  }
</style>
