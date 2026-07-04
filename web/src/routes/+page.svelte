<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { apiRequest } from '$lib/utils/api';
  import { appState } from '$lib/utils/store.svelte';
  import Card from '$lib/components/Card.svelte';
  import EntryModal from '$lib/components/EntryModal.svelte';

  // State variables
  let libraryLoading = $state(true);
  let emptyLibrary = $state(true);
  let newUser = $state(true);

  let continueReading = $state<{ entries: any[]; percentages: number[] }>({ entries: [], percentages: [] });
  let startReading = $state<any[]>([]);
  let recentlyAdded = $state<any[]>([]);

  // Modal control
  let selectedEntry = $state<any>(null);
  let selectedProgress = $state<number>(0);
  let showModal = $state(false);

  // Library config options (for new user guides)
  let libraryPath = $state('');
  let scanInterval = $state(0);
  let configPath = $state('');

  onMount(async () => {
    await loadHomeData();
  });

  async function loadHomeData() {
    libraryLoading = true;
    try {
      // 1. Fetch library statistics
      const libData = await apiRequest('/api/library?depth=0');
      
      if (libData && libData.titles) {
        emptyLibrary = libData.titles.length === 0;
        
        // Compute whether this is a new user (i.e. no progress on any title)
        const percentages = libData.title_percentage || [];
        newUser = !percentages.some((p: number) => p > 0);
      }

      if (!emptyLibrary) {
        // Fetch dashboard collections in parallel
        const [crData, srData, raData] = await Promise.all([
          apiRequest('/api/library/continue_reading'),
          apiRequest('/api/library/start_reading'),
          apiRequest('/api/library/recently_added')
        ]);

        if (crData.success) {
          continueReading = {
            entries: crData.entries || [],
            percentages: crData.entry_percentages || []
          };
        }
        
        if (srData.success) {
          startReading = srData.titles || [];
        }

        if (raData.success) {
          recentlyAdded = raData.items || [];
        }
      } else {
        // Retrieve config metadata to display library paths
        // We can check config or handle fallback
        libraryPath = '/manga';
        scanInterval = 30;
        configPath = 'config.yml';
      }
    } catch (e) {
      console.error('Failed to load home data', e);
    } finally {
      libraryLoading = false;
    }
  }

  function openEntryModal(entry: any, progressPercent: number) {
    selectedEntry = entry;
    selectedProgress = progressPercent;
    showModal = true;
  }

  function handleModalAction() {
    loadHomeData();
  }
</script>

<svelte:head>
  <title>Mango - Home</title>
</svelte:head>

