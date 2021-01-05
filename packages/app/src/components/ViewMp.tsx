import React, { useState } from 'react'
import { useParams } from 'react-router-dom'
import Web3 from 'web3'

import useContractReader from '../hooks/ContractReader'
import { Contracts } from '../models/contracts'
import { MoneyPool } from '../models/money-pool'
import { Transactor } from '../models/transactor'
import Mp from './Mp'

export default function ViewMp({
  contracts,
  transactor,
  address,
}: {
  contracts?: Partial<Contracts>
  transactor?: Transactor
  address?: string
}) {
  const [sustainAmount, setSustainAmount] = useState<number>(0)

  const { number }: { number?: string } = useParams()

  const eth = new Web3(Web3.givenProvider).eth

  const encodedNumber = number !== undefined ? eth.abi.encodeParameter('uint256', parseInt(number)) : undefined

  const mp: MoneyPool | undefined = useContractReader({
    contract: contracts?.Fountain,
    functionName: 'getMp',
    args: [encodedNumber],
  })

  function sustain() {
    if (!transactor || !contracts?.Fountain || !mp?.owner) return

    const amount = number !== undefined ? eth.abi.encodeParameter('uint256', sustainAmount) : undefined

    transactor(contracts.Fountain.sustain(mp?.owner, amount, address), e => (window.location.href = '/mp')).then(() =>
      setSustainAmount(0),
    )
  }

  return (
    <div
      style={{
        display: 'grid',
        gridAutoFlow: 'row',
        rowGap: 20,
      }}
    >
      {mp ? <Mp mp={mp}></Mp> : null}

      <div>
        <input defaultValue={sustainAmount} onChange={e => setSustainAmount(parseFloat(e.target.value))}></input>
        <button onClick={sustain}>Sustain</button>
      </div>
    </div>
  )
}
