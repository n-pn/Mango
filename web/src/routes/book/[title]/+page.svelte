<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { apiRequest } from '$lib/utils/api';
  import { isAdmin, addAlert } from '$lib/utils/store';
  import Card from '$lib/components/Card.svelte';
  import EntryModal from '$lib/components/EntryModal.svelte';

  let titleId = $derived($page.params.title);

  // States
  let loading = $state(true);
  let bookDetails = $state<any>(null);
  let subTitles = $state<any[]>([]);
  let entries = $state<any[]>([]);
  
  // Percentages maps
  let entryPercentages = $state<number[]>([]);
  let titlePercentages = $state<number[]>([]);

  // Search and Sort
  let searchQuery = $state('');
  let sortMethod = $state('auto');
  let sortAsc = $state(true);

  // Tags
  let allTags = $state<string[]>([]);
  let bookTags = $state<string[]>([]);
  let showTagInput = $state(false);
  let newTagValue = $state('');
  let tagInputRef = $state<HTMLInputElement | null>(null);

  // Selection
  let selectedIds = $state<Record<string, boolean>>({});
  const selectedCount = $derived(Object.values(selectedIds).filter(Boolean).length);

  // Modal
  let selectedEntry = $state<any>(null);
  let selectedEntryProgress = $state<number>(0);
  let showEntryModal = $state(false);

  // Edit book metadata modal
  let showEditBookModal = $state(false);
  let editDisplayName = $state('');
  let editSortTitle = $state('');
  let editUploading = $state(false);

  onMount(async () => {
    await initializePage();
  });

  // Re-run initialization if the title route changes
  $effect(() => {
    if (titleId) {
      initializePage();
    }
  });

  async function initializePage() {
    loading = true;
    selectedIds = {};
    try {
      await Promise.all([
        loadBookDetails(),
        loadSortOption(),
        loadTags()
      ]);
    } catch (e) {
      console.error(e);
    } finally {
      loading = false;
    }
  }

  async function loadBookDetails() {
    try {
      const data = await apiRequest(`/api/book/${titleId}?percentage=true`);
      if (data) {
        bookDetails = data;
        subTitles = data.titles || [];
        entries = data.entries || [];
        entryPercentages = data.entry_percentages || new Array(entries.length).fill(0);
        titlePercentages = data.title_percentages || new Array(subTitles.length).fill(0);
        
        editDisplayName = bookDetails.display_name || '';
        editSortTitle = bookDetails.sort_title || '';
      }
    } catch (e) {
      console.error('Failed to load book details', e);
      addAlert('error', 'Failed to load book chapters.');
    }
  }

  async function loadSortOption() {
    try {
      const data = await apiRequest(`/api/sort_opt?tid=${titleId}`);
      if (data && !data.error) {
        sortMethod = data.method || 'auto';
        sortAsc = data.ascend !== false;
      }
    } catch (e) {
      console.error('Failed to load sort option', e);
    }
  }

  async function loadTags() {
    try {
      const [allTagsData, bookTagsData] = await Promise.all([
        apiRequest('/api/tags'),
        apiRequest(`/api/tags/${titleId}`)
      ]);
      if (allTagsData.success) allTags = allTagsData.tags || [];
      if (bookTagsData.success) bookTags = bookTagsData.tags || [];
    } catch (e) {
      console.error('Failed to load tags', e);
    }
  }

  // Filtered sub-titles and entries
  const filteredSubTitles = $derived.by(() => {
    if (!searchQuery.trim()) return subTitles;
    const query = searchQuery.toLowerCase().trim();
    return subTitles.filter(t => (t.display_name || t.title || '').toLowerCase().includes(query));
  });

  const filteredEntries = $derived.by(() => {
    if (!searchQuery.trim()) return entries;
    const query = searchQuery.toLowerCase().trim();
    return entries.filter(e => (e.display_name || e.title || '').toLowerCase().includes(query));
  });

  // Sort change handler
  async function handleSortChange(e: Event) {
    const value = (e.target as HTMLSelectElement).value;
    const [method, dir] = value.split('-');
    const ascend = dir === 'up';

    sortMethod = method;
    sortAsc = ascend;

    try {
      const res = await apiRequest('/api/sort_opt', {
        method: 'PUT',
        body: {
          tid: titleId,
          sort: method,
          ascend: ascend
        }
      });

      if (res.success) {
        await loadBookDetails();
      } else {
        addAlert('error', res.error || 'Failed to update sorting.');
      }
    } catch (err: any) {
      addAlert('error', err.message || 'Error updating sorting.');
    }
  }

  // Tag Operations
  async function addTag(tag: string) {
    if (!tag.trim() || bookTags.includes(tag.trim())) return;
    const cleanTag = tag.trim();
    try {
      const res = await apiRequest(`/api/admin/tags/${titleId}/${encodeURIComponent(cleanTag)}`, {
        method: 'PUT'
      });
      if (res.success) {
        bookTags = [...bookTags, cleanTag];
        if (!allTags.includes(cleanTag)) {
          allTags = [...allTags, cleanTag];
        }
        newTagValue = '';
        showTagInput = false;
        addAlert('success', `Tag "${cleanTag}" added.`);
      } else {
        addAlert('error', res.error || 'Failed to add tag');
      }
    } catch (e: any) {
      addAlert('error', e.message);
    }
  }

  async function removeTag(tag: string) {
    try {
      const res = await apiRequest(`/api/admin/tags/${titleId}/${encodeURIComponent(tag)}`, {
        method: 'DELETE'
      });
      if (res.success) {
        bookTags = bookTags.filter(t => t !== tag);
        addAlert('success', `Tag "${tag}" removed.`);
      } else {
        addAlert('error', res.error || 'Failed to remove tag');
      }
    } catch (e: any) {
      addAlert('error', e.message);
    }
  }

  // Selection controls
  function toggleSelect(id: string) {
    selectedIds = {
      ...selectedIds,
      [id]: !selectedIds[id]
    };
  }

  function selectAll() {
    const newSelects: Record<string, boolean> = {};
    filteredEntries.forEach(e => {
      newSelects[e.id] = true;
    });
    selectedIds = newSelects;
  }

  function deselectAll() {
    selectedIds = {};
  }

  async function handleBulkProgress(action: 'read' | 'unread') {
    const ids = Object.entries(selectedIds)
      .filter(([_, sel]) => sel)
      .map(([id]) => id);
    
    if (ids.length === 0) return;

    try {
      const res = await apiRequest(`/api/bulk_progress/${action}/${titleId}`, {
        method: 'PUT',
        body: { ids }
      });

      if (res.success) {
        addAlert('success', `Marked ${ids.length} items as ${action}.`);
        deselectAll();
        await loadBookDetails();
      } else {
        addAlert('error', res.error || 'Failed to apply bulk changes.');
      }
    } catch (e: any) {
      addAlert('error', e.message);
    }
  }

  // Book Edit Modal functions
  async function saveBookMetadata() {
    if (!bookDetails) return;
    try {
      if (editDisplayName && editDisplayName !== bookDetails.display_name) {
        const nameRes = await apiRequest(`/api/admin/display_name/${titleId}/${encodeURIComponent(editDisplayName)}`, {
          method: 'PUT'
        });
        if (nameRes.error) {
          addAlert('error', nameRes.error);
          return;
        }
      }

      if (editSortTitle !== bookDetails.sort_title) {
        const sortRes = await apiRequest(`/api/admin/sort_title/${titleId}?name=${encodeURIComponent(editSortTitle)}`, {
          method: 'PUT'
        });
        if (sortRes.error) {
          addAlert('error', sortRes.error);
          return;
        }
      }

      addAlert('success', 'Book details updated successfully.');
      showEditBookModal = false;
      await loadBookDetails();
    } catch (e: any) {
      addAlert('error', e.message);
    }
  }

  async function handleBookCoverUpload(e: Event) {
    const target = e.target as HTMLInputElement;
    if (!target.files || target.files.length === 0) return;
    
    const file = target.files[0];
    const formData = new FormData();
    formData.append('file', file);

    editUploading = true;

    try {
      const res = await apiRequest(`/api/admin/upload/cover?tid=${titleId}`, {
        method: 'POST',
        body: formData
      });

      if (res.success) {
        addAlert('success', 'Book cover uploaded successfully.');
        await loadBookDetails();
      } else {
        addAlert('error', res.error || 'Failed to upload cover');
      }
    } catch (err: any) {
      addAlert('error', err.message || 'Error uploading cover');
    } finally {
      editUploading = false;
    }
  }

  async function markAllProgress(status: number) {
    try {
      const res = await apiRequest(`/api/progress/${titleId}/${status}`, {
        method: 'PUT'
      });
      if (res.success) {
        addAlert('success', `Marked all entries.`);
        showEditBookModal = false;
        await loadBookDetails();
      } else {
        addAlert('error', res.error || 'Failed to update all');
      }
    } catch (e: any) {
      addAlert('error', e.message);
    }
  }

  function openChapter(entry: any, index: number) {
    selectedEntry = entry;
    selectedEntryProgress = entryPercentages[index];
    showEntryModal = true;
  }
