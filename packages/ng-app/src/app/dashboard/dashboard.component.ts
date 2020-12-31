import { Component, OnInit } from '@angular/core'
import { ActivatedRoute, Router } from '@angular/router'
import { Observable } from 'rxjs'

import { web3Modal } from '../core/constants/web3-modal'
import { AccountService } from '../core/services/account.service'

@Component({
  selector: 'app-dashboard',
  templateUrl: './dashboard.component.html',
  styleUrls: ['./dashboard.component.scss'],
})
export class DashboardComponent implements OnInit {
  wallet$: Observable<string>
  balance$: Observable<number>
  contract: any

  constructor(
    private accountService: AccountService,
    private router: Router,
    private route: ActivatedRoute
  ) {}

  ngOnInit() {
    this.wallet$ = this.accountService.wallet$
    this.balance$ = this.accountService.balance$

    if (web3Modal.cachedProvider) {
      this.connectAccount()
    }

    // Load burner account
    // if (!environment.production) {
    //   this.accountService.loadAccount(undefined).then(() => this.navigateToCreate())
    // }
  }

  connectAccount() {
    this.accountService.connectAccount().then(() => this.navigateToCreate())
  }

  logout() {
    this.accountService.logout()
  }

  private navigateToCreate() {
    this.router.navigate(['create'], {
      relativeTo: this.route,
    })
  }
}
