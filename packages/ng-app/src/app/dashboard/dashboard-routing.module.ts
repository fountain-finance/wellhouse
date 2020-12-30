import { NgModule } from '@angular/core'
import { RouterModule, Routes } from '@angular/router'

import { CreatePoolComponent } from './components/create-pool/create-pool.component'
import { SustainComponent } from './components/sustain/sustain.component'
import { DashboardComponent } from './dashboard.component'
import { CanActivateDashboard } from './guards/can-activate-dashboard.guard'

const routes: Routes = [
  {
    path: '',
    component: DashboardComponent,
    canActivateChild: [CanActivateDashboard],
    children: [
      {
        path: 'create',
        component: CreatePoolComponent,
      },
      {
        path: 'sustain',
        component: SustainComponent,
      },
      {
        path: 'sustain/:address',
        component: SustainComponent,
      },
    ],
  },
]

@NgModule({
  imports: [RouterModule.forChild(routes)],
  exports: [RouterModule],
  providers: [CanActivateDashboard],
})
export class DashboardRoutingModule {}
