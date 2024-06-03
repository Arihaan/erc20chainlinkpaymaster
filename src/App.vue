<template>
  <div id="app" v-if="!mainLoading">
    <h1>Greeter says: {{ greeting }} 👋</h1>
    <div class="title">
      This simple dApp allows you to interact with a 'Greeter' smart contract using the new ERC20ChainlinkPaymaster <br> developed for the 
      Chainlink Block Magic Hackathon. 
      <p>
        The Greeter contract is deployed on the zkSync testnet on
        <a
          :href="`https://sepolia.explorer.zksync.io/address/${GREETER_CONTRACT_ADDRESS}`"
          target="_blank"
          >{{ GREETER_CONTRACT_ADDRESS }}</a
        >
      </p>
      <p>
        The Chainlink Paymaster is deployed on the zkSync testnet on
        <a
          :href="`https://sepolia.explorer.zksync.io/address/${PAYMASTER_CONTRACT_ADDRESS}`"
          target="_blank"
          >{{ PAYMASTER_CONTRACT_ADDRESS }}</a
        >
      </p>
    </div>
    <div class="main-box">
      <div>
        Select token:
        <select v-model="selectedTokenAddress" @change="changeToken">
          <option
            v-for="token in tokens"
            v-bind:value="token.address"
            v-bind:key="token.address"
          >
            {{ token.symbol }}
          </option>
        </select>
      </div>
      <div class="balance" v-if="selectedToken">
        <p>
          Balance: <span v-if="retrievingBalance">Loading...</span>
          <span v-else>{{ currentBalance }} {{ selectedToken.symbol }}</span>
        </p>
        <p>
          Expected fee: <span v-if="retrievingFee">Loading...</span>
          <span v-else>{{ currentFee }} {{ selectedToken.symbol }}</span>
          <button class="refresh-button" @click="updateFee">Refresh</button>
        </p>
      </div>
      <div class="greeting-input">
        <input
          v-model="newGreeting"
          :disabled="!selectedToken || txStatus != 0"
          placeholder="Write new greeting here..."
        />

        <button
          class="change-button"
          :disabled="!selectedToken || txStatus != 0 || retrievingFee"
          @click="changeGreeting"
        >
          <span v-if="selectedToken && !txStatus">Change greeting</span>
          <span v-else-if="!selectedToken">Select token to pay fee first</span>
          <span v-else-if="txStatus === 1">Sending tx...</span>
          <span v-else-if="txStatus === 2"
            >Waiting until tx is committed...</span
          >
          <span v-else-if="txStatus === 3">Updating the page...</span>
          <span v-else-if="retrievingFee">Updating the fee...</span>
        </button>
      </div>
    </div>
  </div>
  <div id="app" v-else>
    <div class="start-screen">
      <h1>Welcome to the <br>ERC20ChainlinkPaymaster Demo!</h1>
      <button v-if="correctNetwork" @click="connectMetamask">
        Connect Metamask
      </button>
      <button v-else @click="addZkSyncSepolia">Switch to zkSync Sepolia</button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";

import {Contract, BrowserProvider, Provider, utils} from "zksync-ethers";
import {ethers} from "ethers";

const GREETER_CONTRACT_ADDRESS = "0xa7C85Dda62934943C2b3D466e54b51C0BC1113b5"; 
const PAYMASTER_CONTRACT_ADDRESS = "0x754f7fA479497c749f79209A1cfeBd17Cce19497";
import GREETER_CONTRACT_ABI from "./abi.json"; 
import CHAINLINK_CONTRACT_ABI from "./chainlinkabi.json";

const ETH_ADDRESS = "0x0000000000000000000000000000000000000000";
import allowedTokens from "./erc20.json"; // change to "./erc20.json" to use ERC20 tokens

// reactive references
const correctNetwork = ref(false);
const tokens = ref(allowedTokens);
const newGreeting = ref("");
const greeting = ref("");
const mainLoading = ref(true);
const retrievingFee = ref(false);
const retrievingBalance = ref(false);
const currentBalance = ref("");
const currentFee = ref("");
const selectedTokenAddress = ref(null);
const selectedToken = ref<{
  l2Address: string;
  decimals: number;
  symbol: string;
} | null>(null);
// txStatus is a reactive variable that tracks the status of the transaction
// 0 stands for no status, i.e no tx has been sent
// 1 stands for tx is beeing submitted to the operator
// 2 stands for tx awaiting commit
// 3 stands for updating the balance and greeting on the page
const txStatus = ref(0);

let provider: Provider | null = null;
let signer: Wallet | null = null;
let contract: Contract | null = null;

// Lifecycle hook
onMounted(async () => {
  const network = await window.ethereum?.request<string>({
    method: "net_version",
  });
  if (network !== null && network !== undefined && +network === 300) {
    correctNetwork.value = true;
  }
});

const initializeProviderAndSigner = async () => {
  provider = new Provider("https://sepolia.era.zksync.dev");
  // Note that we still need to get the Metamask signer
  signer = await new BrowserProvider(window.ethereum).getSigner();
  contract = new Contract(GREETER_CONTRACT_ADDRESS, GREETER_CONTRACT_ABI, signer);
};


const getGreeting = async () => {
  // Smart contract calls work the same way as in `ethers`
  return await contract.greet();
};

const ethFeeToUsd = async (fee) => {
  const ethUsdAddr = "0xfEefF7c3fB57d18C5C6Cdd71e45D2D0b4F9377bF";
  const ethPriceFeed = new ethers.Contract(ethUsdAddr, CHAINLINK_CONTRACT_ABI, provider);
  const ethLatestRoundData = await ethPriceFeed.latestRoundData();
  const ethToUsd = Number(ethLatestRoundData[1]) / 10 ** 8;
  return ethToUsd * fee;
}

const usdFeeToLink = async (fee) => {
  const linkUsdAddr = "0x894423C43cD7230Cd22a47B329E96097e6355292";
  const linkPriceFeed = new ethers.Contract(linkUsdAddr, CHAINLINK_CONTRACT_ABI, provider);
  const linkLatestRoundData = await linkPriceFeed.latestRoundData();
  const linkToUsd = Number(linkLatestRoundData[1]) / 10 ** 8;
  return fee / linkToUsd;
}

const usdFeeToUSDC = async (fee) => {
  const usdcUsdAddr = "0x1844478CA634f3a762a2E71E3386837Bd50C947F";
  const usdcPriceFeed = new ethers.Contract(usdcUsdAddr, CHAINLINK_CONTRACT_ABI, provider);
  const usdcLatestRoundData = await usdcPriceFeed.latestRoundData();
  const usdcToUsd = Number(usdcLatestRoundData[1]) / 10 ** 8;
  return fee / usdcToUsd;
}

const getFee = async () => {

  // Chainlink Price Feed Contract Addresses on zkSync Sepolia Testnet
  // const ethUsdAddr = "0xfEefF7c3fB57d18C5C6Cdd71e45D2D0b4F9377bF";
  // const linkUsdAddr = "0x894423C43cD7230Cd22a47B329E96097e6355292";
  // const usdcUsdAddr = "0x1844478CA634f3a762a2E71E3386837Bd50C947F";

  // Getting the amount of gas (gas) needed for one transaction
  const feeInGas = await contract.setGreeting.estimateGas(newGreeting.value);
  // Getting the gas price per one erg. For now, it is the same for all tokens.
  const gasPriceInUnits = await provider.getGasPrice();
 
  // To display the number of tokens in the human-readable format, we need to format them,
  const gasInEth = ethers.formatUnits(feeInGas * gasPriceInUnits, selectedToken.value.decimals);

  if (selectedToken.value.symbol == "ETH"){
    return gasInEth;
  }
  else {
    // const ethPriceFeed = new ethers.Contract(ethUsdAddr, CHAINLINK_CONTRACT_ABI, provider);
    // const ethLatestRoundData = await ethPriceFeed.latestRoundData();
    // const ethToUsd = Number(ethLatestRoundData[1]) / 10 ** 8;

    // Calculating the gas cost in USD
    const gasCostUsd = await ethFeeToUsd(gasInEth);

    if (selectedToken.value.symbol == "LINK"){
      // const linkPriceFeed = new ethers.Contract(linkUsdAddr, CHAINLINK_CONTRACT_ABI, provider);
      // const linkLatestRoundData = await linkPriceFeed.latestRoundData();
      // const linkToUsd = Number(linkLatestRoundData[1]) / 10 ** 8;

      // returns cost of gas in LINK
      return await usdFeeToLink(gasCostUsd);
    }
    else if (selectedToken.value.symbol == "USDC"){
      // const usdcPriceFeed = new ethers.Contract(usdcUsdAddr, CHAINLINK_CONTRACT_ABI, provider);
      // const usdcLatestRoundData = await usdcPriceFeed.latestRoundData();
      // const usdcToUsd = Number(usdcLatestRoundData[1]) / 10 ** 8;

      // returns cost of gas in USDC
      return await usdFeeToUSDC(gasCostUsd);
    }
  }
};

const getBalance = async () => {
  // Getting the balance for the signer in the selected token
  const balanceInUnits = await signer.getBalance(selectedToken.value.l2Address);
  // To display the number of tokens in the human-readable format, we need to format them,
  // e.g. if balanceInUnits returns 500000000000000000 wei of ETH, we want to display 0.5 ETH the user
  return ethers.formatUnits(balanceInUnits, selectedToken.value.decimals);
};

