import { JsonRpcProvider } from '@ethersproject/providers'

// 🏠 Your local provider is usually pointed at your local blockchain
const localProviderUrl = 'http://localhost:8545' // for xdai: https://dai.poa.network

export const localProvider = new JsonRpcProvider(localProviderUrl)
