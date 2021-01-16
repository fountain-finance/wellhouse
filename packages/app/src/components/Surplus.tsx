import { BigNumber } from '@ethersproject/bignumber'
import React from 'react'

import useContractReader from '../hooks/ContractReader'
import { Contracts } from '../models/contracts'

export default function Surplus({ contracts, address }: { contracts?: Contracts; address?: string }) {
  const surplus: BigNumber | undefined = useContractReader({
    contract: contracts?.Fountain,
    functionName: 'getAllTrackedRedistribution',
    args: [address, false],
  })

  const pendingSurplus: BigNumber | undefined = useContractReader({
    contract: contracts?.Fountain,
    functionName: 'getAllTrackedRedistribution',
    args: [address, true],
  })

  return (
    <div style={{ display: 'grid', gridAutoFlow: 'column', columnGap: 20 }}>
      <div>Your surplus: {surplus?.toNumber() ?? 0}</div>
      <div>({(pendingSurplus?.toNumber() ?? 0) - (surplus?.toNumber() ?? 0)} pending)</div>
    </div>
  )
}
