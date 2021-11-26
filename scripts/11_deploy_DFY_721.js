require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { PawnConfig } = require('./.deployment_data.json');

const DFY721BuildName = "contracts/pawn/nft_evaluation/implement/DFY_721.sol:DFY_721";

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
    const DFY721Contract = await hre.upgrades.deployProxy(DFY721Factory,["quang","abc","https://defiforyou.mypinata.cloud/ipfs/","rb",0,"0x10D3c9215E122474782c0892954398f8Eaa099CA"],proxyType);

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