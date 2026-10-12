import ApplicationController from '../../../javascript/controllers/application_controller'

// Users::ProfileComponent — Stimulus controller for user profile display
// Handles TFT balance claim and clipboard interactions
export default class extends ApplicationController {
  static values = {
    walletChallengeUrl: String,
    walletConnectUrl: String,
    walletDisconnectUrl: String,
    walletClaimRequestUrl: String,
    walletClaimUrl: String,
    walletChainId: String,
    walletConnectProjectId: String,
    walletConnecting: String,
    walletConnectFailed: String,
    walletconnectUnavailable: String,
    walletDisconnectFailed: String,
    walletExternalConnected: Boolean,
    claimSigning: String,
    claimSubmitted: String,
    claimFailed: String
  }
  static targets = ["walletStatus"]

  connect() {
    // super.connect() вызывает StimulusReflex.register(this) → крепит this.stimulate.
    // Без него бросок: "this.stimulate is not a function" при вызове claim.
    super.connect()
  }

  /**
   * Забирает разблокированные награды (claim).
   * @param {Event} event - click событие
   */
  async claim(event) {
    event.preventDefault()
    if (this.walletExternalConnectedValue) {
      await this.claimWithExternalWallet()
      return
    }

    this.stimulate('UserReflex#claim_rewards')
  }

  async claimWithExternalWallet() {
    try {
      this.setWalletStatus(this.claimSigningValue)
      const provider = await this.claimProvider()
      const [address] = await provider.request({ method: "eth_requestAccounts" })
      const chainId = BigInt(await provider.request({ method: "eth_chainId" }))
      if (chainId !== BigInt(this.walletChainIdValue)) {
        await provider.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: `0x${BigInt(this.walletChainIdValue).toString(16)}` }]
        })
      }

      const { typed_data: typedData } = await this.postJson(this.walletClaimRequestUrlValue, {})
      const expectedAddress = typedData.message.from
      if (!address || address.toLowerCase() !== expectedAddress.toLowerCase()) {
        throw new Error(this.claimFailedValue)
      }
      const signature = await provider.request({
        method: "eth_signTypedData_v4",
        params: [address, JSON.stringify(typedData)]
      })
      await this.postJson(this.walletClaimUrlValue, { signature })
      this.setWalletStatus(this.claimSubmittedValue)
    } catch (error) {
      this.setWalletStatus(error?.message || this.claimFailedValue)
    }
  }

  async claimProvider() {
    const injected = window.ethereum?.providers?.find((provider) => provider.isMetaMask) ||
      window.ethereum
    if (injected) return injected
    if (!this.walletConnectProjectIdValue) throw new Error(this.walletconnectUnavailableValue)
    return this.createWalletConnectProvider()
  }

  connectMetaMask(event) {
    event.preventDefault()
    const ethereum = window.ethereum?.providers?.find((provider) => provider.isMetaMask) ||
      (window.ethereum?.isMetaMask ? window.ethereum : window.ethereum)

    if (!ethereum) {
      const dappUrl = `${window.location.host}${window.location.pathname}${window.location.search}`
      window.location.assign(`https://metamask.app.link/dapp/${dappUrl}`)
      return
    }

    this.connectWallet(ethereum)
  }

  async connectWalletConnect(event) {
    event.preventDefault()
    if (!this.walletConnectProjectIdValue) {
      this.setWalletStatus(this.walletconnectUnavailableValue)
      return
    }

    try {
      const provider = await this.createWalletConnectProvider()
      await this.connectWallet(provider)
    } catch (error) {
      this.setWalletStatus(error?.message || this.walletConnectFailedValue)
    }
  }

  async connectWallet(provider) {
    try {
      this.setWalletStatus(this.walletConnectingValue)
      const [address] = await provider.request({ method: "eth_requestAccounts" })
      if (!address) throw new Error(this.walletConnectFailedValue)

      const actualChainId = BigInt(await provider.request({ method: "eth_chainId" }))
      if (actualChainId !== BigInt(this.walletChainIdValue)) {
        await provider.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: `0x${BigInt(this.walletChainIdValue).toString(16)}` }]
        })
      }

      const challenge = await this.postJson(this.walletChallengeUrlValue, {
        address,
        chain_id: this.walletChainIdValue
      })
      const signature = await provider.request({
        method: "personal_sign",
        params: [challenge.message, address]
      })
      await this.postJson(this.walletConnectUrlValue, { address, signature })
      window.location.reload()
    } catch (error) {
      this.setWalletStatus(error?.message || this.walletConnectFailedValue)
    }
  }

  async disconnectWallet(event) {
    event.preventDefault()
    try {
      await this.postJson(this.walletDisconnectUrlValue, {}, "DELETE")
      window.location.reload()
    } catch (error) {
      this.setWalletStatus(error?.message || this.walletDisconnectFailedValue)
    }
  }

  async createWalletConnectProvider() {
    const { default: EthereumProvider } = await import("@walletconnect/ethereum-provider")
    return EthereumProvider.init({
      projectId: this.walletConnectProjectIdValue,
      chains: [Number(this.walletChainIdValue)],
      showQrModal: true,
      metadata: {
        name: "Travel Fi",
        description: "Travel Fi wallet connection",
        url: window.location.origin,
        icons: [`${window.location.origin}/favicon-192.webp`]
      }
    })
  }

  async postJson(url, body, method = "POST") {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const response = await fetch(url, {
      method,
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify(body)
    })
    const payload = await response.json()
    if (!response.ok) throw new Error(payload.error || this.walletConnectFailedValue)
    return payload
  }

  setWalletStatus(message) {
    if (this.hasWalletStatusTarget) this.walletStatusTarget.textContent = message
  }
}
