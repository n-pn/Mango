<script lang="ts">
  let { 
    item, 
    progress = -1, 
    groupedCount = 1, 
    page = 'home', 
    onclick = null, 
    onselect = null,
    selected = false,
    selectable = false
  } = $props();

  const isEntry = $derived(item && 'zip_path' in item);
  const displayName = $derived(item?.display_name || item?.title || 'Unknown');
  const coverUrl = $derived(item?.cover_url || '/img/banner.png');
  const progressPercent = $derived(progress >= 0 ? progress * 100 : -1);

  let hover = $state(false);

  function handleClick(e: MouseEvent) {
    if (selectable && onselect) {
      e.stopPropagation();
      onselect();
      return;
    }
    if (onclick) {
      onclick();
    }
  }
</script>

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div 
  class="card-wrapper"
  class:selected={selected && selectable}
  onclick={handleClick}
  onmouseenter={() => hover = true}
  onmouseleave={() => hover = false}
>
  <div class="card">
    <div class="card-media">
      <img 
        src={coverUrl} 
        alt={displayName} 
        class:grayscale={isEntry && item?.err_msg}
        loading="lazy"
      />
      
      {#if selectable || (hover && isEntry && !item?.err_msg)}
        <div class="overlay" class:visible={selected || hover}>
          {#if selectable}
            <button 
              class="select-btn" 
              class:checked={selected}
              onclick={(e) => { e.stopPropagation(); onselect && onselect(); }}
              aria-label="Select item"
            >
              <i class="fas fa-check-circle"></i>
            </button>
          {/if}
        </div>
      {/if}
    </div>

    <div class="card-body">
      {#if progressPercent >= 0 && progressPercent <= 100}
        <div class="card-badge" title="Reading Progress: {progressPercent.toFixed(1)}%">
          {progressPercent.toFixed(0)}%
        </div>
      {/if}

      <h3 class="card-title" title={displayName}>
        {displayName}
      </h3>

      {#if page === 'home' && isEntry && item?.book}
        <a 
          href="/book/{item.book.id || item.title_id}" 
          class="card-subtitle"
          onclick={(e) => e.stopPropagation()}
        >
          {item.book.display_name || item.book.title}
        </a>
      {/if}

      {#if isEntry}
        {#if item?.err_msg}
          <div class="error-badge" title={item.err_msg}>
            <i class="fas fa-exclamation-triangle"></i> Error
          </div>
        {:else}
          <p class="card-meta-text">{item.pages || 0} pages</p>
        {/if}
      {:else if item}
        {#if groupedCount > 1}
          <p class="card-meta-text">{groupedCount} new entries</p>
        {:else}
          <p class="card-meta-text">
            {item.content_label || `${item.entries?.length || 0} chapters`}
          </p>
        {/if}
      {/if}
      
      {#if progressPercent > 0 && progressPercent < 100}
        <div class="progress-bar-container">
          <div class="progress-bar" style="width: {progressPercent}%"></div>
        </div>
      {/if}
    </div>
  </div>
</div>

<style>
  .card-wrapper {
    cursor: pointer;
    transition: transform 0.2s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.2s ease;
    height: 100%;
  }

  .card-wrapper:hover {
    transform: translateY(-6px);
  }

  .card {
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-md);
    overflow: hidden;
    height: 100%;
    display: flex;
    flex-direction: column;
    box-shadow: var(--shadow-sm);
    position: relative;
    transition: border-color 0.2s ease;
  }

  .card-wrapper.selected .card {
    border-color: var(--accent);
    box-shadow: 0 0 0 2px var(--accent-light);
  }

  .card-media {
    aspect-ratio: 2 / 3;
    position: relative;
    background-color: var(--bg-tertiary);
    overflow: hidden;
  }

  .card-media img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .grayscale {
    filter: grayscale(100%);
    opacity: 0.8;
  }

  /* Selection overlay */
  .overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(0, 0, 0, 0.4);
    opacity: 0;
    transition: opacity 0.15s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    pointer-events: none;
  }

  .overlay.visible {
    opacity: 1;
    pointer-events: auto;
  }

  .select-btn {
    background: transparent;
    border: none;
    color: rgba(255, 255, 255, 0.7);
    font-size: 2.5rem;
    cursor: pointer;
    transition: color 0.15s ease, transform 0.15s ease;
  }

  .select-btn:hover {
    transform: scale(1.1);
    color: #ffffff;
  }

  .select-btn.checked {
    color: var(--accent);
  }

  .card-body {
    padding: 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
    flex-grow: 1;
  }

  .card-badge {
    position: absolute;
    top: 0.75rem;
    right: 0.75rem;
    background-color: rgba(0, 0, 0, 0.75);
    color: #ffffff;
    font-size: 0.75rem;
    font-weight: 700;
    padding: 0.25rem 0.5rem;
    border-radius: var(--border-radius-sm);
    backdrop-filter: blur(4px);
    z-index: 10;
  }

  .card-title {
    font-family: var(--font-title);
    font-size: 0.95rem;
    font-weight: 600;
    color: var(--text-primary);
    line-height: 1.35;
    margin: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
  }

  .card-subtitle {
    font-size: 0.8rem;
    color: var(--text-secondary);
    display: inline-block;
    width: fit-content;
  }

  .card-subtitle:hover {
    color: var(--accent);
  }

  .card-meta-text {
    font-size: 0.8rem;
    color: var(--text-muted);
    margin: 0;
    margin-top: auto;
  }

  .error-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    font-size: 0.8rem;
    font-weight: 600;
    color: var(--error);
    margin-top: auto;
  }

  .progress-bar-container {
    width: 100%;
    height: 4px;
    background-color: var(--bg-tertiary);
    border-radius: 2px;
    overflow: hidden;
    margin-top: 0.5rem;
  }

  .progress-bar {
    height: 100%;
    background-color: var(--accent);
  }
</style>
