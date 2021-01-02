import { Web3Provider } from '@ethersproject/providers'
import { useCallback, useState } from 'react'

import { localProvider } from '../constants/local-provider'
import { mainnetProvider } from '../constants/mainnet-provider'
import { web3Modal } from '../constants/web3-modal'
import useUserProvider from '../hooks/UserProvider'
import Account from './Account'
import Tab from './Tab'

export default function Navbar() {
  const [injectedProvider, setInjectedProvider] = useState<Web3Provider>()

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

  const loadWeb3Modal = useCallback(async () => {
    const provider = await web3Modal.connect()
    setInjectedProvider(new Web3Provider(provider))
  }, [setInjectedProvider])

  const userProvider = useUserProvider(injectedProvider, localProvider)

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
      {tabs}
      <Account
        userProvider={userProvider}
        localProvider={localProvider}
        mainnetProvider={mainnetProvider}
        loadWeb3Modal={loadWeb3Modal}
      ></Account>
    </div>
  )
}
