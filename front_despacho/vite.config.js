import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react-swc'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: true, // Permite que el contenedor de Docker exponga la app hacia afuera
    port: 8081, // Forzamos a Vite a usar el puerto que definiste en tu Dockerfile
    watch: {
      usePolling: true 
    }
  }
})