import { JsonRpcProvider } from '@ethersproject/providers';

export const mainnetProvider = new JsonRpcProvider('https://mainnet.infura.io/v3/' + process.env.INFURA_ID)
