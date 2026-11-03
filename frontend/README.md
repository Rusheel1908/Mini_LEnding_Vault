# Mini Lending Vault frontend

This frontend connects to the `MiniLendingVault` contract from `Smart_Contract/src/MiniLendingVault.sol`.

## Install and run

1. Install dependencies:
   ```bash
   npm install
   ```
2. Copy `.env.example` to `.env` and fill in addresses and chain ID:
   ```bash
   cp .env.example .env
   ```
3. Start Vite:
   ```bash
   npm run dev
   ```
4. Create a production build:
   ```bash
   npm run build
   ```

## .env values

- `VITE_VAULT_ADDRESS`: deployed vault contract address
- `VITE_LEND_TOKEN_ADDRESS`: LEND ERC-20 token address
- `VITE_COLLATERAL_TOKEN_ADDRESS`: collateral ERC-20 token address
- `VITE_CHAIN_ID`: `11155111` for Sepolia or `31337` for local Anvil

## Assumptions

- Both ERC-20 tokens use 18 decimals.
- The vault is deployed with a valid initial collateral price scaled to 1e18.
- MetaMask is installed and connected to the same network as the vault.
- The ABI was generated from the Foundry build output in `Smart_Contract/out`.
