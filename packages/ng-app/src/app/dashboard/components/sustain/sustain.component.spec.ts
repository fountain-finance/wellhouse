import { async, ComponentFixture, TestBed } from '@angular/core/testing'

import { SustainComponent } from './sustain.component'

describe('SustainComponent', () => {
  let component: SustainComponent
  let fixture: ComponentFixture<SustainComponent>

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [SustainComponent],
    }).compileComponents()
  }))

  beforeEach(() => {
    fixture = TestBed.createComponent(SustainComponent)
    component = fixture.componentInstance
    fixture.detectChanges()
  })

  it('should create', () => {
    expect(component).toBeTruthy()
  })
})
