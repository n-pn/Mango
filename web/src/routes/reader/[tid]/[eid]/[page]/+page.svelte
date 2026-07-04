<script lang="ts">
  import { onMount, tick } from 'svelte';
  import { page as sveltePage } from '$app/stores';
  import { goto, replaceState } from '$app/navigation';
  import { apiRequest, getPageUrl } from '$lib/utils/api';
  import { addAlert } from '$lib/utils/store';

  // URL Parameters
  let tid = $derived($sveltePage.params.tid);
  let eid = $derived($sveltePage.params.eid);
  let initialPage = $derived(parseInt($sveltePage.params.page) || 1);

  // States
  let loading = $state(true);
  let errMsg = $state('');
  let items = $state<any[]>([]);
  let book = $state<any>(null);
  let entry = $state<any>(null);

  // Reader Settings (Synced to localStorage)
  let mode = $state<'continuous' | 'paged'>('continuous');
  let margin = $state(30);
  let fitType = $state<'vert' | 'horz' | 'real'>('vert');
  let preloadLookahead = $state(3);
  let enableFlipAnimation = $state(true);
  let enableRightToLeft = $state(false);

  // Navigation / Control state
  let currentPage = $state(1);
  let showControls = $state(false);
  let lastSavedPage = $state(1);
  let longPages = $state(false);
  let flipAnimation = $state<'left' | 'right' | null>(null);

  // Intersection Observer for continuous scrolling
  let observer: IntersectionObserver | null = null;
  let isScrollingToPage = false;

  // Derive next and previous chapters
  const entryIndex = $derived(book?.entries?.findIndex((e: any) => e.id === eid) ?? -1);
  const nextEntry = $derived(entryIndex !== -1 && entryIndex + 1 < book.entries.length ? book.entries[entryIndex + 1] : null);
  const prevEntry = $derived(entryIndex !== -1 && entryIndex - 1 >= 0 ? book.entries[entryIndex - 1] : null);

  onMount(async () => {
    // Hide default global layout elements (like navigation header/sidebar) if reader is active
    document.body.classList.add('reader-active');
    
    // Load Saved Settings
    mode = (localStorage.getItem('mode') as 'continuous' | 'paged') || 'continuous';
    margin = parseInt(localStorage.getItem('margin') || '30');
    fitType = (localStorage.getItem('fitType') as 'vert' | 'horz' | 'real') || 'vert';
    preloadLookahead = parseInt(localStorage.getItem('preloadLookahead') ?? '3');
    enableFlipAnimation = localStorage.getItem('enableFlipAnimation') !== 'false';
    enableRightToLeft = localStorage.getItem('enableRightToLeft') === 'true';

    await initializeReader();

    // Listeners
    window.addEventListener('keydown', handleKeydown);
    window.addEventListener('resize', handleResize);

    return () => {
      document.body.classList.remove('reader-active');
      window.removeEventListener('keydown', handleKeydown);
      window.removeEventListener('resize', handleResize);
      if (observer) observer.disconnect();
    };
  });

  // Handle reload if TID or EID changes
  $effect(() => {
    if (tid && eid) {
      currentPage = initialPage;
      initializeReader();
    }
  });

  // Watch continuous mode scroll target
  $effect(() => {
    if (mode === 'continuous' && items.length > 0) {
      tick().then(setupIntersectionObserver);
    } else {
      if (observer) {
        observer.disconnect();
        observer = null;
      }
    }
  });

  async function initializeReader() {
    loading = true;
    errMsg = '';
    try {
      // 1. Fetch Book info (to populate entry dropdowns)
      const bookData = await apiRequest(`/api/book/${tid}`);
      if (bookData) {
        book = bookData;
        entry = book.entries?.find((e: any) => e.id === eid);
      }

      // 2. Fetch Page Dimensions
      const dimData = await apiRequest(`/api/dimensions/${tid}/${eid}`);
      if (dimData && dimData.dimensions) {
        const dimensions = dimData.dimensions;
        items = dimensions.map((d: any, i: number) => ({
          id: i + 1,
          url: getPageUrl(tid, eid, i + 1),
          width: d.width === 0 ? '100%' : d.width,
          height: d.height === 0 ? '100%' : d.height,
        }));

        // Compute average ratio
        const avgRatio = dimensions.reduce((acc: number, cur: any) => {
          return acc + (cur.width > 0 ? cur.height / cur.width : 1.4);
        }, 0) / dimensions.length;

        longPages = avgRatio > 2;
        currentPage = initialPage;
        lastSavedPage = initialPage;

        // Auto Scroll to initial page if continuous
        if (mode === 'continuous') {
          tick().then(() => scrollToPage(initialPage));
        } else {
          preloadNextPages(initialPage);
        }
      } else {
        throw new Error(dimData.error || 'Failed to load dimensions');
      }
    } catch (e: any) {
      console.error(e);
      errMsg = e.message || 'Error initializing reader';
      addAlert('error', errMsg);
    } finally {
      loading = false;
    }
  }

  function setupIntersectionObserver() {
    if (observer) observer.disconnect();
    
    observer = new IntersectionObserver((entriesList) => {
      if (isScrollingToPage) return;

      entriesList.forEach(entryItem => {
        if (entryItem.isIntersecting) {
          const id = parseInt(entryItem.target.id);
          if (id && id !== currentPage) {
            currentPage = id;
            updateUrlAndProgress(id);
          }
        }
      });
    }, {
      rootMargin: '-20% 0px -50% 0px',
      threshold: 0
    });

    items.forEach(item => {
      const el = document.getElementById(`page-img-${item.id}`);
      if (el) observer?.observe(el);
    });
  }

  function preloadNextPages(pageIdx: number) {
    const limit = Math.min(pageIdx + preloadLookahead, items.length);
    for (let i = pageIdx + 1; i <= limit; i++) {
      const img = new Image();
      img.src = items[i - 1].url;
    }
  }

  function scrollToPage(pageIdx: number) {
    const el = document.getElementById(`page-img-${pageIdx}`);
    if (el) {
      isScrollingToPage = true;
      el.scrollIntoView({ block: 'start' });
      // Clear scroll lock flag after scroll animation
      setTimeout(() => {
        isScrollingToPage = false;
      }, 500);
    }
  }

  function handlePageJump(pageIdx: number) {
    currentPage = pageIdx;
    showControls = false;
    if (mode === 'continuous') {
      scrollToPage(pageIdx);
    } else {
      preloadNextPages(pageIdx);
    }
    updateUrlAndProgress(pageIdx);
  }

  function updateUrlAndProgress(pageIdx: number) {
    // 1. Update browser path without full SvelteKit navigation
    const path = `/reader/${tid}/${eid}/${pageIdx}`;
    replaceState(path, {});

    // 2. Save Progress to backend
    saveProgress(pageIdx);
  }

  async function saveProgress(pageIdx: number, force = false) {
    const pageNum = parseInt(pageIdx as any);
    const diff = Math.abs(pageNum - lastSavedPage);
    
    if (force || diff >= 5 || longPages || pageNum === 1 || pageNum === items.length) {
      lastSavedPage = pageNum;
      try {
        const url = `/api/progress/${tid}/${pageNum}?eid=${eid}`;
        await fetch(url, { method: 'PUT' });
      } catch (e) {
        console.error('Failed to save progress', e);
      }
    }
  }

  function handleResize() {
    if (mode === 'continuous') return;
    // Auto page orientation fit adjustments if resizing
  }

  function handleKeydown(e: KeyboardEvent) {
    if (mode === 'continuous') return;
    
    if (e.key === 'ArrowLeft' || e.key === 'k') {
      flipPage(false ^ (enableRightToLeft ? 1 : 0));
    } else if (e.key === 'ArrowRight' || e.key === 'j') {
      flipPage(true ^ (enableRightToLeft ? 1 : 0));
    }
  }

  function flipPage(isNext: boolean | number) {
    const target = currentPage + (isNext ? 1 : -1);
    if (target <= 0) return;
    
    if (target > items.length) {
      // Show controls when reaching the end
      showControls = true;
      return;
    }

    // Animation
    if (enableFlipAnimation) {
      flipAnimation = (isNext ^ (enableRightToLeft ? 1 : 0)) ? 'right' : 'left';
      setTimeout(() => {
        flipAnimation = null;
      }, 300);
    }

    currentPage = target;
    preloadNextPages(target);
    updateUrlAndProgress(target);
  }

  // Tap trigger sections
  function handleReaderClick(e: MouseEvent) {
    const width = window.innerWidth;
    const x = e.clientX;
    const leftLimit = width * 0.3;
    const rightLimit = width * 0.7;

    if (mode === 'continuous') {
      // Toggle controls overlay
      showControls = !showControls;
    } else {
      if (x < leftLimit) {
        flipPage(false ^ (enableRightToLeft ? 1 : 0));
      } else if (x > rightLimit) {
        flipPage(true ^ (enableRightToLeft ? 1 : 0));
      } else {
        showControls = !showControls;
      }
    }
  }

  // Chapter switches
  async function exitReader() {
    await saveProgress(items.length, true);
    goto(`/book/${tid}`);
  }

  async function navigateToEntry(nextEid: string) {
    await saveProgress(items.length, true);
    goto(`/reader/${tid}/${nextEid}/1`);
  }

  // Settings update functions
  function updateSetting(key: string, value: any) {
    localStorage.setItem(key, String(value));
    if (key === 'mode') {
      mode = value;
      if (mode === 'continuous') {
        tick().then(() => scrollToPage(currentPage));
      }
    }
  }
