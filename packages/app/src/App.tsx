import './App.scss'

import { BigNumber } from '@ethersproject/bignumber'
import { Web3Provider } from '@ethersproject/providers'
import { useCallback, useEffect, useState } from 'react'
import { BrowserRouter, Route, Switch } from 'react-router-dom'

import Gimme from './components/Gimme'
import InitTickets from './components/InitTickets'
import Landing from './components/Landing'
import MoneyPoolsHistory from './components/MoneyPoolsHistory'
import Navbar from './components/Navbar'
import MoneyPools from './components/Owner'
import { localProvider } from './constants/local-provider'
import { web3Modal } from './constants/web3-modal'
import { createTransactor } from './helpers/Transactor'
import { useContractLoader } from './hooks/ContractLoader'
import useContractReader from './hooks/ContractReader'
import { useGasPrice } from './hooks/GasPrice'
import { useUserProvider } from './hooks/UserProvider'
import { MoneyPool } from './models/money-pool'

function App() {
  const [injectedProvider, setInjectedProvider] = useState<Web3Provider>()
  const [address, setAddress] = useState<string>()

  const gasPrice = useGasPrice('fast')

  const userProvider = useUserProvider(injectedProvider, localProvider)

  const loadWeb3Modal = useCallback(async () => {
    const provider = await web3Modal.connect()
    setInjectedProvider(new Web3Provider(provider))
  }, [setInjectedProvider])

  // https://github.com/austintgriffith/eth-hooks/blob/master/src/UserAddress.ts
  useEffect(() => {
    userProvider
      ?.getSigner()
      .getAddress()
      .then(address => setAddress(address))
  }, [userProvider, setAddress])

  const transactor = createTransactor({
    provider: userProvider,
    gasPrice: typeof gasPrice === 'number' ? BigNumber.from(gasPrice) : undefined,
  })

  const contracts = useContractLoader(userProvider)

  console.log('using provider:', userProvider)

  const hasMp = useContractReader<boolean>({
    contract: contracts?.MpStore,
    functionName: 'getCurrentMp',
    args: [address],
    formatter: (val: MoneyPool) => !!val,
  })

  return (
    <div className="App">
      <Navbar hasMp={hasMp} address={address} userProvider={userProvider} onConnectWallet={loadWeb3Modal} />

      <div style={{ padding: 20 }}>
        <BrowserRouter>
          <Switch>
            <Route exact path="/">
              <Landing address={address} onNeedAddress={loadWeb3Modal} />
            </Route>
            <Route exact path="/init">
              <InitTickets contracts={contracts} transactor={transactor} />
            </Route>
            <Route exact path="/gimme">
              <Gimme contracts={contracts} transactor={transactor} address={address}></Gimme>
            </Route>
            <Route exact path="/:owner">
              <MoneyPools contracts={contracts} transactor={transactor} address={address} />
            </Route>
            <Route exact path="/history/:number">
              <MoneyPoolsHistory contracts={contracts} transactor={transactor} address={address} />
            </Route>
          </Switch>
        </BrowserRouter>
      </div>
    </div>
  )
}

export default App
