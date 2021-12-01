require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { PawnConfig } = require('./.deployment_data.json');

const Collection1155BuildName = "contracts/pawn/nft_evaluation/implement/DFY_Hard_1155_Collection.sol:DFY_Hard_1155_Collection";

const proxyType = { kind: "uups" };

const decimals      = 10**18;

async function main() {
    const[deployer] = await hre.ethers.getSigners();

    console.log("==============================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance: ", ((await deployer.getBalance()) / decimals).toString());
    console.log("=================================\n\r");

    const Collection1155Factory = await hre.ethers.getContractFactory(Collection1155BuildName);
    const Collection1155Artifact = await hre.artifacts.readArtifact(Collection1155BuildName);
    const Collection1155Contract = await hre.upgrades.deployProxy(Collection1155Factory,["0x703204148eEa1a70b28BAAFa99f4d14bB7FA8Ea9"],proxyType);

    await Collection1155Contract.deployed();

    console.log(`COLLECTION_1155_CONTRACT_ADDRESS: ${Collection1155Contract.address}`);

    implementtationAddress = await hre.upgrades.erc1967.getImplementationAddress(Collection1155Contract.address);
    console.log(`${Collection1155Artifact.contractName} implementation address: ${implementtationAddress}`);

    console.log("===========================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });