import { Contract } from '@ethersproject/contracts'
import { useState } from 'react'

import { usePoller } from './Poller'

export default function useContractReader<V>({
  contract,
  functionName,
  args,
  pollTime,
  formatter,
}: {
  contract?: Contract
  functionName: string
  args?: unknown[]
  pollTime?: number
  formatter?: (val: unknown) => V
}) {
  const adjustPollTime = pollTime ?? 10000

  const [value, setValue] = useState<V>()

  usePoller(
    async () => {
      if (!contract) return

      try {
        let newValue: unknown

        console.log('using args', args, contract, functionName)
        newValue = await contract[functionName](...(args ?? []))

        const result = formatter ? formatter(newValue) : (newValue as V)

        if (result !== value) setValue(result)
      } catch (e) {
        console.log(e)
      }
    },
    adjustPollTime,
    contract,
  )

  return value
}
