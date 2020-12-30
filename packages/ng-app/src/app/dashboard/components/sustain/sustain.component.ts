import { Component, Inject, OnDestroy, OnInit } from '@angular/core'
import { FormControl, FormGroup } from '@angular/forms'
import { ActivatedRoute, Router } from '@angular/router'
import { ReplaySubject, Subscription } from 'rxjs'
import { filter, map, take, withLatestFrom } from 'rxjs/operators'
import { abi } from 'src/app/core/constants/abi'
import { fountainAddress } from 'src/app/core/constants/fountain-address'
import { WEB3 } from 'src/app/core/constants/web3'
import { AccountsService } from 'src/app/core/services/accounts.service'

@Component({
  selector: 'app-sustain',
  templateUrl: './sustain.component.html',
  styleUrls: ['./sustain.component.scss'],
})
export class SustainComponent implements OnInit, OnDestroy {
  private readonly subscription = new Subscription()
  private readonly moneyPoolId = new ReplaySubject<string>(1)
  private readonly sustainabilityTarget = new ReplaySubject<string>(1)
  private readonly duration = new ReplaySubject<string>(1)
  private readonly currentSustainment = new ReplaySubject<string>(1)
  private readonly timeLeft = new ReplaySubject<string>(1)

  readonly moneyPoolId$ = this.moneyPoolId.asObservable()
  readonly sustainabilityTarget$ = this.sustainabilityTarget.asObservable()
  readonly duration$ = this.duration.asObservable()
  readonly currentSustainment$ = this.currentSustainment.asObservable()
  readonly timeLeft$ = this.timeLeft.asObservable()

  readonly sustainAmountForm = new FormGroup({
    amount: new FormControl(),
  })
  readonly moneyPoolIdForm = new FormGroup({
    address: new FormControl(),
  })

  constructor(
    @Inject(WEB3) private web3: Web3,
    private accountsService: AccountsService,
    private route: ActivatedRoute,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.route.params.pipe(take(1)).subscribe(params => this.moneyPoolId.next(params.address))

    this.subscription.add(this.onMoneyPoolIdChange$.subscribe())
  }

  setMoneyPoolId() {
    const newMoneyPoolId = this.moneyPoolIdForm.value.address

    this.moneyPoolId.next(newMoneyPoolId)

    this.router.navigate([newMoneyPoolId], { relativeTo: this.route })
  }

  submitSustainAmount() {
    const amount = this.web3.eth.abi.encodeParameter('uint256', this.sustainAmountForm.value.amount)

    this.accountsService.accounts$.pipe(take(1)).subscribe(accounts =>
      this.contract.methods.sustain(this.moneyPoolId, amount).send({
        from: accounts[0],
      })
    )
  }

  private get contract() {
    return new this.web3.eth.Contract(abi, fountainAddress)
  }

  // Whenever money pool ID updates, get latest MP info
  private get onMoneyPoolIdChange$() {
    return this.moneyPoolId$.pipe(
      filter(a => !!a),
      withLatestFrom(this.accountsService.accounts$),
      map(([moneyPoolId, accounts]) => {
        const account = accounts[0]
        // this.getDuration(moneyPoolId, account)
        // this.getSustainabilitTarget(moneyPoolId, account)
        // this.getCurrentSustainment(moneyPoolId, account)
        // this.getTimeLeft(moneyPoolId, account)
      })
    )
  }

  // Untested
  private getDuration(moneyPoolId: string, account: string) {
    this.contract.methods
      .getDuration(moneyPoolId)
      .call({ from: account }, (err, res) => this.duration.next(res))
  }

  // Untested
  private getSustainabilitTarget(moneyPoolId: string, account: string) {
    this.contract.methods
      .getSustainabilitTarget(moneyPoolId)
      .call({ from: account }, (err, res) => this.sustainabilityTarget.next(res))
  }

  // Not yet supported in contract
  private getCurrentSustainment(moneyPoolId: string, account: string) {}

  // Not yet supported in contract
  private getTimeLeft(moneyPoolId: string, account: string) {}

  ngOnDestroy() {
    this.subscription.unsubscribe()
  }
}
