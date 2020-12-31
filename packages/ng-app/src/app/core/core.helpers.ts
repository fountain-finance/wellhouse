/* eslint-disable import/no-dynamic-require */
/* eslint-disable global-require */
import { HttpClient } from '@angular/common/http'
import { BigNumber } from '@ethersproject/bignumber'
import { hexlify } from '@ethersproject/bytes'
import { Contract } from '@ethersproject/contracts'
import { Deferrable } from '@ethersproject/properties'
import {
  JsonRpcProvider,
  JsonRpcSigner,
  TransactionRequest,
  Web3Provider,
} from '@ethersproject/providers'
import { notification } from 'antd'
import Notify, { InitOptions } from 'bnc-notify'
import { map } from 'rxjs/operators'

import { ContractName } from './enums/contract-name'
import { TxGasOption } from './models/tx-gas-option'

// it is basically just a wrapper around BlockNative's wonderful Notify.js
// https://docs.blocknative.com/notify
export function createNotifier(provider: Web3Provider, gasPrice: BigNumber) {
  if (provider === undefined) return

  // eslint-disable-next-line consistent-return
  return async (tx: Deferrable<TransactionRequest>) => {
    const signer = provider.getSigner()

    const network = await provider.getNetwork()

    console.log('network', network)

    const options: InitOptions = {
      dappId: '0b58206a-f3c0-4701-a62f-73c7243e8c77', // GET YOUR OWN KEY AT https://account.blocknative.com
      system: 'ethereum',
      networkId: network.chainId,
      // darkMode: Boolean, // (default: false)
      transactionHandler: txInformation => {
        console.log('HANDLE TX', txInformation)
      },
    }
    const notify = Notify(options)

    let etherscanNetwork = ''
    if (network.name && network.chainId > 1) {
      etherscanNetwork = network.name + '.'
    }

    let etherscanTxUrl = 'https://' + etherscanNetwork + 'etherscan.io/tx/'
    if (network.chainId === 100) {
      etherscanTxUrl = 'https://blockscout.com/poa/xdai/tx/'
    }

    try {
      let result
      if (tx instanceof Promise) {
        console.log('AWAITING TX', tx)
        result = await tx
      } else {
        if (!tx.gasPrice) {
          tx.gasPrice = gasPrice
        }
        if (!tx.gasLimit) {
          tx.gasLimit = hexlify(120000)
        }
        console.log('RUNNING TX', tx)
        result = await signer.sendTransaction(tx)
      }
      console.log('RESULT:', result)
      // console.log("Notify", notify);

      // if it is a valid Notify.js network, use that, if not, just send a default notification
      if ([1, 3, 4, 5, 42, 100].indexOf(network.chainId) >= 0) {
        const { emitter } = notify.hash(result.hash)
        emitter.on('all', transaction => ({
          onclick: () => window.open(etherscanTxUrl + transaction.hash),
        }))
      } else {
        notification.info({
          message: 'Local Transaction Sent',
          description: result.hash,
          placement: 'bottomRight',
        })
      }

      return result
    } catch (e) {
      console.log(e)
      console.log('Transaction Error:', e.message)
      notification.error({
        message: 'Transaction Error',
        description: e.message,
      })
    }
  }
}

// https://docs.ethgasstation.info/gas-price#gas-price
export const useGasPrice = (speed: TxGasOption, http: HttpClient, apiKey = '') =>
  http
    .get('https://ethgasstation.info/json/ethgasAPI.json' + apiKey)
    .pipe(
      map(response => {
        console.log('response :>> ', response)
        return response[speed || 'fast'] * 100000000
      })
    )
    .toPromise()

const loadContract = (
  contractName: string,
  signerOrProvider: JsonRpcSigner | JsonRpcProvider
): Contract => {
  const contract = new Contract(
    require(`../contracts/${contractName}.address.js`),
    require(`../contracts/${contractName}.abi.js`),
    signerOrProvider
  )

  const bytecode: string = require(`../contracts/${contractName}.bytecode.js`)

  return {
    ...contract,
    ...(bytecode ? { bytecode } : {}),
  } as Contract
}

async function isProviderWithAccounts(signerOrProvider: JsonRpcSigner | JsonRpcProvider) {
  if (
    (signerOrProvider as JsonRpcProvider).listAccounts !== undefined &&
    (await (signerOrProvider as JsonRpcProvider).listAccounts()).length > 0
  ) {
    return signerOrProvider as JsonRpcProvider
  }
}

export async function useContractLoader(signerOrProvider: JsonRpcProvider | JsonRpcSigner) {
  let contracts: Record<ContractName, Contract>

  if (signerOrProvider === undefined) return

  try {
    const signer =
      (await isProviderWithAccounts(signerOrProvider))?.getSigner() ??
      (signerOrProvider as JsonRpcSigner)

    const contractList: ContractName[] = require('../contracts/contracts.js')

    const newContracts = contractList.reduce((accumulator, contractName) => {
      accumulator[contractName] = loadContract(contractName, signer)
      return accumulator
    }, {} as Record<ContractName, Contract>)

    contracts = newContracts
  } catch (e) {
    console.log('ERROR LOADING CONTRACTS!!', e)
  }

  return contracts
}
