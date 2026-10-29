/**
 * Grants or revokes the admin role. Run where DATABASE_URL points at the
 * database (e.g. inside the API container):
 *   node dist/cli/set-role.js owner@example.com ADMIN
 *   node dist/cli/set-role.js former@example.com USER
 * There is deliberately no HTTP endpoint for this.
 */
import { PrismaPg } from '@prisma/adapter-pg';

import { PrismaClient, type Role } from '../generated/prisma/client';

const ROLES: readonly Role[] = ['USER', 'ADMIN'];

export async function setRole(prisma: PrismaClient, email: string, role: Role): Promise<boolean> {
  const updated = await prisma.user.updateMany({
    where: { email: email.trim().toLowerCase() },
    data: { role },
  });
  if (updated.count === 0) return false;
  const user = await prisma.user.findUniqueOrThrow({ where: { email: email.trim().toLowerCase() } });
  await prisma.auditLog.create({
    data: { actorId: null, action: 'role.changed', targetId: user.id, details: { role, via: 'cli' } },
  });
  return true;
}

async function main(): Promise<number> {
  const [email, role] = process.argv.slice(2);
  const url = process.env.DATABASE_URL;
  if (!email || !ROLES.includes(role as Role) || !url) {
    console.error('usage: DATABASE_URL=... node dist/cli/set-role.js <email> <USER|ADMIN>');
    return 2;
  }
  const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url }) });
  try {
    if (!(await setRole(prisma, email, role as Role))) {
      console.error(`No account with email ${email}`);
      return 1;
    }
    console.log(`${email} is now ${role}`);
    return 0;
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main().then(
    (code) => process.exit(code),
    (error: unknown) => {
      console.error(error);
      process.exit(1);
    },
  );
}
