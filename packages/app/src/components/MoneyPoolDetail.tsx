import Web3 from 'web3'

import { SECONDS_IN_DAY } from '../constants/seconds-in-day'
import { MoneyPool } from '../models/money-pool'
import useContractReader from '../hooks/ContractReader'
import { Contracts } from '../models/contracts'
import { BigNumber } from '@ethersproject/bignumber'
import { daiAddress } from '../constants/dai-address'
import { Transactor } from '../models/transactor'

export default function MoneyPoolDetail({
  mp,
  contracts,
  transactor,
  showSustained,
  showTimeLeft,
}: {
  mp?: MoneyPool
  contracts?: Contracts
  transactor?: Transactor
  showSustained?: boolean
  showTimeLeft?: boolean
}) {
  const secondsLeft = mp && mp.start.toNumber() + mp.duration.toNumber() - new Date().valueOf() / 1000

  const label = (text: string) => (
    <label
      style={{
        fontWeight: 'bold',
        textTransform: 'uppercase',
        fontSize: 'small',
      }}
    >
      {text}:
    </label>
  )

  function expandedTimeString(millis: number) {
    if (!millis || millis <= 0) return 0

    const days = millis && millis / 1000 / SECONDS_IN_DAY
    const hours = days && (days % 1) * 24
    const minutes = hours && (hours % 1) * 60
    const seconds = minutes && (minutes % 1) * 60

    return (
      <span>
        {days && days >= 1 ? Math.floor(days) + 'd' : null} {hours && hours >= 1 ? Math.floor(hours) + 'h' : null}{' '}
        {minutes && minutes >= 1 ? Math.floor(minutes) + 'm' : null}{' '}
        {seconds && seconds >= 1 ? Math.floor(seconds) + 's' : null}
      </span>
    )
  }

  const title = mp?.title && Web3.utils.hexToString(mp.title)

  const link = mp?.link && Web3.utils.hexToString(mp.link)

  const rewardToken = useContractReader({
    contract: contracts?.TicketStore,
    functionName: 'tickets',
    formatter: tickets => (mp?.owner ? tickets[mp?.owner]?.rewardToken() : undefined),
  })

  const swappable: number | undefined = useContractReader({
    contract: contracts?.TicketStore,
    functionName: 'swappable',
    args: [mp?.owner, rewardToken, daiAddress],
    formatter: (num: BigNumber | undefined) => num?.toNumber(),
  })

  function swap() {
    if (!transactor || !contracts || !mp || swappable === undefined) return

    const eth = new Web3(Web3.givenProvider).eth

    const _swappable = eth.abi.encodeParameter('uint256', swappable)
    // TODO handle conversion. Use 1:1 for now
    const _expectedAmount = _swappable

    transactor(contracts.Controller.swap(mp.owner, mp.want, _swappable, daiAddress, _expectedAmount))
  }

  function mint() {
    if (!transactor || !contracts || !mp) return

    transactor(contracts.Controller.mintReservedTickets(mp.owner))
  }

  return mp ? (
    <div>
      <div>
        <h2 style={{ margin: 0 }}>{title}</h2>
        <a href={link} target="_blank" rel="noopener noreferrer">
          {link}
        </a>
      </div>
      <br />
      <div>
        {label('Number')} {mp.id.toNumber()}
      </div>
      <div>
        {label('Target')} {mp.target.toNumber()}
      </div>
      {showSustained ? (
        <div>
          {label('Sustained')} {mp.total.toNumber()}
        </div>
      ) : null}
      <div>
        {label('Start')} {new Date(mp.start.toNumber() * 1000).toISOString()}
      </div>
      <div>
        {label('Duration')} {expandedTimeString(mp && mp.duration.toNumber() * 1000)}
      </div>
      <div>
        {label('Reserved for owner')} {mp.o?.toNumber()}
      </div>
      {mp?.bAddress ? (
        <div>
          {label('Beneficiary')} {mp.bAddress} - {mp.b.toNumber()}%
        </div>
      ) : null}
      {showTimeLeft ? (
        <div>
          {label('Time left')} {(secondsLeft && expandedTimeString(secondsLeft * 1000)) || 'Ended'}
        </div>
      ) : null}
      <div>
        {label('Bias / weight')} {`${mp.bias?.toNumber()} / ${mp.weight?.toNumber()}`}
      </div>
      <div>
        {label('Reserves')}{' '}
        {mp.hasMintedReserves ? (
          'Minted'
        ) : (
          <button type="submit" onClick={mint}>
            Mint
          </button>
        )}
      </div>
      <div>
        {label('Swappable')} {swappable}
        {swappable ? (
          <button type="submit" onClick={swap}>
            Swap
          </button>
        ) : null}
      </div>
    </div>
  ) : null
}
