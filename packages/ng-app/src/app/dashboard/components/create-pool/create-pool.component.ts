import { ChangeDetectorRef, Component, Inject } from '@angular/core'
import { FormControl, FormGroup } from '@angular/forms'
import { BehaviorSubject, ReplaySubject } from 'rxjs'
import { take } from 'rxjs/operators'
import { abi } from 'src/app/core/constants/abi'
import { DAI } from 'src/app/core/constants/dai'
import { fountainAddress } from 'src/app/core/constants/fountain-address'
import { WEB3 } from 'src/app/core/constants/web3'
import { AccountsService } from 'src/app/core/services/accounts.service'

@Component({
  selector: 'app-create-pool',
  templateUrl: './create-pool.component.html',
  styleUrls: ['./create-pool.component.scss'],
})
export class CreatePoolComponent {
  private readonly pendingTx = new BehaviorSubject(null)
  private readonly txHash = new ReplaySubject<string>(1)
  private readonly submitMessage = new ReplaySubject<string>(1)
  readonly pendingTx$ = this.pendingTx.asObservable()
  readonly txHash$ = this.txHash.asObservable()
  readonly submitMessage$ = this.submitMessage.asObservable()

  readonly form = new FormGroup({
    target: new FormControl(),
    duration: new FormControl(),
  })

  constructor(
    @Inject(WEB3) private web3: Web3,
    private accountsService: AccountsService,
    private cdf: ChangeDetectorRef
  ) {}

  submit() {
    const target = this.web3.eth.abi.encodeParameter('uint256', this.form.value.target)
    const duration = this.web3.eth.abi.encodeParameter('uint256', this.form.value.duration)

    this.accountsService.accounts$
      .pipe(take(1))
      .subscribe(async accounts => this.configureMoneyPool(accounts[0], target, duration))
  }

  private async configureMoneyPool(from: string, target: string, duration: string) {
    this.pendingTx.next(true)

    const contract = new this.web3.eth.Contract(abi, fountainAddress)
    const want = DAI

    console.log(
      'Calling `contract.methods.configureMoneyPool(target, duration, want)`',
      { target },
      { duration },
      { want }
    )

    contract.methods
      .configureMoneyPool(target, duration, DAI)
      .send({
        from,
      })
      .on('transactionHash', hash => {
        this.txHash.next(hash)
        this.cdf.detectChanges()
        console.log('Got hash:', hash)
      })
      .on('receipt', receipt => {
        this.pendingTx.next(null)
        this.submitMessage.next('🤑 Success 🤑')
        this.cdf.detectChanges()
        console.log('Got receipt:', receipt)
      })
      .on('error', (error, receipt) => {
        this.pendingTx.next(null)
        this.submitMessage.next('💀 Failed 💀')
        this.cdf.detectChanges()
        console.log(
          'Error creating money pool.',
          {
            error,
          },
          {
            receipt,
          }
        )
      })
  }
}