const getOverrides = async () => {
  if (selectedToken.value.l2Address != ETH_ADDRESS) {
    const chainlinkPaymaster = "0x754f7fA479497c749f79209A1cfeBd17Cce19497";

    const gasPrice = await provider.getGasPrice();

    // define paymaster parameters for gas estimation
    const paramsForFeeEstimation = utils.getPaymasterParams(chainlinkPaymaster, {
      type: "ApprovalBased",
      minimalAllowance: BigInt("1"),
      token: selectedToken.value.l2Address,
      innerInput: new Uint8Array(),
    });

    // estimate gasLimit via paymaster
    const gasLimit = await contract.setGreeting.estimateGas(newGreeting.value, {
      customData: {
        gasPerPubdata: utils.DEFAULT_GAS_PER_PUBDATA_LIMIT,
        paymasterParams: paramsForFeeEstimation,
      },
    });

    // fee calculated in ETH will be the same in
    // ERC20 token using the testnet paymaster
    let fee = gasPrice * gasLimit;
    const feeInEth = ethers.formatUnits(fee, selectedToken.value.decimals);

    if (selectedToken.value.symbol != "ETH"){
      const finalFeeInUsd = await ethFeeToUsd(feeInEth);
      if (selectedToken.value.symbol == "LINK"){
        fee = BigInt(await usdFeeToLink(finalFeeInUsd) * 10 ** 18);
      }
      else if (selectedToken.value.symbol == "USDC"){
        fee = BigInt(await usdFeeToUSDC(finalFeeInUsd) * 10 ** 18);
      }
    }

    const paymasterParams = utils.getPaymasterParams(chainlinkPaymaster, {
      type: "ApprovalBased",
      token: selectedToken.value.l2Address,
      // provide estimated fee as allowance
      minimalAllowance: fee,
      // empty bytes as testnet paymaster does not use innerInput
      innerInput: new Uint8Array(),
    });

    return {
      maxFeePerGas: gasPrice,
      maxPriorityFeePerGas: BigInt(1),
      gasLimit,
      customData: {
        gasPerPubdata: utils.DEFAULT_GAS_PER_PUBDATA_LIMIT,
        paymasterParams,
      },
    };
  }

  return {};
};


const changeGreeting = async () => {
  txStatus.value = 1;
  try {
    const overrides = await getOverrides();
    const txHandle = await contract.setGreeting(newGreeting.value, overrides);

    txStatus.value = 2;

    // Wait until the transaction is committed
    await txHandle.wait();
    txStatus.value = 3;

    // Update greeting
    greeting.value = await getGreeting();

    retrievingFee.value = true;
    retrievingBalance.value = true;
    // Update balance and fee
    currentBalance.value = await getBalance();
    currentFee.value = await getFee();
  } catch (e) {
    console.error(e);
    alert(e);
  }

  txStatus.value = 0;
  retrievingFee.value = false;
  retrievingBalance.value = false;
  newGreeting.value = "";
};

const updateFee = async () => {
  retrievingFee.value = true;
  getFee()
    .then((fee) => {
      currentFee.value = fee;
    })
    .catch((e) => console.log(e))
    .finally(() => {
      retrievingFee.value = false;
    });
};
const updateBalance = async () => {
  retrievingBalance.value = true;
  getBalance()
    .then((balance) => {
      currentBalance.value = balance;
    })
    .catch((e) => console.log(e))
    .finally(() => {
      retrievingBalance.value = false;
    });
};
const changeToken = async () => {
  retrievingFee.value = true;
  retrievingBalance.value = true;

  const tokenAddress = tokens.value.filter(
    (t) => t.address === selectedTokenAddress.value,
  )[0];
  selectedToken.value = {
    l2Address: tokenAddress.address,
    decimals: tokenAddress.decimals,
    symbol: tokenAddress.symbol,
  };
  try {
    updateFee();
    updateBalance();
  } catch (e) {
    console.log(e);
  } finally {
    retrievingFee.value = false;
    retrievingBalance.value = false;
  }
};
const loadMainScreen = async () => {
  await initializeProviderAndSigner();

  if (!provider || !signer) {
    alert("Follow the tutorial to learn how to connect to Metamask!");
    return;
  }

  await getGreeting()
    .then((newGreeting) => (greeting.value = newGreeting))
    .catch((e: unknown) => console.error(e));

  mainLoading.value = false;
};
const addZkSyncSepolia = async () => {
  // add zkSync testnet to Metamask
  await window.ethereum?.request({
    method: "wallet_addEthereumChain",
    params: [
      {
        chainId: "0x12C",
        chainName: "zkSync Sepolia testnet",
        rpcUrls: ["https://sepolia.era.zksync.dev"],
        blockExplorerUrls: ["https://sepolia.explorer.zksync.io/"],
        nativeCurrency: {
          name: "ETH",
          symbol: "ETH",
          decimals: 18,
        },
      },
    ],
  });
  window.location.reload();
};
const connectMetamask = async () => {
  await window.ethereum
    ?.request({ method: "eth_requestAccounts" })
    .catch((e: unknown) => console.error(e));

  loadMainScreen();
};
</script>

<style scoped>
input,
select {
  padding: 8px 3px;
  margin: 0 5px;
}
button {
  margin: 0 5px;
}
.title,
.main-box,
.greeting-input,
.balance {
  margin: 10px;
}
</style>
