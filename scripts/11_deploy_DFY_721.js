require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { PawnConfig } = require('./.deployment_data.json');

const DFY721BuildName = "contracts/pawn/nft_evaluation/implement/DFY_Hard_721.sol:DFY_Hard_721";

const proxyType = { kind: "uups" };

const decimals      = 10**18;

async function main() {
    const[deployer] = await hre.ethers.getSigners();

    console.log("==============================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance: ", ((await deployer.getBalance()) / decimals).toString());
    console.log("=================================\n\r");

    const DFY721Factory = await hre.ethers.getContractFactory(DFY721BuildName);
    const DFY721Artifact = await hre.artifacts.readArtifact(DFY721BuildName);
    const DFY721Contract = await hre.upgrades.deployProxy(DFY721Factory,["quang","abc","rb",0,"0xF124Ac6EAe6a1CD22a5D4cab44C0D4A428334520","0x3Bf6D45954467a2aC3179b2ee03ca29469f4665d"],proxyType);

    await DFY721Contract.deployed();

    console.log(`DFY721_CONTRACT_ADDRESS: ${DFY721Contract.address}`);

    implementtationAddress = await hre.upgrades.erc1967.getImplementationAddress(DFY721Contract.address);
    console.log(`${DFY721Artifact.contractName} implementation address: ${implementtationAddress}`);

    console.log("===========================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });