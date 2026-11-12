# TrustFund

TrustFund is a starter monorepo for the Avalanche Fuji crowdfunding MVP described in `trustfund.docx`. It contains the app layout and local development setup. Campaign escrow, wallet transactions, API routes, event indexing, deployment and tests remain implementation tasks.

## Repository layout

```text
apps/
  api/       Express + TypeScript starter, Prisma schema and health route
  web/       Next.js + TypeScript + Tailwind UI starter
contracts/   Foundry Solidity starter
.github/     GitHub Actions workflow starter
docker-compose.yml
```

## Requirements

- Node.js 20 or newer
- pnpm 9 (`npm install --global pnpm`)
- Docker Desktop / Docker Engine
- Foundry, if you plan to work on Solidity (`https://getfoundry.sh`)

## Install and run locally

From the repository root:

```sh
pnpm install
cp .env.example .env
docker compose up -d db
pnpm --filter @trustfund/api db:push
pnpm dev
```

On Windows PowerShell, copy the example environment file with:

```powershell
Copy-Item .env.example .env
```

The web starter runs at `http://localhost:3000`. The API health route is at `http://localhost:4000/health`. Example campaign cards in the UI are placeholder data.

To run the API and database in containers instead of starting them through pnpm:

```sh
docker compose up --build
```

## Smart contract starter

```sh
cd contracts
forge build
```

The contract is intentionally a stub. Before implementing it, agree on who approves milestones, what makes a campaign successful, and when contributors can claim refunds. Never commit private keys, seed phrases, RPC credentials or database passwords.

## Next implementation steps

1. Agree contract rules and events; implement and test the escrow contract.
2. Connect the UI to Fuji, add create/donate and milestone actions, and replace placeholder campaign data.
3. Implement API read routes and an idempotent event indexer with PostgreSQL persistence.
4. Add CI checks for lint, tests and builds; configure deployment after selecting a VPS, domain and secret store.

The workflow in `.github/workflows/ci.yml` is a CI starting point. Use feature branches and pull requests into `develop`; review before promoting to `main`. No deployed contract address, RPC secret, VPS or domain was provided, so deployment is not configured.
