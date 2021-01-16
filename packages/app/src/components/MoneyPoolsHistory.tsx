import { BigNumber } from '@ethersproject/bignumber'
import React, { useState } from 'react'
import { useParams } from 'react-router-dom'
import Web3 from 'web3'

import useContractReader from '../hooks/ContractReader'
import { Contracts } from '../models/contracts'
import { MoneyPool } from '../models/money-pool'
import { Transactor } from '../models/transactor'
import MoneyPoolDetail from './MoneyPoolDetail'

export default function MoneyPoolsHistory({
  contracts,
  transactor,
  address,
}: {
  contracts?: Contracts
  transactor?: Transactor
  address?: string
}) {
  const [moneyPools, setMoneyPools] = useState<MoneyPool[]>([])
  const [poolNumbers, setPoolNumbers] = useState<BigNumber[]>([])
  const [tappableAmounts, setTappableAmounts] = useState<{ [key: number]: BigNumber }>({})

  const { number }: { number?: string } = useParams()

  if (number !== undefined && !poolNumbers.length) setPoolNumbers([BigNumber.from(number)])

  const allPoolsLoaded = moneyPools.length >= poolNumbers.length
  const poolNumber = allPoolsLoaded ? undefined : poolNumbers[poolNumbers.length - 1]
  const pollTime = allPoolsLoaded ? undefined : 100

  useContractReader<MoneyPool>({
    contract: contracts?.Fountain,
    functionName: 'getMp',
    args: [poolNumber],
    pollTime,
    callback: mp => {
      if (!mp || !poolNumber || poolNumbers.includes(mp.previous)) return
      setMoneyPools([...moneyPools, mp])
      setPoolNumbers([...poolNumbers, ...(mp.previous.toNumber() > 0 ? [mp.previous] : [])])
    },
  })

  useContractReader<BigNumber>({
    contract: contracts?.Fountain,
    functionName: 'getTappableAmount',
    args: [poolNumber],
    pollTime,
    callback: val => poolNumber && setTappableAmounts({ ...tappableAmounts, [poolNumber.toNumber()]: val }),
  })

  function tap(mpNumber: BigNumber, amount: number) {
    if (!transactor || !contracts?.Fountain) return

    const eth = new Web3(Web3.givenProvider).eth

    const _mpNumber = eth.abi.encodeParameter('uint256', mpNumber)
    const _amount = eth.abi.encodeParameter('uint256', amount)

    transactor(contracts.Fountain?.tapMp(_mpNumber, _amount, address), () =>
      // reset tappable amount for withdrawn pool
      setTappableAmounts({
        ...tappableAmounts,
        [mpNumber.toNumber()]: BigNumber.from(0),
      }),
    )
  }

  return (
    <div
      style={{
        display: 'grid',
        gridAutoFlow: 'row',
        rowGap: 40,
      }}
    >
      {moneyPools.map((mp, index) => {
        const tappable = tappableAmounts[mp.number.toNumber()]?.toNumber()

        return (
          <div key={index}>
            <MoneyPoolDetail mp={mp} showSustained={true} />
            {tappable ? (
              <button
                style={{
                  color: 'white',
                  background: 'green',
                  fontWeight: 'bold',
                }}
                onClick={() => tap(mp.number, tappable)}
              >
                Withdraw {tappable}
              </button>
            ) : (
              <div style={{ color: '#888' }}>Nothing to withdraw</div>
            )}
          </div>
        )
      })}

      {allPoolsLoaded ? null : <div>Loading...</div>}
    </div>
  )
}
