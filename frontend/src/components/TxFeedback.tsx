import { Alert } from 'react-bootstrap'
import { friendlyError } from '../utils/format'
import { selectedChain } from '../wagmi'

export function TxFeedback({ tx }: { tx: any }) {
  const errorText = friendlyError(tx.error)
  return (
    <>
      {errorText && <Alert className="mt-3 mb-0" variant="danger">{errorText}</Alert>}
      {tx.isSuccess && tx.hash && (
        <Alert className="mt-3 mb-0" variant="success">
          Transaction confirmed.{' '}
          {selectedChain.blockExplorers?.default?.url ? (
            <a href={`${selectedChain.blockExplorers.default.url}/tx/${tx.hash}`} target="_blank" rel="noreferrer">View on block explorer</a>
          ) : (
            'View your wallet history.'
          )}
        </Alert>
      )}
    </>
  )
}
