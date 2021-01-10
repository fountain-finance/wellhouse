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
  const [tappables, setTappables] = useState<BigNumber[]>([])

  const { number }: { number?: string } = useParams()

  if (number !== undefined && !poolNumbers?.length) {
    setPoolNumbers([BigNumber.from(number)])
  }

  const moneyPool: MoneyPool | undefined = useContractReader({
    contract: contracts?.Fountain,
    functionName: 'getMp',
    args: [poolNumbers[poolNumbers.length - 1]],
  })

  const tappableAmount: BigNumber | undefined = useContractReader<BigNumber>({
    contract: contracts?.Fountain,
    functionName: 'getTappableAmount',
    args: [moneyPool?.number],
  })

  if (moneyPool && tappableAmount && !poolNumbers.includes(moneyPool.previous)) {
    setMoneyPools([...moneyPools, moneyPool])
    setTappables([...tappables, tappableAmount])
    if (moneyPool.previous.toNumber() > 0) setPoolNumbers([...poolNumbers, moneyPool.previous])
  }

  function tap(mpNumber: BigNumber, amount: number) {
    if (!transactor || !contracts?.Fountain) return

    const eth = new Web3(Web3.givenProvider).eth

    const _mpNumber = eth.abi.encodeParameter('uint256', mpNumber)
    const _amount = eth.abi.encodeParameter('uint256', amount)

    transactor(contracts.Fountain?.tapMp(_mpNumber, _amount, address))
  }

  return (
    <div style={{ display: 'grid', gridAutoFlow: 'row', rowGap: 40 }}>
      {moneyPools.map((mp, index) => {
        const tappable = tappables[index].toNumber()

        return (
          <div key={index}>
            <MoneyPoolDetail mp={mp} showSustained={true} />
            {tappable ? (
              <button
                style={{ color: 'white', background: 'green', fontWeight: 'bold' }}
                onClick={() => tap(mp.number, tappable)}
              >
                Withdraw {tappable}
              </button>
            ) : null}
          </div>
        )
      })}
      {poolNumbers.length > moneyPools.length ? <div>Loading...</div> : null}
    </div>
  )
}
