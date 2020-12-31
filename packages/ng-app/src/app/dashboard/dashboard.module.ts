import { CommonModule } from '@angular/common'
import { HttpClientModule } from '@angular/common/http'
import { NgModule } from '@angular/core'
import { ReactiveFormsModule } from '@angular/forms'

import { CreatePoolComponent } from './components/create-pool/create-pool.component'
import { SustainComponent } from './components/sustain/sustain.component'
import { DashboardRoutingModule } from './dashboard-routing.module'
import { DashboardComponent } from './dashboard.component'

@NgModule({
  declarations: [DashboardComponent, CreatePoolComponent, SustainComponent],
  imports: [CommonModule, DashboardRoutingModule, ReactiveFormsModule, HttpClientModule],
  exports: [DashboardComponent],
})
export class DashboardModule {}
