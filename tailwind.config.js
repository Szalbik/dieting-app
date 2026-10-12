const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}',
    './app/assets/stylesheets/**/*.css',
    './app/components/**/*.{erb,haml,html,slim,rb}',
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['DM Sans', ...defaultTheme.fontFamily.sans],
        serif: ['Playfair Display', ...defaultTheme.fontFamily.serif],
      },
      colors: {
        brand: {
          // Peach Skyline palette. Legacy token names kept and repointed so
          // existing brand-* markup reskins without per-view edits.
          sage: '#FFDBBB',         // → peach
          'sage-light': '#FFEDDB', // → peach-soft
          'sage-dark': '#496580',  // → navy: primary CTA / active
          cream: '#FFEDDB',
          'warm-white': '#FBF8F1', // → paper (body bg)
          charcoal: '#2A2823',     // → ink
          'soft-gray': '#5A5448',  // → ink-soft
          accent: '#E8A874',       // → peach-strong: CTA hover, eyebrow
          'accent-light': '#FFDBBB',
          paper: '#F4EEE0',        // → paper-2
          // New semantic accents used by the redesigned screens
          navy: '#496580',
          'navy-strong': '#2D4259',
          peach: '#FFDBBB',
          'peach-strong': '#E8A874',
          'peach-soft': '#FFEDDB',
          sky: '#BADDFF',
          'sky-strong': '#5B8FC9',
          'sky-soft': '#E2EEFC',
          mint: '#BAFFF5',
          'mint-strong': '#3AA48F',
          'mint-soft': '#E2FBF5',
          ink: '#2A2823',
          'ink-soft': '#5A5448',
          'ink-faint': '#9A948A',
        },
        nutrition: {
          protein: '#ef4444',    // Red for protein
          carbs: '#f59e0b',      // Amber for carbohydrates
          fats: '#8b5cf6',       // Purple for fats
          fiber: '#10b981',      // Green for fiber
          vitamins: '#06b6d4',   // Cyan for vitamins
        },
      },
      animation: {
        'scale-in': 'scaleIn 0.2s ease-out',
      },
      keyframes: {
        scaleIn: {
          '0%': { transform: 'scale(0.95)', opacity: '0' },
          '100%': { transform: 'scale(1)', opacity: '1' },
        },
      },
      boxShadow: {
        'soft': '0 2px 4px 0 rgba(42, 40, 35, 0.06), 0 1px 2px 0 rgba(42, 40, 35, 0.04)',
        'medium': '0 8px 24px 0 rgba(42, 40, 35, 0.08), 0 2px 6px 0 rgba(42, 40, 35, 0.05)',
        'large': '0 16px 48px -3px rgba(42, 40, 35, 0.10), 0 4px 12px -2px rgba(42, 40, 35, 0.06)',
      },
      borderRadius: {
        'xl': '0.75rem',
        '2xl': '1rem',
        '3xl': '1.5rem',
      },
      opacity: {
        '80': '.8',
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
  ]
}
