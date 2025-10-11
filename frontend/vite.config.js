import { defineConfig } from 'vite'

export default defineConfig({
  // Enable access from local network
  server: {
    host: '0.0.0.0', // Listen on all network interfaces
    port: 5173,      // Default Vite port
    strictPort: true, // Fail if port is already in use
    // HTTPS disabled for now - causes certificate issues in local dev
    // The SSL error in Brave/Chrome when connecting to MetaMask is expected behavior
    // It WILL work in production with proper HTTPS
    https: false
  },
  
  // Multi-page application configuration
  build: {
    rollupOptions: {
      input: {
        main: 'index.html',
        betting: 'main.html',
        claim: 'claim.html',
        leaderboard: 'leaderboard.html',
        rules: 'rules.html'
      }
    },
    // Handle platform-specific dependencies
    commonjsOptions: {
      include: [/node_modules/]
    }
  },
  
  // Serve static files from deploy directory for contract artifacts
  publicDir: 'public',
  
  // Additional static file serving for deploy artifacts
  define: {
    // Enable development mode features
    __DEV__: true,
    // Fix for buffer polyfill
    global: 'globalThis'
  },
  
  // Optimize dependencies to handle platform issues
  optimizeDeps: {
    include: ['ethers', 'buffer']
  },
  
  // Resolve buffer polyfill for browser compatibility
  resolve: {
    alias: {
      buffer: 'buffer'
    }
  }
})
