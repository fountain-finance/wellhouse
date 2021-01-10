import { BigNumber } from '@ethersproject/bignumber'

export interface MoneyPool {
  duration: BigNumber
  number: BigNumber
  start: BigNumber
  target: BigNumber
  total: BigNumber
  previous: BigNumber
  tapped: BigNumber
  title: string
  link: string
  want: string
  owner: string
}
