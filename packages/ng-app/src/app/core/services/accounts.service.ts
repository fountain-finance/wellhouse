import { Inject, Injectable } from '@angular/core'
import { BehaviorSubject } from 'rxjs'
import { WEB3 } from 'src/app/core/constants/web3'
import { JsonRpcSuccess } from 'src/app/core/models/jsonrpc'

@Injectable({
  providedIn: 'root',
})
export class AccountsService {
  private readonly accounts = new BehaviorSubject([])
  readonly accounts$ = this.accounts.asObservable()

  constructor(@Inject(WEB3) private web3: Web3) {}

  async connectAccount() {
    if (!this.web3.currentProvider) {
      console.log('Missing web3 provider')
      return
    }

    try {
      const accounts = await this.web3.currentProvider?.send('eth_requestAccounts')

      this.accounts.next((accounts as JsonRpcSuccess<string[]>).result)
    } catch (e) {
      console.log('Error getting accounts')
      return
    }
  }
}
