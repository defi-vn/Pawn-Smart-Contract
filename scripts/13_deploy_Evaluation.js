require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { PawnConfig } = require('./.deployment_data.json');

const EvaluationBuildName = "contracts/pawn/nft_evaluation/implement/Hard_Evaluation.sol:Hard_Evaluation";

const proxyType = { kind: "uups" };

const decimals      = 10**18;

async function main() {
    const[deployer] = await hre.ethers.getSigners();

    console.log("==============================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance: ", ((await deployer.getBalance()) / decimals).toString());
    console.log("=================================\n\r");

    const EvaluationFactory = await hre.ethers.getContractFactory(EvaluationBuildName);
    const EvaluationArtifact = await hre.artifacts.readArtifact(EvaluationBuildName);
    const EvaluationContract = await hre.upgrades.deployProxy(EvaluationFactory,["0xd247F1f6455E747d9854282115bd6D1CB9b39206"],proxyType);

    await EvaluationContract.deployed();

    console.log(`EVALUATION_CONTRACT_ADDRESS: ${EvaluationContract.address}`);

    implementtationAddress = await hre.upgrades.erc1967.getImplementationAddress(EvaluationContract.address);
    console.log(`${EvaluationArtifact.contractName} implementation address: ${implementtationAddress}`);

    console.log("===========================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });