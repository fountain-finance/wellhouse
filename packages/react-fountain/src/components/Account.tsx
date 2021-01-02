import React from 'react'

export default function Account() {
  const connectButton = true ? <button>Connect wallet</button> : null
  const spacing = 10

  return (
    <div style={{ display: 'flex' }}>
      <div style={{ marginRight: spacing }}>Account: {}</div>
      <div style={{ marginRight: spacing }}>Balance: {}</div>
      {connectButton}
    </div>
  )
}
