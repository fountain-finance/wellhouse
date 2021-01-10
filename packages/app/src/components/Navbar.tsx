import { JsonRpcProvider } from '@ethersproject/providers'

import { Contracts } from '../models/contracts'
import Account from './Account'
import Withdrawable from './Withdrawable'

export default function Navbar({
  address,
  userProvider,
  onConnectWallet,
  contracts,
}: {
  address?: string
  userProvider?: JsonRpcProvider
  onConnectWallet: VoidFunction
  contracts?: Contracts
}) {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '6px 20px',
        borderBottom: '1px solid lightgrey',
      }}
    >
      <span style={{ display: 'grid', gridAutoFlow: 'column', columnGap: 20, alignItems: 'center' }}>
        <a style={{ fontSize: 24 }} href="/">
          ⛲️
        </a>
        <Withdrawable contracts={contracts} address={address} />
      </span>
      <Account userProvider={userProvider} loadWeb3Modal={onConnectWallet} address={address} />
    </div>
  )
}
