import { Component, OnInit } from '@angular/core'
import { ActivatedRoute, Router } from '@angular/router'
import { Observable } from 'rxjs'

import { AccountsService } from '../core/services/accounts.service'

@Component({
  selector: 'app-dashboard',
  templateUrl: './dashboard.component.html',
  styleUrls: ['./dashboard.component.scss'],
})
export class DashboardComponent implements OnInit {
  accounts$: Observable<string[]>
  contract: any

  constructor(
    private accountsService: AccountsService,
    private router: Router,
    private route: ActivatedRoute
  ) {}

  ngOnInit() {
    this.accounts$ = this.accountsService.accounts$
  }

  async connectAccount() {
    this.accountsService.connectAccount().then(success =>
      this.router.navigate(['create'], {
        relativeTo: this.route,
      })
    )
  }
}
