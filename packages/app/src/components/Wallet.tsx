import { Tooltip } from 'antd'
import React from 'react'

export default function Wallet({
  providerAddress,
}: {
  providerAddress?: string
}) {
  const shortened = providerAddress?.substr(providerAddress.length - 6, 6)

  return providerAddress ? (
    <Tooltip title={providerAddress}>
      Wallet: <span>...{shortened}</span>
    </Tooltip>
  ) : null
}
