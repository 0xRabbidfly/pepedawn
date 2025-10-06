import { defineConfig } from 'vite'

export default defineConfig({
  // Enable access from local network
  server: {
    host: '0.0.0.0', // Listen on all network interfaces
    port: 5173,      // Default Vite port
    strictPort: true, // Fail if port is already in use
  },
  
  // Multi-page application configuration
  build: {
    rollupOptions: {
      input: {
        main: 'index.html',
        betting: 'main.html',
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
    __DEV__: true
  },
  
  // Optimize dependencies to handle platform issues
  optimizeDeps: {
    include: ['ethers']
  }
})
