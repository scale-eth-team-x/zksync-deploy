import { Wallet, utils } from "zksync-web3";
import * as ethers from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import * as dotenv from "dotenv";
dotenv.config();

// Get private key from the environment variable
const PRIVATE_KEY: string = process.env.ZKS_PRIVATE_KEY || "";
if (!PRIVATE_KEY) {
  throw new Error("Please set ZKS_PRIVATE_KEY in the environment variables.");
}

// An example of a deploy script that will deploy and call a simple contract.
export default async function (hre: HardhatRuntimeEnvironment) {
  // Initialize the wallet.
  const wallet = new Wallet(PRIVATE_KEY);

  // Create deployer object and load the artifact of the contract you want to deploy.
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact("SRWalletFactory");

  // Deploy
  const entryPointAddr = "0x0576a174D229E3cFA37253523E645A78A0C91B57"
  const greeterContract = await deployer.deploy(artifact, [entryPointAddr]);

  // Show the contract info.
  const contractAddress = greeterContract.address;
  console.log(`${artifact.contractName} was deployed to ${contractAddress}`);
}

