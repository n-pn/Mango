<script lang="ts">
  import { onMount } from 'svelte';
  import { apiRequest } from '$lib/utils/api';
  import { addAlert } from '$lib/utils/store';
  import { goto } from '$app/navigation';

  interface MangaPlugin {
    id: string;
    title: string;
    description?: string;
  }

  interface PluginInfo {
    id: string;
    title: string;
    version: number;
    placeholder?: string;
    [key: string]: any;
  }

  interface MangaItem {
    id: string;
    title: string;
    cover_url?: string;
  }

  let loading = $state(true);
  let searching = $state(false);
  let adding = $state(false);
  let subscribing = $state(false);

  let plugins = $state<MangaPlugin[]>([]);
  let selectedPid = $state('');
  let pluginInfo = $state<PluginInfo | null>(null);
  let subscribable = $state(false);

  let searchQuery = $state('');
  
  // Search results
  let mangaList = $state<MangaItem[] | null>(null);
  let chapters = $state<any[] | null>(null);
  let allChapters = $state<any[]>([]);
  let selectedMangaId = $state('');
  let mangaTitle = $state('');

  // Filtering states
  let showFilters = $state(false);
  let filtersConfig = $state<any[]>([]);
  let filterInputs = $state<Record<string, any>>({});
  
  // Chapter selections
  let selectedChapterIds = $state<Record<string, boolean>>({});
  const selectedCount = $derived(Object.values(selectedChapterIds).filter(Boolean).length);

  // Sorting
  let sortKey = $state('');
  let sortDirection = $state<'asc' | 'desc' | null>(null);

  // Subscription modal
  let showSubModal = $state(false);
  let subscriptionName = $state('');

  onMount(async () => {
    await loadPlugins();
  });

  async function loadPlugins() {
    loading = true;
    try {
      const data = await apiRequest('/api/admin/plugin');
      if (data && data.success) {
        plugins = data.plugins || [];
        
        const savedPid = localStorage.getItem('plugin_id');
        if (savedPid && plugins.some(p => p.id === savedPid)) {
          selectedPid = savedPid;
        } else if (plugins.length > 0) {
          selectedPid = plugins[0].id;
        }

        if (selectedPid) {
          await loadPluginInfo(selectedPid);
        }
      }
    } catch (e: any) {
      addAlert('error', e.message || 'Error listing plugins.');
    } finally {
      loading = false;
    }
  }

  async function loadPluginInfo(pid: string) {
    try {
      const data = await apiRequest(`/api/admin/plugin/info?plugin=${encodeURIComponent(pid)}`);
      if (data && data.success) {
        pluginInfo = data.info;
        subscribable = !!data.subscribable;
        
        // Reset states
        mangaList = null;
        chapters = null;
        allChapters = [];
        selectedChapterIds = {};
        filtersConfig = [];
        filterInputs = {};
        showFilters = false;
      }
    } catch (e: any) {
      addAlert('error', e.message || 'Failed to fetch plugin metadata.');
    }
  }

  async function handlePluginChange() {
    localStorage.setItem('plugin_id', selectedPid);
    await loadPluginInfo(selectedPid);
  }

  async function triggerSearch() {
    const query = searchQuery.trim();
    if (!query || !pluginInfo) return;

    searching = true;
    mangaList = null;
    chapters = null;
    allChapters = [];
    selectedChapterIds = {};

    try {
      if (pluginInfo.version === 1) {
        // Direct search returns chapters
        await searchChapters(query);
      } else {
        // Returns manga items
        const data = await apiRequest(`/api/admin/plugin/search?plugin=${encodeURIComponent(selectedPid)}&query=${encodeURIComponent(query)}`);
        if (data && data.success) {
          mangaList = data.manga || [];
        } else {
          addAlert('error', data.error || 'Search failed');
        }
      }
    } catch (e: any) {
      addAlert('error', e.message || 'Failed to perform search.');
    } finally {
      searching = false;
    }
  }

  async function selectManga(manga: MangaItem) {
    selectedMangaId = manga.id;
    mangaTitle = manga.title;
    mangaList = null; // hide list
    searching = true;

    try {
      await searchChapters(manga.id);
    } catch (e: any) {
      addAlert('error', e.message);
    } finally {
      searching = false;
    }
  }

  async function searchChapters(queryId: string) {
    const data = await apiRequest(`/api/admin/plugin/list?plugin=${encodeURIComponent(selectedPid)}&query=${encodeURIComponent(queryId)}`);
    if (data && data.success) {
      allChapters = data.chapters || [];
      chapters = allChapters;
      
      try {
        mangaTitle = allChapters[0]?.manga_title || data.title || mangaTitle;
      } catch (e) {}

      setupFilters();
    } else {
      throw new Error(data.error || 'Failed to fetch chapters list.');
    }
  }

  function setupFilters() {
    if (allChapters.length === 0) return;
    
    const sample = allChapters[0];
    const keys = Object.keys(sample).filter(k => !['manga_title', 'id'].includes(k));
    
    filtersConfig = keys.map(k => {
      let values = allChapters.map(c => c[k]);
      let type = 'string';
      
      const allNumbers = values.every(v => !isNaN(v) && v !== null && v !== '');
      const allDates = values.every(v => isDateTimestamp(v));
      const allArrays = values.every(v => Array.isArray(v));

      if (allDates) type = 'date';
      else if (allNumbers) type = 'number';
      else if (allArrays) type = 'array';

      if (type === 'array') {
        values = Array.from(new Set(values.flat().map(v => typeof v === 'string' ? v.toLowerCase() : v)));
      }

      return { key: k, type, values };
    });

    // Reset inputs
    filterInputs = {};
    filtersConfig.forEach(f => {
      if (f.type === 'number' || f.type === 'date') {
        filterInputs[`${f.key}-min`] = '';
        filterInputs[`${f.key}-max`] = '';
      } else if (f.type === 'array') {
        filterInputs[f.key] = 'all';
      } else {
        filterInputs[f.key] = '';
      }
    });
  }

  function applyFilters() {
    let result = [...allChapters];
    
    Object.entries(filterInputs).forEach(([fieldKey, val]) => {
      if (!val || val === 'all') return;

      if (fieldKey.endsWith('-min')) {
        const key = fieldKey.replace('-min', '');
        result = result.filter(c => Number(c[key]) >= Number(val));
      } else if (fieldKey.endsWith('-max')) {
        const key = fieldKey.replace('-max', '');
        result = result.filter(c => Number(c[key]) <= Number(val));
      } else {
        const config = filtersConfig.find(f => f.key === fieldKey);
        if (config?.type === 'array') {
          result = result.filter(c => c[fieldKey]?.map((s: string) => s.toLowerCase()).includes(val.toLowerCase()));
        } else if (config?.type === 'string') {
          result = result.filter(c => String(c[fieldKey] || '').toLowerCase().includes(val.toLowerCase()));
        }
      }
    });

    chapters = result;
    selectedChapterIds = {};
  }

  function clearFilters() {
    setupFilters();
    chapters = allChapters;
  }

  function toggleChapterSelection(id: string) {
    selectedChapterIds = {
      ...selectedChapterIds,
      [id]: !selectedChapterIds[id]
    };
  }

  function selectAll() {
    const selects: Record<string, boolean> = {};
    chapters?.forEach(ch => {
      selects[ch.id] = true;
    });
    selectedChapterIds = selects;
  }

  function clearSelection() {
    selectedChapterIds = {};
  }

  async function triggerDownload() {
    const selectedList = Object.entries(selectedChapterIds)
      .filter(([_, sel]) => sel)
      .map(([id]) => id);

    if (selectedList.length === 0 || !chapters) return;

    const chaptersToDownload = allChapters.filter(c => selectedList.includes(c.id));
    const confirm = window.confirm(`Trigger download for ${chaptersToDownload.length} selected chapters?`);
    if (!confirm) return;

    adding = true;
    try {
      const res = await apiRequest('/api/admin/plugin/download', {
        method: 'POST',
        body: {
          chapters: chaptersToDownload,
          plugin: selectedPid,
          title: mangaTitle
        }
      });

      if (res.success) {
        addAlert('success', `${res.success} chapters added to download queue!`);
        clearSelection();
      } else {
        addAlert('error', res.error || 'Failed to download chapters');
      }
    } catch (e: any) {
      addAlert('error', e.message || 'Error triggering download.');
    } finally {
      adding = false;
    }
  }

  async function createSubscription() {
    if (!subscriptionName.trim()) return;

    subscribing = true;
    try {
      // Package active filters
      const activeFilters = Object.entries(filterInputs)
        .filter(([_, val]) => val && val !== 'all')
        .map(([fieldKey, val]) => {
          let type = 'string';
          let key = fieldKey;
          if (fieldKey.endsWith('-min')) {
            key = fieldKey.replace('-min', '');
            type = filtersConfig.find(f => f.key === key)?.type === 'date' ? 'date-min' : 'number-min';
          } else if (fieldKey.endsWith('-max')) {
            key = fieldKey.replace('-max', '');
            type = filtersConfig.find(f => f.key === key)?.type === 'date' ? 'date-max' : 'number-max';
          } else {
            type = filtersConfig.find(f => f.key === fieldKey)?.type || 'string';
          }

          let cleanVal = val;
          if (type.startsWith('date')) {
            cleanVal = Date.parse(val).toString();
          }

          return { key, value: cleanVal, type };
        });

      const res = await apiRequest('/api/admin/plugin/subscriptions', {
        method: 'POST',
        body: {
          filters: activeFilters,
          plugin: selectedPid,
          name: subscriptionName.trim(),
          manga: mangaTitle,
          manga_id: selectedMangaId || searchQuery
        }
      });

      if (res.success) {
        addAlert('success', 'Subscription created successfully.');
        showSubModal = false;
        subscriptionName = '';
      } else {
        addAlert('error', res.error || 'Failed to create subscription.');
      }
    } catch (e: any) {
      addAlert('error', e.message || 'Error setting subscription.');
    } finally {
      subscribing = false;
    }
  }

  function isDateTimestamp(val: any): boolean {
    if (isNaN(val) || val === '') return false;
    const num = Number(val);
    return num > 328896000000; // Jan 1 1980 timestamp
  }

  function cellText(val: any): string {
    if (isDateTimestamp(val)) {
      return new Date(Number(val)).toLocaleDateString();
    }
    if (Array.isArray(val)) {
      return val.join(', ');
    }
    return String(val ?? '');
  }

  function handleSort(key: string) {
    if (sortKey === key) {
      if (sortDirection === 'asc') sortDirection = 'desc';
      else if (sortDirection === 'desc') {
        sortDirection = null;
        sortKey = '';
        chapters = [...allChapters];
        return;
      }
    } else {
      sortKey = key;
      sortDirection = 'asc';
    }

    if (!chapters) return;

    const sorted = [...chapters];
    sorted.sort((a, b) => {
      const valA = a[key];
      const valB = b[key];

      if (valA === valB) return 0;
      if (!isNaN(valA) && !isNaN(valB)) {
        return sortDirection === 'asc' ? Number(valA) - Number(valB) : Number(valB) - Number(valA);
      }
      
      const strA = String(valA).toLowerCase();
      const strB = String(valB).toLowerCase();
      return sortDirection === 'asc' ? strA.localeCompare(strB) : strB.localeCompare(strA);
    });

    chapters = sorted;
  }