</script>

<svelte:head>
  <title>Mango - {bookDetails?.display_name || 'Loading Book...'}</title>
</svelte:head>

<div class="container">
  <!-- Bulk Selection Toolbar -->
  {#if selectedCount > 0}
    <div class="select-bar">
      <div class="select-info">
        <span class="count-badge">{selectedCount}</span> items selected
      </div>
      <div class="select-actions">
        <button class="action-btn" onclick={() => handleBulkProgress('read')} title="Mark Selected as Read">
          <i class="fas fa-check-circle"></i> Mark Read
        </button>
        <button class="action-btn" onclick={() => handleBulkProgress('unread')} title="Mark Selected as Unread">
          <i class="fas fa-times-circle"></i> Mark Unread
        </button>
      </div>
      <div class="select-all-controls">
        <button class="control-btn" onclick={selectAll}>Select All</button>
        <button class="control-btn" onclick={deselectAll}>Cancel</button>
      </div>
    </div>
  {/if}

  {#if loading}
    <div class="loading-state">
      <i class="fas fa-circle-notch fa-spin fa-3x"></i>
      <p>Loading book details...</p>
    </div>
  {:else if bookDetails}
    <!-- Breadcrumbs -->
    <nav class="breadcrumbs">
      <a href="/library">Library</a>
      {#each bookDetails.parents || [] as parent}
        <i class="fas fa-chevron-right separator"></i>
        <a href="/book/{parent.id}">{parent.display_name}</a>
      {/each}
      <i class="fas fa-chevron-right separator"></i>
      <span class="current">{bookDetails.display_name}</span>
    </nav>

    <!-- Header section -->
    <div class="book-header">
      <div class="cover-card">
        <img src={bookDetails.cover_url || '/img/banner.png'} alt={bookDetails.display_name} />
      </div>
      <div class="book-info">
        <div class="title-row">
          <h2>{bookDetails.display_name}</h2>
          {#if $isAdmin}
            <button class="edit-book-btn" onclick={() => showEditBookModal = true} title="Edit Book Settings">
              <i class="fas fa-cog"></i> Edit Settings
            </button>
          {/if}
        </div>
        
        <p class="meta-label">{bookDetails.content_label || 'No contents info'}</p>
        <p class="meta-dir"><code>{bookDetails.dir}</code></p>
        
        <!-- Tags Manager -->
        <div class="tags-container">
          {#each bookTags as tag}
            <span class="tag-capsule">
              <a href="/tags/{encodeURIComponent(tag)}">{tag}</a>
              {#if $isAdmin}
                <button class="delete-tag-btn" onclick={() => removeTag(tag)} aria-label="Remove tag">
                  &times;
                </button>
              {/if}
            </span>
          {/each}
          
          {#if $isAdmin}
            {#if showTagInput}
              <form class="new-tag-form" onsubmit={e => { e.preventDefault(); addTag(newTagValue); }}>
                <input 
                  type="text" 
                  class="tag-input" 
                  placeholder="New tag name" 
                  bind:value={newTagValue}
                  bind:this={tagInputRef}
                  onblur={() => setTimeout(() => showTagInput = false, 200)}
                />
                <button type="submit" class="add-tag-submit"><i class="fas fa-plus"></i></button>
              </form>
            {:else}
              <button class="add-tag-btn" onclick={() => { showTagInput = true; setTimeout(() => tagInputRef?.focus(), 50); }}>
                <i class="fas fa-plus"></i> Add Tag
              </button>
            {/if}
          {/if}
        </div>
      </div>
    </div>

    <!-- Search / Sort bar -->
    <div class="filters-bar">
      <div class="search-input-wrapper">
        <i class="fas fa-search search-icon"></i>
        <input 
          type="text" 
          class="input search-field" 
          placeholder="Filter chapters or sub-volumes..." 
          bind:value={searchQuery}
        />
        {#if searchQuery}
          <button class="clear-search-btn" onclick={() => searchQuery = ''}>
            <i class="fas fa-times"></i>
          </button>
        {/if}
      </div>

      <div class="sort-select-wrapper">
        <select class="select sort-dropdown" value={`${sortMethod}-${sortAsc ? 'up' : 'down'}`} onchange={handleSortChange}>
          <option value="auto-up">▲ Auto Sort</option>
          <option value="auto-down">▼ Auto Sort</option>
          <option value="title-up">▲ Name</option>
          <option value="title-down">▼ Name</option>
          <option value="time_modified-up">▲ Date Modified</option>
          <option value="time_modified-down">▼ Date Modified</option>
          <option value="time_added-up">▲ Date Added</option>
          <option value="time_added-down">▼ Date Added</option>
          <option value="progress-up">▲ Progress</option>
          <option value="progress-down">▼ Progress</option>
        </select>
      </div>
    </div>

    <!-- Volumes / Subtitles Grids -->
    {#if subTitles.length > 0}
      <div class="section-group">
        <h3 class="section-group-title">Volumes & Sub-folders</h3>
        {#if filteredSubTitles.length === 0}
          <p class="empty-info">No sub-folders match your filter.</p>
        {:else}
          <div class="card-grid">
            {#each filteredSubTitles as subTitle, idx}
              <Card 
                item={subTitle} 
                progress={titlePercentages[idx]} 
                page="title" 
                onclick={() => goto(`/book/${subTitle.id}`)}
              />
            {/each}
          </div>
        {/if}
      </div>
    {/if}

    <!-- Chapters / Entries List -->
    {#if entries.length > 0}
      <div class="section-group">
        <h3 class="section-group-title">Chapters</h3>
        {#if filteredEntries.length === 0}
          <p class="empty-info">No chapters match your filter.</p>
        {:else}
          <div class="card-grid">
            {#each filteredEntries as entry, idx}
              <Card 
                item={entry} 
                progress={entryPercentages[idx]} 
                page="title" 
                selected={!!selectedIds[entry.id]}
                selectable={$isAdmin}
                onselect={() => toggleSelect(entry.id)}
                onclick={() => openChapter(entry, idx)}
              />
            {/each}
          </div>
        {/if}
      </div>
    {/if}

    {#if subTitles.length === 0 && entries.length === 0}
      <div class="empty-book text-center">
        <i class="fas fa-folder-open empty-icon"></i>
        <h3>This title is empty</h3>
        <p>There are no chapters or sub-volumes in this manga folder.</p>
      </div>
    {/if}
  {/if}
</div>

<!-- Chapter Details Modal -->
<EntryModal
  entry={selectedEntry}
  progress={selectedEntryProgress}
  show={showEntryModal}
  onclose={() => showEntryModal = false}
  onaction={loadBookDetails}
/>

<!-- Administrative Book Edit Modal -->
{#if showEditBookModal && bookDetails}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="modal-overlay" onclick={() => showEditBookModal = false}>
    <div class="modal-content" onclick={e => e.stopPropagation()}>
      <div class="modal-header">
        <h3 class="modal-title">Edit Book: {bookDetails.title}</h3>
        <button class="modal-close" onclick={() => showEditBookModal = false}>&times;</button>
      </div>
      <div class="modal-body edit-book-body">
        <div class="form-group">
          <label class="form-label" for="book-display-name">Display Name</label>
          <input 
            id="book-display-name"
            type="text" 
            class="input" 
            bind:value={editDisplayName} 
            placeholder={bookDetails.title}
          />
        </div>

        <div class="form-group">
          <label class="form-label" for="book-sort-title">Sort Title</label>
          <input 
            id="book-sort-title"
            type="text" 
            class="input" 
            bind:value={editSortTitle} 
            placeholder={bookDetails.title}
          />
        </div>

        <div class="form-group">
          <label class="form-label">Upload Cover Image</label>
          <div class="cover-uploader">
            <div class="cover-uploader-preview">
              <img src={bookDetails.cover_url || '/img/banner.png'} alt="Preview" />
            </div>
            <div class="file-upload-zone">
              <input 
                type="file" 
                accept="image/png, image/jpeg" 
                onchange={handleBookCoverUpload} 
                disabled={editUploading}
              />
              {#if editUploading}
                <div class="upload-status"><i class="fas fa-spinner fa-spin"></i> Uploading...</div>
              {:else}
                <div class="upload-prompt">
                  <i class="fas fa-cloud-upload-alt"></i> Select New Image
                </div>
              {/if}
            </div>
          </div>
        </div>

        <div class="form-group title-bulk-progress">
          <label class="form-label">Bulk Mark Progress</label>
          <div class="bulk-progress-row">
            <button class="btn btn-secondary" onclick={() => markAllProgress(1)}>
              <i class="fas fa-check-double"></i> Mark all read (100%)
            </button>
            <button class="btn btn-secondary" onclick={() => markAllProgress(0)}>
              <i class="fas fa-undo"></i> Mark all unread (0%)
            </button>
          </div>
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" onclick={() => showEditBookModal = false}>Cancel</button>
        <button class="btn btn-primary" onclick={saveBookMetadata}>Save Details</button>
      </div>
    </div>
  </div>
{/if}

<style>
  /* Sticky Select Bar */
  .select-bar {
    position: sticky;
    top: 80px;
    z-index: 850;
    background-color: var(--bg-secondary);
    border: 1px solid var(--accent);
    border-radius: var(--border-radius-md);
    box-shadow: var(--shadow-md);
    padding: 0.75rem 1.5rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 1rem;
    margin-bottom: 1.5rem;
  }

  @media (max-width: 600px) {
    .select-bar {
      flex-direction: column;
      align-items: stretch;
      gap: 0.75rem;
    }
  }

  .select-info {
    font-weight: 500;
    color: var(--text-primary);
  }

  .count-badge {
    background-color: var(--accent);
    color: #ffffff;
    font-weight: 700;
    font-size: 0.85rem;
    padding: 0.15rem 0.5rem;
    border-radius: 9999px;
  }

  .select-actions {
    display: flex;
    gap: 0.5rem;
  }

  .select-actions .action-btn {
    background-color: var(--accent-light);
    color: var(--accent);
    border: 1px solid transparent;
    padding: 0.4rem 0.875rem;
    font-weight: 600;
    font-size: 0.85rem;
    border-radius: var(--border-radius-sm);
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 0.35rem;
    transition: all 0.15s ease;
  }

  .select-actions .action-btn:hover {
    background-color: var(--accent);
    color: #ffffff;
  }

  .select-all-controls {
    display: flex;
    gap: 0.5rem;
  }

  .control-btn {
    background: transparent;
    border: none;
    color: var(--text-secondary);
    font-weight: 500;
    font-size: 0.85rem;
    cursor: pointer;
    padding: 0.25rem 0.5rem;
  }

  .control-btn:hover {
    color: var(--text-primary);
  }

  /* Breadcrumbs */
  .breadcrumbs {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
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

  /* Book Info Header */
  .book-header {
    display: flex;
    gap: 2rem;
    margin-bottom: 2.5rem;
  }

  @media (max-width: 600px) {
    .book-header {
      flex-direction: column;
      align-items: center;
      text-align: center;
      gap: 1.25rem;
    }
  }

  .cover-card {
    width: 150px;
    aspect-ratio: 2 / 3;
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-md);
    overflow: hidden;
    box-shadow: var(--shadow-md);
    flex-shrink: 0;
  }

  .cover-card img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .book-info {
    display: flex;
    flex-direction: column;
    justify-content: center;
    gap: 0.5rem;
    flex-grow: 1;
  }

  .title-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    flex-wrap: wrap;
  }

  @media (max-width: 600px) {
    .title-row {
      justify-content: center;
    }
  }

  .title-row h2 {
    font-size: 1.75rem;
    font-weight: 750;
  }

  .edit-book-btn {
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    color: var(--text-primary);
    padding: 0.5rem 1rem;
    font-size: 0.85rem;
    font-weight: 500;
    border-radius: var(--border-radius-sm);
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 0.375rem;
    transition: all 0.15s ease;
    font-family: var(--font-body);
  }

  .edit-book-btn:hover {
    border-color: var(--accent);
    color: var(--accent);
  }

  .meta-label {
    font-weight: 500;
    color: var(--text-secondary);
  }

  .meta-dir {
    font-size: 0.8rem;
    color: var(--text-muted);
    word-break: break-all;
  }

  /* Tags Management capsules */
  .tags-container {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin-top: 0.75rem;
  }

  @media (max-width: 600px) {
    .tags-container {
      justify-content: center;
    }
  }

  .tag-capsule {
    display: inline-flex;
    align-items: center;
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    padding: 0.25rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.8rem;
    font-weight: 500;
    gap: 0.35rem;
  }

  .tag-capsule a {
    color: var(--text-primary);
  }

  .tag-capsule a:hover {
    color: var(--accent);
  }

  .delete-tag-btn {
    background: transparent;
    border: none;
    color: var(--text-muted);
    cursor: pointer;
    font-size: 1.1rem;
    line-height: 1;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .delete-tag-btn:hover {
    color: var(--error);
  }

  .add-tag-btn {
    background-color: var(--accent-light);
    color: var(--accent);
    border: 1px solid transparent;
    padding: 0.25rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.8rem;
    font-weight: 600;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    transition: all 0.15s ease;
  }

  .add-tag-btn:hover {
    background-color: var(--accent);
    color: #ffffff;
  }

  .new-tag-form {
    display: inline-flex;
    align-items: center;
    background-color: var(--bg-secondary);
    border: 1px solid var(--accent);
    border-radius: 9999px;
    padding: 0.1rem 0.5rem;
  }

  .tag-input {
    border: none;
    background: transparent;
    outline: none;
    font-size: 0.8rem;
    padding: 0.15rem 0.35rem;
    color: var(--text-primary);
    width: 100px;
  }

  .add-tag-submit {
    background: transparent;
    border: none;
    color: var(--accent);
    cursor: pointer;
    font-size: 0.8rem;
    padding: 0.25rem;
  }

  /* Filters list */
  .filters-bar {
    display: flex;
    justify-content: space-between;
    gap: 1.5rem;
    margin-bottom: 2rem;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 1.25rem;
  }

  @media (max-width: 600px) {
    .filters-bar {
      flex-direction: column;
      align-items: stretch;
      gap: 0.75rem;
    }
  }

  .search-input-wrapper {
    position: relative;
    flex-grow: 1;
    max-width: 600px;
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

  /* Chapter Grids list */
  .section-group {
    margin-bottom: 3rem;
  }

  .section-group-title {
    font-family: var(--font-title);
    font-size: 1.25rem;
    font-weight: 700;
    margin-bottom: 1rem;
    color: var(--text-primary);
  }

  .empty-info {
    color: var(--text-secondary);
    font-size: 0.9rem;
    font-style: italic;
  }

  .empty-book {
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

  .empty-book h3 {
    margin-bottom: 0.5rem;
  }

  .empty-book p {
    color: var(--text-secondary);
  }

  /* Uploader preview */
  .edit-book-body {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .cover-uploader {
    display: flex;
    gap: 1rem;
    align-items: center;
  }

  .cover-uploader-preview {
    width: 80px;
    aspect-ratio: 2 / 3;
    border-radius: var(--border-radius-sm);
    overflow: hidden;
    border: 1px solid var(--border-color);
    background-color: var(--bg-tertiary);
    flex-shrink: 0;
  }

  .cover-uploader-preview img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .cover-uploader .file-upload-zone {
    flex-grow: 1;
    border: 2px dashed var(--border-color);
    border-radius: var(--border-radius-sm);
    padding: 1rem;
    text-align: center;
    position: relative;
    cursor: pointer;
    background-color: var(--bg-primary);
  }

  .cover-uploader .file-upload-zone:hover {
    border-color: var(--accent);
  }

  .cover-uploader .file-upload-zone input {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    opacity: 0;
    cursor: pointer;
  }

  .bulk-progress-row {
    display: flex;
    gap: 0.75rem;
  }

  .bulk-progress-row .btn {
    flex: 1;
  }

  @media (max-width: 480px) {
    .bulk-progress-row {
      flex-direction: column;
      gap: 0.5rem;
    }
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
</style>
