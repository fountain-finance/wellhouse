import { Contract } from '@ethersproject/contracts'
import { useState } from 'react'
import Web3 from 'web3'

import { ContractName } from '../constants/contract-name'
import { Transactor } from '../models/transactor'

export default function CreateMp({
  transactor,
  contracts,
}: {
  transactor?: Transactor
  contracts?: Partial<Record<ContractName, Contract>>
}) {
  const [target, setTarget] = useState<number>()
  const [duration, setDuration] = useState<number>()

  const eth = new Web3(Web3.givenProvider).eth

  function onSubmit() {
    if (!transactor || !contracts?.Fountain || !contracts?.Token) return
    const target_ = eth.abi.encodeParameter('uint256', target)
    const duration_ = eth.abi.encodeParameter('uint256', duration)
    transactor(
      contracts.Fountain.configureMp(target_, duration_, contracts.Token.address),
      e => (window.location.href = '/mp'),
    )
  }

  if (!transactor || !contracts) return null

  return (
    <div style={{ padding: 20 }}>
      <h1>Create money pool</h1>

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
          days
        </p>
        <button type="submit">Create</button>
      </form>
    </div>
  )
}
