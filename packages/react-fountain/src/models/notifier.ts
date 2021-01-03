import { Deferrable } from '@ethersproject/properties'
import { TransactionRequest } from '@ethersproject/providers'

export type Notifier = (tx: Deferrable<TransactionRequest>) => Promise<unknown>
