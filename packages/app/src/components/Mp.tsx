import { MoneyPool } from '../models/money-pool'

export default function Mp({ mp }: { mp?: MoneyPool }) {
  return mp ? (
    <div>
      <div>Owner: {mp.owner}</div>
      <div>Target: {mp.target.toNumber()}</div>
      <div>Total: {mp.total.toNumber()}</div>
      <div>Duration: {mp.duration.toNumber()} seconds</div>
      <div>Start: {new Date(mp.start.toNumber() * 1000).toISOString()}</div>
    </div>
  ) : null
}
