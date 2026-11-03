import { Alert, Button, Container, Navbar as BsNavbar } from 'react-bootstrap'
import { useAccount, useConnect, useDisconnect, useSwitchChain } from 'wagmi'
import { selectedChain } from '../wagmi'

function shorten(value: string) {
  return `${value.slice(0, 6)}...${value.slice(-4)}`
}

export function Navbar() {
  const { address, chainId, isConnected } = useAccount()
  const { connect, connectors } = useConnect()
  const { disconnect } = useDisconnect()
  const { switchChain, isPending } = useSwitchChain()
  const wrongChain = isConnected && chainId !== selectedChain.id

  return (
    <>
      <BsNavbar className="shadow-sm bg-white border-bottom">
        <Container>
          <BsNavbar.Brand className="fw-bold">Mini Lending Vault</BsNavbar.Brand>
          <div className="d-flex align-items-center gap-2">
            {address && isConnected ? (
              <>
                <span className="badge rounded-pill bg-light text-dark border">{shorten(address)}</span>
                <Button size="sm" variant="outline-secondary" onClick={() => disconnect()}>Disconnect</Button>
              </>
            ) : (
              <Button
                size="sm"
                onClick={() => {
                  const connector = connectors[0]
                  if (connector) connect({ connector })
                }}
              >
                Connect MetaMask
              </Button>
            )}
          </div>
        </Container>
      </BsNavbar>
      {wrongChain && (
        <Container className="pt-3">
          <Alert variant="warning" className="d-flex align-items-center justify-content-between gap-3 mb-0">
            <span>Wallet is on the wrong network. Switch to {selectedChain.name}.</span>
            <Button size="sm" variant="warning" disabled={isPending} onClick={() => switchChain({ chainId: selectedChain.id })}>
              {isPending ? 'Switching…' : 'Switch network'}
            </Button>
          </Alert>
        </Container>
      )}
    </>
  )
}
