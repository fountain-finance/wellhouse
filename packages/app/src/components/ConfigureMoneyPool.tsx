import { Contract } from '@ethersproject/contracts'
import { useState } from 'react'
import Web3 from 'web3'

import { ContractName } from '../constants/contract-name'
import { SECONDS_IN_DAY } from '../constants/seconds-in-day'
import { Transactor } from '../models/transactor'

export default function ConfigureMoneyPool({
  transactor,
  contracts,
}: {
  transactor?: Transactor
  contracts?: Record<ContractName, Contract>
}) {
  const [target, setTarget] = useState<number>(0)
  const [duration, setDuration] = useState<number>(0)

  const eth = new Web3(Web3.givenProvider).eth

  const useDays = process.env.NODE_ENV === 'production'

  function onSubmit() {
    if (!transactor || !contracts?.Fountain || !contracts?.Token) return

    const target_ = eth.abi.encodeParameter('uint256', target)
    // Contracts created during development use seconds for duration
    const duration_ = eth.abi.encodeParameter('uint256', duration * (useDays ? SECONDS_IN_DAY : 1))

    transactor(contracts.Fountain.configureMp(target_, duration_, contracts.Token.address))
  }

  if (!transactor || !contracts) return null

  return (
    <form
      onSubmit={e => {
        onSubmit()
        e.preventDefault()
      }}
    >
      <p>
        <label htmlFor="target">Sustainability target</label>
        <br />
        <input
          onChange={e => setTarget(parseFloat(e.target.value))}
          style={{ marginRight: 10 }}
          type="number"
          name="target"
          id="target"
          placeholder="1500"
        />
        DAI
      </p>
      <p>
        <label htmlFor="duration">Duration</label>
        <br />
        <input
          onChange={e => setDuration(parseFloat(e.target.value))}
          style={{ marginRight: 10 }}
          type="number"
          name="duration"
          id="duration"
          placeholder="30"
        />
        {useDays ? 'days' : 'seconds'}
      </p>
      <button type="submit">Create</button>
    </form>
  )
}
