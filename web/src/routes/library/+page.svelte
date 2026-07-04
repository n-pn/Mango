<script lang="ts">
  import { onMount } from 'svelte';
  import { apiRequest } from '$lib/utils/api';
  import { addAlert } from '$lib/utils/store.svelte';
  import { goto } from '$app/navigation';
  import Card from '$lib/components/Card.svelte';

  let loading = $state(true);
  let titles = $state<any[]>([]);
  let percentages = $state<number[]>([]);
  let searchQuery = $state('');

  // Sort state
  let currentSortMethod = $state('auto');
  let currentSortAsc = $state(true);

  // Computed filtered list
  const filteredTitles = $derived.by(() => {
    if (!searchQuery.trim()) {
      return titles.map((title, i) => ({ title, percentage: percentages[i] }));
    }
    
    const query = searchQuery.toLowerCase().trim();
    return titles
      .map((title, i) => ({ title, percentage: percentages[i], originalIndex: i }))
      .filter(item => {
        const name = (item.title.display_name || item.title.title || '').toLowerCase();
        const dir = (item.title.dir || '').toLowerCase();
        return name.includes(query) || dir.includes(query);
      });
  });

  onMount(async () => {
    await loadSortOptions();
    await loadLibrary();
  });

  async function loadSortOptions() {
    try {
      const data = await apiRequest('/api/sort_opt');
      if (data && !data.error) {
        currentSortMethod = data.method || 'auto';
        currentSortAsc = data.ascend !== false;
      }
    } catch (e) {
      console.error('Failed to load sort options', e);
    }
  }

  async function loadLibrary() {
    loading = true;
    try {
      const data = await apiRequest('/api/library?percentage=true');
      if (data && data.titles) {
        titles = data.titles;
        percentages = data.title_percentage || new Array(titles.length).fill(0);
      }
    } catch (e) {
      console.error('Failed to load library', e);
      addAlert('error', 'Failed to load library titles.');
    } finally {
      loading = false;
    }
  }

  async function handleSortChange(e: Event) {
    const value = (e.target as HTMLSelectElement).value;
    const [method, dir] = value.split('-');
    const ascend = dir === 'up';

    currentSortMethod = method;
    currentSortAsc = ascend;

    try {
      const res = await apiRequest('/api/sort_opt', {
        method: 'PUT',
        body: {
          sort: method,
          ascend: ascend
        }
      });

      if (res.success) {
        // Refetch library sorted by the backend
        await loadLibrary();
      } else {
        addAlert('error', res.error || 'Failed to save sort preference.');
      }
    } catch (err: any) {
      addAlert('error', err.message || 'Error saving sort preference.');
    }
  }
</script>

<svelte:head>
  <title>Mango - Library</title>
</svelte:head>

<div class="container">
  <div class="library-header">
    <div class="title-section">
      <h2>Library</h2>
      <p class="text-meta">{titles.length} titles found</p>
    </div>
    
    <div class="search-sort-section">
      <div class="search-input-wrapper">
        <i class="fas fa-search search-icon"></i>
        <input 
          type="text" 
          class="input search-field" 
          placeholder="Search titles..." 
          bind:value={searchQuery}
        />
        {#if searchQuery}
          <button class="clear-search-btn" onclick={() => searchQuery = ''} aria-label="Clear search">
            <i class="fas fa-times"></i>
          </button>
        {/if}
      </div>

      <div class="sort-select-wrapper">
        <select 
          class="select sort-dropdown" 
          value={`${currentSortMethod}-${currentSortAsc ? 'up' : 'down'}`}
          onchange={handleSortChange}
        >
          <option value="auto-up">▲ Auto Sort</option>
          <option value="auto-down">▼ Auto Sort</option>
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
      <p>Loading library titles...</p>
    </div>
  {:else if titles.length === 0}
    <div class="empty-state text-center">
      <i class="fas fa-book-open empty-icon"></i>
      <h3>Your library is empty</h3>
      <p>Please place supported manga archives inside your configured library path and scan the directories.</p>
      <a href="/" class="btn btn-primary margin-top">Back to Dashboard</a>
    </div>
  {:else if filteredTitles.length === 0}
    <div class="empty-state text-center">
      <i class="fas fa-search empty-icon"></i>
      <h3>No matches found</h3>
      <p>We couldn't find any titles matching "{searchQuery}". Check spelling or try different keywords.</p>
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
