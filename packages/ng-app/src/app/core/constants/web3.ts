import { InjectionToken } from '@angular/core'

declare global {
  const web3: any

  class Web3 {
    currentProvider: any
    givenProvider: any
    eth: {
      Contract: any
      abi: any
      getAccounts: () => any
    }

    constructor(provider: string)
  }

  interface Window {
    web3: any
  }
}

export const WEB3 = new InjectionToken<Web3>('web3', {
  providedIn: 'root',
  factory: () => {
    if (typeof web3 !== 'undefined') return new Web3(web3.currentProvider)
  },
})
