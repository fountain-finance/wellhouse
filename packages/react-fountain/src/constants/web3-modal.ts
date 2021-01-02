import WalletConnectProvider from '@walletconnect/web3-provider'
import Web3Modal from 'web3modal'

import { infuraId } from './infura-id'

/*
  Web3 modal helps us "connect" external wallets:
*/
export const web3Modal = new Web3Modal({
  // network: "mainnet", // optional
  cacheProvider: true, // optional
  providerOptions: {
    walletconnect: {
      package: WalletConnectProvider, // required
      options: {
        infuraId,
      },
    },
  },
})
