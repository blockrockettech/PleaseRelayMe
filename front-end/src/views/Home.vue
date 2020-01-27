<template>
  <div class="container">
    <h1 class="mb-2 mt-4">rDAI Token</h1>
    <div>
      Metamask Balance: {{rDai.balance}} rDAI
    </div>
    <h3 class="mt-5">
      Account Hat Stats:
    </h3>
    <div v-if="rDai.accountStats">
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
    <b-button variant="dark" class="mt-2" @click="claimInterst">
      Claim Interest
    </b-button>
  </div>
</template>

<script>
import {ethers} from 'ethers';
import rDAIRelayHub from '../truffleconf/rDAIRelayHub';
import IRToken from '../truffleconf/IRToken';

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
  },
  data() {
    return {
      web3: {
        provider: null,
        signer: null,
        chain: null,
        contracts: {
          hub: null,
          rToken: null
        }
      },
      rDai: {
        balance: null,
        accountStats: null,
        hub: {
          interestPayable: null,
          balance: null
        }
      }
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
    }
  }
}
</script>
