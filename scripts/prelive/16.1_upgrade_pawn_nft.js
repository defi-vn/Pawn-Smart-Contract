require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');

const { Proxies } = require('./.deployment_data_prelive.json');
const proxies = Proxies.Prelive;

const PawnNFTProxyAddr = proxies.PAWN_NFT_CONTRACT_ADDRESS;
const PawnNFTBuildName = "PawnNFTContract";

const HubProxyAddr = proxies.HUB_CONTRACT_ADDRESS;
const HubBuildName = "Hub";

const decimals = 10**18;

async function main() {
    const[deployer] = await hre.ethers.getSigners();

    console.log("============================\n\r");
    console.log("Upgrading contract with the account:" , deployer.address);
    console.log("Account balance:", ((await deployer.getBalance()) / decimals).toString());
    console.log("============================\n\r");

    const PawnNFTFactoryV1 = await hre.ethers.getContractFactory(PawnNFTBuildName);
    const PawnNFTArtifactV1 = await hre.artifacts.readArtifact(PawnNFTBuildName);
    const PawnNFTContractV1 = PawnNFTFactoryV1.attach(PawnNFTProxyAddr);

    const PawnNFTImpLV1 = await hre.upgrades.erc1967.getImplementationAddress(PawnNFTContractV1.address);

    console.log(`Upgrading ${PawnNFTArtifactV1.contractName} at proxy: ${PawnNFTContractV1.address}`);
    console.log(`Current implementation address: ${PawnNFTImpLV1}`);

    const PawnNFTFactoryV2 = await hre.ethers.getContractFactory(PawnNFTBuildName);
    const PawnNFTArtifactV2 = await hre.artifacts.readArtifact(PawnNFTBuildName);
    const PawnNFTContractV2 = await hre.upgrades.upgradeProxy(PawnNFTContractV1, PawnNFTFactoryV2);

    await PawnNFTContractV2.deployed();

    const PawnNFTImplV2 = await hre.upgrades.erc1967.getImplementationAddress(PawnNFTContractV2.address);

    console.log(`${PawnNFTArtifactV2.contractName} deployed to ${PawnNFTContractV2.address}`);
    console.log(`New implementation Address: ${PawnNFTImplV2}`);

    const HubFactory = await hre.ethers.getContractFactory(HubBuildName);
    const HubArtifact = await hre.artifacts.readArtifact(HubBuildName);
    const HubContract = HubFactory.attach(HubProxyAddr);

    console.log(`HUB_ADDRESS: \x1b[31m${HubContract.address}\x1b[0m`);
    console.log(`Registering \x1b[36m${PawnNFTArtifactV2.contractName}\x1b[0m to \x1b[31m${HubArtifact.contractName}\x1b[0m...`);

    
    
    const signature = await PawnNFTContractV2.signature();
    console.log(`Signature: \x1b[36m${signature}\x1b[0m`);

    await HubContract.registerContract(signature,PawnNFTContractV2.address,PawnNFTArtifactV2.contractName);
    console.log("===========================\n\r");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });