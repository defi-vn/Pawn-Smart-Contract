require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { Proxies } = require('./.deployment_data.json');

const Collection1155BuildName = "DFYHard1155Factory";
const HubProxy = Proxies.Dev1.HUB_CONTRACT_ADDRESS;
const proxyType = { kind: "uups" };
const HubBuildName = "Hub";
const decimals      = 10**18;

async function main() {
    const[deployer] = await hre.ethers.getSigners();

    console.log("==============================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance: ", ((await deployer.getBalance()) / decimals).toString());
    console.log("=================================\n\r");

    const Collection1155Factory = await hre.ethers.getContractFactory(Collection1155BuildName);
    const Collection1155Artifact = await hre.artifacts.readArtifact(Collection1155BuildName);
    const Collection1155Contract = await hre.upgrades.deployProxy(Collection1155Factory,[HubProxy],proxyType);

    await Collection1155Contract.deployed();
    const signature = await Collection1155Contract.signature();

    console.log(`FACTORY_1155_CONTRACT_ADDRESS: ${Collection1155Contract.address}`);
    console.log(`Signature: \x1b[36m${signature}\x1b[0m`);

    implementtationAddress = await hre.upgrades.erc1967.getImplementationAddress(Collection1155Contract.address);
    console.log(`${Collection1155Artifact.contractName} implementation address: ${implementtationAddress}`);

    const HubFactory = await hre.ethers.getContractFactory(HubBuildName);
    const HubArtifact = await hre.artifacts.readArtifact(HubBuildName);
    const HubContract = HubFactory.attach(HubProxy);

    console.log(`HUB_ADDRESS: \x1b[31m${HubContract.address}\x1b[0m`);
    console.log(`Registering \x1b[36m${Collection1155Artifact.contractName}\x1b[0m to \x1b[31m${HubArtifact.contractName}\x1b[0m...`);

    await HubContract.registerContract(signature,Collection1155Contract.address,Collection1155Artifact.contractName);
    console.log("===========================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });