import { JsonRpcProvider } from '@ethersproject/providers'

import { infuraId } from './infura-id'

export const mainnetProvider = new JsonRpcProvider('https://mainnet.infura.io/v3/' + infuraId)
