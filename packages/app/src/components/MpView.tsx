import { BigNumber } from '@ethersproject/bignumber'
import React, { useState } from 'react'
import { useParams } from 'react-router-dom'
import Web3 from 'web3'

import useContractReader from '../hooks/ContractReader'
import { Contracts } from '../models/contracts'
import { MoneyPool } from '../models/money-pool'
import { Transactor } from '../models/transactor'
import Mp from './Mp'

export default function MpView({
  address,
  transactor,
  contracts,
}: {
  address?: string
  transactor?: Transactor
  contracts?: Partial<Contracts>
}) {
  const [sustainAmount, setSustainAmount] = useState<number>(0)
  const [tapAmount, setTapAmount] = useState<number>(0)

  const { owner }: { owner?: string } = useParams()

  const currentMp: MoneyPool | undefined = useContractReader({
    contract: contracts?.Fountain,
    functionName: 'getCurrentMp',
    args: [owner],
  })

  const queuedMp: MoneyPool | undefined = useContractReader({
    contract: contracts?.Fountain,
    functionName: 'getQueuedMp',
    args: [owner],
  })

  const tappableAmount: BigNumber | undefined = useContractReader({
    contract: contracts?.Fountain,
    functionName: 'getTappableAmount',
    args: [currentMp?.number],
  })

  const isOwner = owner === address

  function sustain() {
    if (!transactor || !contracts?.Fountain || !currentMp?.owner) return

    const eth = new Web3(Web3.givenProvider).eth

    const amount = sustainAmount !== undefined ? eth.abi.encodeParameter('uint256', sustainAmount) : undefined

    transactor(contracts.Fountain.sustainOwner(currentMp.owner, amount, address), () => setSustainAmount(0))
  }

  function tap() {
    if (!transactor || !contracts?.Fountain || !currentMp) return

    const eth = new Web3(Web3.givenProvider).eth

    const number = eth.abi.encodeParameter('uint256', currentMp.number)
    const amount = eth.abi.encodeParameter('uint256', tapAmount)

    transactor(contracts.Fountain?.tapMp(number, amount, address))
  }

  const spacing = 20

  return (
    <div
      style={{
        display: 'grid',
        gridAutoFlow: 'column',
        columnGap: spacing,
      }}
    >
      <div
        style={{
          display: 'grid',
          gridAutoFlow: 'row',
          rowGap: spacing,
        }}
      >
        <h1>Current moneypool</h1>

        {currentMp ? <Mp mp={currentMp}></Mp> : <div>Getting money pool...</div>}

        <div>
          <input placeholder="0" onChange={e => setSustainAmount(parseFloat(e.target.value))}></input>
          <button onClick={sustain}>Sustain</button>
        </div>

        {tappableAmount !== undefined && isOwner ? (
          <div>
            <div>Withdrawable amount: {tappableAmount.toNumber()}</div>
            <input placeholder="0" onChange={e => setTapAmount(parseFloat(e.target.value))}></input>
            <button disabled={tapAmount > tappableAmount.toNumber()} onClick={tap}>
              Withdraw
            </button>
          </div>
        ) : null}
      </div>

      <div
        style={{
          display: 'grid',
          gridAutoFlow: 'row',
          rowGap: spacing,
        }}
      >
        <h1>Queued</h1>
        {queuedMp ? <Mp mp={queuedMp}></Mp> : <div>Nada</div>}
      </div>
    </div>
  )
}