<div class="container">
  {#if libraryLoading}
    <div class="loading-state">
      <i class="fas fa-circle-notch fa-spin fa-3x"></i>
      <p>Loading your dashboard, please wait...</p>
    </div>
  {:else if emptyLibrary}
    <!-- Empty Library View -->
    <div class="dashboard-hero text-center">
      <div class="hero-icon"><i class="fas fa-plus"></i></div>
      <h2>Add your first manga</h2>
      <p class="hero-desc">We can't find any manga files yet. Place some supported archives (.cbz, .cbr) in your library folder to get started.</p>
      
      <div class="info-card">
        <h4 class="info-title">Server Configuration</h4>
        <div class="info-row">
          <span class="info-label">Library Path:</span>
          <span class="info-value"><code>{libraryPath}</code></span>
        </div>
        <div class="info-row">
          <span class="info-label">Config Location:</span>
          <span class="info-value"><code>{configPath}</code></span>
        </div>
        <div class="info-row">
          <span class="info-label">Update Frequency:</span>
          <span class="info-value">Scans every {scanInterval} minutes</span>
        </div>
      </div>
      
      {#if appState.isAdmin}
        <a href="/admin" class="btn btn-primary margin-top">
          <i class="fas fa-cog"></i> Go to Admin Panel
        </a>
      {/if}
    </div>
  {:else if newUser && startReading.length > 0 && continueReading.entries.length === 0}
    <!-- New User View (Library populated, but no reading progress yet) -->
    <div class="dashboard-hero text-center">
      <div class="hero-icon"><i class="fas fa-book-open"></i></div>
      <h2>Read your first manga</h2>
      <p class="hero-desc">Your library files are processed and ready. Start reading your first volume, and Mango will automatically save your progress here.</p>
      <a href="/library" class="btn btn-primary margin-top">
        <i class="fas fa-th-large"></i> Explore Library
      </a>
    </div>
  {:else}
    <!-- Normal Dashboard View -->
    <div class="dashboard">
      <!-- Continue Reading Section -->
      {#if continueReading.entries.length > 0}
        <section class="dashboard-section">
          <h2 class="section-heading">Continue Reading</h2>
          <div class="card-grid">
            {#each continueReading.entries as entry, idx}
              <Card
                item={entry}
                progress={continueReading.percentages[idx]}
                page="home"
                onclick={() => openEntryModal(entry, continueReading.percentages[idx])}
              />
            {/each}
          </div>
        </section>
      {/if}

      <!-- Start Reading Section -->
      {#if startReading.length > 0}
        <section class="dashboard-section">
          <h2 class="section-heading">Start Reading</h2>
          <div class="card-grid">
            {#each startReading as title}
              <Card
                item={title}
                progress={-1}
                page="home"
                onclick={() => goto(`/book/${title.id}`)}
              />
            {/each}
          </div>
        </section>
      {/if}

      <!-- Recently Added Section -->
      {#if recentlyAdded.length > 0}
        <section class="dashboard-section">
          <h2 class="section-heading">Recently Added</h2>
          <div class="card-grid">
            {#each recentlyAdded as wrapper}
              <Card
                item={wrapper.item}
                progress={wrapper.percentage}
                groupedCount={wrapper.count}
                page="home"
                onclick={() => {
                  if (wrapper.count === 1) {
                    openEntryModal(wrapper.item, wrapper.percentage);
                  } else {
                    goto(`/book/${wrapper.item.id}`);
                  }
                }}
              />
            {/each}
          </div>
        </section>
      {/if}

      {#if continueReading.entries.length === 0 && startReading.length === 0 && recentlyAdded.length === 0}
        <div class="dashboard-hero text-center">
          <img src="/img/banner.png" alt="Mango Logo" class="hero-logo-img" />
          <p class="hero-desc">Welcome to Mango manga server. Browse the library to find something to read.</p>
          <a href="/library" class="btn btn-primary">
            <i class="fas fa-th-large"></i> Go to Library
          </a>
        </div>
      {/if}
    </div>
  {/if}
</div>

<!-- Reactive Entry Modal -->
<EntryModal
  entry={selectedEntry}
  progress={selectedProgress}
  show={showModal}
  onclose={() => showModal = false}
  onaction={handleModalAction}
/>

<style>
  .loading-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 50vh;
    gap: 1.5rem;
    color: var(--text-secondary);
  }

  .loading-state i {
    color: var(--accent);
  }

  /* Hero Dashboard */
  .dashboard-hero {
    max-width: 600px;
    margin: 4rem auto;
    padding: 3rem 2rem;
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-lg);
    box-shadow: var(--shadow-md);
  }

  .hero-icon {
    font-size: 4rem;
    color: var(--accent);
    margin-bottom: 1.5rem;
  }

  .hero-logo-img {
    max-width: 280px;
    margin-bottom: 1.5rem;
  }

  .hero-desc {
    color: var(--text-secondary);
    margin-bottom: 2rem;
    font-size: 1rem;
    line-height: 1.5;
  }

  /* Info Config Card */
  .info-card {
    background-color: var(--bg-primary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-md);
    padding: 1.25rem 1.5rem;
    text-align: left;
    margin-top: 1.5rem;
  }

  .info-title {
    font-size: 0.95rem;
    margin-bottom: 0.75rem;
    color: var(--text-primary);
  }

  .info-row {
    display: flex;
    justify-content: space-between;
    padding: 0.5rem 0;
    border-bottom: 1px solid var(--border-color);
    font-size: 0.85rem;
  }

  .info-row:last-child {
    border-bottom: none;
  }

  .info-label {
    color: var(--text-secondary);
    font-weight: 500;
  }

  .info-value {
    color: var(--text-primary);
  }

  /* Main Dashboard */
  .dashboard {
    display: flex;
    flex-direction: column;
    gap: 3rem;
  }

  .dashboard-section {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .section-heading {
    font-family: var(--font-title);
    font-size: 1.5rem;
    font-weight: 700;
    position: relative;
    padding-bottom: 0.5rem;
  }

  .section-heading::after {
    content: '';
    position: absolute;
    bottom: 0;
    left: 0;
    width: 60px;
    height: 3px;
    background-color: var(--accent);
    border-radius: 2px;
  }
</style>
