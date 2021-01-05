import { parseEther } from '@ethersproject/units'
import React, { useState } from 'react'

import { localProvider } from '../constants/local-provider'
import { createTransactor } from '../helpers/Transactor'

export default function Faucet({ address }: { address?: string }) {
  const [amount, setAmount] = useState<string>('0.01')
  const notifier = createTransactor({ provider: localProvider })

  return (
    <span style={{ display: 'inline-grid', gridAutoFlow: 'column', columnGap: 5 }}>
      <input defaultValue={amount} onChange={e => setAmount(e.target.value)} />
      <button
        onClick={() => {
          if (!notifier || !address) return

          notifier({
            to: address,
            value: parseEther(amount),
          })
        }}
      >
        Send ETH to wallet
      </button>
    </span>
  )
}
