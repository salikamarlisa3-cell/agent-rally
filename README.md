# AgentRally 🏁

**The daily check-in club for Agent ID holders on BNB Chain.**

AgentRally is a dApp built for the **Binance Wallet × BNB Chain Agent ID Hackathon**. It gives Agent ID (.ai) holders a simple daily ritual with lasting on-chain proof: check in once a day, build a streak, and earn soulbound badges.

🌐 Live site: https://salikamarlisa3-cell.github.io/agent-rally/
📜 Contract (BNB Chain): `0x3745dE1B6F2d2f818b680ecb2533e2703eAc77fd`

## How Agent ID is used

Agent ID is not decoration here — it is the access key and the identity layer of the whole product:

- **Access control:** `checkIn()` calls `balanceOf(address)` on the official Agent ID registry (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`). Only addresses holding an Agent ID can check in; everyone else is rejected on-chain.
- **Identity-bound achievements:** badges are minted as **soulbound ERC-721** tokens (transfers and approvals always revert), mirroring the non-transferable nature of Agent ID itself. Your rally history is bound to the same identity that holds your .ai name.
- **Community pulse:** the contract keeps public counters (unique agents, check-ins today, total check-ins) — an on-chain heartbeat of the Agent ID community.

## How it works

- Check in once per day (UTC day). Consecutive days build your **streak**; a missed day resets the streak (your total and badges are kept).
- Badges are minted automatically when your **total** check-ins reach a milestone:

| Tier | Badge | Milestone |
|------|-------|-----------|
| 1 | First Rally | 1 check-in |
| 2 | Hat Trick | 3 check-ins |
| 3 | Week Warrior | 7 check-ins |
| 4 | Rally Legend | 14 check-ins |

## Safety by design

- The contract has **no owner and no admin functions**: nobody can pause it, change the rules, move badges, or seize anything. It never holds or moves user funds — check-in costs only network gas.
- No QR-code or pairing-code sign-in, no session storage on any server, no collection of seed phrases / private keys / credentials. The site only asks your own wallet to sign the check-in transaction, which you review and confirm yourself.
- No returns are promised anywhere. Badges are commemorative only.

## Tech

- `contracts/AgentRally.sol` — a single dependency-free Solidity 0.8.24 contract (check-in logic + minimal soulbound ERC-721), deployed via the public CREATE2 deterministic deployment proxy (`0x4e59b44847b379578588920cA78FbF26c0B4956C`).
- The site is static (GitHub Pages) and talks to the contract through any injected wallet on BNB Chain plus a public RPC for read-only stats.
- Local test suite (ganache): 22/22 checks pass — Agent ID gating, once-per-day rule, streak build/reset, milestone badge minting, soulbound reverts, ERC-721 interface support.

## License

MIT
