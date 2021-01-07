import { JsonRpcProvider, Listener } from '@ethersproject/providers'
import { useEffect, useState } from 'react'

import { ContractName } from '../constants/contract-name'
import { Contracts } from '../models/contracts'

export default function useEventListener({
  contracts,
  contractName,
  eventName,
  provider,
  startBlock,
  args,
  getInitial,
}: {
  contracts?: Contracts
  contractName?: ContractName
  eventName?: string
  provider?: JsonRpcProvider
  startBlock?: number
  args?: any[]
  getInitial?: boolean
}) {
  const [events, setEvents] = useState<any[]>([])
  const [needsInitialGet, setNeedsInitialGet] = useState<boolean>(!!getInitial)

  const contract = contracts && contractName && contracts[contractName]

  function formatEvent(event: any) {
    return {
      ...event.args,
      ...event.blockNumber,
    }
  }

  if (needsInitialGet) {
    contract?.queryFilter({ ...contract }).then(initialEvents => {
      setEvents(initialEvents.map(e => formatEvent(e)))
      setNeedsInitialGet(false)
    })
  }

  useEffect(() => {
    if (provider && startBlock !== undefined) {
      // if you want to read _all_ events from your contracts, set this to the block number it is deployed
      provider.resetEventsBlock(startBlock)
    }

    if (contract && eventName) {
      try {
        const listener: Listener = (..._events: any[]) => {
          const event = _events[_events.length - 1]

          setEvents((events: any[]) => [formatEvent(event), ...events])
        }

        contract.on(eventName, listener)

        return () => {
          contract.off(eventName, listener)
        }
      } catch (e) {
        console.log(e)
      }
    }
  }, [provider, startBlock, contracts, contractName, eventName])

  return events
}
