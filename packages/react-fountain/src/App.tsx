import './App.scss'

import { BrowserRouter, Route, Switch } from 'react-router-dom'

import Navbar from './components/Navbar'
import CreateMp from './components/CreateMp'

function App() {
  return (
    <div className="App">
      <Navbar></Navbar>

      <BrowserRouter>
        <Switch>
          <Route exact path="/">
            some /
          </Route>
          <Route exact path="/create">
            <CreateMp />
          </Route>
        </Switch>
      </BrowserRouter>
    </div>
  )
}

export default App
