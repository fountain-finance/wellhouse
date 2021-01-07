import { BigNumber } from '@ethersproject/bignumber'
import React, { useState } from 'react'
import { useParams } from 'react-router-dom'
import Web3 from 'web3'

import useContractReader from '../hooks/ContractReader'
import { Contracts } from '../models/contracts'
import { MoneyPool } from '../models/money-pool'
import { Transactor } from '../models/transactor'
import ConfigureMoneyPool from './ConfigureMoneyPool'
import MoneyPoolDetail from './MoneyPoolDetail'

export default function MoneyPools({
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

  const spacing = 30

  const isOwner = owner === address

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

  const tappableAmount: number | undefined = useContractReader<number>({
    contract: contracts?.Fountain,
    functionName: 'getTappableAmount',
    args: [currentMp?.number],
    formatter: (result: BigNumber) => result?.toNumber(),
  })

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

  const configureMoneyPool = <ConfigureMoneyPool transactor={transactor} contracts={contracts} />

  function header(text: string) {
    return <h2 style={{ margin: 0 }}>{text}</h2>
  }

  const formStyle: React.CSSProperties = {
    width: 300,
    padding: 20,
    borderRadius: 10,
    border: '1px solid lightGray',
  }

  const pools =
    !currentMp && !queuedMp ? null : (
      <div>
        <h3>{owner}</h3>
        <h1 style={{ marginRight: spacing }}>Money Pool</h1>
        <div
          style={{
            display: 'grid',
            gridAutoFlow: 'column',
            columnGap: spacing,
          }}
        >
          <div>
            <div
              style={{
                display: 'grid',
                gridAutoFlow: 'row',
                rowGap: spacing,
              }}
            >
              {header('Current')}

              {currentMp ? <MoneyPoolDetail mp={currentMp} isActive={true} /> : <div>Getting money pool...</div>}

              {currentMp ? (
                <div>
                  <div>
                    <label htmlFor="sustain">Sustain money pool</label>
                  </div>
                  <input
                    name="sustain"
                    placeholder="0"
                    onChange={e => setSustainAmount(parseFloat(e.target.value))}
                  ></input>
                  <button onClick={sustain}>Sustain</button>
                </div>
              ) : null}

              {currentMp && tappableAmount !== undefined && isOwner ? (
                <div>
                  <div>
                    <label htmlFor="withdrawable">Withdrawable: {tappableAmount}</label>
                  </div>
                  <input
                    name="withdrawable"
                    placeholder="0"
                    onChange={e => setTapAmount(parseFloat(e.target.value))}
                  ></input>
                  <button disabled={tapAmount > tappableAmount} onClick={tap}>
                    Withdraw
                  </button>
                </div>
              ) : null}

              {isOwner && currentMp?.total?.toNumber() === 0 ? (
                <div style={formStyle}>
                  {header('Reconfigure')}
                  {configureMoneyPool}
                </div>
              ) : null}
            </div>
          </div>

          <div>
            <div
              style={{
                display: 'grid',
                gridAutoFlow: 'row',
                rowGap: spacing,
              }}
            >
              {header('Queued')}

              {queuedMp ? <MoneyPoolDetail mp={queuedMp} /> : <div>Nada</div>}

              {isOwner && currentMp?.total?.toNumber() ? (
                <div style={formStyle}>
                  {header('Reconfigure queued money pool')}
                  {configureMoneyPool}
                </div>
              ) : null}
            </div>
          </div>
        </div>
      </div>
    )

  return (
    <div>
      {pools}
      {!currentMp ? (
        <div>
          <h1>Create money pool</h1>
          {configureMoneyPool}
        </div>
      ) : null}
    </div>
  )
}
