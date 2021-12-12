require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { Proxies } = require('./.deployment_data_prelive.json');
const proxiesEnv = Proxies.Prelive;

const EvaluationBuildName = "HardEvaluation";

const HubBuildName = "Hub";
const HubProxy = proxiesEnv.HUB_CONTRACT_ADDRESS;

const proxyType = { kind: "uups" };

const decimals      = 10**18;

async function main() {
    const[deployer] = await hre.ethers.getSigners();

    console.log("==============================================\n\r");
    console.log("Start time: ", Date(Date.now()));
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance: ", ((await deployer.getBalance()) / decimals).toString());
    console.log("=================================\n\r");

    const EvaluationFactory = await hre.ethers.getContractFactory(EvaluationBuildName);
    const EvaluationArtifact = await hre.artifacts.readArtifact(EvaluationBuildName);
    const EvaluationContract = await hre.upgrades.deployProxy(EvaluationFactory,[HubProxy], proxyType);

    await EvaluationContract.deployed();
    const signature = await EvaluationContract.signature();

    console.log(`EVALUATION_CONTRACT_ADDRESS: \x1b[36m${EvaluationContract.address}\x1b[0m`);
    console.log(`Signature: \x1b[36m${signature}\x1b[0m`);

    implementtationAddress = await hre.upgrades.erc1967.getImplementationAddress(EvaluationContract.address);
    console.log(`${EvaluationArtifact.contractName} implementation address: ${implementtationAddress}`);

    const HubFactory = await hre.ethers.getContractFactory(HubBuildName);
    const HubArtifact = await hre.artifacts.readArtifact(HubBuildName);
    const HubContract = HubFactory.attach(HubProxy);

    console.log(`HUB_ADDRESS: \x1b[31m${HubContract.address}\x1b[0m`);
    console.log(`Registering \x1b[36m${EvaluationArtifact.contractName}\x1b[0m to \x1b[31m${HubArtifact.contractName}\x1b[0m...`);

    await HubContract.registerContract(signature,EvaluationContract.address,EvaluationArtifact.contractName);
    console.log(`Completed at ${Date(Date.now())}`);
    
    console.log("===========================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });