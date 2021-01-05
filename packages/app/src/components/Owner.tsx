import { BigNumber } from '@ethersproject/bignumber'
import React, { useState } from 'react'
import Web3 from 'web3'

import useContractReader from '../hooks/ContractReader'
import { Contracts } from '../models/contracts'
import { MoneyPool } from '../models/money-pool'
import { Transactor } from '../models/transactor'
import Mp from './Mp'

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

  const activeMp: MoneyPool | undefined = useContractReader({
    contract: contracts?.Fountain,
    functionName: 'getActiveMp',
    args: [address],
  })

  const upcomingMp: MoneyPool | undefined = useContractReader({
    contract: contracts?.Fountain,
    functionName: 'getUpcomingMp',
    args: [address],
  })

  const tappableAmount: BigNumber | undefined = useContractReader({
    contract: contracts?.Fountain,
    functionName: 'getTappableAmount',
    args: [activeMp?.number],
  })

  function tap() {
    if (!transactor || !contracts?.Fountain || !activeMp) return

    const eth = new Web3(Web3.givenProvider).eth

    const number = eth.abi.encodeParameter('uint256', activeMp.number)
    const amount = eth.abi.encodeParameter('uint256', tapAmount)

    transactor(contracts.Fountain?.tap(number, amount, address))
  }

  return (
    <div
      style={{
        display: 'grid',
        gridAutoFlow: 'column',
        columnGap: 20,
      }}
    >
      <div
        style={{
          display: 'grid',
          gridAutoFlow: 'row',
          rowGap: 20,
        }}
      >
        <h1>Your active moneypool</h1>

        {activeMp ? <Mp mp={activeMp}></Mp> : null}

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

      {upcomingMp ? (
        <div
          style={{
            display: 'grid',
            gridAutoFlow: 'row',
            rowGap: 20,
          }}
        >
          <h1>Your upcoming moneypool</h1>

          <Mp mp={upcomingMp}></Mp>
        </div>
      ) : null}
    </div>
  )
}
