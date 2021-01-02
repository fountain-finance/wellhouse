import { JsonRpcProvider } from '@ethersproject/providers'

// 🏠 Your local provider is usually pointed at your local blockchain
const localProviderUrl = 'http://localhost:8545' // for xdai: https://dai.poa.network
// as you deploy to other networks you can set REACT_APP_PROVIDER=https://dai.poa.network in packages/react-app/.env
const localProviderUrlFromEnv = process.env.REACT_APP_PROVIDER ? process.env.REACT_APP_PROVIDER : localProviderUrl

export const localProvider = new JsonRpcProvider(localProviderUrlFromEnv)
