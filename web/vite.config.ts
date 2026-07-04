import adapter from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [
		sveltekit({
			compilerOptions: {
				// Force runes mode for the project, except for libraries. Can be removed in svelte 6.
				runes: ({ filename }) => filename.split(/[/\\]/).includes('node_modules') ? undefined : true
			},
			adapter: adapter({
				pages: '../public',
				assets: '../public',
				fallback: 'index.html',
				precompress: false,
				strict: true
			})
		})
	],
	server: {
		proxy: {
			'/api': 'http://localhost:3000',
			'/uploads': 'http://localhost:3000',
			'/img': 'http://localhost:3000',
		}
	}
});
