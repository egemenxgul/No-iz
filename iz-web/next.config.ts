import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'standalone',
  env: {
    NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL ?? 'https://api.no-iz.app',
    NEXT_PUBLIC_WS_URL:  process.env.NEXT_PUBLIC_WS_URL  ?? 'wss://api.no-iz.app/api/ws',
  },
  transpilePackages: ['@noble/curves', '@noble/hashes'],
};

export default nextConfig;
