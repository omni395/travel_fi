#!/usr/bin/env node

import * as esbuild from 'esbuild'
import path from 'path'
import fs from 'fs'
import { execSync } from 'child_process'
import rails from 'esbuild-rails'

const watch = process.argv.includes('--watch')
const production = process.env.RAILS_ENV === 'production'
const BUILDS_DIR = path.join(process.cwd(), "app/assets/builds")

// Очищаем app/assets/builds/ перед сборкой
console.log('🧹 esbuild: Cleaning app/assets/builds/...')
try {
  fs.rmSync(BUILDS_DIR, { recursive: true, force: true })
  fs.mkdirSync(BUILDS_DIR, { recursive: true })
} catch (err) {
  console.warn(`⚠️  esbuild: Cleanup warning: ${err.message}`)
}

// Запускаем авто-обнаружение компонентных контроллеров и CSS перед сборкой
console.log('⚙️  esbuild: Discovering ViewComponent controllers & CSS...')
try {
  execSync('node scripts/discover_components.js', { stdio: 'inherit' })
} catch (err) {
  console.error('❌ esbuild: discover_components failed:', err.message)
  process.exit(1)
}

const config = {
  entryPoints: [
    "app/javascript/application.js",
    "app/javascript/admin.js"
  ],

  bundle: true,
  splitting: false,

  outdir: path.join(process.cwd(), "app/assets/builds"),
  absWorkingDir: process.cwd(),

  format: 'esm',
  publicPath: '/assets',

  plugins: [
    rails(),
    {
      name: 'rebuild-logger',
      setup(build) {
        let count = 0
        build.onEnd(result => {
          const time = new Date().toLocaleTimeString()
          if (result.errors.length > 0) {
            console.error(`❌ esbuild: Rebuild failed at ${time} (${result.errors.length} errors)`)
          } else {
            // После каждого успешного билда копируем _components.css → builds/components.css
            // чтобы Propshaft мог найти его по asset_path("components.css")
            const src = path.join(process.cwd(), "app/javascript/controllers/_components.css")
            const dest = path.join(BUILDS_DIR, "components.css")
            try {
              fs.copyFileSync(src, dest)
              if (count > 0) console.log(`📦 Copied _components.css → builds/components.css (#${count})`)
            } catch (err) {
              console.warn(`⚠️  Copy components.css warning: ${err.message}`)
            }
            if (count > 0) {
              console.log(`✅ esbuild: Rebuild #${count} at ${time}`)
            }
          }
          count++
        })
      }
    }
  ],

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
    '.webp': 'file'
  },

  minify: production,
  sourcemap: !production,
  preserveSymlinks: true
}

async function run() {
  if (watch) {
    const context = await esbuild.context(config)
    await context.rebuild()
    console.log("⚡ esbuild: Initial build complete")
    await context.watch()
    console.log("⚡ esbuild: Watching for changes (esbuild built-in)...")
  } else {
    await esbuild.build(config)
    console.log("🚀 esbuild: JS Build complete")
  }
}

run().catch((e) => {
  console.error(e)
  process.exit(1)
})
