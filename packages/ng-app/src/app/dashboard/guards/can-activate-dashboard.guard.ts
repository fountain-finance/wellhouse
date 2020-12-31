import { Injectable } from '@angular/core'
import {
  ActivatedRouteSnapshot,
  CanActivateChild,
  Router,
  RouterStateSnapshot,
  UrlTree,
} from '@angular/router'
import { Observable } from 'rxjs'
import { map } from 'rxjs/operators'
import { AccountService } from 'src/app/core/services/account.service'

@Injectable()
export class CanActivateDashboard implements CanActivateChild {
  constructor(private accountService: AccountService, private router: Router) {}

  canActivateChild(
    route: ActivatedRouteSnapshot,
    state: RouterStateSnapshot
  ): Observable<boolean | UrlTree> | Promise<boolean | UrlTree> | boolean | UrlTree {
    return this.accountService.wallet$.pipe(
      map(account => (account ? true : this.router.createUrlTree(['/app'])))
    )
  }
}
