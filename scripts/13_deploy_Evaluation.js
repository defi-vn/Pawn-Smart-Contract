require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { Proxies } = require('./.deployment_data.json');

const EvaluationBuildName = "contracts/pawn/nft_evaluation/implement/Hard_Evaluation.sol:Hard_Evaluation";

const HubBuildName = "Hub";
const HubProxy = Proxies.Dev1.HUB_CONTRACT_ADDRESS;
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
    const EvaluationContract = await hre.upgrades.deployProxy(EvaluationFactory,[HubProxy],proxyType);

    await EvaluationContract.deployed();
    const signature = await EvaluationContract.signature();

    console.log(`EVALUATION_CONTRACT_ADDRESS: ${EvaluationContract.address}`);
    console.log(`Signature: \x1b[36m${signature}\x1b[0m`);

    implementtationAddress = await hre.upgrades.erc1967.getImplementationAddress(EvaluationContract.address);
    console.log(`${EvaluationArtifact.contractName} implementation address: ${implementtationAddress}`);

    const HubFactory = await hre.ethers.getContractFactory(HubBuildName);
    const HubArtifact = await hre.artifacts.readArtifact(HubBuildName);
    const HubContract = HubFactory.attach(HubProxy);

    console.log(`HUB_ADDRESS: \x1b[31m${HubContract.address}\x1b[0m`);
    console.log(`Registering \x1b[36m${EvaluationArtifact.contractName}\x1b[0m to \x1b[31m${HubArtifact.contractName}\x1b[0m...`);

    await HubContract.registerContract(signature,EvaluationContract.address,EvaluationArtifact.contractName);
    
    console.log("===========================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });