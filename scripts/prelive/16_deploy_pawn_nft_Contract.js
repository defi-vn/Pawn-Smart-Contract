require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { Proxies } = require('./.deployment_data_prelive.json');

const PawnNFTBuildName = "contracts/pawn/pawn-nft-v2/PawnNFTContract.sol:PawnNFTContract";

const proxyType = { kind: "uups" };
const proxies = Proxies.Prelive;

const HubProxyAddr = proxies.HUB_CONTRACT_ADDRESS;
const HubBuildName = "Hub";
const decimals = 10**18;

async function main() {
    const[deployer] = await hre.ethers.getSigners();
 
    console.log("=============================\n\r");
    console.log("Deploying contracts with the account: ", deployer.address);
    console.log("Account balance:" , ((await deployer.getBalance()) / decimals).toString());
    console.log("===================================\n\r");

    const PawnNFTFactory = await hre.ethers.getContractFactory(PawnNFTBuildName);
    const PawnNFTArtifact = await hre.artifacts.readArtifact(PawnNFTBuildName);
    const PawnNFTContract = await  hre.upgrades.deployProxy(PawnNFTFactory,[HubProxyAddr], proxyType);

    await PawnNFTContract.deployed();
    const signature = await PawnNFTContract.signature();

    console.log(`PAWN_NFT_CONTRACT_ADDRESS: ${PawnNFTContract.address}`);
    console.log(`Signature: \x1b[36m${signature}\x1b[0m`);
     
    implementationAddress = await hre.upgrades.erc1967.getImplementationAddress(PawnNFTContract.address);
    console.log(`${PawnNFTArtifact.contractName} implementation address: ${implementationAddress}`);

    const HubFactory = await hre.ethers.getContractFactory(HubBuildName);
    const HubArtifact = await hre.artifacts.readArtifact(HubBuildName);
    const HubContract = HubFactory.attach(HubProxyAddr);

    console.log(`HUB_ADDRESS: \x1b[31m${HubContract.address}\x1b[0m`);
    console.log(`Registering \x1b[36m${PawnNFTArtifact.contractName}\x1b[0m to \x1b[31m${HubArtifact.contractName}\x1b[0m...`);

    await HubContract.registerContract(signature,PawnNFTContract.address,PawnNFTArtifact.contractName);
    console.log("==============================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.log(error);
        process.exit(1);
    });