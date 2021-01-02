import { JsonRpcProvider, Web3Provider } from '@ethersproject/providers'
import { useLayoutEffect, useState } from 'react'

import { web3Modal } from '../constants/web3-modal'
import useExchangePrice from '../hooks/ExchangePrice'
import Balance from './Balance'
import Wallet from './Wallet'

export default function Account({
  userProvider,
  localProvider,
  mainnetProvider,
  loadWeb3Modal,
}: {
  userProvider?: Web3Provider
  localProvider: JsonRpcProvider
  mainnetProvider: JsonRpcProvider
  loadWeb3Modal: VoidFunction
}) {
  const [address, setAddress] = useState<string>()

  // https://github.com/austintgriffith/eth-hooks/blob/master/src/UserAddress.ts
  useLayoutEffect(() => {
    const provider = userProvider ?? localProvider
    provider.getSigner().getAddress().then(setAddress)
  }, [userProvider, localProvider])

  const logoutOfWeb3Modal = async () => {
    await web3Modal.clearCachedProvider()
    setTimeout(() => {
      window.location.reload()
    }, 1)
  }

  const price = useExchangePrice(mainnetProvider)

  return (
    <div style={{ display: 'inline-grid', gridAutoFlow: 'column', columnGap: 30, alignItems: 'baseline' }}>
      <Balance address={address} provider={userProvider ?? localProvider} dollarMultiplier={price} />
      <Wallet address={address}></Wallet>
      {web3Modal?.cachedProvider ? (
        <button onClick={logoutOfWeb3Modal}>Logout</button>
      ) : (
        <button onClick={loadWeb3Modal}>Connect</button>
      )}
    </div>
  )
}
