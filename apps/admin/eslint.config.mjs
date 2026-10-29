import nextCoreWebVitals from 'eslint-config-next/core-web-vitals';
import nextTypeScript from 'eslint-config-next/typescript';

const config = [
  ...nextCoreWebVitals,
  ...nextTypeScript,
  { ignores: ['.next/**', 'next-env.d.ts', 'node_modules/**'] },
];

export default config;
