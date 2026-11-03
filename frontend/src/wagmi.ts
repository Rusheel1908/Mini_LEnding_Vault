import { createConfig, http } from 'wagmi'
import { injected } from 'wagmi/connectors'
import { foundry, sepolia } from 'viem/chains'

const chainId = Number(import.meta.env.VITE_CHAIN_ID ?? 11155111)
export const selectedChain = chainId === 31337 ? foundry : sepolia

export const wagmiConfig = createConfig({
  chains: [selectedChain],
  connectors: [injected()],
  transports: {
    [selectedChain.id]: http(),
  },
})

export const vaultAddress = (import.meta.env.VITE_VAULT_ADDRESS as `0x${string}` | undefined) ?? '0x0000000000000000000000000000000000000000'
export const lendTokenAddress = (import.meta.env.VITE_LEND_TOKEN_ADDRESS as `0x${string}` | undefined) ?? '0x0000000000000000000000000000000000000000'
export const collateralTokenAddress = (import.meta.env.VITE_COLLATERAL_TOKEN_ADDRESS as `0x${string}` | undefined) ?? '0x0000000000000000000000000000000000000000'
