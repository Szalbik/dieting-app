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
        primary: {
          50: '#ecfdf5',
          100: '#d1fae5',
          200: '#a7f3d0',
          300: '#6ee7b7',
          400: '#34d399',
          500: '#10b981',
          600: '#059669',
          700: '#047857',
          800: '#065f46',
          900: '#064e3b',
        },
        nutrition: {
          protein: '#ef4444',    // Red for protein
          carbs: '#f59e0b',      // Amber for carbohydrates
          fats: '#8b5cf6',       // Purple for fats
          fiber: '#10b981',      // Green for fiber
          vitamins: '#06b6d4',   // Cyan for vitamins
        },
        health: {
          50: '#f0fdf4',
          100: '#dcfce7',
          200: '#bbf7d0',
          300: '#86efac',
          400: '#4ade80',
          500: '#22c55e',
          600: '#16a34a',
          700: '#15803d',
          800: '#166534',
          900: '#14532d',
        },
        // Enhanced semantic colors
        success: {
          50: '#f0fdf4',
          100: '#dcfce7',
          200: '#bbf7d0',
          300: '#86efac',
          400: '#4ade80',
          500: '#22c55e',
          600: '#16a34a',
          700: '#15803d',
          800: '#166534',
          900: '#14532d',
        },
        warning: {
          50: '#fffbeb',
          100: '#fef3c7',
          200: '#fde68a',
          300: '#fcd34d',
          400: '#fbbf24',
          500: '#f59e0b',
          600: '#d97706',
          700: '#b45309',
          800: '#92400e',
          900: '#78350f',
        },
        error: {
          50: '#fef2f2',
          100: '#fee2e2',
          200: '#fecaca',
          300: '#fca5a5',
          400: '#f87171',
          500: '#ef4444',
          600: '#dc2626',
          700: '#b91c1c',
          800: '#991b1b',
          900: '#7f1d1d',
        },
        info: {
          50: '#f0f9ff',
          100: '#e0f2fe',
          200: '#bae6fd',
          300: '#7dd3fc',
          400: '#38bdf8',
          500: '#0ea5e9',
          600: '#0284c7',
          700: '#0369a1',
          800: '#075985',
          900: '#0c4a6e',
        },
      },
      animation: {
        'fade-in': 'fadeIn 0.5s ease-in-out',
        'slide-up': 'slideUp 0.3s ease-out',
        'slide-down': 'slideDown 0.3s ease-out',
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'bounce-gentle': 'bounceGentle 2s infinite',
        'scale-in': 'scaleIn 0.2s ease-out',
        'shimmer': 'shimmer 2s linear infinite',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { transform: 'translateY(10px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        slideDown: {
          '0%': { transform: 'translateY(-10px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        bounceGentle: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-5px)' },
        },
        scaleIn: {
          '0%': { transform: 'scale(0.95)', opacity: '0' },
          '100%': { transform: 'scale(1)', opacity: '1' },
        },
        shimmer: {
          '0%': { transform: 'translateX(-100%)' },
          '100%': { transform: 'translateX(100%)' },
        },
      },
      boxShadow: {
        'health': '0 4px 6px -1px rgba(73, 101, 128, 0.1), 0 2px 4px -1px rgba(73, 101, 128, 0.06)',
        'health-lg': '0 10px 15px -3px rgba(73, 101, 128, 0.1), 0 4px 6px -2px rgba(73, 101, 128, 0.05)',
        'health-xl': '0 20px 25px -5px rgba(73, 101, 128, 0.1), 0 10px 10px -5px rgba(73, 101, 128, 0.04)',
        'soft': '0 2px 4px 0 rgba(42, 40, 35, 0.06), 0 1px 2px 0 rgba(42, 40, 35, 0.04)',
        'medium': '0 8px 24px 0 rgba(42, 40, 35, 0.08), 0 2px 6px 0 rgba(42, 40, 35, 0.05)',
        'large': '0 16px 48px -3px rgba(42, 40, 35, 0.10), 0 4px 12px -2px rgba(42, 40, 35, 0.06)',
        'glow': '0 0 20px rgba(232, 168, 116, 0.18)',
        'glow-lg': '0 0 40px rgba(232, 168, 116, 0.22)',
      },
      borderRadius: {
        'xl': '0.75rem',
        '2xl': '1rem',
        '3xl': '1.5rem',
        '4xl': '2rem',
      },
      spacing: {
        '18': '4.5rem',
        '88': '22rem',
        '128': '32rem',
      },
      maxWidth: {
        '8xl': '88rem',
        '9xl': '96rem',
      },
      minHeight: {
        'screen-75': '75vh',
      },
      fontSize: {
        '55': '55rem',
      },
      opacity: {
        '80': '.8',
      },
      zIndex: {
        '2': 2,
        '3': 3,
      },
      inset: {
        'auto': 'auto',
        '1/2': '50%',
        '1/3': '33.333333%',
        '2/3': '66.666667%',
        '1/4': '25%',
        '2/4': '50%',
        '3/4': '75%',
        '1/5': '20%',
        '2/5': '40%',
        '3/5': '60%',
        '4/5': '80%',
        '1/6': '16.666667%',
        '2/6': '33.333333%',
        '3/6': '50%',
        '4/6': '66.666667%',
        '5/6': '83.333333%',
        '1/12': '8.333333%',
        '2/12': '16.666667%',
        '3/12': '25%',
        '4/12': '33.333333%',
        '5/12': '41.666667%',
        '6/12': '50%',
        '7/12': '58.333333%',
        '8/12': '66.666667%',
        '9/12': '75%',
        '10/12': '83.333333%',
        '11/12': '91.666667%',
        'full': '100%',
      },
      transitionProperty: {
        'height': 'height',
        'spacing': 'margin, padding',
      },
      backgroundImage: {
        'gradient-radial': 'radial-gradient(var(--tw-gradient-stops))',
        'gradient-conic': 'conic-gradient(from 180deg at 50% 50%, var(--tw-gradient-stops))',
        'gradient-health': 'linear-gradient(135deg, #ecfdf5 0%, #d1fae5 50%, #a7f3d0 100%)',
        'gradient-warm': 'linear-gradient(135deg, #fef3c7 0%, #fde68a 50%, #fcd34d 100%)',
        'gradient-cool': 'linear-gradient(135deg, #e0f2fe 0%, #bae6fd 50%, #7dd3fc 100%)',
      },
      backdropBlur: {
        xs: '2px',
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
  ]
}
