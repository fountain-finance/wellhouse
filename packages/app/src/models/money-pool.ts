import { BigNumber } from '@ethersproject/bignumber'

export interface MoneyPool {
  duration: BigNumber
  number: BigNumber
  start: BigNumber
  target: BigNumber
  total: BigNumber
  want: string
  owner: string
}
