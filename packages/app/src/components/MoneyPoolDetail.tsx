import Web3 from 'web3'

import { SECONDS_IN_DAY } from '../constants/seconds-in-day'
import { MoneyPool } from '../models/money-pool'

export default function MoneyPoolDetail({
  mp,
  showSustained,
  showTimeLeft,
}: {
  mp?: MoneyPool
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
        {label('Number')} {mp.number.toNumber()}
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
      {showTimeLeft ? (
        <div>
          {label('Time left')} {(secondsLeft && expandedTimeString(secondsLeft * 1000)) || 'Ended'}
        </div>
      ) : null}
    </div>
  ) : null
}
