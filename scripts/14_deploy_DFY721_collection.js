require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { PawnConfig } = require('./.deployment_data.json');

const Collection721BuildName = "contracts/pawn/nft_evaluation/implement/DFY_721_Collection.sol:DFY_721_Collection";

const proxyType = { kind: "uups" };

const decimals      = 10**18;

async function main() {
    const[deployer] = await hre.ethers.getSigners();

    console.log("==============================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance: ", ((await deployer.getBalance()) / decimals).toString());
    console.log("=================================\n\r");

    const Collection721Factory = await hre.ethers.getContractFactory(Collection721BuildName);
    const Collection721Artifact = await hre.artifacts.readArtifact(Collection721BuildName);
    const Collection721Contract = await hre.upgrades.deployProxy(Collection721Factory,["quang","abc","https://defiforyou.mypinata.cloud/ipfs/","0xd247F1f6455E747d9854282115bd6D1CB9b39206"],proxyType);

    await Collection721Contract.deployed();

    console.log(`COLLECTION_721_CONTRACT_ADDRESS: ${Collection721Contract.address}`);

    implementtationAddress = await hre.upgrades.erc1967.getImplementationAddress(Collection721Contract.address);
    console.log(`${Collection721Artifact.contractName} implementation address: ${implementtationAddress}`);

    console.log("===========================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });