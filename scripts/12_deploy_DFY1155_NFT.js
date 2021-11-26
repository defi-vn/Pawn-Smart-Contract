require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { PawnConfig } = require('./.deployment_data.json');

const DFY1155BuildName = "contracts/pawn/nft_evaluation/implement/DFY_1155.sol:DFY_1155";

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
    const DFY1155Contract = await hre.upgrades.deployProxy(DFY1155Factory,["quang","abc","https://defiforyou.mypinata.cloud/ipfs/","rb",0,"0x10D3c9215E122474782c0892954398f8Eaa099CA"],proxyType);

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