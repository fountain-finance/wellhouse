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
  const [redeemAmount, setRedeemAmount] = useState<number>(0)

  const _ticketsHolderAddress = ticketsHolderAddress && Web3.utils.utf8ToHex(ticketsHolderAddress)
  const _issuerAddress = issuerAddress && Web3.utils.utf8ToHex(issuerAddress)

  const balance: number | undefined = useContractReader<number>({
    contract: contracts?.TicketStore,
    functionName: 'getRedeemableAmount',
    args: [_ticketsHolderAddress, _issuerAddress],
    formatter: (result: BigNumber) => result?.toNumber(),
  })

  if (balance && balance !== redeemAmount) setRedeemAmount(balance)

  function redeem() {
    if (!transactor || !contracts) return

    const eth = new Web3(Web3.givenProvider).eth
    const _amount = eth.abi.encodeParameter('uint256', balance)

    transactor(contracts?.Controller.redeem(_issuerAddress, _amount))
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
      <div>{balance !== undefined ? balance : 'Loading ticket balance...'}</div>
      <div>
        <input
          onChange={e => setRedeemAmount(parseFloat(e.target.value))}
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
