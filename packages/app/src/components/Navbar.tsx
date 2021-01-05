import { JsonRpcProvider } from '@ethersproject/providers'

import Account from './Account'
import Tab from './Tab'

export default function Navbar({
  address,
  userProvider,
  onConnectWallet,
}: {
  address?: string
  userProvider?: JsonRpcProvider
  onConnectWallet: VoidFunction
}) {
  // Key tabs by index
  const tabs = [
    Tab({
      name: 'Create',
      link: '/create',
    }),
  ].map((tab, key) => ({
    ...tab,
    key,
  }))

  // const showFaucet =
  //   localProvider?.connection?.url?.indexOf('localhost') >= 0 &&
  //   userProvider?.connection?.url.includes('unknown') &&
  //   !process.env.REACT_APP_PROVIDER &&
  //   address

  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'baseline',
        justifyContent: 'space-between',
        padding: 20,
        borderBottom: '1px solid lightgrey',
      }}
    >
      <div>{tabs}</div>
      <div>
        {/* {showFaucet ? (
          <span style={{ marginRight: 30 }}>
            <Faucet address={address} />
          </span>
        ) : (
          ''
        )} */}
        <Account userProvider={userProvider} loadWeb3Modal={onConnectWallet} address={address}></Account>
      </div>
    </div>
  )
}
