require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { PawnConfig } = require('./.deployment_data.json');

const HubBuildName = "Hub";

const proxyType = { kind: "uups" };
const feeWallet = PawnConfig.FeeWallet;
const feeToken = PawnConfig.DFYToken;
const operator = PawnConfig.Operator;

const decimals      = 10**18;

async function main() {
    const[deployer] = await hre.ethers.getSigners();

    console.log("================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", ((await deployer.getBalance()) / decimals).toString());
    console.log("=================================\n\r");

    const HubFactory = await hre.ethers.getContractFactory(HubBuildName);
    const HubArtifact = await hre.artifacts.readArtifact(HubBuildName);
    const HubContract = await hre.upgrades.deployProxy(HubFactory,[feeWallet,feeToken,operator], proxyType);

    await HubContract.deployed();

    console.log(`HUB_CONTRACT_ADDRESS: ${HubContract.address}`);

    implementationAddress = await hre.upgrades.erc1967.getImplementationAddress(HubContract.address);
    console.log(`${HubArtifact.contractName} implementation address: ${implementationAddress}`);

    console.log("===============================\n\r");

}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

