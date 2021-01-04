import { Tooltip } from 'antd'
import React from 'react'

export default function Wallet({ address }: { address?: string }) {
  return address ? (
    <div>
      Wallet:
      <Tooltip title={address}>
        <span style={{ cursor: 'default' }}>...{address?.substring(address.length - 6)}</span>
      </Tooltip>
    </div>
  ) : null
}
