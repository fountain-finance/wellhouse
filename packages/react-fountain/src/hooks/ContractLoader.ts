import { Contract } from '@ethersproject/contracts'
import { JsonRpcProvider, JsonRpcSigner } from '@ethersproject/providers'
import { useEffect, useState } from 'react'

import { ContractName } from '../constants/contract-name'

export function useContractLoader(signerOrProvider?: JsonRpcProvider | JsonRpcSigner) {
  const [contracts, setContracts] = useState<Partial<Record<ContractName, Contract>>>()

  useEffect(() => {
    async function loadContracts() {
      if (signerOrProvider === undefined) return

      try {
        const signer =
          (await isProviderWithAccounts(signerOrProvider))?.getSigner() ?? (signerOrProvider as JsonRpcSigner)

        const contractList: ContractName[] = require('../contracts/contracts.js')

        const newContracts = contractList.reduce((accumulator, contractName) => {
          accumulator[contractName] = loadContract(contractName, signer)
          return accumulator
        }, {} as Record<ContractName, Contract>)

        setContracts(newContracts)
      } catch (e) {
        console.log('ERROR LOADING CONTRACTS!!', e)
      }
    }

    loadContracts()
  }, [signerOrProvider])

  return contracts
}

async function isProviderWithAccounts(signerOrProvider: JsonRpcSigner | JsonRpcProvider) {
  if (
    (signerOrProvider as JsonRpcProvider).listAccounts !== undefined &&
    (await (signerOrProvider as JsonRpcProvider).listAccounts()).length > 0
  ) {
    return signerOrProvider as JsonRpcProvider
  }
}

const loadContract = (contractName: string, signerOrProvider: JsonRpcSigner | JsonRpcProvider): Contract => {
  const contract = new Contract(
    require(`../contracts/${contractName}.address.js`),
    require(`../contracts/${contractName}.abi.js`),
    signerOrProvider,
  )

  const bytecode: string = require(`../contracts/${contractName}.bytecode.js`)

  return {
    ...contract,
    ...(bytecode ? { bytecode } : {}),
  } as Contract
}
