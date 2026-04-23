/** @type {import('tailwindcss').Config} */
export const content = [
  './public/*.html',
  './app/helpers/**/*.rb',
  './app/javascript/**/*.js',
  './app/views/**/*.{erb,html}',
  './app/components/**/*.{rb,erb,html}',
  './node_modules/flowbite/**/*.js',
];
export const theme = {
  extend: {
    colors: {
      primary: '#0288D1', // Эквивалент: sky-500 (или blue-500)
      secondary: '#26A69A', // Эквивалент: teal-600 (или cyan-600)
      accent: '#FF5722', // Эквивалент: orange-600
      error: '#D32F2F', // Эквивалент: red-700
      warning: '#FFA000', // Эквивалент: amber-500
      info: '#0288D1', // Эквивалент: sky-500 (или blue-500)
      success: '#388E3C', // Эквивалент: green-700
      text: '#fafafa', // Эквивалент: gray-50 или slate-50
    },
    backgroundImage: {
      'gradient-primary-to-secondary': 'linear-gradient(135deg, rgb(2, 136, 209) 0%, rgb(38, 166, 154) 100%)',
      'gradient-secondary-to-primary': 'linear-gradient(135deg, rgb(38, 166, 154) 0%, rgb(2, 136, 209) 100%)',
    },
  },
};
export const plugins = [
  require('flowbite') // Flowbite plugin
];