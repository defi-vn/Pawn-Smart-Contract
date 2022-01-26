require('@nomiclabs/hardhat-ethers');
const hre = require('hardhat');

const envKey = "Live";
const datafilePath = "./scripts/live-4.1/";

const datafileName = ".deployment_data.json";
const deploymentInfo = require('./' + datafileName);
const dataFileRelativePath = datafilePath + datafileName;

// const { PawnConfig, Proxies, Exchanges } = require('./.deployment_data_prelive.json');
const proxiesEnv = deploymentInfo.Proxies[envKey];
const Exchanges = deploymentInfo.Exchanges;

const ContractBuildName = "Exchange";
const ContractJsonKey = "EXCHANGE_CONTRACT_ADDRESS";
const ContractProxyAddr = proxiesEnv[ContractJsonKey];

const decimals          = 10**18;

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("===================================\n\r");
    console.log("Start time: ", Date(Date.now()));
    console.log(`Initialize contracts with the account: ${deployer.address}`);  
    console.log("Account balance: ", ((await deployer.getBalance()) / decimals).toString());
    console.log("===================================\n\r");

    const ContractFactory = await hre.ethers.getContractFactory(ContractBuildName);
    const ContractArtifact  = await hre.artifacts.readArtifact(ContractBuildName);
    const DeployedContract  = ContractFactory.attach(ContractProxyAddr);

    console.log(`Initializing ${ContractArtifact.contractName}...`);

    console.log(`Setting Exchange addresses...`);
    for await (let exchange of Exchanges) {
        await DeployedContract.setCryptoExchange(exchange.Address, exchange.Exchange);
        console.log(`\tExchange address for ${exchange.Name}: ${exchange.Exchange}`);
    }

    console.log(`Completed at ${Date(Date.now())}`);
    console.log("===========================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });