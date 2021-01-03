import { Contract } from '@ethersproject/contracts'
import { useState } from 'react'
import Web3 from 'web3'

import { ContractName } from '../constants/contract-name'
import { daiAddress } from '../constants/dai-address'
import { Notifier } from '../models/notifier'

export default function CreateMp({
  notifier,
  contracts,
}: {
  notifier?: Notifier
  contracts?: Partial<Record<ContractName, Contract>>
}) {
  const [target, setTarget] = useState<number>()
  const [duration, setDuration] = useState<number>()

  function onSubmit() {
    if (!notifier || !contracts?.FountainV1) return
    const target_ = eth.abi.encodeParameter('uint256', target)
    const duration_ = eth.abi.encodeParameter('uint256', duration)
    notifier(contracts.FountainV1.configureMp(target_, duration_, daiAddress))
  }

  const eth = new Web3(Web3.givenProvider).eth

  if (!notifier || !contracts) return null

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
