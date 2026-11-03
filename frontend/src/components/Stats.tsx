import { Badge, Card, Col, Row, Spinner } from 'react-bootstrap'
import type { Address } from 'viem'
import { formatHealthFactor, formatToken, healthBadgeVariant } from '../utils/format'
import type { useVaultData } from '../hooks/useVaultData'

type VaultData = ReturnType<typeof useVaultData>

export function Stats({ data, address }: { data: VaultData; address?: Address }) {
  const shareValue = data.totalShares > 0n ? (data.shares * data.totalSupplied) / data.totalShares : 0n

  return (
    <Row className="g-3 mb-4">
      <Col md={6} xl={3}><Card className="h-100"><Card.Body><div className="muted-label">Total supplied</div><div className="stat-number">{formatToken(data.totalSupplied)} LEND</div></Card.Body></Card></Col>
      <Col md={6} xl={3}><Card className="h-100"><Card.Body><div className="muted-label">Total borrowed</div><div className="stat-number">{formatToken(data.totalBorrowed)} LEND</div></Card.Body></Card></Col>
      <Col md={6} xl={3}><Card className="h-100"><Card.Body><div className="muted-label">Available liquidity</div><div className="stat-number">{formatToken(data.availableLiquidity)} LEND</div></Card.Body></Card></Col>
      <Col md={6} xl={3}><Card className="h-100"><Card.Body><div className="muted-label">Collateral price</div><div className="stat-number">{formatToken(data.collateralPrice)} LEND</div></Card.Body></Card></Col>
      <Col md={6} xl={3}><Card className="h-100"><Card.Body><div className="muted-label">Your LEND</div><div className="stat-number">{address ? formatToken(data.lendBalance) : 'Connect wallet'}</div></Card.Body></Card></Col>
      <Col md={6} xl={3}><Card className="h-100"><Card.Body><div className="muted-label">Your collateral</div><div className="stat-number">{address ? formatToken(data.collateralBalance) : 'Connect wallet'}</div></Card.Body></Card></Col>
      <Col md={6} xl={3}><Card className="h-100"><Card.Body><div className="muted-label">Your shares</div><div className="stat-number">{address ? `${formatToken(data.shares)} / ${formatToken(shareValue)} LEND` : 'Connect wallet'}</div></Card.Body></Card></Col>
      <Col md={6} xl={3}><Card className="h-100"><Card.Body><div className="muted-label">Health factor</div><div className="stat-number">{address ? data.healthFactor === undefined ? <Spinner animation="border" size="sm" /> : <Badge bg={healthBadgeVariant(data.healthFactor)}>{formatHealthFactor(data.healthFactor)}</Badge> : 'Connect wallet'}</div></Card.Body></Card></Col>
    </Row>
  )
}
