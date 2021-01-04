import './App.scss'
import 'antd/dist/antd.css'

import { BigNumber } from '@ethersproject/bignumber'
import { Web3Provider } from '@ethersproject/providers'
import { useCallback, useState } from 'react'
import { BrowserRouter, Route, Switch } from 'react-router-dom'

import CreateMp from './components/CreateMp'
import Navbar from './components/Navbar'
import { localProvider } from './constants/local-provider'
import { web3Modal } from './constants/web3-modal'
import { createNotifier } from './helpers/Notifier'
import { useContractLoader } from './hooks/ContractLoader'
import { useGasPrice } from './hooks/GasPrice'
import { useUserProvider } from './hooks/UserProvider'

function App() {
  const [injectedProvider, setInjectedProvider] = useState<Web3Provider>()

  const loadWeb3Modal = useCallback(async () => {
    const provider = await web3Modal.connect()
    setInjectedProvider(new Web3Provider(provider))
  }, [setInjectedProvider])

  const gasPrice = useGasPrice('fast')

  const userProvider = useUserProvider(injectedProvider, localProvider)

  console.log('using provider:', userProvider)

  const notifier = createNotifier({
    provider: userProvider,
    gasPrice: gasPrice !== undefined ? BigNumber.from(gasPrice) : undefined,
  })

  const contracts = useContractLoader(userProvider)

  return (
    <div className="App">
      <Navbar userProvider={userProvider} onConnectWallet={loadWeb3Modal}></Navbar>

      <BrowserRouter>
        <Switch>
          <Route exact path="/"></Route>
          <Route exact path="/create">
            <CreateMp notifier={notifier} contracts={contracts} />
          </Route>
        </Switch>
      </BrowserRouter>
    </div>
  )
}

export default App
