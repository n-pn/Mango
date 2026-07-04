<script lang="ts">
  import { apiRequest } from '$lib/utils/api';
  import { appState, addAlert } from '$lib/utils/store.svelte';

  let { 
    entry, 
    progress = 0, 
    show = false, 
    onclose, 
    onaction 
  } = $props();

  let isEditing = $state(false);
  let displayNameField = $state('');
  let sortTitleField = $state('');
  let uploading = $state(false);
  let uploadProgress = $state(0);

  // Initialize edit fields when entry changes or modal opens
  $effect(() => {
    if (show && entry) {
      displayNameField = entry.display_name || '';
      sortTitleField = entry.sort_title || '';
      isEditing = false;
    }
  });

  async function updateProgress(targetPage: number) {
    if (!entry) return;
    try {
      const data = await apiRequest(`/api/progress/${entry.title_id}/${targetPage}`, {
        method: 'PUT',
        headers: {},
        // Kemal expects eid in query param
        body: null
      });
      // wait, let's verify if apiRequest appends the query param
      // The original endpoint: /api/progress/:tid/:page?eid=xxx
      const url = `/api/progress/${entry.title_id}/${targetPage}?eid=${entry.id}`;
      const res = await apiRequest(url, { method: 'PUT' });
      
      if (res.success) {
        addAlert('success', `Progress updated successfully.`);
        if (onaction) onaction();
        onclose();
      } else {
        addAlert('error', res.error || 'Failed to update progress');
      }
    } catch (e: any) {
      addAlert('error', e.message);
    }
  }

  async function saveMetadata() {
    if (!entry) return;
    try {
      // 1. Save display name
      if (displayNameField && displayNameField !== entry.display_name) {
        const nameUrl = `/api/admin/display_name/${entry.title_id}/${encodeURIComponent(displayNameField)}?eid=${entry.id}`;
        const nameRes = await apiRequest(nameUrl, { method: 'PUT' });
        if (nameRes.error) {
          addAlert('error', nameRes.error);
          return;
        }
      }

      // 2. Save sort title
      if (sortTitleField !== entry.sort_title) {
        const sortUrl = `/api/admin/sort_title/${entry.title_id}?eid=${entry.id}&name=${encodeURIComponent(sortTitleField)}`;
        const sortRes = await apiRequest(sortUrl, { method: 'PUT' });
        if (sortRes.error) {
          addAlert('error', sortRes.error);
          return;
        }
      }

      addAlert('success', 'Metadata updated successfully.');
      isEditing = false;
      if (onaction) onaction();
    } catch (e: any) {
      addAlert('error', e.message);
    }
  }

  async function handleCoverUpload(e: Event) {
    const target = e.target as HTMLInputElement;
    if (!target.files || target.files.length === 0 || !entry) return;
    
    const file = target.files[0];
    const formData = new FormData();
    formData.append('file', file);

    uploading = true;
    uploadProgress = 0;

    try {
      const url = `/api/admin/upload/cover?tid=${entry.title_id}&eid=${entry.id}`;
      const res = await apiRequest(url, {
        method: 'POST',
        body: formData
      });

      if (res.success) {
        addAlert('success', 'Cover uploaded successfully.');
        if (onaction) onaction();
      } else {
        addAlert('error', res.error || 'Failed to upload cover');
      }
    } catch (err: any) {
      addAlert('error', err.message || 'Error uploading cover');
    } finally {
      uploading = false;
    }
  }
</script>

