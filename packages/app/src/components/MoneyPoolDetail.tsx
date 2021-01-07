import { MoneyPool } from '../models/money-pool'
import { SECONDS_IN_DAY } from '../constants/seconds-in-day'

export default function MoneyPoolDetail({ mp }: { mp?: MoneyPool }) {
  const secondsLeft = mp && mp.start.toNumber() + mp.duration.toNumber() - new Date().valueOf() / 1000
  const duration = mp && mp.duration.toNumber() / SECONDS_IN_DAY

  const days = secondsLeft && secondsLeft / SECONDS_IN_DAY
  const hours = days && (days % 1) * 24
  const minutes = hours && (hours % 1) * 60
  const seconds = minutes && (minutes % 1) * 60

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

  return mp ? (
    <div>
      <div>
        {label('Owner')} {mp.owner}
      </div>
      <div>
        {label('Target')} {mp.target.toNumber()}
      </div>
      <div>
        {label('Sustained')} {mp.total.toNumber()}
      </div>
      <div>
        {label('Start')} {new Date(mp.start.toNumber() * 1000).toISOString()}
      </div>
      <div>
        {label('Duration')} {duration} {duration && duration > 1 ? 'days' : 'day'}
      </div>
      <div>
        {label('Time left')} {days && days >= 1 ? Math.floor(days) + 'd' : null}{' '}
        {hours && hours >= 1 ? Math.floor(hours) + 'h' : null}{' '}
        {minutes && minutes >= 1 ? Math.floor(minutes) + 'm' : null}{' '}
        {seconds && seconds >= 1 ? Math.floor(seconds) + 's' : null}
      </div>
    </div>
  ) : null
}
