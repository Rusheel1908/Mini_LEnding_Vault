import { decodeErrorResult, formatUnits, isAddress, parseUnits } from 'viem'
import type { Address } from 'viem'
import { vaultAbi } from '../abi/vault'

export function formatToken(value: bigint | undefined, decimals = 18, maxFraction = 4) {
  if (value === undefined) return '—'
  const s = formatUnits(value, decimals)
  const [whole, fraction = ''] = s.split('.')
  const trimmed = fraction.slice(0, maxFraction).replace(/0+$/, '')
  return trimmed ? `${whole}.${trimmed}` : whole
}

export function parseAmount(raw: string): bigint | null {
  const trimmed = raw.trim()
  if (!trimmed) return null
  if (!/^\d*\.?\d*$/.test(trimmed)) return null
  try {
    return parseUnits(trimmed, 18)
  } catch {
    return null
  }
}

export function formatHealthFactor(value: bigint | undefined) {
  if (value === undefined) return '—'
  if (value === (2n ** 256n - 1n)) return '∞ (no debt)'
  const num = Number(value) / 1e18
  if (!Number.isFinite(num)) return '—'
  return num.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

export function healthBadgeVariant(value: bigint | undefined): 'danger' | 'warning' | 'success' | 'secondary' {
  if (value === undefined) return 'secondary'
  if (value === (2n ** 256n - 1n)) return 'success'
  const ratio = Number(value) / 1e18
  if (ratio < 1) return 'danger'
  if (ratio <= 1.2) return 'warning'
  return 'success'
}

export function isValidAddress(value: string): value is Address {
  return isAddress(value)
}

const errorMap: Record<string, string> = {
  ZeroAmount: 'Enter an amount greater than zero.',
  ZeroPrice: 'Price must remain greater than zero.',
  NotOwner: 'Only the vault owner may perform this action.',
  TransferFailed: 'The token transfer failed.',
  InsufficientShares: 'You do not have enough vault shares.',
  InsufficientLiquidity: 'The vault does not have enough available liquidity.',
  InsufficientCollateral: 'This withdrawal would exceed your collateral position.',
  UnhealthyPosition: 'This action would leave the user below the required health threshold.',
  NothingToTopUp: 'There is no shortfall to fill.',
  Reentrancy: 'The vault blocked this call to prevent reentrancy.',
}

export function friendlyError(error: Error | null | undefined): string | undefined {
  if (!error) return undefined
  const msg = error.message || String(error)
  const lowered = msg.toLowerCase()
  if (lowered.includes('rejected') || lowered.includes('denied')) return 'User rejected the request.'
  for (const [name, friendly] of Object.entries(errorMap)) {
    if (msg.includes(name)) return friendly
  }
  try {
    const match = msg.match(/0x[0-9a-fA-F]{8,}/)
    if (match) {
      const result = decodeErrorResult({ abi: vaultAbi, data: match[0] as `0x${string}` })
      if (result.errorName && result.errorName in errorMap) return errorMap[result.errorName]
    }
  } catch {
    // ignore decode errors and fall back to message
  }
  return msg.split('\n')[0]
}
