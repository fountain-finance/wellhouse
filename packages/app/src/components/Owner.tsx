import { BigNumber } from '@ethersproject/bignumber'
import React, { useState } from 'react'
import Web3 from 'web3'

import useContractReader from '../hooks/ContractReader'
import { Contracts } from '../models/contracts'
import { MoneyPool } from '../models/money-pool'
import { Transactor } from '../models/transactor'

export default function Owner({
  address,
  transactor,
  contracts,
}: {
  address?: string
  transactor?: Transactor
  contracts?: Partial<Contracts>
}) {
  const [tapAmount, setTapAmount] = useState<number>(0)

  const mp: MoneyPool | undefined = useContractReader({
    contract: contracts?.Fountain,
    functionName: 'getActiveMp',
    args: [address],
  })

  const tappableAmount: BigNumber | undefined = useContractReader({
    contract: contracts?.Fountain,
    functionName: 'getTappableAmount',
    args: [mp?.number],
  })

  function tap() {
    if (!transactor || !contracts?.Fountain || !mp) return

    const eth = new Web3(Web3.givenProvider).eth

    const number = eth.abi.encodeParameter('uint256', mp.number)
    const amount = eth.abi.encodeParameter('uint256', tapAmount)

    transactor(contracts.Fountain?.tap(number, amount, address))
  }

  return (
    <div
      style={{
        display: 'grid',
        gridAutoFlow: 'row',
        rowGap: 20,
      }}
    >
      <h1>Your active moneypool</h1>

      {mp ? (
        <div>
          <div>Target: {mp.target.toNumber()}</div>
          <div>Total: {mp.total.toNumber()}</div>
          <div>Duration: {mp.duration.toNumber()} days</div>
          <div>Start: {new Date(mp.start.toNumber()).toISOString()}</div>
        </div>
      ) : null}

      {tappableAmount !== undefined ? (
        <div>
          <div>Tappable amount: {tappableAmount.toNumber()}</div>
          <input defaultValue={tapAmount.toString()} onChange={e => setTapAmount(parseFloat(e.target.value))}></input>
          <button disabled={tapAmount > tappableAmount.toNumber()} onClick={tap}>
            Withdraw
          </button>
        </div>
      ) : null}
    </div>
  )
}
