<template>
  <div class="container">
    <h1 class="mb-2 mt-4">rDAI Token</h1>
    <div>
      Metamask Balance: {{rDai.balance}} rDAI
    </div>
    <h3 class="mt-5 d-none">
      Account Hat Stats:
    </h3>
    <div v-if="rDai.accountStats" class="d-none">
      <div>
        hatID: {{accountStats.hatID}}
      </div>
      <div>
        rAmount: {{accountStats.rAmount}}
      </div>
      <div>
        rInterest: {{rDai.accountStats.rInterest.toString()}}
      </div>
      <div>
        lDebt: {{rDai.accountStats.lDebt.toString()}}
      </div>
      <div>
        sInternalAmount: {{rDai.accountStats.sInternalAmount.toString()}}
      </div>
      <div>
        rInterestPayable: {{rDai.accountStats.rInterestPayable.toString()}}
      </div>
      <div>
        cumulativeInterest: {{rDai.accountStats.cumulativeInterest.toString()}}
      </div>
      <div>
        lRecipientsSum: {{accountStats.lRecipientsSum}}
      </div>
    </div>
    <h3 class="mt-5">
      rDAI Relay Hub
    </h3>
    <div >
      Interest accrued for relay hub: {{rDai.hub.interestPayable}} rDAI
    </div>
    <div>
      Hub balance: {{rDai.hub.balance}} rDAI
    </div>
    <div>
      Dapp Balance: {{dappEthBalance}} ETH
    </div>
    <div class="mt-4"><b-button variant="dark" @click="claimInterst">
      Claim Interest
    </b-button></div>
    <div class="mt-2">
      <b-button variant="dark" @click="swapDAI">
        Swap DAI for ETH (Kyber)
      </b-button>
      <div v-if="kyber.expectedDaiEthConvRate">
        Expected DAI / ETH Conversion Rate: {{kyber.expectedDaiEthConvRate}}
      </div>
    </div>
    <div class="mt-2">
      <b-button variant="dark" @click="refuel">
        Refuel Dapp
      </b-button>
    </div>
  </div>
</template>

<script>
import {ethers} from 'ethers';
import rDAIRelayHub from '../truffleconf/rDAIRelayHub';
import IRToken from '../truffleconf/IRToken';
import KyberNetworkInterface from '../truffleconf/KyberNetworkInterface';

export default {
  name: 'home',
  async created() {
    await window.ethereum.enable();
    this.web3.provider = new ethers.providers.Web3Provider(web3.currentProvider);
    this.web3.signer = this.web3.provider.getSigner();
    this.web3.chain = await this.web3.provider.getNetwork();
    const hubContractAddress = '0x512F74CC6f106C571B790D5f8062F2f3742C71d2';
    this.web3.contracts.hub = new ethers.Contract(
        hubContractAddress,
        rDAIRelayHub.abi,
        this.web3.signer,
    );

    const rTokenAddress = '0x462303f77a3f17Dbd95eb7bab412FE4937F9B9CB';
    this.web3.contracts.rToken = new ethers.Contract(
      rTokenAddress,
      IRToken.abi,
      this.web3.signer
    );

    const kyberAddress = '0x692f391bCc85cefCe8C237C01e1f636BbD70EA4D';
    this.web3.contracts.kyber = new ethers.Contract(
      kyberAddress,
      KyberNetworkInterface.abi,
      this.web3.signer
    );

    this.kyber.expectedDaiEthConvRate = ethers.utils.formatUnits((await this.web3.contracts.kyber.getExpectedRate(
      '0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa',
      '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE',
      '1000000000000000000'
    ))[0], '18');

    const accounts = await this.web3.provider.listAccounts();
    const account = accounts && accounts.length ? accounts[0] : null;

    let rDaiBalance = await this.web3.contracts.rToken.balanceOf(account);
    this.rDai.balance = ethers.utils.formatUnits(rDaiBalance, '18');

    this.rDai.accountStats = await this.web3.contracts.rToken.getAccountStats(account);

    //console.log(await this.web3.contracts.rToken.getHatByAddress(account));

    const interestEarnedForHubInWei = await this.web3.contracts.rToken.interestPayableOf(hubContractAddress);
    this.rDai.hub.interestPayable = ethers.utils.formatUnits(interestEarnedForHubInWei, '18');

    rDaiBalance = await this.web3.contracts.rToken.balanceOf(hubContractAddress);
    this.rDai.hub.balance = ethers.utils.formatUnits(rDaiBalance, '18');

    //await this.web3.contracts.rToken.payInterest(account);

    this.dappEthBalance = ethers.utils.formatEther(await this.web3.contracts.hub.balanceOf(account));
  },
  data() {
    return {
      web3: {
        provider: null,
        signer: null,
        chain: null,
        contracts: {
          hub: null,
          rToken: null,
          kyber: null,
        }
      },
      rDai: {
        balance: null,
        accountStats: null,
        hub: {
          interestPayable: null,
          balance: null
        }
      },
      kyber: {
        expectedDaiEthConvRate: null
      },
      dappEthBalance: null
    };
  },
  computed: {
    accountStats() {
      const stats = this.rDai.accountStats;
      return {
        hatID: stats.hatID.toString(),
        rAmount: ethers.utils.formatUnits(stats.rAmount, '18'),
        lRecipientsSum: ethers.utils.formatUnits(stats.lRecipientsSum, '18'),
      };
    }
  },
  methods: {
    async claimInterst() {
      await this.web3.contracts.rToken.payInterest('0x512F74CC6f106C571B790D5f8062F2f3742C71d2');
    },
    async refuel() {
      await this.web3.contracts.hub.refuelFor(
        '0x12D062B19a2DF1920eb9FC28Bd6E9A7E936de4c2',
        '0x462303f77a3f17Dbd95eb7bab412FE4937F9B9CB',
        '0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa',
        '0x692f391bCc85cefCe8C237C01e1f636BbD70EA4D',
        {
          gasLimit: 5000000
        }
      );
    },
    async swapDAI() {
      await this.web3.contracts.kyber.tradeWithHint(
        '0x12D062B19a2DF1920eb9FC28Bd6E9A7E936de4c2',
        '0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa',
        '1000000000000000000',
        '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE',
        '0x12D062B19a2DF1920eb9FC28Bd6E9A7E936de4c2',
        '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
        ethers.utils.parseUnits(this.kyber.expectedDaiEthConvRate, '18'),
        '0x0000000000000000000000000000000000000000',
        '0x0'
      );
    }
  }
}
</script>
