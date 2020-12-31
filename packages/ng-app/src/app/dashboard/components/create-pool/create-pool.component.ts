import { HttpClient } from '@angular/common/http'
import { Component, Inject } from '@angular/core'
import { FormControl, FormGroup } from '@angular/forms'
import { BigNumber } from '@ethersproject/bignumber'
import { BehaviorSubject } from 'rxjs'
import { take } from 'rxjs/operators'
import { DAI } from 'src/app/core/constants/dai'
import { WEB3 } from 'src/app/core/constants/web3'
import { createNotifier, useContractLoader, useGasPrice } from 'src/app/core/core.helpers'
import { ContractName } from 'src/app/core/enums/contract-name'
import { AccountService } from 'src/app/core/services/account.service'

@Component({
  selector: 'app-create-pool',
  templateUrl: './create-pool.component.html',
  styleUrls: ['./create-pool.component.scss'],
})
export class CreatePoolComponent {
  private readonly pendingTx = new BehaviorSubject(null)
  readonly pendingTx$ = this.pendingTx.asObservable()

  readonly form = new FormGroup({
    target: new FormControl(),
    duration: new FormControl(),
  })

  constructor(
    @Inject(WEB3) private web3: Web3,
    private accountService: AccountService,
    private http: HttpClient
  ) {}

  submit() {
    const target = this.web3.eth.abi.encodeParameter('uint256', this.form.value.target)
    const duration = this.web3.eth.abi.encodeParameter('uint256', this.form.value.duration)

    this.accountService.wallet$
      .pipe(take(1))
      .subscribe(async account => this.configureMoneyPool(account, target, duration))
  }

  private async configureMoneyPool(from: string, target: string, duration: string) {
    this.pendingTx.next(true)

    const provider = await this.accountService.getUserProvider()
    const gasPrice = await useGasPrice('fast', this.http)
    const notifier = createNotifier(provider, BigNumber.from(gasPrice))

    const writeContracts = await useContractLoader(provider)

    notifier(writeContracts[ContractName.FountainV1].configureMp(target, duration, DAI))
      .then(() => {
        this.form.reset()
        this.pendingTx.next(null)
      })
      .catch(e => {
        console.error(e)
        this.pendingTx.next(null)
      })
  }
}
