import { Injectable } from '@angular/core'
import { Router } from '@angular/router'
import { BigNumberish } from '@ethersproject/bignumber'
import { Web3Provider } from '@ethersproject/providers'
import { formatUnits } from '@ethersproject/units'
import BurnerProvider from 'burner-provider'
import { BehaviorSubject } from 'rxjs'

import { infuraId } from '../constants/infura-id'
import { localProvider } from '../constants/local-provider'
import { web3Modal } from '../constants/web3-modal'

@Injectable({
  providedIn: 'root',
})
export class AccountService {
  private readonly wallet = new BehaviorSubject<string>(undefined)
  private readonly balance = new BehaviorSubject<number>(undefined)
  readonly wallet$ = this.wallet.asObservable()
  readonly balance$ = this.balance.asObservable()

  constructor(private router: Router) {}

  loadAccount = async (provider?: Web3Provider) => {
    const userProvider = provider ?? burnerProvider()

    const address = await getUserAddress(userProvider)
    this.wallet.next(address)

    const balance = parseFloat(
      formatUnits(await userProvider.getBalance(address), 'ether' as BigNumberish)
    )
    this.balance.next(balance)
  }

  connectAccount = async () => this.loadAccount(new Web3Provider(await web3Modal.connect()))

  logout = async () => {
    this.wallet.next(undefined)
    this.balance.next(undefined)

    await web3Modal.clearCachedProvider()

    this.router.navigate(['/app'])
  }
}

// https://github.com/austintgriffith/eth-hooks/blob/master/src/UserAddress.ts
const getUserAddress = async (provider: Web3Provider): Promise<string> => {
  return await provider.getSigner().getAddress()
}

const burnerProvider = () => {
  let burnerConfig = {
    rpcUrl: undefined,
    privateKey: undefined,
  }

  // if (window.location.pathname) {
  //   if(window.location.pathname.indexOf("/pk")>=0){
  //     let incomingPK = window.location.hash.replace("#","")
  //     let rawPK

  //     if(incomingPK.length===64||incomingPK.length===66){
  //       console.log("🔑 Incoming Private Key...");
  //       rawPK=incomingPK
  //       burnerConfig.privateKey = rawPK
  //       window.history.pushState({},"", "/");
  //       let currentPrivateKey = window.localStorage.getItem("metaPrivateKey");
  //       if(currentPrivateKey && currentPrivateKey!==rawPK){
  //         window.localStorage.setItem("metaPrivateKey_backup"+Date.now(),currentPrivateKey);
  //       }
  //       window.localStorage.setItem("metaPrivateKey",rawPK);
  //     }
  //   }
  // }

  if (localProvider.connection && localProvider.connection.url) {
    burnerConfig.rpcUrl = localProvider.connection.url
    return new Web3Provider(new BurnerProvider(burnerConfig))
  } else {
    // eslint-disable-next-line no-underscore-dangle
    const networkName = localProvider._network && localProvider._network.name

    burnerConfig.rpcUrl = `https://${networkName || 'mainnet'}.infura.io/v3/${infuraId}`

    return new Web3Provider(new BurnerProvider(burnerConfig))
  }
}
