import { useReadContracts } from 'wagmi'
import type { Address } from 'viem'
import { erc20Abi } from '../abi/erc20'
import { vaultAbi } from '../abi/vault'
import { collateralTokenAddress, lendTokenAddress, vaultAddress } from '../wagmi'

export function useVaultData(user?: Address) {
  const enabled = Boolean(vaultAddress)
  const summary = useReadContracts({
    contracts: [
      { address: vaultAddress as `0x${string}` , abi: vaultAbi, functionName: 'totalSupplied' },
      { address: vaultAddress as `0x${string}` , abi: vaultAbi, functionName: 'totalBorrowed' },
      { address: vaultAddress as `0x${string}` , abi: vaultAbi, functionName: 'availableLiquidity' },
      { address: vaultAddress as `0x${string}` , abi: vaultAbi, functionName: 'totalShares' },
      { address: vaultAddress as `0x${string}` , abi: vaultAbi, functionName: 'collateralPrice' },
      { address: vaultAddress as `0x${string}` , abi: vaultAbi, functionName: 'owner' },
    ],
    query: { enabled },
  })

  const userData = useReadContracts({
    contracts: user
      ? [
          { address: lendTokenAddress as `0x${string}` , abi: erc20Abi, functionName: 'balanceOf', args: [user] },
          { address: collateralTokenAddress as `0x${string}` , abi: erc20Abi, functionName: 'balanceOf', args: [user] },
          { address: vaultAddress as `0x${string}` , abi: vaultAbi, functionName: 'shares', args: [user] },
          { address: vaultAddress as `0x${string}` , abi: vaultAbi, functionName: 'collateral', args: [user] },
          { address: vaultAddress as `0x${string}` , abi: vaultAbi, functionName: 'debt', args: [user] },
          { address: vaultAddress as `0x${string}` , abi: vaultAbi, functionName: 'healthFactor', args: [user] },
          { address: vaultAddress as `0x${string}` , abi: vaultAbi, functionName: 'collateralShortfall', args: [user] },
        ]
      : [],
    query: { enabled: Boolean(user && vaultAddress && lendTokenAddress && collateralTokenAddress) },
  })

  const r = summary.data ?? []
  const u = userData.data ?? []

  return {
    totalSupplied: (r[0]?.result as bigint | undefined) ?? 0n,
    totalBorrowed: (r[1]?.result as bigint | undefined) ?? 0n,
    availableLiquidity: (r[2]?.result as bigint | undefined) ?? 0n,
    totalShares: (r[3]?.result as bigint | undefined) ?? 0n,
    collateralPrice: (r[4]?.result as bigint | undefined) ?? 0n,
    owner: (r[5]?.result as Address | undefined) ?? undefined,
    lendBalance: (u[0]?.result as bigint | undefined) ?? 0n,
    collateralBalance: (u[1]?.result as bigint | undefined) ?? 0n,
    shares: (u[2]?.result as bigint | undefined) ?? 0n,
    collateral: (u[3]?.result as bigint | undefined) ?? 0n,
    debt: (u[4]?.result as bigint | undefined) ?? 0n,
    healthFactor: (u[5]?.result as bigint | undefined) ?? undefined,
    collateralShortfall: (u[6]?.result as bigint | undefined) ?? 0n,
    loading: summary.isLoading || userData.isLoading,
  }
}
