require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { PawnConfig } = require('./.deployment_data.json');

const DFY1155BuildName = "contracts/pawn/nft_evaluation/implement/DFY_Hard_1155.sol:DFY_Hard_1155";

const proxyType = { kind: "uups" };

const decimals      = 10**18;

async function main() {
    const[deployer] = await hre.ethers.getSigners();

    console.log("==============================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance: ", ((await deployer.getBalance()) / decimals).toString());
    console.log("=================================\n\r");

    const DFY1155Factory = await hre.ethers.getContractFactory(DFY1155BuildName);
    const DFY1155Artifact = await hre.artifacts.readArtifact(DFY1155BuildName);
    const DFY1155Contract = await hre.upgrades.deployProxy(DFY1155Factory,["quang","abc","rb",0,"0xF124Ac6EAe6a1CD22a5D4cab44C0D4A428334520","0x3Bf6D45954467a2aC3179b2ee03ca29469f4665d"],proxyType);

    await DFY1155Contract.deployed();

    console.log(`DFY71155_CONTRACT_ADDRESS: ${DFY1155Contract.address}`);

    implementtationAddress = await hre.upgrades.erc1967.getImplementationAddress(DFY1155Contract.address);
    console.log(`${DFY1155Artifact.contractName} implementation address: ${implementtationAddress}`);

    console.log("===========================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });