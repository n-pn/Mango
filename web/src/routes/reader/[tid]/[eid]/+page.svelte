<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { apiRequest } from '$lib/utils/api';

  let tid = $derived($page.params.tid);
  let eid = $derived($page.params.eid);

  onMount(async () => {
    try {
      const bookData = await apiRequest(`/api/book/${tid}`);
      if (bookData && bookData.entries) {
        const entry = bookData.entries.find((e: any) => e.id === eid);
        if (entry) {
          // fetch reading progress page number
          const progress = entry.progress || 1;
          goto(`/reader/${tid}/${eid}/${progress}`, { replaceState: true });
          return;
        }
      }
      goto(`/reader/${tid}/${eid}/1`, { replaceState: true });
    } catch (e) {
      console.error(e);
      goto(`/reader/${tid}/${eid}/1`, { replaceState: true });
    }
  });
</script>

<div class="redirect-loading">
  <i class="fas fa-spinner fa-spin fa-2x"></i>
  <p>Resuming reading progress...</p>
</div>

<style>
  .redirect-loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    gap: 1rem;
    color: #888888;
    background-color: #000000;
  }
</style>
