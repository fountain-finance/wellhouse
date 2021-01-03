import { JsonRpcProvider } from '@ethersproject/providers'
import { useLayoutEffect, useState } from 'react'

import { localProvider } from '../constants/local-provider'
import Account from './Account'
import Faucet from './Faucet'
import Tab from './Tab'

export default function Navbar({
  userProvider,
  onConnectWallet,
}: {
  userProvider?: JsonRpcProvider
  onConnectWallet: VoidFunction
}) {
  const [address, setAddress] = useState<string>()

  // https://github.com/austintgriffith/eth-hooks/blob/master/src/UserAddress.ts
  useLayoutEffect(() => {
    userProvider?.getSigner().getAddress().then(setAddress)
  }, [userProvider, setAddress])

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

  const showFaucet =
    localProvider?.connection?.url?.indexOf('localhost') >= 0 &&
    userProvider?.connection?.url.includes('unknown') &&
    !process.env.REACT_APP_PROVIDER &&
    address

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
        {showFaucet ? (
          <span style={{ marginRight: 30 }}>
            <Faucet address={address} />
          </span>
        ) : (
          ''
        )}
        <Account userProvider={userProvider} loadWeb3Modal={onConnectWallet} address={address}></Account>
      </div>
    </div>
  )
}