</script>

<svelte:head>
  <title>Mango Reader - {entry?.display_name || 'Loading...'}</title>
</svelte:head>

<div class="reader-container">
  {#if loading}
    <div class="reader-loader">
      <i class="fas fa-spinner fa-spin fa-3x"></i>
      <p>Loading pages...</p>
    </div>
  {:else if errMsg}
    <div class="reader-error">
      <i class="fas fa-exclamation-triangle fa-3x"></i>
      <h3>Error Loading Reader</h3>
      <p>{errMsg}</p>
      <button class="btn btn-primary" onclick={() => goto(`/book/${tid}`)}>Exit Reader</button>
    </div>
  {:else}
    <!-- Reader content view -->
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="reader-workspace" onclick={handleReaderClick}>
      {#if mode === 'continuous'}
        <!-- Continuous Mode Grid -->
        <div class="continuous-flow">
          {#each items as item (item.id)}
            <img
              id="page-img-{item.id}"
              src={item.url}
              alt="Page {item.id}"
              class="continuous-img"
              style="margin-top: {margin}px; margin-bottom: {margin}px;"
              width={item.width}
              height={item.height}
            />
          {/each}
          
          <div class="reader-flow-footer">
            {#if nextEntry}
              <button class="btn btn-primary" onclick={(e) => { e.stopPropagation(); navigateToEntry(nextEntry.id); }}>
                Next Chapter: {nextEntry.display_name} <i class="fas fa-chevron-right"></i>
              </button>
            {:else}
              <button class="btn btn-secondary" onclick={(e) => { e.stopPropagation(); exitReader(); }}>
                <i class="fas fa-sign-out-alt"></i> Return to Title Info
              </button>
            {/if}
          </div>
        </div>
      {:else}
        <!-- Paged Single Mode -->
        <!-- svelte-ignore a11y_alt_text -->
        <div 
          class="paged-view"
          class:fit-height={fitType === 'vert'}
          class:fit-width={fitType === 'horz'}
          class:fit-real={fitType === 'real'}
        >
          <img 
            src={items[currentPage - 1].url}
            class="paged-img"
            class:animate-left={flipAnimation === 'left'}
            class:animate-right={flipAnimation === 'right'}
          />
          <div class="tap-indicator left-tap"></div>
          <div class="tap-indicator right-tap"></div>
        </div>
      {/if}
    </div>
  {/if}

  <!-- Controls overlay drawer -->
  {#if showControls && !loading}
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="controls-overlay" onclick={() => showControls = false}>
      <div class="controls-panel" onclick={e => e.stopPropagation()}>
        <div class="panel-header">
          <div class="panel-title-group">
            <h4>{entry?.display_name}</h4>
            <span class="meta-detail">{currentPage} / {items.length} pages</span>
          </div>
          <button class="panel-close-btn" onclick={() => showControls = false}>&times;</button>
        </div>

        <div class="panel-body">
          <!-- Page Jumper -->
          <div class="panel-row">
            <label for="page-jumper">Jump to Page</label>
            <select 
              id="page-jumper" 
              class="select" 
              value={currentPage}
              onchange={e => handlePageJump(parseInt((e.target as HTMLSelectElement).value))}
            >
              {#each items as item}
                <option value={item.id}>Page {item.id}</option>
              {/each}
            </select>
          </div>

          <!-- Reader Mode -->
          <div class="panel-row">
            <label for="reader-mode">Reader Mode</label>
            <select 
              id="reader-mode" 
              class="select" 
              value={mode}
              onchange={e => updateSetting('mode', (e.target as HTMLSelectElement).value)}
            >
              <option value="continuous">Continuous Vertical</option>
              <option value="paged">Paged Single</option>
            </select>
          </div>

          <!-- Paged Settings -->
          {#if mode === 'paged'}
            <div class="panel-row">
              <label for="fit-type">Page Fit Type</label>
              <select 
                id="fit-type" 
                class="select" 
                value={fitType}
                onchange={e => updateSetting('fitType', (e.target as HTMLSelectElement).value)}
              >
                <option value="vert">Fit Height (100vh)</option>
                <option value="horz">Fit Width (100vw)</option>
                <option value="real">Real Size</option>
              </select>
            </div>

            <div class="panel-row toggle-row">
              <label for="rtl-toggle" class="checkbox-group">
                <input 
                  id="rtl-toggle" 
                  type="checkbox" 
                  class="checkbox" 
                  checked={enableRightToLeft} 
                  onchange={e => { enableRightToLeft = (e.target as HTMLInputElement).checked; updateSetting('enableRightToLeft', enableRightToLeft); }}
                />
                Right to Left (RTL)
              </label>
            </div>

            <div class="panel-row toggle-row">
              <label for="anim-toggle" class="checkbox-group">
                <input 
                  id="anim-toggle" 
                  type="checkbox" 
                  class="checkbox" 
                  checked={enableFlipAnimation}
                  onchange={e => { enableFlipAnimation = (e.target as HTMLInputElement).checked; updateSetting('enableFlipAnimation', enableFlipAnimation); }}
                />
                Flip Animations
              </label>
            </div>

            <div class="panel-row">
              <label for="preload-range">Preload: {preloadLookahead} pages</label>
              <input 
                id="preload-range" 
                type="range" 
                min="0" 
                max="5" 
                class="range-slider" 
                value={preloadLookahead}
                onchange={e => { preloadLookahead = parseInt((e.target as HTMLInputElement).value); updateSetting('preloadLookahead', preloadLookahead); }}
              />
            </div>
          {:else}
            <!-- Continuous Settings -->
            <div class="panel-row">
              <label for="margin-range">Page Margin: {margin}px</label>
              <input 
                id="margin-range" 
                type="range" 
                min="0" 
                max="50" 
                step="5" 
                class="range-slider" 
                value={margin}
                onchange={e => { margin = parseInt((e.target as HTMLInputElement).value); updateSetting('margin', margin); }}
              />
            </div>
          {/if}

          <!-- Chapter list jumper -->
          {#if book && book.entries}
            <div class="panel-row">
              <label for="entry-jumper">Jump to Chapter</label>
              <select 
                id="entry-jumper" 
                class="select" 
                value={eid}
                onchange={e => navigateToEntry((e.target as HTMLSelectElement).value)}
              >
                {#each book.entries as ch}
                  <option value={ch.id}>{ch.display_name}</option>
                {/each}
              </select>
            </div>
          {/if}
        </div>

        <div class="panel-footer">
          <div class="chapter-nav-buttons">
            {#if prevEntry}
              <button class="btn btn-secondary" onclick={() => navigateToEntry(prevEntry.id)}>
                <i class="fas fa-chevron-left"></i> Prev
              </button>
            {/if}
            {#if nextEntry}
              <button class="btn btn-secondary" onclick={() => navigateToEntry(nextEntry.id)}>
                Next <i class="fas fa-chevron-right"></i>
              </button>
            {/if}
          </div>
          <button class="btn btn-danger exit-btn" onclick={exitReader}>
            <i class="fas fa-sign-out-alt"></i> Exit Reader
          </button>
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  :global(body.reader-active) {
    overflow: hidden;
  }

  :global(body.reader-active .header) {
    display: none !important;
  }

  :global(body.reader-active .main-content) {
    margin-top: 0 !important;
    padding: 0 !important;
  }

  .reader-container {
    background-color: #000000;
    color: #ffffff;
    min-height: 100vh;
    width: 100vw;
    position: relative;
    overflow: hidden;
  }

  .reader-loader, .reader-error {
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 1.5rem;
    color: #888888;
  }

  .reader-loader i {
    color: var(--accent);
  }

  .reader-error i {
    color: var(--error);
  }

  .reader-error h3 {
    color: #ffffff;
  }

  .reader-workspace {
    width: 100%;
    min-height: 100vh;
    overflow-y: auto;
    display: flex;
    justify-content: center;
  }

  /* Continuous Scroll Mode styles */
  .continuous-flow {
    display: flex;
    flex-direction: column;
    align-items: center;
    width: 100%;
    max-width: 900px;
    padding: 0 1rem;
  }

  .continuous-img {
    display: block;
    max-width: 100%;
    height: auto;
    background-color: #121212;
  }

  .reader-flow-footer {
    padding: 3rem 0;
    text-align: center;
    width: 100%;
  }

  /* Paged View mode styles */
  .paged-view {
    position: relative;
    width: 100%;
    height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }

  .paged-img {
    max-width: 100%;
    max-height: 100%;
    object-fit: contain;
    transition: transform 0.25s ease-out;
  }

  .paged-view.fit-height .paged-img {
    height: 100vh;
    width: auto;
  }

  .paged-view.fit-width .paged-img {
    width: 100vw;
    height: auto;
  }

  .paged-view.fit-real .paged-img {
    width: auto;
    height: auto;
    max-width: none;
    max-height: none;
  }

  /* Slide Animations */
  .paged-img.animate-left {
    animation: slideLeft 0.3s ease;
  }

  .paged-img.animate-right {
    animation: slideRight 0.3s ease;
  }

  @keyframes slideLeft {
    0% { transform: translateX(-10%); opacity: 0.7; }
    100% { transform: translateX(0); opacity: 1; }
  }

  @keyframes slideRight {
    0% { transform: translateX(10%); opacity: 0.7; }
    100% { transform: translateX(0); opacity: 1; }
  }

  /* Tap triggers */
  .tap-indicator {
    position: absolute;
    top: 0;
    height: 100%;
    width: 30%;
    z-index: 10;
  }
  .left-tap { left: 0; }
  .right-tap { right: 0; }

  /* Controls Overlay */
  .controls-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(0, 0, 0, 0.4);
    z-index: 1000;
    display: flex;
    align-items: center;
    justify-content: flex-end;
  }

  .controls-panel {
    background-color: #1a1a1a;
    border-left: 1px solid #333333;
    height: 100vh;
    width: 350px;
    box-shadow: -4px 0 10px rgba(0,0,0,0.5);
    display: flex;
    flex-direction: column;
    z-index: 1100;
    color: #ffffff;
  }

  @media (max-width: 480px) {
    .controls-panel {
      width: 100%;
    }
  }

  .panel-header {
    padding: 1.25rem 1.5rem;
    border-bottom: 1px solid #333333;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .panel-title-group h4 {
    font-family: var(--font-title);
    font-size: 1.1rem;
    font-weight: 700;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 250px;
  }

  .meta-detail {
    font-size: 0.8rem;
    color: #888888;
  }

  .panel-close-btn {
    background: transparent;
    border: none;
    color: #888888;
    font-size: 1.5rem;
    cursor: pointer;
  }

  .panel-close-btn:hover {
    color: #ffffff;
  }

  .panel-body {
    padding: 1.5rem;
    flex-grow: 1;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }

  .panel-row {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .panel-row label {
    font-size: 0.85rem;
    font-weight: 600;
    color: #888888;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .panel-row .select {
    background-color: #2b2b2b;
    border-color: #444444;
    color: #ffffff;
  }

  .panel-row.toggle-row {
    flex-direction: row;
    align-items: center;
    padding: 0.25rem 0;
  }

  .panel-row.toggle-row label {
    color: #ffffff;
    text-transform: none;
    font-size: 0.9rem;
    font-weight: 500;
  }

  .range-slider {
    width: 100%;
    accent-color: var(--accent);
    cursor: pointer;
  }

  .panel-footer {
    padding: 1.25rem 1.5rem;
    border-top: 1px solid #333333;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .chapter-nav-buttons {
    display: flex;
    gap: 0.5rem;
  }

  .chapter-nav-buttons .btn {
    flex: 1;
    background-color: #2b2b2b;
    border-color: #444444;
    color: #ffffff;
  }

  .chapter-nav-buttons .btn:hover {
    background-color: #3b3b3b;
  }

  .exit-btn {
    width: 100%;
  }
</style>
