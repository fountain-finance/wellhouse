import { JsonRpcProvider } from '@ethersproject/providers'
import { Fetcher, Route, Token, WETH } from '@uniswap/sdk'
import { useState } from 'react'

import { daiAddress } from './../constants/dai-address'
import { usePoller } from './Poller'

export default function useExchangePrice(mainnetProvider: JsonRpcProvider, pollTime = 1000) {
  const [price, setPrice] = useState(0)

  /* 💵 get the price of ETH from 🦄 Uniswap: */
  const pollPrice = () => {
    async function getPrice() {
      const DAI = new Token(mainnetProvider.network ? mainnetProvider.network.chainId : 1, daiAddress, 18)
      const pair = await Fetcher.fetchPairData(DAI, WETH[DAI.chainId], mainnetProvider)
      const route = new Route([pair], WETH[DAI.chainId])
      setPrice(parseFloat(route.midPrice.toSignificant(6)))
    }
    getPrice()
  }
  usePoller(pollPrice, pollTime)

  return price
}
