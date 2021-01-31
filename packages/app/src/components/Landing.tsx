import React from 'react'
import { Button } from 'antd'

import { colors } from '../constants/styles/colors'

export default function Landing({
  providerAddress,
  onNeedAddress,
}: {
  providerAddress?: string
  onNeedAddress: VoidFunction
}) {
  const bulletSize = 8

  const bullet = (text: string) => (
    <li
      style={{
        listStyle: 'none',
        display: 'flex',
        alignItems: 'baseline',
        marginBottom: 10,
        fontWeight: 500,
      }}
    >
      <span
        style={{
          display: 'inline-block',
          minWidth: bulletSize,
          width: bulletSize,
          height: bulletSize,
          borderRadius: '50%',
          background: colors.juiceOrange,
          marginRight: 12,
        }}
      ></span>
      {text}
    </li>
  )
  return (
    <div style={{ width: '100vw', display: 'flex', justifyContent: 'center' }}>
      <div style={{ maxWidth: 960, paddingLeft: 40, paddingRight: 40 }}>
        <div
          style={{
            display: 'grid',
            gridAutoFlow: 'column',
            gridTemplateColumns: '2fr 1fr',
            alignItems: 'center',
            columnGap: 80,
          }}
        >
          <div>
            <h1>A composable ethereum business model for:</h1>
            {bullet('Open source projects')}
            {bullet('Indy projects')}
            {bullet('Public goods')}
            {bullet('Any initiative with recurring and predictable expenses')}
            <p>
              Unlike a Patreon or pricing/donations page, your Budgets are pre-programmed to return overflow back to
              addresses that helped sustain you once it has received the funds you asked for.
            </p>
            <div style={{ display: 'grid', gridAutoFlow: 'column', columnGap: 10 }}>
              {providerAddress ? (
                <a href={providerAddress}>
                  <Button type="primary">Create a project</Button>
                </a>
              ) : (
                <Button onClick={onNeedAddress} type="primary">
                  Create a project
                </Button>
              )}
            </div>
          </div>
          <img style={{ maxWidth: 560, maxHeight: 600 }} src="/assets/orange_lady.png" alt="GET JUICED" />
        </div>
      </div>
    </div>
  )
}
