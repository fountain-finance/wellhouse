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
        alignItems: 'baseline',
        justifyContent: 'space-between',
        padding: '10px 20px',
        borderBottom: '1px solid lightgrey',
      }}
    >
      <Withdrawable contracts={contracts} address={address} />
      <Account userProvider={userProvider} loadWeb3Modal={onConnectWallet} address={address} />
    </div>
  )
}
