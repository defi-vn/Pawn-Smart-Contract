require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { Proxies } = require('./.deployment_data.json');

const VoteBuildName = "Vote";
const HubProxy = Proxies.Dev2.HUB_CONTRACT_ADDRESS;
const proxyType = { kind: "uups" };
const HubBuildName = "Hub";

const decimals      = 10**18;

async function main() {
    const[deployer] = await hre.ethers.getSigners();

    console.log("==============================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance: ", ((await deployer.getBalance()) / decimals).toString());
    console.log("=================================\n\r");

    const VoteFactory = await hre.ethers.getContractFactory(VoteBuildName);
    const VoteArtifact = await hre.artifacts.readArtifact(VoteBuildName);
    const VoteContract = await hre.upgrades.deployProxy(VoteFactory,[HubProxy],proxyType);

    await VoteContract.deployed();
    const signature = await VoteContract.signature();

    console.log(`VOTING_CONTRACT_ADDRESS: ${VoteContract.address}`);
    console.log(`Signature: \x1b[36m${signature}\x1b[0m`);

    implementtationAddress = await hre.upgrades.erc1967.getImplementationAddress(VoteContract.address);
    console.log(`${VoteArtifact.contractName} implementation address: ${implementtationAddress}`);
    
    const HubFactory = await hre.ethers.getContractFactory(HubBuildName);
    const HubArtifact = await hre.artifacts.readArtifact(HubBuildName);
    const HubContract = HubFactory.attach(HubProxy);

    console.log(`HUB_ADDRESS: \x1b[31m${HubContract.address}\x1b[0m`);
    console.log(`Registering \x1b[36m${VoteArtifact.contractName}\x1b[0m to \x1b[31m${HubArtifact.contractName}\x1b[0m...`);

    await HubContract.registerContract(signature,VoteContract.address,VoteArtifact.contractName);
    console.log("===========================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });