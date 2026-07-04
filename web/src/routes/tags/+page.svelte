<script lang="ts">
  import { onMount } from 'svelte';
  import { apiRequest } from '$lib/utils/api';
  import { addAlert } from '$lib/utils/store';

  interface TagWithCount {
    tag: string;
    count: number;
  }

  let loading = $state(true);
  let tags = $state<TagWithCount[]>([]);
  let searchQuery = $state('');

  const filteredTags = $derived.by(() => {
    if (!searchQuery.trim()) return tags;
    const query = searchQuery.toLowerCase().trim();
    return tags.filter(t => t.tag.toLowerCase().includes(query));
  });

  onMount(async () => {
    try {
      const data = await apiRequest('/api/tags_with_counts');
      if (data && data.success) {
        tags = data.tags || [];
      } else {
        addAlert('error', data.error || 'Failed to retrieve tags');
      }
    } catch (e: any) {
      console.error(e);
      addAlert('error', e.message || 'Error loading tags');
    } finally {
      loading = false;
    }
  });
</script>

<svelte:head>
  <title>Mango - Tags</title>
</svelte:head>

<div class="container">
  <div class="tags-header">
    <div class="title-section">
      <h2>Tags</h2>
      <p class="text-meta">{tags.length} tags found</p>
    </div>
    
    <div class="search-section">
      <div class="search-input-wrapper">
        <i class="fas fa-search search-icon"></i>
        <input 
          type="text" 
          class="input search-field" 
          placeholder="Search tags..." 
          bind:value={searchQuery}
        />
        {#if searchQuery}
          <button class="clear-search-btn" onclick={() => searchQuery = ''}>
            <i class="fas fa-times"></i>
          </button>
        {/if}
      </div>
    </div>
  </div>

  {#if loading}
    <div class="loading-state">
      <i class="fas fa-circle-notch fa-spin fa-3x"></i>
      <p>Loading tags...</p>
    </div>
  {:else if tags.length === 0}
    <div class="empty-state text-center">
      <i class="fas fa-tags empty-icon"></i>
      <h3>No tags found</h3>
      <p>You haven't tagged any manga titles in your library yet.</p>
    </div>
  {:else if filteredTags.length === 0}
    <div class="empty-state text-center">
      <i class="fas fa-search empty-icon"></i>
      <h3>No matches found</h3>
      <p>We couldn't find any tags matching "{searchQuery}".</p>
      <button class="btn btn-secondary margin-top" onclick={() => searchQuery = ''}>Clear Search</button>
    </div>
  {:else}
    <div class="tags-cloud">
      {#each filteredTags as item}
        <a href="/tags/{encodeURIComponent(item.tag)}" class="tag-badge-link">
          <span class="tag-name">{item.tag}</span>
          <span class="tag-count">{item.count}</span>
        </a>
      {/each}
    </div>
  {/if}
</div>

<style>
  .tags-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    margin-bottom: 2.5rem;
    gap: 1.5rem;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 1.5rem;
  }

  @media (max-width: 600px) {
    .tags-header {
      flex-direction: column;
      align-items: stretch;
    }
  }

  .title-section h2 {
    font-size: 1.75rem;
    font-weight: 700;
  }

  .search-section {
    flex-grow: 1;
    max-width: 400px;
  }

  @media (max-width: 600px) {
    .search-section {
      max-width: none;
    }
  }

  .search-input-wrapper {
    position: relative;
    width: 100%;
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
    max-width: 500px;
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

  /* Tag cloud design styling */
  .tags-cloud {
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
    padding: 1rem 0;
  }

  .tag-badge-link {
    display: inline-flex;
    align-items: center;
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: 9999px;
    overflow: hidden;
    font-size: 0.9rem;
    font-weight: 500;
    transition: all 0.15s cubic-bezier(0.4, 0, 0.2, 1);
    box-shadow: var(--shadow-sm);
  }

  .tag-badge-link:hover {
    transform: translateY(-2px);
    border-color: var(--accent);
    box-shadow: var(--shadow-md);
  }

  .tag-name {
    padding: 0.35rem 0.875rem;
    color: var(--text-primary);
  }

  .tag-count {
    background-color: var(--accent-light);
    color: var(--accent);
    padding: 0.35rem 0.625rem;
    font-weight: 700;
    border-left: 1px solid var(--border-color);
    font-size: 0.8rem;
  }

  .tag-badge-link:hover .tag-count {
    background-color: var(--accent);
    color: #ffffff;
    border-left-color: var(--accent);
  }
</style>
