import { randomBytes, scryptSync } from "node:crypto";
import { PrismaClient, UserRole } from "@prisma/client";

const prisma = new PrismaClient();

function hashPassword(password: string): string {
  const salt = randomBytes(16).toString("hex");
  const hash = scryptSync(password, salt, 64).toString("hex");
  return `${salt}:${hash}`;
}

async function main() {
  const password = process.env.DEMO_PASSWORD;
  if (!password || password.length < 12) {
    throw new Error("Set DEMO_PASSWORD to at least 12 characters before seeding.");
  }

  const demoUsers = [
    { email: "alex.employee@example.test", name: "Alex Employee", role: UserRole.EMPLOYEE },
    { email: "sam.employee@example.test", name: "Sam Employee", role: UserRole.EMPLOYEE },
    { email: "taylor.admin@example.test", name: "Taylor Admin", role: UserRole.ADMIN },
  ];

  for (const user of demoUsers) {
    await prisma.user.upsert({
      where: { email: user.email },
      update: {
        name: user.name,
        role: user.role,
        active: true,
        passwordHash: hashPassword(password),
      },
      create: {
        ...user,
        active: true,
        passwordHash: hashPassword(password),
      },
    });
  }

  await prisma.user.upsert({
    where: { email: "inactive.employee@example.test" },
    update: { name: "Inactive Employee", active: false, passwordHash: null },
    create: {
      email: "inactive.employee@example.test",
      name: "Inactive Employee",
      role: UserRole.EMPLOYEE,
      active: false,
    },
  });
}

main()
  .catch((error: unknown) => {
    console.error("Database seed failed:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
