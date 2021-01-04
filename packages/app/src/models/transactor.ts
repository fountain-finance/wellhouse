import { Deferrable } from '@ethersproject/properties'
import { TransactionRequest } from '@ethersproject/providers'
import { TransactionEvent } from 'bnc-notify'

export type Transactor = (
  tx: Deferrable<TransactionRequest>,
  callback?: (e: TransactionEvent) => void,
) => Promise<unknown>
