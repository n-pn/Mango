<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { apiRequest } from '$lib/utils/api';
  import { addAlert } from '$lib/utils/store';

  interface DownloadJob {
    id: string;
    manga_id: string;
    title: string;
    manga_title: string;
    status: 'Pending' | 'Completed' | 'Error' | 'MissingPages' | 'Downloading';
    status_message: string;
    success_count: number;
    pages: number;
    time: number;
    plugin_id?: string;
  }

  let loading = $state(true);
  let toggling = $state(false);
  let paused = $state<boolean | undefined>(undefined);
  let jobs = $state<DownloadJob[]>([]);

  let ws: WebSocket | null = null;
  let retryCount = 0;

  onMount(() => {
    connectWebSocket();
    loadQueue();

    return () => {
      closeWebSocket();
    };
  });

  onDestroy(() => {
    closeWebSocket();
  });

  function connectWebSocket(secure = true) {
    if (typeof window === 'undefined') return;
    closeWebSocket();

    const protocol = secure ? 'wss' : 'ws';
    const host = window.location.host;
    const wsUrl = `${protocol}://${host}/api/admin/mangadex/queue`;
    
    console.log(`Connecting to WebSocket: ${wsUrl}`);
    
    try {
      ws = new WebSocket(wsUrl);

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          jobs = data.jobs || [];
          paused = data.paused;
          loading = false;
        } catch (e) {
          console.error('Error parsing WebSocket message', e);
        }
      };

      ws.onclose = () => {
        console.log('WebSocket connection closed.');
        // Retry with insecure if secure failed, but limit retries
        if (secure && retryCount < 2) {
          retryCount++;
          connectWebSocket(false);
        }
      };

      ws.onerror = (err) => {
        console.error('WebSocket encountered an error', err);
      };
    } catch (e) {
      console.error('Failed to instantiate WebSocket', e);
    }
  }

  function closeWebSocket() {
    if (ws) {
      ws.close();
      ws = null;
    }
  }

  async function loadQueue() {
    loading = true;
    try {
      const data = await apiRequest('/api/admin/mangadex/queue');
      if (data && data.success) {
        jobs = data.jobs || [];
        paused = data.paused;
      } else if (data && data.error) {
        addAlert('error', data.error);
      }
    } catch (e: any) {
      addAlert('error', e.message || 'Failed to fetch download queue.');
    } finally {
      loading = false;
    }
  }

  async function handleBulkAction(action: 'delete' | 'retry') {
    try {
      const res = await apiRequest(`/api/admin/mangadex/queue/${action}`, {
        method: 'POST'
      });
      if (res.success) {
        addAlert('success', `Completed action "${action}" on queue.`);
        await loadQueue();
      } else {
        addAlert('error', res.error || 'Failed to run action.');
      }
    } catch (e: any) {
      addAlert('error', e.message || 'Error processing queue action.');
    }
  }

  async function handleJobAction(action: 'delete' | 'retry', jobId: string) {
    try {
      const res = await apiRequest(`/api/admin/mangadex/queue/${action}?id=${encodeURIComponent(jobId)}`, {
        method: 'POST'
      });
      if (res.success) {
        addAlert('success', `Job update triggered.`);
        await loadQueue();
      } else {
        addAlert('error', res.error || 'Failed to execute action on job.');
      }
    } catch (e: any) {
      addAlert('error', e.message || 'Error modifying job.');
    }
  }

  async function toggleQueueState() {
    if (paused === undefined || toggling) return;
    toggling = true;
    const action = paused ? 'resume' : 'pause';
    try {
      const res = await apiRequest(`/api/admin/mangadex/queue/${action}`, {
        method: 'POST'
      });
      if (res.success) {
        paused = !paused;
        addAlert('success', `Downloads ${paused ? 'paused' : 'resumed'}.`);
      } else {
        addAlert('error', res.error || 'Failed to toggle queue.');
      }
    } catch (e: any) {
      addAlert('error', e.message || 'Error toggling queue.');
    } finally {
      toggling = false;
      await loadQueue();
    }
  }

  function formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    return date.toLocaleString();
  }
</script>

<svelte:head>
  <title>Mango - Download Manager</title>
</svelte:head>

<div class="container">
  <!-- Breadcrumbs -->
  <nav class="breadcrumbs">
    <a href="/admin">Admin Dashboard</a>
    <i class="fas fa-chevron-right separator"></i>
    <span class="current">Download Manager</span>
  </nav>

  <div class="downloads-header">
    <div class="title-section">
      <h2>Download Manager</h2>
      <p class="text-meta">Manage active downloader plugins tasks queue</p>
    </div>
    
    <div class="queue-controls">
      {#if paused !== undefined}
        <button 
          class="btn" 
          class:btn-primary={paused} 
          class:btn-secondary={!paused} 
          onclick={toggleQueueState}
          disabled={toggling}
        >
          {#if paused}
            <i class="fas fa-play"></i> Resume Downloads
          {:else}
            <i class="fas fa-pause"></i> Pause Downloads
          {/if}
        </button>
      {/if}
      <button class="btn btn-secondary" onclick={() => handleBulkAction('retry')}>
        <i class="fas fa-redo"></i> Retry Failed
      </button>
      <button class="btn btn-secondary" onclick={() => handleBulkAction('delete')}>
        <i class="fas fa-broom"></i> Clear Completed
      </button>
      <button class="btn btn-secondary" onclick={loadQueue} disabled={loading}>
        <i class="fas fa-sync" class:fa-spin={loading}></i> Refresh
      </button>
    </div>
  </div>

  {#if loading && jobs.length === 0}
    <div class="loading-state">
      <i class="fas fa-circle-notch fa-spin fa-3x"></i>
      <p>Loading download queue...</p>
    </div>
  {:else if jobs.length === 0}
    <div class="empty-state text-center">
      <i class="fas fa-download empty-icon"></i>
      <h3>No tasks in queue</h3>
      <p>Active downloads triggered by downloader plugins will show up here.</p>
    </div>
  {:else}
    <div class="table-container">
      <table class="downloads-table">
        <thead>
          <tr>
            <th>Chapter</th>
            <th>Manga</th>
            <th>Progress</th>
            <th>Date Added</th>
            <th>Status</th>
            <th>Plugin</th>
            <th class="actions-column">Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each jobs as job (job.id)}
            <tr>
              <td class="bold-cell">{job.title}</td>
              <td class="manga-title-cell">{job.manga_title}</td>
              <td>
                <div class="progress-cell">
                  <span class="progress-text">{job.success_count} / {job.pages} pages</span>
                  <div class="progress-bar-container mini">
                    <div class="progress-bar" style="width: {(job.success_count / (job.pages || 1)) * 100}%"></div>
                  </div>
                </div>
              </td>
              <td class="time-cell">{formatTime(job.time)}</td>
              <td>
                <div class="status-cell">
                  <span class="badge" class:badge-accent={job.status === 'Pending'} class:badge-success={job.status === 'Completed'} class:badge-error={job.status === 'Error'} class:badge-warning={job.status === 'MissingPages'}>
                    {job.status}
                  </span>
                  {#if job.status_message}
                    <div class="info-tooltip-wrapper">
                      <i class="fas fa-info-circle info-tooltip-icon"></i>
                      <div class="tooltip-content">{job.status_message}</div>
                    </div>
                  {/if}
                </div>
              </td>
              <td><code>{job.plugin_id || 'builtin'}</code></td>
              <td class="actions-cell">
                {#if job.status === 'Error' || job.status === 'MissingPages' || job.status_message}
                  <button 
                    class="action-icon-btn retry" 
                    onclick={() => handleJobAction('retry', job.id)}
                    title="Retry task"
                  >
                    <i class="fas fa-redo"></i>
                  </button>
                {/if}
                <button 
                  class="action-icon-btn delete" 
                  onclick={() => handleJobAction('delete', job.id)}
                  title="Remove task"
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

  .downloads-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    margin-bottom: 2rem;
    gap: 1.5rem;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 1.5rem;
  }

  @media (max-width: 900px) {
    .downloads-header {
      flex-direction: column;
      align-items: stretch;
    }
  }

  .title-section h2 {
    font-size: 1.75rem;
    font-weight: 750;
  }

  .queue-controls {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .table-container {
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-md);
    box-shadow: var(--shadow-sm);
    overflow-x: auto;
  }

  .downloads-table {
    width: 100%;
    border-collapse: collapse;
    text-align: left;
    font-size: 0.9rem;
    min-width: 800px;
  }

  .downloads-table th, .downloads-table td {
    padding: 1rem 1.25rem;
    border-bottom: 1px solid var(--border-color);
  }

  .downloads-table tr:last-child td {
    border-bottom: none;
  }

  .downloads-table th {
    font-family: var(--font-title);
    font-weight: 600;
    color: var(--text-secondary);
    background-color: rgba(0, 0, 0, 0.02);
  }

  :global(html.dark) .downloads-table th {
    background-color: rgba(255, 255, 255, 0.02);
  }

  .bold-cell {
    font-weight: 600;
  }

  .manga-title-cell {
    color: var(--text-primary);
  }

  .time-cell {
    color: var(--text-muted);
    font-size: 0.85rem;
  }

  .progress-cell {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    min-width: 120px;
  }

  .progress-text {
    font-size: 0.8rem;
    font-weight: 500;
  }

  .progress-bar-container.mini {
    height: 4px;
    border-radius: 2px;
  }

  .status-cell {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .badge-success {
    background-color: rgba(16, 185, 129, 0.1);
    color: var(--success);
  }

  .badge-error {
    background-color: rgba(239, 68, 68, 0.1);
    color: var(--error);
  }

  .badge-warning {
    background-color: rgba(245, 158, 11, 0.1);
    color: var(--warning);
  }

  /* Tooltip info styling */
  .info-tooltip-wrapper {
    position: relative;
    display: inline-flex;
    cursor: pointer;
  }

  .info-tooltip-icon {
    color: var(--text-muted);
    font-size: 0.95rem;
  }

  .info-tooltip-icon:hover {
    color: var(--accent);
  }

  .tooltip-content {
    display: none;
    position: absolute;
    bottom: calc(100% + 8px);
    left: 50%;
    transform: translateX(-50%);
    background-color: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    color: var(--text-primary);
    padding: 0.5rem 0.75rem;
    border-radius: var(--border-radius-sm);
    font-size: 0.8rem;
    white-space: pre-wrap;
    width: 220px;
    z-index: 100;
    box-shadow: var(--shadow-lg);
  }

  .info-tooltip-wrapper:hover .tooltip-content {
    display: block;
  }

  .actions-column {
    text-align: right;
  }

  .actions-cell {
    display: flex;
    justify-content: flex-end;
    gap: 0.35rem;
  }

  .action-icon-btn {
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    color: var(--text-secondary);
    width: 30px;
    height: 30px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    font-size: 0.8rem;
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
    max-width: 500px;
    margin: 2rem auto;
  }

  .empty-icon {
    font-size: 3rem;
    color: var(--text-muted);
    margin-bottom: 1rem;
  }
</style>
