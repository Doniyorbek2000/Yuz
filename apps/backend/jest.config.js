/** Unit tests (*.spec.ts) and e2e tests (test/*.e2e-spec.ts) against real Postgres and Redis. */
module.exports = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: '.',
  testRegex: '(src/.*\\.spec\\.ts|test/.*\\.e2e-spec\\.ts)$',
  transform: { '^.+\\.ts$': ['ts-jest', { tsconfig: 'tsconfig.json' }] },
  testEnvironment: 'node',
  globalSetup: '<rootDir>/test/global-setup.ts',
  setupFiles: ['<rootDir>/test/env.ts'],
  testTimeout: 30000,
  // Suites share one database and reset it: never run them in parallel.
  maxWorkers: 1,
};
