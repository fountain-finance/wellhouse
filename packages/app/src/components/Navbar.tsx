import { JsonRpcProvider } from '@ethersproject/providers'

import Account from './Account'

export default function Navbar({
  address,
  userProvider,
  onConnectWallet,
}: {
  address?: string
  userProvider?: JsonRpcProvider
  onConnectWallet: VoidFunction
}) {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'baseline',
        justifyContent: 'flex-end',
        padding: 20,
        borderBottom: '1px solid lightgrey',
      }}
    >
      <Account userProvider={userProvider} loadWeb3Modal={onConnectWallet} address={address}></Account>
    </div>
  )
}
