import Tab from './Tab'
import Account from './Account'

export default function Navbar() {
  const tabs = [
    Tab({
      name: 'Create',
      link: '/create',
    }),
  ].map((tab, key) => ({
    ...tab,
    key,
  }))

  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'space-between',
        padding: 20,
        borderBottom: '1px solid lightgrey',
      }}
    >
      {tabs}
      <Account />
    </div>
  )
}
