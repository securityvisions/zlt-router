import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

// The SPA is served from the router's /www as a static build (same-origin as
// the Router API). base: './' keeps asset paths relative so the dist works
// from any sub-path. RTL is set at the document level in index.html.
export default defineConfig({
  plugins: [react()],
  base: './',
  build: { outDir: 'dist', emptyOutDir: true },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./tests/setup.ts'],
    include: ['tests/**/*.test.{ts,tsx}'],
  },
});
