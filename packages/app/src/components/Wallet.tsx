import React from 'react'

export default function Wallet({ providerAddress }: { providerAddress?: string }) {
  return providerAddress ? (
    <div>
      Wallet: <span>{providerAddress}</span>
    </div>
  ) : null
}
