import { BigNumber } from '@ethersproject/bignumber'
import { JsonRpcProvider } from '@ethersproject/providers'
import { formatEther } from '@ethersproject/units'
import React, { useState } from 'react'
import { usePoller } from '../hooks/Poller'

export default function Balance({
  address,
  provider,
  balance,
  dollarMultiplier,
}: {
  address?: string
  provider: JsonRpcProvider
  balance?: BigNumber
  dollarMultiplier: number
}) {
  const [dollarMode, setDollarMode] = useState(false)
  const [_balance, setBalance] = useState<BigNumber>()

  // get updated balance
  usePoller(async () => {
    if (!address || !provider) return

    try {
      setBalance(await provider.getBalance(address))
    } catch (e) {
      console.log(e)
    }
  })

  let floatBalance = parseFloat('0.00')

  const usingBalance = balance ?? _balance

  if (usingBalance !== undefined) {
    const etherBalance = formatEther(usingBalance)
    floatBalance = parseFloat(etherBalance)
  }

  const displayBalance =
    dollarMultiplier && dollarMode
      ? `$${(floatBalance * dollarMultiplier).toFixed(2)}`
      : `${floatBalance.toFixed(4)}ETH`

  return (
    <span
      style={{
        verticalAlign: 'middle',
        padding: 8,
        cursor: 'pointer',
      }}
      onClick={() => {
        setDollarMode(!dollarMode)
      }}
    >
      {displayBalance}
    </span>
  )
}
