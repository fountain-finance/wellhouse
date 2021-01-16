import React, { useState } from 'react'
import useContractReader from '../hooks/ContractReader'
import { Contracts } from '../models/contracts'
import Web3 from 'web3'
import { BigNumber } from '@ethersproject/bignumber'
import { Transactor } from '../models/transactor'

export default function TicketsBalance({
  ticketsHolderAddress,
  issuerAddress,
  contracts,
  transactor,
}: {
  ticketsHolderAddress?: string
  issuerAddress?: string
  contracts?: Contracts
  transactor?: Transactor
}) {
  const [redeemAmount, setRedeemAmount] = useState<BigNumber>(BigNumber.from(0))

  const balance = useContractReader<BigNumber>({
    contract: contracts?.TicketStore,
    functionName: 'getTicketBalance',
    args: [issuerAddress, ticketsHolderAddress],
  })

  if (balance && balance !== redeemAmount) setRedeemAmount(balance)

  function redeem() {
    if (!transactor || !contracts) return

    const eth = new Web3(Web3.givenProvider).eth
    const _amount = eth.abi.encodeParameter('uint256', redeemAmount)

    console.log('🧃 Calling Controller.redeem(issuerAddress, amount)', { issuerAddress, amount: _amount })

    transactor(contracts?.Controller.redeem(issuerAddress, _amount))
  }

  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'baseline',
        background: '#000',
        color: '#fff',
        padding: 10,
      }}
    >
      <div>Ticket balance: {balance !== undefined ? balance.toString() : 'loading...'}</div>
      <div>
        <input
          onChange={e => setRedeemAmount(BigNumber.from(parseFloat(e.target.value)))}
          style={{ marginRight: 10 }}
          type="number"
          placeholder="0"
          defaultValue="0"
        />
        <button disabled={!balance} type="submit" onClick={redeem}>
          Redeem
        </button>
      </div>
    </div>
  )
}