{#if show && entry}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="modal-overlay" onclick={onclose}>
    <div class="modal-content" onclick={e => e.stopPropagation()}>
      <div class="modal-header">
        <h3 class="modal-title break-word">
          {entry.display_name}
          
          <div class="header-actions">
            {#if appState.isAdmin}
              <button 
                class="icon-btn" 
                class:active={isEditing}
                onclick={() => isEditing = !isEditing}
                title="Edit Metadata"
              >
                <i class="fas fa-pencil-alt"></i>
              </button>
            {/if}
            <a 
              href="/api/download/{entry.title_id}/{entry.id}" 
              class="icon-btn-link"
              title="Download Chapter"
              download
            >
              <i class="fas fa-download"></i>
            </a>
          </div>
        </h3>
        <button class="modal-close" onclick={onclose}>&times;</button>
      </div>

      <div class="modal-body">
        <p class="meta-path"><code>{entry.path}</code></p>
        <p class="meta-pages">{entry.pages} pages • Progress: {progress.toFixed(1)}%</p>
        
        {#if isEditing}
          <!-- Metadata Editing Form -->
          <div class="edit-form">
            <h4 class="section-title">Edit Details</h4>
            
            <div class="form-group">
              <label class="form-label" for="edit-display-name">Display Name</label>
              <input
                id="edit-display-name"
                type="text"
                class="input"
                bind:value={displayNameField}
                placeholder={entry.title}
              />
            </div>

            <div class="form-group">
              <label class="form-label" for="edit-sort-title">Sort Title</label>
              <input
                id="edit-sort-title"
                type="text"
                class="input"
                bind:value={sortTitleField}
                placeholder={entry.title}
              />
            </div>

            <div class="form-group">
              <label class="form-label" for="cover-upload-file">Upload Cover (PNG/JPG)</label>
              <div class="file-upload-zone">
                <input 
                  id="cover-upload-file" 
                  type="file" 
                  accept="image/png, image/jpeg" 
                  onchange={handleCoverUpload}
                  disabled={uploading} 
                />
                {#if uploading}
                  <div class="upload-status">
                    <i class="fas fa-spinner fa-spin"></i> Uploading...
                  </div>
                {:else}
                  <div class="upload-prompt">
                    <i class="fas fa-cloud-upload-alt"></i> Click to select image
                  </div>
                {/if}
              </div>
            </div>

            <div class="form-actions">
              <button class="btn btn-secondary" onclick={() => isEditing = false}>Cancel</button>
              <button class="btn btn-primary" onclick={saveMetadata}>Save Changes</button>
            </div>
          </div>
        {:else}
          <!-- Read Actions -->
          <div class="action-section">
            <h4 class="section-title">Read</h4>
            <div class="button-row">
              <a href="/reader/{entry.title_id}/{entry.id}/1" class="btn btn-secondary">
                <i class="fas fa-book-open"></i> From Beginning
              </a>
              <a href="/reader/{entry.title_id}/{entry.id}" class="btn btn-primary">
                {#if progress > 0 && progress < 100}
                  <i class="fas fa-play"></i> Continue from {progress.toFixed(0)}%
                {:else}
                  <i class="fas fa-play"></i> Read Chapter
                {/if}
              </a>
            </div>
          </div>

          <!-- Progress Actions -->
          <div class="action-section">
            <h4 class="section-title">Change Progress</h4>
            <div class="button-row">
              <button class="btn btn-secondary" onclick={() => updateProgress(0)}>
                <i class="fas fa-history"></i> Mark as Unread (0%)
              </button>
              <button class="btn btn-secondary" onclick={() => updateProgress(entry.pages)}>
                <i class="fas fa-check"></i> Mark as Read (100%)
              </button>
            </div>
          </div>
        {/if}
      </div>

      <div class="modal-footer">
        <button class="btn btn-secondary" onclick={onclose}>Close</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .header-actions {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    margin-left: 0.75rem;
  }

  .icon-btn, .icon-btn-link {
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    color: var(--text-secondary);
    width: 32px;
    height: 32px;
    border-radius: 50%;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    font-size: 0.85rem;
    transition: all 0.15s ease;
  }

  .icon-btn:hover, .icon-btn-link:hover {
    color: var(--accent);
    border-color: var(--accent);
    background-color: var(--accent-light);
  }

  .icon-btn.active {
    color: #ffffff;
    background-color: var(--accent);
    border-color: var(--accent);
  }

  .meta-path {
    font-size: 0.8rem;
    color: var(--text-secondary);
    margin-bottom: 0.25rem;
    word-break: break-all;
  }

  .meta-pages {
    font-size: 0.85rem;
    color: var(--text-muted);
    margin-bottom: 1.25rem;
  }

  .action-section {
    margin-bottom: 1.5rem;
  }

  .section-title {
    font-family: var(--font-title);
    font-size: 0.9rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--text-muted);
    margin-bottom: 0.75rem;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 0.25rem;
  }

  .button-row {
    display: flex;
    gap: 0.75rem;
  }

  @media (max-width: 600px) {
    .button-row {
      flex-direction: column;
    }
  }

  .button-row .btn {
    flex: 1;
  }

  /* Edit Form */
  .edit-form {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    background-color: var(--bg-primary);
    padding: 1.25rem;
    border-radius: var(--border-radius-md);
    border: 1px solid var(--border-color);
  }

  .file-upload-zone {
    border: 2px dashed var(--border-color);
    border-radius: var(--border-radius-sm);
    padding: 1.5rem;
    text-align: center;
    position: relative;
    cursor: pointer;
    background-color: var(--bg-secondary);
    transition: border-color 0.15s ease;
  }

  .file-upload-zone:hover {
    border-color: var(--accent);
  }

  .file-upload-zone input {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    opacity: 0;
    cursor: pointer;
  }

  .upload-prompt {
    color: var(--text-secondary);
    font-size: 0.875rem;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.5rem;
  }

  .upload-prompt i {
    font-size: 1.5rem;
    color: var(--text-muted);
  }

  .upload-status {
    color: var(--accent);
    font-weight: 500;
    font-size: 0.875rem;
  }

  .form-actions {
    display: flex;
    justify-content: flex-end;
    gap: 0.75rem;
    margin-top: 0.5rem;
  }
</style>
