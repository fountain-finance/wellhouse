import { BigNumber } from '@ethersproject/bignumber'

export interface SustainEvent {
  amount: BigNumber
  mpNumber: BigNumber
  beneficiary: string
  owner: string
  sustainer: string
}
