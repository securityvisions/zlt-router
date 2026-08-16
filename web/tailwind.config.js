/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // Dark-mode-only OLED operations palette (ui-ux-pro-max NOC design).
        bg: '#0a0a0f',
        surface: '#131318',
        raised: '#1a1a22',
        line: '#26262e',
        fg: '#e6e6ec',
        muted: '#8a8a96',
        up: '#22c55e',      // healthy / excellent
        warn: '#f59e0b',
        down: '#ef4444',
        info: '#3b82f6',
        accent: '#22c55e',
      },
      fontFamily: {
        sans: ['Vazirmatn', 'Fira Sans', 'system-ui', 'sans-serif'],
        mono: ['Fira Code', 'ui-monospace', 'monospace'],
      },
      fontSize: {
        '2xs': ['0.6875rem', { lineHeight: '1rem' }],
      },
      borderRadius: {
        card: '0.75rem',
      },
    },
  },
  plugins: [],
};
