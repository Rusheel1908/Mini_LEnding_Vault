import { useState } from 'react'
import { Alert, Button, Card, Col, Form, Row } from 'react-bootstrap'
import { useReadContract } from 'wagmi'
import type { Address } from 'viem'
import { erc20Abi } from '../abi/erc20'
import { vaultAbi } from '../abi/vault'
import { useTx } from '../hooks/useTx'
import type { useVaultData } from '../hooks/useVaultData'
import { formatToken, parseAmount } from '../utils/format'
import { lendTokenAddress, vaultAddress } from '../wagmi'
import { TxFeedback } from './TxFeedback'

type VaultData = ReturnType<typeof useVaultData>

export function LenderPanel({ data, address }: { data: VaultData; address?: Address }) {
  const [depositValue, setDepositValue] = useState('')
  const [withdrawValue, setWithdrawValue] = useState('')
  const tx = useTx()

  const depositAmount = parseAmount(depositValue)
  const withdrawAmount = parseAmount(withdrawValue)
  const allowRead = useReadContract({
    address: lendTokenAddress as `0x${string}`,
    abi: erc20Abi,
    functionName: 'allowance',
    args: address && vaultAddress ? [address, vaultAddress as `0x${string}`] : undefined,
    query: { enabled: Boolean(address && vaultAddress) },
  })

  const maxWithdrawAssets = withdrawAmount && data.totalShares > 0n ? (withdrawAmount * data.totalSupplied) / data.totalShares : 0n

  async function doDeposit() {
    if (!address || !depositAmount || !vaultAddress || !lendTokenAddress) return
    if ((allowRead.data ?? 0n) < depositAmount) {
      const approved = await tx.run({ address: lendTokenAddress as `0x${string}`, abi: erc20Abi, functionName: 'approve', args: [vaultAddress as `0x${string}`, depositAmount] })
      if (!approved) return
    }
    await tx.run({ address: vaultAddress as `0x${string}`, abi: vaultAbi, functionName: 'deposit', args: [depositAmount] })
  }

  async function doWithdraw() {
    if (!address || !withdrawAmount || !vaultAddress) return
    await tx.run({ address: vaultAddress as `0x${string}`, abi: vaultAbi, functionName: 'withdraw', args: [withdrawAmount] })
  }

  const canDeposit = Boolean(address && depositAmount && depositAmount > 0n && depositAmount <= data.lendBalance)
  const canWithdraw = Boolean(address && withdrawAmount && withdrawAmount > 0n && withdrawAmount <= data.shares)

  return (
    <>
      {!address && <Alert variant="info">Connect wallet to use the lender panel.</Alert>}
      <Row className="g-3">
        <Col lg={6}>
          <Card>
            <Card.Body>
              <Card.Title>Deposit LEND</Card.Title>
              <Form.Group className="mb-3">
                <Form.Label>Amount</Form.Label>
                <div className="input-group">
                  <Form.Control value={depositValue} onChange={(event) => setDepositValue(event.target.value)} placeholder="0.00" disabled={!address} />
                  <Button variant="outline-secondary" onClick={() => setDepositValue(formatToken(data.lendBalance, 18, 18))} disabled={!address}>Max</Button>
                </div>
                <Form.Text>Balance: {formatToken(data.lendBalance)} LEND</Form.Text>
              </Form.Group>
              <Button className="w-100" disabled={!canDeposit || tx.isPending || tx.isConfirming} onClick={() => void doDeposit()}>
                {tx.isPending ? 'Waiting...' : tx.isConfirming ? 'Confirming...' : 'Deposit'}
              </Button>
              <TxFeedback tx={tx} />
            </Card.Body>
          </Card>
        </Col>
        <Col lg={6}>
          <Card>
            <Card.Body>
              <Card.Title>Withdraw shares</Card.Title>
              <Form.Group className="mb-3">
                <Form.Label>Shares</Form.Label>
                <div className="input-group">
                  <Form.Control value={withdrawValue} onChange={(event) => setWithdrawValue(event.target.value)} placeholder="0.00" disabled={!address} />
                  <Button variant="outline-secondary" onClick={() => setWithdrawValue(formatToken(data.shares, 18, 18))} disabled={!address}>Max</Button>
                </div>
                <Form.Text>Available shares: {formatToken(data.shares)} · Est. receive: {formatToken(maxWithdrawAssets)} LEND</Form.Text>
              </Form.Group>
              <Button className="w-100" variant="outline-primary" disabled={!canWithdraw || tx.isPending || tx.isConfirming} onClick={() => void doWithdraw()}>
                {tx.isPending ? 'Waiting...' : tx.isConfirming ? 'Confirming...' : 'Withdraw'}
              </Button>
              <TxFeedback tx={tx} />
            </Card.Body>
          </Card>
        </Col>
      </Row>
    </>
  )
}
