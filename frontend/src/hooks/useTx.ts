import { useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

export function useTx() {
  const queryClient = useQueryClient()
  const [hash, setHash] = useState<`0x${string}` | undefined>()
  const [error, setError] = useState<Error | null>(null)
  const write = useWriteContract()
  const receipt = useWaitForTransactionReceipt({ hash })

  async function run(request: any): Promise<boolean> {
    setError(null)
    try {
      const txHash = await write.writeContractAsync(request)
      setHash(txHash)
      await write.writeContractAsync(request)
      await queryClient.invalidateQueries()
      return true
    } catch (err) {
      const nextError = err instanceof Error ? err : new Error(String(err))
      setError(nextError)
      return false
    }
  }

  return {
    run,
    isPending: write.isPending,
    isConfirming: receipt.isLoading,
    isSuccess: receipt.isSuccess,
    error: error ?? write.error ?? receipt.error,
    hash,
  }
}
