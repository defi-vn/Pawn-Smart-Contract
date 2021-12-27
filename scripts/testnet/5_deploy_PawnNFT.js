require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { PawnConfig } = require('./.deployment_data.json');

const PawnNFTBuildName  = "contracts/pawn/pawn-nft/PawnNFTContract.sol:PawnNFTContract";

const proxyType = { kind: "uups" };

const decimals      = 10**18;

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    
    console.log("============================================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================\n\r");

    const PawnNFTFactory    = await hre.ethers.getContractFactory(PawnNFTBuildName);
    const PawnNFTArtifact   = await hre.artifacts.readArtifact(PawnNFTBuildName);

    const PawnNFTContract   = await hre.upgrades.deployProxy(PawnNFTFactory, [100000], proxyType);

    await PawnNFTContract.deployed();

    console.log(`PAWN_NFT_CONTRACT_ADDRESS: ${PawnNFTContract.address}`);

    implementationAddress = await hre.upgrades.erc1967.getImplementationAddress(PawnNFTContract.address);
    console.log(`${PawnNFTArtifact.contractName} implementation address: ${implementationAddress}`);
    
    console.log("============================================================\n\r");
}
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });