import { BigNumber } from '@ethersproject/bignumber'
import React from 'react'

import useContractReader from '../hooks/ContractReader'
import { Contracts } from '../models/contracts'

export default function Withdrawable({ contracts, address }: { contracts?: Contracts; address?: string }) {
  const withdrawable: BigNumber | undefined = useContractReader({
    contract: contracts?.Fountain,
    functionName: 'getAllTrackedRedistribution',
    args: [address, false],
  })

  const pendingWithdrawable: BigNumber | undefined = useContractReader({
    contract: contracts?.Fountain,
    functionName: 'getAllTrackedRedistribution',
    args: [address, true],
  })

  return (
    <div style={{ display: 'grid', gridAutoFlow: 'column', columnGap: 30 }}>
      <div>Withdrawable: {withdrawable?.toNumber() ?? 0}</div>
      <div>Withdrawable soon: {(pendingWithdrawable?.toNumber() ?? 0) - (withdrawable?.toNumber() ?? 0)}</div>
    </div>
  )
}
