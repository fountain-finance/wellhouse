# ⛲️ fountain.finance

[fountain.finance](https://fountain.finance)

Built with [🏗 scaffold-eth](https://github.com/austintgriffith/scaffold-eth)

---

## Run local

```bash
yarn install
```

> start [Hardhat](https://hardhat.org/) local blockchain:

```bash
yarn chain
```

> in a second terminal window, deploy contract to local blockchain:

```bash
yarn deploy
```
> in a third terminal window, start the app and open http://localhost:3000 to view it

```bash
yarn start
```

🔑 Create wallet links to your app with `yarn wallet` (empty) or `yarn fundedwallet` (pre-loaded with ETH)


🔧 Configure 👷[HardHat](https://hardhat.org/config/) by editing `hardhat.config.js` in `packages/hardhat`

> ✨ The [HardHat network](https://hardhat.org/hardhat-network/) provides _stack traces_ and _console.log_ debugging for our contracts ✨

---

## Deploying to public chains

### mainnet

Copies contract artifacts to git-tracked directory: packages/app/src/contracts/mainnet
```bash
yarn deploy-mainnet
```

### ropsten

Copies contract artifacts to git-tracked directory: packages/app/src/contracts/ropsten
```bash
yarn deploy-ropsten
```

To point local app to a public network, edit `env.REACT_APP_DEV_NETWORK`

---

## app .env

reference `packages/app/.example.env`

```bash
REACT_APP_INFURA_ID=
REACT_APP_DEV_NETWORK=
```
`REACT_APP_INFURA_ID`: Your [Infura](https://infura.io/) key.

`REACT_APP_DEV_NETWORK`: (options: `local`, `ropsten`, `mainnet`) network used by frontend during development. Requires contract artifacts to be present in `packages/app/src/contracts/<network-name>` which are generated after a deployment to that network.

---

## 🔏 Web3 Providers:

The frontend has three different providers that provide different levels of access to different chains:

`mainnetProvider`: (read only) [Infura](https://infura.io/) connection to main [Ethereum](https://ethereum.org/developers/) network (and contracts already deployed like [DAI](https://etherscan.io/address/0x6b175474e89094c44da98b954eedeac495271d0f#code) or [Uniswap](https://etherscan.io/address/0x2a1530c4c41db0b0b2bb646cb5eb1a67b7158667)).

`localProvider`: local [HardHat](https://hardhat.org) accounts, used to read from _your_ contracts (`.env` file points you at testnet or mainnet)

`injectedProvider`: your personal [MetaMask](https://metamask.io/download.html), [WalletConnect](https://walletconnect.org/apps) via [Argent](https://www.argent.xyz/), or other injected wallet (generates [burner-provider](https://www.npmjs.com/package/burner-provider) on page load)

---

## Deploying frontend

Deployment is managed via a CI workflow defined in `.github/workflows/main.yaml`, which runs for all commits to the `main` branch and depends on github secrets `GCP_PROD_SA_KEY` and `INFURA_ID`. The react app is packaged and published to the fountain.finance Google Cloud App Engine. Once new deployment versions have been published, they must be manually promoted before they become live.