require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { Proxies } = require('./.deployment_data.json');
const proxies = Proxies.Dev2;

const VoteProxyAddr = proxies.VOTE_CONTRACT_ADDRESS;
const VoteBuildName = "Vote";

const HubProxyAddr = proxies.HUB_CONTRACT_ADDRESS;
const HubBuildName = "Hub";

const decimals      = 10**18;

async function main() {
    const[deployer] = await hre.ethers.getSigners();

    console.log("==============================");
    console.log("Upgrading contract with the account: ", deployer.address);
    console.log("Account balance: " , ((await deployer.getBalance())/decimals).toString());
    console.log("=============================\n\r");

    const VoteFactoryV1 = await hre.ethers.getContractFactory(VoteBuildName);
    const VoteArtifactV1 = await hre.artifacts.readArtifact(VoteBuildName);
    const VoteContractV1 = VoteFactoryV1.attach(VoteProxyAddr);

    const VoteIV1 = await hre.upgrades.erc1967.getImplementationAddress(VoteContractV1.address);

    console.log(`Upgrading ${VoteArtifactV1.contractName} at proxy : ${VoteContractV1.address}`);
    console.log(`Current implementation address: ${VoteIV1}`);

    const VoteFactoryV2 = await hre.ethers.getContractFactory(VoteBuildName);
    const VoteArtifactv2 = await hre.artifacts.readArtifact(VoteBuildName);
    const VoteContractV2 = await hre.upgrades.upgradeProxy(VoteContractV1, VoteFactoryV2);

    await VoteContractV2.deployed();

    const VoteIV2 = await hre.upgrades.erc1967.getImplementationAddress(VoteContractV2.address);

    console.log(`${VoteArtifactv2.contractName} deployed to ${VoteContractV2.address}`);
    console.log(`New implementation Address: ${VoteIV2}`);

    const HubFactory = await hre.ethers.getContractFactory(HubBuildName);
    const HubArtifact = await hre.artifacts.readArtifact(HubBuildName);
    const HubContract = HubFactory.attach(HubProxyAddr);

    console.log(`HUB_ADDRESS: \x1b[31m${HubContract.address}\x1b[0m`);
    console.log(`Registering \x1b[36m${VoteArtifactv2.contractName}\x1b[0m to \x1b[31m${HubArtifact.contractName}\x1b[0m...`);
    const signature = await VoteContractV2.signature();
    console.log(`Signature: \x1b[36m${signature}\x1b[0m`);
    await HubContract.registerContract(signature,VoteContractV2.address,VoteArtifactv2.contractName);



    console.log("=================================\n\r");


}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });