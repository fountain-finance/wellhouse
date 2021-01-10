import { BigNumber } from '@ethersproject/bignumber'

export interface MoneyPool {
  duration: BigNumber
  number: BigNumber
  start: BigNumber
  target: BigNumber
  total: BigNumber
  title: string
  link: string
  want: string
  owner: string
}
