<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { apiRequest } from '$lib/utils/api';
  import { addAlert } from '$lib/utils/store';
  import { goto } from '$app/navigation';
  import Card from '$lib/components/Card.svelte';

  let tag = $derived($page.params.tag);
  let decodedTag = $derived(decodeURIComponent(tag));

  let loading = $state(true);
  let titles = $state<any[]>([]);
  let percentages = $state<number[]>([]);
  let searchQuery = $state('');

  // Sort states
  let currentSortMethod = $state('auto');
  let currentSortAsc = $state(true);

  // Computed filter
  const filteredTitles = $derived.by(() => {
    if (!searchQuery.trim()) {
      return titles.map((title, i) => ({ title, percentage: percentages[i] }));
    }
    const query = searchQuery.toLowerCase().trim();
    return titles
      .map((title, i) => ({ title, percentage: percentages[i] }))
      .filter(item => {
        const name = (item.title.display_name || item.title.title || '').toLowerCase();
        return name.includes(query);
      });
  });

  onMount(async () => {
    await loadTaggedTitles();
  });

  $effect(() => {
    if (tag) {
      loadTaggedTitles();
    }
  });

  async function loadTaggedTitles() {
    loading = true;
    try {
      const data = await apiRequest(`/api/tags/titles/${tag}`);
      if (data && data.success) {
        titles = data.titles || [];
        percentages = data.percentages || new Array(titles.length).fill(0);
      } else {
        addAlert('error', data.error || 'Failed to fetch tagged titles');
      }
    } catch (e: any) {
      console.error(e);
      addAlert('error', e.message || 'Error loading tagged titles');
    } finally {
      loading = false;
    }
  }

  function handleSortChange(e: Event) {
    const val = (e.target as HTMLSelectElement).value;
    const [method, dir] = val.split('-');
    const ascend = dir === 'up';

    currentSortMethod = method;
    currentSortAsc = ascend;

    // Client-side sorting for tags query
    const sorted = [...titles].map((t, idx) => ({ title: t, pct: percentages[idx] }));
    
    sorted.sort((a, b) => {
      let comparison = 0;
      if (method === 'title') {
        const titleA = (a.title.display_name || a.title.title || '').toLowerCase();
        const titleB = (b.title.display_name || b.title.title || '').toLowerCase();
        comparison = titleA.localeCompare(titleB);
      } else if (method === 'time_modified') {
        const timeA = a.title.mtime || 0;
        const timeB = b.title.mtime || 0;
        comparison = timeA - timeB;
      } else if (method === 'progress') {
        comparison = a.pct - b.pct;
      }
      return ascend ? comparison : -comparison;
    });

    titles = sorted.map(s => s.title);
    percentages = sorted.map(s => s.pct);
  }
</script>

<svelte:head>
  <title>Mango - Tag: {decodedTag}</title>
</svelte:head>

<div class="container">
  <!-- Breadcrumbs -->
  <nav class="breadcrumbs">
    <a href="/tags">Tags</a>
    <i class="fas fa-chevron-right separator"></i>
    <span class="current">Tag: {decodedTag}</span>
  </nav>

  <div class="library-header">
    <div class="title-section">
      <h2>Tag: <span class="tag-title-highlight">{decodedTag}</span></h2>
      <p class="text-meta">{titles.length} titles tagged</p>
    </div>
    
    <div class="search-sort-section">
      <div class="search-input-wrapper">
        <i class="fas fa-search search-icon"></i>
        <input 
          type="text" 
          class="input search-field" 
          placeholder="Filter tagged titles..." 
          bind:value={searchQuery}
        />
        {#if searchQuery}
          <button class="clear-search-btn" onclick={() => searchQuery = ''}>
            <i class="fas fa-times"></i>
          </button>
        {/if}
      </div>

      <div class="sort-select-wrapper">
        <select class="select sort-dropdown" onchange={handleSortChange}>
          <option value="auto-up">Auto Sort</option>
          <option value="title-up">▲ Name</option>
          <option value="title-down">▼ Name</option>
          <option value="time_modified-up">▲ Date Modified</option>
          <option value="time_modified-down">▼ Date Modified</option>
          <option value="progress-up">▲ Progress</option>
          <option value="progress-down">▼ Progress</option>
        </select>
      </div>
    </div>
  </div>

  {#if loading}
    <div class="loading-state">
      <i class="fas fa-circle-notch fa-spin fa-3x"></i>
      <p>Loading tagged titles...</p>
    </div>
  {:else if titles.length === 0}
    <div class="empty-state text-center">
      <i class="fas fa-folder-open empty-icon"></i>
      <h3>No titles tagged</h3>
      <p>No titles have been tagged with "{decodedTag}" yet.</p>
      <a href="/tags" class="btn btn-secondary margin-top">Back to Tags</a>
    </div>
  {:else if filteredTitles.length === 0}
    <div class="empty-state text-center">
      <i class="fas fa-search empty-icon"></i>
      <h3>No matches found</h3>
      <p>No titles with tag "{decodedTag}" match "{searchQuery}".</p>
      <button class="btn btn-secondary margin-top" onclick={() => searchQuery = ''}>Clear Search</button>
    </div>
  {:else}
    <div class="card-grid">
      {#each filteredTitles as { title, percentage }}
        <Card 
          item={title} 
          progress={percentage} 
          page="library" 
          onclick={() => goto(`/book/${title.id}`)}
        />
      {/each}
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

  .library-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    margin-bottom: 2rem;
    gap: 1.5rem;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 1.5rem;
  }

  @media (max-width: 768px) {
    .library-header {
      flex-direction: column;
      align-items: stretch;
    }
  }

  .title-section h2 {
    font-size: 1.75rem;
    font-weight: 700;
  }

  .tag-title-highlight {
    color: var(--accent);
  }

  .search-sort-section {
    display: flex;
    gap: 1rem;
    flex-grow: 1;
    max-width: 600px;
    justify-content: flex-end;
  }

  @media (max-width: 768px) {
    .search-sort-section {
      max-width: none;
    }
  }

  @media (max-width: 480px) {
    .search-sort-section {
      flex-direction: column;
    }
  }

  .search-input-wrapper {
    position: relative;
    flex-grow: 1;
  }

  .search-icon {
    position: absolute;
    left: 0.875rem;
    top: 50%;
    transform: translateY(-50%);
    color: var(--text-muted);
  }

  .search-field {
    padding-left: 2.25rem;
    padding-right: 2.25rem;
  }

  .clear-search-btn {
    position: absolute;
    right: 0.875rem;
    top: 50%;
    transform: translateY(-50%);
    background: transparent;
    border: none;
    color: var(--text-muted);
    cursor: pointer;
    padding: 0.25rem;
  }

  .clear-search-btn:hover {
    color: var(--text-primary);
  }

  .sort-select-wrapper {
    min-width: 180px;
  }

  .loading-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 40vh;
    gap: 1rem;
    color: var(--text-secondary);
  }

  .loading-state i {
    color: var(--accent);
  }

  .empty-state {
    padding: 4rem 2rem;
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-lg);
    max-width: 600px;
    margin: 2rem auto;
  }

  .empty-icon {
    font-size: 3.5rem;
    color: var(--text-muted);
    margin-bottom: 1.5rem;
  }

  .empty-state h3 {
    margin-bottom: 0.5rem;
  }

  .empty-state p {
    color: var(--text-secondary);
  }
</style>
