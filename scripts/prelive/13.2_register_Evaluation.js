require('@nomiclabs/hardhat-ethers');

const { Proxies } = require('./.deployment_data_prelive.json');
const proxiesEnv = Proxies.Prelive;

const HardEvaluationProxyAddr = proxiesEnv.HARD_EVAL_CONTRACT_ADDRESS;
const HardEvaluationBuildName = "HardEvaluation";

const HubProxy = proxiesEnv.HUB_CONTRACT_ADDRESS;
const HubBuildName = "Hub";

const decimals      = 10**18;

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    
    console.log("============================================================\n\r");
    console.log("Start time: ", Date(Date.now()));
    console.log("Registering contract with the account:", deployer.address);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================\n\r");

    const HardEvaluationFactory     = await hre.ethers.getContractFactory(HardEvaluationBuildName);
    const HardEvaluationArtifact    = await hre.artifacts.readArtifact(HardEvaluationBuildName);
    const HardEvaluationContract    = HardEvaluationFactory.attach(HardEvaluationProxyAddr);
    
    const signature         = await HardEvaluationContract.signature();
    const HardEvaluationImpl = await hre.upgrades.erc1967.getImplementationAddress(HardEvaluationContract.address);

    console.log(`\x1b[36m${HardEvaluationArtifact.contractName}\x1b[0m is deployed at: \x1b[36m${HardEvaluationContract.address}\x1b[0m`);
    console.log(`Implementation address: \x1b[36m${HardEvaluationImpl}\x1b[0m`);
    console.log(`Contract SIGNATURE: \x1b[36m${signature}\x1b[0m\n\r`);

    const HubFactory   = await hre.ethers.getContractFactory(HubBuildName);
    const HubArtifact  = await hre.artifacts.readArtifact(HubBuildName);
    const HubContract  = HubFactory.attach(HubProxy);

    console.log(`HUB_ADDRESS: \x1b[31m${HubContract.address}\x1b[0m`);
    console.log(`Registering \x1b[36m${HardEvaluationArtifact.contractName}\x1b[0m to ${HubArtifact.contractName}...`);
    
    await HubContract.registerContract(signature, HardEvaluationContract.address, HardEvaluationArtifact.contractName);
    
    console.log(`Completed at ${Date(Date.now())}`);

    console.log("============================================================\n\r");
}
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });