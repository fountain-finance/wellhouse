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
import { AccountsService } from 'src/app/core/services/accounts.service'

@Injectable()
export class CanActivateDashboard implements CanActivateChild {
  constructor(private accountsService: AccountsService, private router: Router) {}

  canActivateChild(
    route: ActivatedRouteSnapshot,
    state: RouterStateSnapshot
  ): Observable<boolean | UrlTree> | Promise<boolean | UrlTree> | boolean | UrlTree {
    return this.accountsService.accounts$.pipe(
      map(accounts => (accounts?.length > 0 ? true : this.router.createUrlTree(['/app'])))
    )
  }
}
