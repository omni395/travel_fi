#!/usr/bin/env node

/**
 * esbuild.config.mjs — Simple single build
 */

import * as esbuild from 'esbuild'
import path from 'path'
import fs from 'fs'
import { execSync } from 'child_process'
import rails from 'esbuild-rails'

const watch = process.argv.includes('--watch')
const production = process.env.RAILS_ENV === 'production'
const BUILDS_DIR = path.join(process.cwd(), 'app/assets/builds')

// Очищаем директорию
console.log('🧹 esbuild: Cleaning app/assets/builds/...')
try {
  fs.rmSync(BUILDS_DIR, { recursive: true, force: true })
  fs.mkdirSync(BUILDS_DIR, { recursive: true })
} catch (err) {
  console.warn(`⚠️  esbuild: Cleanup warning: ${err.message}`)
}

// Запускаем авто-обнаружение компонентных контроллеров и CSS
console.log('⚙️  esbuild: Discovering ViewComponent controllers & CSS...')
try {
  execSync('node scripts/discover_components.js', { stdio: 'inherit' })
} catch (err) {
  console.error('❌ esbuild: discover_components failed:', err.message)
  process.exit(1)
}

// ========================================================================
// Единая сборка: entry points + code-split chunks
// ========================================================================
const config = {
  entryPoints: [
    'app/javascript/application.js',
    'app/javascript/admin.js',
  ],
  bundle: true,
  splitting: false,
  outdir: 'app/assets/builds',
  absWorkingDir: process.cwd(),
  format: 'esm',
  publicPath: '/assets',
  plugins: [rails()],
  define: {
    global: 'window',
    'process.env.NODE_ENV': production ? '"production"' : '"development"',
  },
  loader: {
    '.css': 'css',
    '.ttf': 'file',
    '.woff': 'file',
    '.woff2': 'file',
    '.svg': 'file',
    '.eot': 'file',
    '.png': 'file',
    '.jpg': 'file',
    '.jpeg': 'file',
    '.gif': 'file',
    '.webp': 'file',
  },
  minify: production,
  sourcemap: !production,
  preserveSymlinks: true,
}

// ========================================================================
// Copy _components.css → builds (for Propshaft)
// ========================================================================
function copyComponentsCSS() {
  const src = path.join(process.cwd(), 'app/javascript/controllers/_components.css')
  const dest = path.join(BUILDS_DIR, 'components.css')
  try {
    fs.copyFileSync(src, dest)
    console.log(`📦 Copied _components.css → builds/components.css`)
  } catch (err) {
    console.warn(`⚠️  Copy components.css warning: ${err.message}`)
  }
}

// ========================================================================
// Runner
// ========================================================================
async function run() {
  if (watch) {
    const ctx = await esbuild.context(config)
    await ctx.rebuild()
    copyComponentsCSS()
    console.log('⚡ esbuild: Build complete, watching for changes...')
    await ctx.watch()
  } else {
    await esbuild.build(config)
    copyComponentsCSS()
    console.log('🚀 esbuild: Build complete')
  }
}

run().catch((e) => {
  console.error(e)
  process.exit(1)
})
