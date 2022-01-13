require('@nomiclabs/hardhat-ethers');
require('@openzeppelin/hardhat-upgrades');

const hre = require('hardhat');

const { Proxies } = require('./.deployment_data.json');
const proxies = Proxies.Dev2;

const EvaluationProxyAddr     = proxies.EVALUATION_ADDRESS;

// const EvaluationBuildName = "HardEvaluation";
const EvaluationBuildNameV1   = "HardEvaluation";
const EvaluationBuildNameV2   = "HardEvaluation";

const decimals          = 10**18;

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("============================================================");
    console.log("Upgrading contracts with the account:", deployer.address);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================");

    const EvaluationFactoryV1     = await hre.ethers.getContractFactory(EvaluationBuildNameV1);
    const EvaluationArtifactV1    = await hre.artifacts.readArtifact(EvaluationBuildNameV1);
    const EvaluationContractV1    = EvaluationFactoryV1.attach(EvaluationProxyAddr);

    const EvaluationImplV1        = await hre.upgrades.erc1967.getImplementationAddress(EvaluationContractV1.address);

    console.log(`Upgrading ${EvaluationArtifactV1.contractName} at proxy: ${EvaluationContractV1.address}`);
    console.log(`Current implementation address: ${EvaluationImplV1}`);

    const EvaluationFactoryV2      = await hre.ethers.getContractFactory(EvaluationBuildNameV2);
    const EvaluationArtifactV2     = await hre.artifacts.readArtifact(EvaluationBuildNameV2);
    
    const EvaluationContractV2     = await hre.upgrades.upgradeProxy(EvaluationProxyAddr, EvaluationFactoryV2);
    
    await EvaluationContractV2.deployed();
    
    const EvaluationImplV2         = await hre.upgrades.erc1967.getImplementationAddress(EvaluationContractV2.address);

    console.log(`${EvaluationArtifactV2.contractName} deployed to: ${EvaluationContractV2.address}`);
    console.log(`New implementation Address: ${EvaluationImplV2}`);

    console.log("============================================================\n\r");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });