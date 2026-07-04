<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { apiRequest } from '$lib/utils/api';
  import { appState, addAlert } from '$lib/utils/store.svelte';

  // State
  let mangoVersion = $state('0.0.0');
  let missingCount = $state(0);

  // Scan states
  let scanning = $state(false);
  let scanMs = $state(-1);
  let scanTitles = $state(0);

  // Thumbnail generation states
  let generating = $state(false);
  let progress = $state(1.0);
  let progressInterval: any = null;

  onMount(async () => {
    await loadInitialData();
    
    // Start polling progress if page loaded while generating
    await checkThumbnailProgress();
    progressInterval = setInterval(checkThumbnailProgress, 4000);
  });

  onDestroy(() => {
    if (progressInterval) clearInterval(progressInterval);
  });

  async function loadInitialData() {
    try {
      const [verData, missingTitles, missingEntries] = await Promise.all([
        apiRequest('/api/version'),
        apiRequest('/api/admin/titles/missing'),
        apiRequest('/api/admin/entries/missing')
      ]);

      if (verData && verData.success) {
        mangoVersion = verData.version;
      }
      
      const titleCount = Array.isArray(missingTitles) ? missingTitles.length : 0;
      const entryCount = Array.isArray(missingEntries) ? missingEntries.length : 0;
      missingCount = titleCount + entryCount;

    } catch (e) {
      console.error('Failed to load initial admin data', e);
    }
  }

  async function triggerScan() {
    if (scanning) return;
    scanning = true;
    scanMs = -1;
    scanTitles = 0;
    
    try {
      const data = await apiRequest('/api/admin/scan', { method: 'POST' });
      scanMs = data.milliseconds;
      scanTitles = data.titles;
      addAlert('success', `Scan complete! Found ${scanTitles} titles.`);
    } catch (e: any) {
      addAlert('error', `Failed to trigger scan: ${e.message}`);
    } finally {
      scanning = false;
    }
  }

  async function triggerThumbnailGeneration() {
    if (generating) return;
    generating = true;
    progress = 0.0;
    
    try {
      await apiRequest('/api/admin/generate_thumbnails', { method: 'POST' });
      addAlert('success', 'Thumbnail generation started in background.');
      await checkThumbnailProgress();
    } catch (e: any) {
      addAlert('error', `Failed to start thumbnail generation: ${e.message}`);
      generating = false;
    }
  }

  async function checkThumbnailProgress() {
    try {
      const data = await apiRequest('/api/admin/thumbnail_progress');
      if (data && typeof data.progress === 'number') {
        progress = data.progress;
        generating = progress > 0 && progress < 1.0;
      }
    } catch (e) {
      console.error('Failed to check thumbnail progress', e);
    }
  }

  function handleThemeSelect(e: Event) {
    const val = (e.target as HTMLSelectElement).value as 'light' | 'dark' | 'system';
    appState.theme = val;
  }
</script>

<svelte:head>
  <title>Mango - Admin Dashboard</title>
</svelte:head>

<div class="container-small">
  <div class="admin-header">
    <h2>Admin Control Panel</h2>
    <p class="text-meta">Configure and manage your manga server</p>
  </div>

  <div class="admin-card-menu">
    <!-- Links section -->
    <div class="admin-menu-list">
      <a href="/admin/user" class="menu-item">
        <div class="menu-item-left">
          <i class="fas fa-users-cog item-icon"></i>
          <div class="item-details">
            <span class="item-title">User Management</span>
            <span class="item-desc">Create, edit, and delete user profiles and roles</span>
          </div>
        </div>
        <i class="fas fa-chevron-right item-arrow"></i>
      </a>

      <a href="/admin/missing" class="menu-item">
        <div class="menu-item-left">
          <i class="fas fa-exclamation-circle item-icon text-warning"></i>
          <div class="item-details">
            <span class="item-title">Missing Items</span>
            <span class="item-desc">Clean up references to deleted files in the library</span>
          </div>
        </div>
        <div class="menu-item-right">
          {#if missingCount > 0}
            <span class="badge badge-accent">{missingCount}</span>
          {/if}
          <i class="fas fa-chevron-right item-arrow"></i>
        </div>
      </a>
    </div>

    <!-- Actions section -->
    <div class="admin-actions-section">
      <!-- Library Scan -->
      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div class="action-item" onclick={triggerScan} class:action-disabled={scanning}>
        <div class="action-details">
          <div class="action-title-row">
            <span class="action-title">Scan Library Files</span>
            {#if scanning}
              <i class="fas fa-spinner fa-spin text-accent"></i>
            {/if}
          </div>
          <span class="action-desc">Check for new manga files and updates in library directory</span>
          {#if scanMs > 0}
            <span class="action-status-text text-success">
              Scanned {scanTitles} titles in {scanMs.toFixed(0)}ms
            </span>
          {/if}
        </div>
      </div>

      <!-- Thumbnail Builder -->
      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div class="action-item" onclick={triggerThumbnailGeneration} class:action-disabled={generating}>
        <div class="action-details">
          <div class="action-title-row">
            <span class="action-title">Generate Thumbnails</span>
            {#if generating}
              <span class="progress-pct">{(progress * 100).toFixed(1)}%</span>
            {/if}
          </div>
          <span class="action-desc">Pre-render covers for all manga titles to speed up loading</span>
          
          {#if generating}
            <div class="progress-bar-container margin-top-sm">
              <div class="progress-bar" style="width: {progress * 100}%"></div>
            </div>
          {/if}
        </div>
      </div>
    </div>

    <!-- Dropdowns/Theme settings -->
    <div class="admin-settings-section">
      <div class="setting-row">
        <label for="theme-select" class="setting-label">
          <i class="fas fa-palette"></i> Default Appearance Theme
        </label>
        <select 
          id="theme-select" 
          class="select setting-select" 
          value={appState.theme}
          onchange={handleThemeSelect}
        >
          <option value="dark">Dark Theme</option>
          <option value="light">Light Theme</option>
          <option value="system">System Preference Sync</option>
        </select>
      </div>
    </div>
  </div>

  <hr class="admin-divider" />
  
  <div class="admin-footer-meta">
    <p>Version: <code>v{mangoVersion}</code></p>
    <a href="/logout" class="btn btn-danger log-out-btn">
      <i class="fas fa-sign-out-alt"></i> Log Out
    </a>
  </div>
</div>

<style>
  .admin-header {
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 1.5rem;
    margin-bottom: 2rem;
  }

  .admin-header h2 {
    font-size: 1.75rem;
    font-weight: 750;
  }

  .admin-card-menu {
    display: flex;
    flex-direction: column;
    gap: 1.75rem;
  }

  /* List Menu items */
  .admin-menu-list, .admin-actions-section, .admin-settings-section {
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-md);
    overflow: hidden;
    box-shadow: var(--shadow-sm);
  }

  .menu-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1.25rem 1.5rem;
    border-bottom: 1px solid var(--border-color);
    color: var(--text-primary);
    transition: background-color 0.15s ease;
  }

  .menu-item:last-child {
    border-bottom: none;
  }

  .menu-item:hover {
    background-color: var(--bg-tertiary);
  }

  .menu-item-left {
    display: flex;
    align-items: center;
    gap: 1.25rem;
  }

  .item-icon {
    font-size: 1.5rem;
    color: var(--accent);
    width: 24px;
    text-align: center;
  }

  .item-icon.text-warning {
    color: var(--warning);
  }

  .item-details {
    display: flex;
    flex-direction: column;
  }

  .item-title {
    font-weight: 600;
    font-size: 0.975rem;
  }

  .item-desc {
    font-size: 0.8rem;
    color: var(--text-secondary);
  }

  .menu-item-right {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .item-arrow {
    color: var(--text-muted);
    font-size: 0.85rem;
  }

  /* Action Buttons item style */
  .action-item {
    padding: 1.25rem 1.5rem;
    border-bottom: 1px solid var(--border-color);
    cursor: pointer;
    transition: background-color 0.15s ease;
  }

  .action-item:last-child {
    border-bottom: none;
  }

  .action-item:hover:not(.action-disabled) {
    background-color: var(--bg-tertiary);
  }

  .action-item.action-disabled {
    cursor: not-allowed;
    opacity: 0.75;
  }

  .action-details {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    width: 100%;
  }

  .action-title-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-weight: 600;
    font-size: 0.975rem;
  }

  .text-accent {
    color: var(--accent);
  }

  .action-desc {
    font-size: 0.8rem;
    color: var(--text-secondary);
  }

  .action-status-text {
    font-size: 0.85rem;
    font-weight: 500;
    margin-top: 0.35rem;
  }

  .text-success {
    color: var(--success);
  }

  .progress-pct {
    color: var(--accent);
    font-size: 0.85rem;
    font-weight: 700;
  }

  .margin-top-sm {
    margin-top: 0.5rem;
  }

  /* Setting row style */
  .setting-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1.25rem 1.5rem;
    gap: 1rem;
  }

  @media (max-width: 480px) {
    .setting-row {
      flex-direction: column;
      align-items: stretch;
      gap: 0.75rem;
    }
  }

  .setting-label {
    font-weight: 600;
    font-size: 0.95rem;
    color: var(--text-primary);
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .setting-label i {
    color: var(--text-muted);
  }

  .setting-select {
    width: auto;
    min-width: 200px;
  }

  @media (max-width: 480px) {
    .setting-select {
      width: 100%;
    }
  }

  .admin-divider {
    border: none;
    border-top: 1px solid var(--border-color);
    margin: 2rem 0;
  }

  /* Footer metadata */
  .admin-footer-meta {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 0.875rem;
    color: var(--text-secondary);
  }

  .log-out-btn {
    padding: 0.5rem 1rem;
  }
</style>
