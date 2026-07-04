<script lang="ts">
  import { onMount } from 'svelte';

  onMount(() => {
    // Dynamically load Scalar script if not loaded
    if (!(window as any).Scalar) {
      const script = document.createElement('script');
      script.src = 'https://cdn.jsdelivr.net/npm/@scalar/api-reference';
      script.async = true;
      script.onload = () => {
        initScalar();
      };
      document.head.appendChild(script);
    } else {
      initScalar();
    }
  });

  function initScalar() {
    if ((window as any).Scalar) {
      const isDark = typeof document !== 'undefined' && (
        document.documentElement.classList.contains('dark') || 
        (localStorage.getItem('theme') === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches)
      );
      (window as any).Scalar.createApiReference(document.getElementById('scalar-container'), {
        url: '/openapi.json',
        theme: 'kepler',
        darkMode: isDark
      });
    }
  }
</script>

<svelte:head>
  <title>Mango API Documentation</title>
</svelte:head>

<div id="scalar-container"></div>

<style>
  #scalar-container {
    min-height: 100vh;
  }
</style>
