require('@nomiclabs/hardhat-ethers');
require('@openzeppelin/hardhat-upgrades');

const hre = require("hardhat");

const { Proxies } = require('./.deployment_data.json');
const proxies = Proxies.Staging;

const PawnNFTProxyAddr  = proxies.PAWN_NFT_CONTRACT_ADDRESS;
const PawnNFTBuildV1    = "contracts/pawn/pawn-nft/PawnNFTContract.sol:PawnNFTContract";
const PawnNFTBuildV2    = "contracts/pawn/pawn-nft/PawnNFTContract.sol:PawnNFTContract";

const decimals      = 10**18;

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("============================================================");
    console.log("Upgrading contracts with the account:", deployer.address);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================");

    const PawnNFTFactoryV1      = await hre.ethers.getContractFactory(PawnNFTBuildV1);
    const PawnNFTArtifactV1     = await hre.artifacts.readArtifact(PawnNFTBuildV1);
    const PawnNFTContractV1     = PawnNFTFactoryV1.attach(PawnNFTProxyAddr);

    const PawnNFTImplV1         = await hre.upgrades.erc1967.getImplementationAddress(PawnNFTContractV1.address);

    console.log(`Upgrading ${PawnNFTArtifactV1.contractName} at proxy: ${PawnNFTContractV1.address}`);
    console.log(`Current implementation address: ${PawnNFTImplV1}`);

    const PawnNFTFactoryV2      = await hre.ethers.getContractFactory(PawnNFTBuildV2);
    const PawnNFTArtifactV2     = await hre.artifacts.readArtifact(PawnNFTBuildV2);
    const PawnNFTContractV2     = await hre.upgrades.upgradeProxy(PawnNFTContractV1, PawnNFTFactoryV2);
    
    await PawnNFTContractV2.deployed();
    
    const PawnNFTImplV2         = await hre.upgrades.erc1967.getImplementationAddress(PawnNFTContractV2.address);

    console.log(`${PawnNFTArtifactV2.contractName} deployed to: ${PawnNFTContractV2.address}`);
    console.log(`New implementation Address: ${PawnNFTImplV2}`);

    console.log("============================================================\n\r");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });