require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { Proxies } = require('./.deployment_data.json');

const Collection721BuildName = "DFYHard721Factory";
const HubProxy = Proxies.Staging.HUB_CONTRACT_ADDRESS;
const proxyType = { kind: "uups" };
const HubBuildName = "Hub";

const decimals      = 10**18;

async function main() {
    const[deployer] = await hre.ethers.getSigners();

    console.log("==============================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance: ", ((await deployer.getBalance()) / decimals).toString());
    console.log("=================================\n\r");

    const Collection721Factory = await hre.ethers.getContractFactory(Collection721BuildName);
    const Collection721Artifact = await hre.artifacts.readArtifact(Collection721BuildName);
    const Collection721Contract = await hre.upgrades.deployProxy(Collection721Factory,[HubProxy],proxyType);

    await Collection721Contract.deployed();
    const signature = await Collection721Contract.signature();

    console.log(`FACTORY_721_CONTRACT_ADDRESS: ${Collection721Contract.address}`);
    console.log(`Signature: \x1b[36m${signature}\x1b[0m`);

    implementtationAddress = await hre.upgrades.erc1967.getImplementationAddress(Collection721Contract.address);
    console.log(`${Collection721Artifact.contractName} implementation address: ${implementtationAddress}`);
    
    const HubFactory = await hre.ethers.getContractFactory(HubBuildName);
    const HubArtifact = await hre.artifacts.readArtifact(HubBuildName);
    const HubContract = HubFactory.attach(HubProxy);

    console.log(`HUB_ADDRESS: \x1b[31m${HubContract.address}\x1b[0m`);
    console.log(`Registering \x1b[36m${Collection721Artifact.contractName}\x1b[0m to \x1b[31m${HubArtifact.contractName}\x1b[0m...`);

    await HubContract.registerContract(signature,Collection721Contract.address,Collection721Artifact.contractName);
    console.log("===========================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });