import * as esbuild from 'esbuild'
import path from 'path'
import rails from 'esbuild-rails'

// Проверяем флаг --watch из package.json (скрипт build:watch)
const watch = process.argv.includes('--watch')
const production = process.env.RAILS_ENV === 'production'

const config = {
  // Точка входа твоего приложения
  entryPoints: [
    "app/javascript/application.js",
    "app/javascript/admin.js"
  ],
  
  // Собираем всё в один файл
  bundle: true,
  
  // Куда класть результат (для Propshaft/Sprockets)
  outdir: path.join(process.cwd(), "app/assets/builds"),
  absWorkingDir: process.cwd(),
  
  // Формат ESM нужен для корректной работы современных Web3 библиотек и type="module"
  format: 'esm',
  publicPath: '/assets',
  
  // Плагины
  plugins: [
    rails() // Автоматически подхватывает контроллеры, если используешь esbuild-rails
  ],
  
  // КРИТИЧНО ДЛЯ WEB3 (Viem, WalletConnect, Ethers)
  // Заменяем глобальные Node-переменные на браузерные аналоги без лишних полифиллов
  define: {
    global: 'window',
    'process.env.NODE_ENV': production ? '"production"' : '"development"',
    // Сеть
    'process.env.CHAIN_ID': JSON.stringify(process.env.CHAIN_ID),
    'process.env.CHAIN_NAME': JSON.stringify(process.env.CHAIN_NAME),
    'process.env.CHAIN_EXPLORER_URL': JSON.stringify(process.env.CHAIN_EXPLORER_URL),
    'process.env.RPC_URL': JSON.stringify(process.env.RPC_URL),
    'process.env.WSS_URL': JSON.stringify(process.env.WSS_URL),
    // Контракты
    'process.env.TOKEN_CONTRACT_ADDRESS': JSON.stringify(process.env.TOKEN_CONTRACT_ADDRESS),
    'process.env.CROWDSALE_CONTRACT_ADDRESS': JSON.stringify(process.env.CROWDSALE_CONTRACT_ADDRESS),
    'process.env.REWARDS_CONTRACT_ADDRESS': JSON.stringify(process.env.REWARDS_CONTRACT_ADDRESS),
    'process.env.USDT_CONTRACT_ADDRESS': JSON.stringify(process.env.USDT_CONTRACT_ADDRESS)
  },

  
  // Лоадеры для ассетов, которые могут импортироваться в JS (Leaflet, шрифты иконки)
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
  
  // Настройки сжатия
  minify: production,
  sourcemap: !production,
  
  // Чтобы избежать конфликтов с именами в некоторых Web3 либах
  preserveSymlinks: true
}

// Запуск процесса
async function run() {
  if (watch) {
    // Режим разработки с отслеживанием изменений
    const context = await esbuild.context(config)
    await context.watch()
    console.log("⚡ esbuild: Watching for JS changes...")
  } else {
    // Разовый билд для продакшена
    await esbuild.build(config)
    console.log("🚀 esbuild: JS Build complete")
  }
}

run().catch((e) => {
  console.error(e)
  process.exit(1)
})
