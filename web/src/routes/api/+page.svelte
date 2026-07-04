<script lang="ts">
  import { onMount } from 'svelte';

  onMount(() => {
    // Dynamically load ReDoc script if not loaded
    if (!(window as any).Redoc) {
      const script = document.createElement('script');
      script.src = 'https://cdn.jsdelivr.net/npm/redoc/bundles/redoc.standalone.js';
      script.async = true;
      script.onload = () => {
        initRedoc();
      };
      document.head.appendChild(script);
    } else {
      initRedoc();
    }
  });

  function initRedoc() {
    if ((window as any).Redoc) {
      (window as any).Redoc.init('/openapi.json', {}, document.getElementById('redoc-container'));
    }
  }
</script>

<svelte:head>
  <title>Mango API Documentation</title>
</svelte:head>

<div id="redoc-container"></div>

<style>
  #redoc-container {
    background-color: white;
    min-height: 100vh;
  }
</style>
