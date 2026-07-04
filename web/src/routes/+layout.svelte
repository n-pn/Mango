<script lang="ts">
  import '../app.css';
  import '@fortawesome/fontawesome-free/css/all.css';
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { appState, removeAlert } from '$lib/utils/store.svelte';

  let { children } = $props();

  let mobileNavOpen = $state(false);
  let adminDropdownOpen = $state(false);
  let currentPath = $state('');

  $effect(() => {
    currentPath = $page.url.pathname;
  });

  $effect(() => {
    const themeValue = appState.theme;
    localStorage.setItem('theme', themeValue);
    applyTheme(themeValue);
  });

  onMount(() => {
    // 1. Initialize Theme
    const savedTheme = localStorage.getItem('theme') as 'light' | 'dark' | 'system' || 'system';
    appState.theme = savedTheme;

    // 2. Listen to system preference changes
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handleSystemThemeChange = () => {
      if (localStorage.getItem('theme') === 'system') {
        applyTheme('system');
      }
    };
    mediaQuery.addEventListener('change', handleSystemThemeChange);

    // 3. Perform Authentication & Role Probing
    checkAuth();

    return () => {
      mediaQuery.removeEventListener('change', handleSystemThemeChange);
    };
  });

  function applyTheme(themeValue: 'light' | 'dark' | 'system') {
    const isDark = 
      themeValue === 'dark' || 
      (themeValue === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
    
    if (isDark) {
      document.documentElement.classList.add('dark');
      document.documentElement.style.background = 'rgb(20, 20, 20)';
    } else {
      document.documentElement.classList.remove('dark');
      document.documentElement.style.background = '';
    }
  }

  function toggleTheme() {
    const current = appState.theme;
    if (current === 'system') appState.theme = 'light';
    else if (current === 'light') appState.theme = 'dark';
    else appState.theme = 'system';
  }

  async function checkAuth() {
    if (currentPath === '/login') return;
    try {
      const res = await fetch('/api/library');
      if (res.status === 401) {
        goto('/login');
        return;
      }
      
      // Probe if user is admin
      const adminRes = await fetch('/api/admin/thumbnail_progress');
      appState.isAdmin = adminRes.status !== 403;
    } catch (e) {
      console.error('Auth verification failed', e);
    }
  }

  async function logout() {
    try {
      await fetch('/logout', { method: 'GET' });
    } catch (e) {
      console.error('Logout request failed', e);
    } finally {
      goto('/login');
    }
  }

  // To-top button scrolling
  let showToTop = $state(false);
  if (typeof window !== 'undefined') {
    window.addEventListener('scroll', () => {
      showToTop = window.scrollY > window.innerHeight * 0.5;
    });
  }

  function scrollToTop() {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }
</script>

<!-- Alert Banners -->
<div class="alert-container">
  {#each appState.alerts as alert (alert.id)}
    <div class="alert alert-{alert.type}">
      <span>{alert.text}</span>
      <button class="alert-close" onclick={() => removeAlert(alert.id)} aria-label="Close alert">
        <i class="fas fa-times"></i>
      </button>
    </div>
  {/each}
</div>

{#if currentPath === '/login'}
  {@render children()}
{:else}
  <!-- Premium Header -->
  <header class="header">
    <div class="header-container">
      <div class="header-left">
        <button class="menu-toggle" onclick={() => mobileNavOpen = !mobileNavOpen} aria-label="Toggle menu">
          <i class="fas fa-bars"></i>
        </button>
        <a href="/" class="logo">
          <img src="/img/icons/icon.png" alt="Mango Logo" />
          <span>Mango</span>
        </a>
        <nav class="desktop-nav">
          <a href="/" class:active={currentPath === '/'}>Home</a>
          <a href="/library" class:active={currentPath.startsWith('/library')}>Library</a>
          <a href="/tags" class:active={currentPath.startsWith('/tags')}>Tags</a>
          {#if appState.isAdmin}
            <div class="dropdown-wrapper">
              <button 
                class="nav-dropdown-btn" 
                class:active={currentPath.startsWith('/admin') || currentPath.startsWith('/download')}
                onclick={() => adminDropdownOpen = !adminDropdownOpen}
              >
                Admin <i class="fas fa-chevron-down"></i>
              </button>
              {#if adminDropdownOpen}
                <!-- svelte-ignore a11y_click_events_have_key_events -->
                <!-- svelte-ignore a11y_no_static_element_interactions -->
                <div class="dropdown-menu" onclick={() => adminDropdownOpen = false}>
                  <a href="/admin">Dashboard</a>
                  <a href="/admin/user">User Management</a>
                  <a href="/admin/missing">Missing Items</a>
                  <hr class="dropdown-divider" />
                  <a href="/download/plugins">Plugin Store</a>
                  <a href="/admin/downloads">Download Manager</a>
                  <a href="/admin/subscriptions">Subscription Manager</a>
                </div>
              {/if}
            </div>
          {/if}
        </nav>
      </div>
      <div class="header-right">
        <button class="theme-btn" onclick={toggleTheme} title="Toggle Theme: {appState.theme}">
          {#if appState.theme === 'system'}
            <i class="fas fa-desktop"></i>
          {:else}
            <i class="fas" class:fa-moon={appState.theme === 'dark'} class:fa-sun={appState.theme === 'light'}></i>
          {/if}
        </button>
        <button class="logout-btn" onclick={logout} title="Log Out">
          <i class="fas fa-sign-out-alt"></i>
        </button>
      </div>
    </div>
  </header>

  <!-- Mobile Drawer Menu -->
  {#if mobileNavOpen}
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="mobile-drawer-overlay" onclick={() => mobileNavOpen = false}>
      <div class="mobile-drawer" onclick={e => e.stopPropagation()}>
        <div class="drawer-header">
          <span class="drawer-title">Navigation</span>
          <button class="drawer-close" onclick={() => mobileNavOpen = false} aria-label="Close menu">
            <i class="fas fa-times"></i>
          </button>
        </div>
        <nav class="drawer-nav">
          <a href="/" onclick={() => mobileNavOpen = false} class:active={currentPath === '/'}>
            <i class="fas fa-home"></i> Home
          </a>
          <a href="/library" onclick={() => mobileNavOpen = false} class:active={currentPath.startsWith('/library')}>
            <i class="fas fa-book"></i> Library
          </a>
          <a href="/tags" onclick={() => mobileNavOpen = false} class:active={currentPath.startsWith('/tags')}>
            <i class="fas fa-tags"></i> Tags
          </a>
          {#if appState.isAdmin}
            <hr class="drawer-divider" />
            <div class="drawer-section-title">Admin Controls</div>
            <a href="/admin" onclick={() => mobileNavOpen = false} class:active={currentPath === '/admin'}>
              <i class="fas fa-cog"></i> Dashboard
            </a>
            <a href="/admin/user" onclick={() => mobileNavOpen = false} class:active={currentPath.startsWith('/admin/user')}>
              <i class="fas fa-users"></i> Users
            </a>
            <a href="/admin/missing" onclick={() => mobileNavOpen = false} class:active={currentPath.startsWith('/admin/missing')}>
              <i class="fas fa-exclamation-triangle"></i> Missing Items
            </a>
            <a href="/download/plugins" onclick={() => mobileNavOpen = false} class:active={currentPath.startsWith('/download/plugins')}>
              <i class="fas fa-plug"></i> Plugins
            </a>
            <a href="/admin/downloads" onclick={() => mobileNavOpen = false} class:active={currentPath.startsWith('/admin/downloads')}>
              <i class="fas fa-download"></i> Downloads
            </a>
            <a href="/admin/subscriptions" onclick={() => mobileNavOpen = false} class:active={currentPath.startsWith('/admin/subscriptions')}>
              <i class="fas fa-rss"></i> Subscriptions
            </a>
          {/if}
          <hr class="drawer-divider" />
          <button class="drawer-nav-btn" onclick={() => { toggleTheme(); mobileNavOpen = false; }}>
            <i class="fas fa-adjust"></i> Theme: {appState.theme}
          </button>
          <button class="drawer-nav-btn logout" onclick={() => { logout(); mobileNavOpen = false; }}>
            <i class="fas fa-sign-out-alt"></i> Log Out
          </button>
        </nav>
      </div>
    </div>
  {/if}

  <!-- Main Content Space -->
  <main class="main-content">
    {@render children()}
  </main>

  <!-- Scroll To Top Button -->
  {#if showToTop}
    <button class="totop-btn" onclick={scrollToTop} aria-label="Scroll to top">
      <i class="fas fa-chevron-up"></i>
    </button>
  {/if}
{/if}

<style>
  /* Toast Notification Container */
  .alert-container {
    position: fixed;
    top: 1.5rem;
    left: 50%;
    transform: translateX(-50%);
    z-index: 10000;
    width: 90%;
    max-width: 500px;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    pointer-events: none;
  }

  .alert-container :global(.alert) {
    pointer-events: auto;
    margin-bottom: 0;
  }

  /* Header Styles */
  .header {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    height: 70px;
    background-color: var(--header-bg);
    backdrop-filter: var(--header-blur);
    border-bottom: 1px solid var(--border-color);
    z-index: 900;
  }

  .header-container {
    max-width: 1200px;
    margin: 0 auto;
    height: 100%;
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0 1.5rem;
  }

  .header-left {
    display: flex;
    align-items: center;
    gap: 2rem;
  }

  .logo {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-family: var(--font-title);
    font-weight: 700;
    font-size: 1.25rem;
    color: var(--text-primary);
  }

  .logo img {
    height: 36px;
    width: 36px;
  }

  .desktop-nav {
    display: flex;
    align-items: center;
    gap: 1.5rem;
  }

  .desktop-nav a, .nav-dropdown-btn {
    font-size: 0.95rem;
    font-weight: 500;
    color: var(--text-secondary);
    padding: 0.5rem 0.25rem;
    position: relative;
    background: transparent;
    border: none;
    cursor: pointer;
    font-family: var(--font-body);
  }

  .desktop-nav a:hover, .nav-dropdown-btn:hover,
  .desktop-nav a.active, .nav-dropdown-btn.active {
    color: var(--accent);
  }

  .desktop-nav a.active::after, .nav-dropdown-btn.active::after {
    content: '';
    position: absolute;
    bottom: -15px;
    left: 0;
    right: 0;
    height: 2px;
    background-color: var(--accent);
  }

  .dropdown-wrapper {
    position: relative;
  }

  .dropdown-menu {
    position: absolute;
    top: calc(100% + 15px);
    left: 0;
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--border-radius-md);
    box-shadow: var(--shadow-lg);
    min-width: 200px;
    padding: 0.5rem 0;
    display: flex;
    flex-direction: column;
    z-index: 1000;
  }

  .dropdown-menu a {
    padding: 0.625rem 1.25rem;
    color: var(--text-primary);
    font-size: 0.9rem;
    transition: background-color 0.15s ease;
  }

  .dropdown-menu a:hover {
    background-color: var(--bg-tertiary);
    color: var(--accent);
  }

  .dropdown-divider {
    border: none;
    border-top: 1px solid var(--border-color);
    margin: 0.375rem 0;
  }

  .header-right {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .theme-btn, .logout-btn, .menu-toggle {
    background: transparent;
    border: none;
    color: var(--text-secondary);
    width: 38px;
    height: 38px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    font-size: 1.05rem;
    transition: background-color 0.15s ease, color 0.15s ease;
  }

  .theme-btn:hover, .logout-btn:hover, .menu-toggle:hover {
    background-color: var(--bg-secondary);
    color: var(--text-primary);
  }

  .menu-toggle {
    display: none;
  }

  /* Main content layout offset */
  .main-content {
    margin-top: 70px;
    padding: 2rem 0;
    min-height: calc(100vh - 70px);
  }

  /* Mobile Drawer */
  .mobile-drawer-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(0, 0, 0, 0.4);
    z-index: 2000;
  }

  .mobile-drawer {
    position: fixed;
    top: 0;
    left: 0;
    bottom: 0;
    width: 280px;
    background-color: var(--bg-secondary);
    z-index: 2100;
    box-shadow: var(--shadow-lg);
    display: flex;
    flex-direction: column;
    padding: 1.5rem;
  }

  .drawer-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.5rem;
  }

  .drawer-title {
    font-family: var(--font-title);
    font-weight: 700;
    font-size: 1.15rem;
  }

  .drawer-close {
    background: transparent;
    border: none;
    font-size: 1.25rem;
    color: var(--text-secondary);
    cursor: pointer;
  }

  .drawer-nav {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .drawer-nav a, .drawer-nav-btn {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.75rem 1rem;
    border-radius: var(--border-radius-sm);
    color: var(--text-primary);
    font-weight: 500;
    font-size: 0.95rem;
    background: transparent;
    border: none;
    text-align: left;
    width: 100%;
    cursor: pointer;
    font-family: var(--font-body);
  }

  .drawer-nav a:hover, .drawer-nav-btn:hover {
    background-color: var(--bg-tertiary);
    color: var(--accent);
  }

  .drawer-nav a.active {
    background-color: var(--accent-light);
    color: var(--accent);
  }

  .drawer-divider {
    border: none;
    border-top: 1px solid var(--border-color);
    margin: 0.75rem 0;
  }

  .drawer-section-title {
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    color: var(--text-muted);
    padding: 0.25rem 1rem;
    letter-spacing: 0.05em;
  }

  .drawer-nav-btn.logout {
    color: var(--error);
  }
  .drawer-nav-btn.logout:hover {
    background-color: rgba(239, 68, 68, 0.08);
  }

  /* To Top Button */
  .totop-btn {
    position: fixed;
    bottom: 2rem;
    right: 2rem;
    width: 44px;
    height: 44px;
    border-radius: 50%;
    background-color: var(--accent);
    color: #ffffff;
    border: none;
    box-shadow: var(--shadow-md);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1rem;
    transition: transform 0.2s ease, background-color 0.2s ease;
    z-index: 800;
  }

  .totop-btn:hover {
    background-color: var(--accent-hover);
    transform: translateY(-2px);
  }

  /* Responsive Adjustments */
  @media (max-width: 768px) {
    .desktop-nav {
      display: none;
    }
    .menu-toggle {
      display: flex;
    }
  }
</style>