</script>

<svelte:head>
  <title>Mango - Plugins Downloader</title>
</svelte:head>

<div class="container">
  <!-- Breadcrumbs -->
  <nav class="breadcrumbs">
    <a href="/admin">Admin Dashboard</a>
    <i class="fas fa-chevron-right separator"></i>
    <span class="current">Download with Plugins</span>
  </nav>

  <div class="plugin-down-header">
    <div class="title-section">
      <h2>
        Download with Plugins
        {#if searching}
          <i class="fas fa-spinner fa-spin loader-icon"></i>
        {/if}
      </h2>
      <p class="text-meta">Browse catalog feeds and download manga volumes directly</p>
    </div>
  </div>

  {#if loading}
    <div class="loading-state">
      <i class="fas fa-circle-notch fa-spin fa-3x"></i>
      <p>Loading plugin directories...</p>
    </div>
  {:else if plugins.length === 0}
    <div class="empty-state text-center">
      <i class="fas fa-plug empty-icon"></i>
      <h3>No plugins found</h3>
      <p>Please place supported plugin scripts in your server folder to download chapters.</p>
    </div>
  {:else}
    <!-- Selector section -->
    <div class="control-panel-grid">
      <div class="plugin-meta-wrapper">
        <div class="form-group select-group">
          <label class="form-label" for="plugin-dropdown">Choose Plugin</label>
          <select 
            id="plugin-dropdown" 
            class="select" 
            bind:value={selectedPid} 
            onchange={handlePluginChange}
          >
            {#each plugins as p}
              <option value={p.id}>{p.title}</option>
            {/each}
          </select>
        </div>

        {#if pluginInfo}
          <div class="plugin-info-card">
            <h4 class="card-subtitle"><i class="fas fa-info-circle"></i> Info</h4>
            <div class="info-meta-row">
              <span class="meta-label">Author:</span>
              <span class="meta-value">{pluginInfo.author || 'Unknown'}</span>
            </div>
            <div class="info-meta-row">
              <span class="meta-label">Plugin version:</span>
              <span class="meta-value">v{pluginInfo.version || '1'}</span>
            </div>
          </div>
        {/if}
      </div>

      {#if pluginInfo}
        <form class="search-form-row" onsubmit={e => { e.preventDefault(); triggerSearch(); }}>
          <div class="form-group flex-grow">
            <label class="form-label" for="search-input">Search Query</label>
            <div class="search-bar-row">
              <input 
                id="search-input"
                type="text" 
                class="input" 
                placeholder={pluginInfo.placeholder || "Enter title or ID..."} 
                bind:value={searchQuery}
              />
              <button type="submit" class="btn btn-primary" disabled={searching}>
                Search
              </button>
            </div>
          </div>
        </form>
      {/if}
    </div>

    <!-- Manga search list results -->
    {#if mangaList}
      <div class="search-results-section margin-top">
        <h3 class="results-heading">{mangaList.length} manga found</h3>
        {#if mangaList.length === 0}
          <p class="empty-info">No manga matched your query.</p>
        {:else}
          <div class="card-grid">
            {#each mangaList as m}
              <!-- svelte-ignore a11y_click_events_have_key_events -->
              <!-- svelte-ignore a11y_no_static_element_interactions -->
              <div onclick={() => selectManga(m)} class="manga-result-card">
                <Card item={m} page="library" />
              </div>
            {/each}
          </div>
        {/if}
      </div>
    {/if}

    <!-- Chapter list section -->
    {#if chapters !== null}
      <div class="chapters-section margin-top">
        <div class="chapter-list-header">
          <div class="chapter-info-col">
            <h3>{mangaTitle}</h3>
            <p class="text-meta">{chapters.length} chapters found</p>
          </div>
          
          <div class="actions-row">
            {#if chapters.length > 0}
              <button class="btn btn-secondary" onclick={selectAll}>Select All</button>
              <button class="btn btn-secondary" onclick={clearSelection}>Clear Selection</button>
              <button class="btn btn-primary" onclick={triggerDownload} disabled={selectedCount === 0 || adding}>
                {#if adding}
                  <i class="fas fa-spinner fa-spin"></i> Adding...
                {:else}
                  Download Selected ({selectedCount})
                {/if}
              </button>
            {/if}
            <button class="btn btn-secondary icon-only" onclick={() => showFilters = !showFilters} title="Toggle Filters">
              <i class="fas fa-filter"></i>
            </button>
          </div>
        </div>

        <!-- Filter Form -->
        {#if showFilters || allChapters.length > 500}
          <div class="filters-card">
            <h4 class="card-subtitle"><i class="fas fa-filter"></i> Filter Chapters</h4>
            
            <div class="filters-grid">
              {#each filtersConfig as field}
                <div class="form-group">
                  <label class="form-label" for="filter-{field.key}">{field.key}</label>
                  
                  {#if field.type === 'number'}
                    <div class="range-inputs">
                      <input 
                        type="number" 
                        class="input" 
                        placeholder="min" 
                        bind:value={filterInputs[`${field.key}-min`]} 
                      />
                      <span class="range-sep">to</span>
                      <input 
                        type="number" 
                        class="input" 
                        placeholder="max" 
                        bind:value={filterInputs[`${field.key}-max`]} 
                      />
                    </div>
                  {:else if field.type === 'date'}
                    <div class="range-inputs">
                      <input 
                        type="date" 
                        class="input" 
                        bind:value={filterInputs[`${field.key}-min`]} 
                      />
                      <span class="range-sep">to</span>
                      <input 
                        type="date" 
                        class="input" 
                        bind:value={filterInputs[`${field.key}-max`]} 
                      />
                    </div>
                  {:else if field.type === 'array'}
                    <select class="select" bind:value={filterInputs[field.key]}>
                      <option value="all">All Values</option>
                      {#each field.values as v}
                        <option value={v}>{v}</option>
                      {/each}
                    </select>
                  {:else}
                    <input 
                      type="text" 
                      class="input" 
                      placeholder="Filter text..." 
                      bind:value={filterInputs[field.key]} 
                    />
                  {/if}
                </div>
              {/each}
            </div>

            <div class="filter-actions">
              <button class="btn btn-secondary" onclick={clearFilters}>Clear Filters</button>
              <button class="btn btn-primary" onclick={applyFilters}>Apply Filters</button>
              
              {#if subscribable}
                <span class="vertical-divider"></span>
                <button class="btn btn-secondary" onclick={() => showSubModal = true} disabled={subscribing}>
                  Subscribe to Feed
                </button>
              {/if}
            </div>
          </div>
        {/if}

        <!-- Chapters Table list -->
        {#if chapters.length === 0}
          <div class="empty-state text-center margin-top">
            <p>No chapters matched your filter queries.</p>
          </div>
        {:else}
          <div class="table-container margin-top">
            <table class="chapters-table">
              <thead>
                <tr>
                  <th style="width: 50px;">Select</th>
                  {#if chapters.length > 0}
                    {#each Object.keys(chapters[0]).filter(k => k !== 'manga_title' && k !== 'id') as key}
                      <!-- svelte-ignore a11y_click_events_have_key_events -->
                      <!-- svelte-ignore a11y_no_static_element_interactions -->
                      <th onclick={() => handleSort(key)} class="sortable-th">
                        {key}
                        {#if sortKey === key}
                          <i class="fas" class:fa-sort-up={sortDirection === 'asc'} class:fa-sort-down={sortDirection === 'desc'}></i>
                        {:else}
                          <i class="fas fa-sort table-sort-icon"></i>
                        {/if}
                      </th>
                    {/each}
                  {/if}
                </tr>
              </thead>
              <tbody>
                {#each chapters as ch (ch.id)}
                  <!-- svelte-ignore a11y_click_events_have_key_events -->
                  <!-- svelte-ignore a11y_no_static_element_interactions -->
                  <tr 
                    class="clickable-row" 
                    class:selected-row={selectedChapterIds[ch.id]}
                    onclick={() => toggleChapterSelection(ch.id)}
                  >
                    <td>
                      <input 
                        type="checkbox" 
                        class="checkbox" 
                        checked={!!selectedChapterIds[ch.id]} 
                        onclick={(e) => e.stopPropagation()} 
                        onchange={() => toggleChapterSelection(ch.id)} 
                      />
                    </td>
                    {#each Object.entries(ch).filter(([k]) => k !== 'manga_title' && k !== 'id') as [_, val]}
                      <td>{cellText(val)}</td>
                    {/each}
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      </div>
    {/if}
  {/if}
</div>

<!-- Subscription modal -->
{#if showSubModal}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="modal-overlay" onclick={() => showSubModal = false}>
    <div class="modal-content" onclick={e => e.stopPropagation()}>
      <div class="modal-header">
        <h3 class="modal-title">Confirm Subscription</h3>
        <button class="modal-close" onclick={() => showSubModal = false}>&times;</button>
      </div>
      <div class="modal-body">
        <p class="sub-explain-text">
          A subscription will be created using your current filters. 
          All <strong>FUTURE</strong> releases matching these filters will be automatically downloaded.
        </p>

        <h4 class="section-subtitle margin-top">Selected Filters</h4>
        <div class="table-container mini">
          <table class="filters-table">
            <thead>
              <tr>
                <th>Field</th>
                <th>Type</th>
                <th>Value</th>
              </tr>
            </thead>
            <tbody>
              {#each Object.entries(filterInputs).filter(([_, val]) => val && val !== 'all') as [fieldKey, val]}
                <tr>
                  <td><code>{fieldKey.replace('-min', '').replace('-max', '')}</code></td>
                  <td>{fieldKey.endsWith('-min') ? 'Minimum' : fieldKey.endsWith('-max') ? 'Maximum' : 'Match'}</td>
                  <td>{val}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>

        <div class="form-group margin-top">
          <label class="form-label" for="sub-name-input">Subscription Name</label>
          <input 
            id="sub-name-input"
            type="text" 
            class="input" 
            placeholder="e.g. Manga Title Updates" 
            bind:value={subscriptionName}
          />
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" onclick={() => showSubModal = false}>Cancel</button>
        <button class="btn btn-primary" onclick={createSubscription} disabled={!subscriptionName.trim() || subscribing}>
          Confirm Subscription
        </button>
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

  .plugin-down-header {
    margin-bottom: 2rem;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 1.5rem;
  }

  .title-section h2 {
    font-size: 1.75rem;
    font-weight: 750;
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .loader-icon {
    font-size: 1.25rem;
    color: var(--accent);
  }

  /* Control panel layout details */
  .control-panel-grid {
    display: grid;
    grid-template-columns: 300px 1fr;
    gap: 1.5rem;
  }

  @media (max-width: 768px) {
    .control-panel-grid {
      grid-template-columns: 1fr;
    }
  }

  .plugin-meta-wrapper {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .plugin-info-card {
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-md);
    padding: 1.25rem;
    box-shadow: var(--shadow-sm);
  }

  .info-meta-row {
    display: flex;
    justify-content: space-between;
    font-size: 0.85rem;
    padding: 0.35rem 0;
    border-bottom: 1px solid var(--border-color);
  }

  .info-meta-row:last-child {
    border-bottom: none;
  }

  .meta-label {
    color: var(--text-secondary);
    font-weight: 500;
  }

  .meta-value {
    color: var(--text-primary);
  }

  .search-form-row {
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-md);
    padding: 1.5rem;
    box-shadow: var(--shadow-sm);
    display: flex;
    align-items: flex-end;
  }

  .flex-grow {
    flex-grow: 1;
  }

  .search-bar-row {
    display: flex;
    gap: 0.75rem;
  }

  .search-bar-row .input {
    flex-grow: 1;
  }

  /* Manga Result grid */
  .manga-result-card {
    transition: transform 0.2s ease;
  }

  .manga-result-card:hover {
    transform: scale(1.02);
  }

  /* Chapters section styling */
  .chapter-list-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 1rem;
    gap: 1rem;
  }

  @media (max-width: 768px) {
    .chapter-list-header {
      flex-direction: column;
      align-items: stretch;
    }
  }

  .actions-row {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .btn.icon-only {
    width: 38px;
    height: 38px;
    padding: 0;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
  }

  /* Filters list styles */
  .filters-card {
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-md);
    padding: 1.5rem;
    margin-top: 1rem;
  }

  .filters-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
    gap: 1rem;
    margin-top: 1rem;
  }

  .range-inputs {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .range-sep {
    font-size: 0.8rem;
    color: var(--text-muted);
  }

  .filter-actions {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
    margin-top: 1.25rem;
    align-items: center;
  }

  .vertical-divider {
    height: 24px;
    width: 1px;
    background-color: var(--border-color);
    margin: 0 0.5rem;
  }

  /* Chapters Table list */
  .table-container {
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-md);
    box-shadow: var(--shadow-sm);
    overflow-x: auto;
  }

  .chapters-table {
    width: 100%;
    border-collapse: collapse;
    text-align: left;
    font-size: 0.875rem;
    min-width: 600px;
  }

  .chapters-table th, .chapters-table td {
    padding: 0.875rem 1rem;
    border-bottom: 1px solid var(--border-color);
  }

  .chapters-table tr:last-child td {
    border-bottom: none;
  }

  .chapters-table th {
    font-family: var(--font-title);
    font-weight: 600;
    color: var(--text-secondary);
    background-color: rgba(0, 0, 0, 0.02);
    user-select: none;
  }

  :global(html.dark) .chapters-table th {
    background-color: rgba(255, 255, 255, 0.02);
  }

  .sortable-th {
    cursor: pointer;
    transition: color 0.15s ease;
  }

  .sortable-th:hover {
    color: var(--accent);
  }

  .table-sort-icon {
    font-size: 0.75rem;
    color: var(--text-muted);
    margin-left: 0.25rem;
    opacity: 0.5;
  }

  .clickable-row {
    cursor: pointer;
    transition: background-color 0.1s ease;
  }

  .clickable-row:hover {
    background-color: var(--bg-tertiary);
  }

  .clickable-row.selected-row {
    background-color: var(--accent-light);
  }

  /* Modal styling details */
  .sub-explain-text {
    font-size: 0.9rem;
    line-height: 1.5;
    color: var(--text-secondary);
  }

  .table-container.mini {
    max-height: 150px;
    overflow-y: auto;
    border-radius: var(--border-radius-sm);
  }

  .filters-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.8rem;
  }

  .filters-table th, .filters-table td {
    padding: 0.5rem 0.75rem;
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
  }

  .empty-icon {
    font-size: 3rem;
    color: var(--text-muted);
    margin-bottom: 1rem;
  }
</style>
