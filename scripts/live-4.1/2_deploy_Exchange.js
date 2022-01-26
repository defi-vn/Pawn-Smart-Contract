require('@nomiclabs/hardhat-ethers');
const hre = require('hardhat');
const fs = require("fs");

const envKey = "Live";
const datafilePath = "./scripts/live-4.1/";

const datafileName = ".deployment_data.json";
const deploymentInfo = require('./' + datafileName);
const dataFileRelativePath = datafilePath + datafileName;

const proxyType = { kind: "uups" };
const decimals      = 10**18;

const proxiesEnv = deploymentInfo.Proxies[envKey];

const HubBuildName = "Hub";
const HubProxy = proxiesEnv.HUB_ADDRESS;

const ContractBuildName = "Exchange";
const ContractJsonKey = "EXCHANGE_CONTRACT_ADDRESS";
const ContractSigKey = "EXCHANGE";

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("===================================\n\r");
    console.log("Start time: ", Date(Date.now()));
    console.log("Deploying contracts with the account: ", deployer.address);
    console.log("Account balance: ", ((await deployer.getBalance()) / decimals).toString());
    console.log("===================================\n\r");

    const ContractFactory   = await hre.ethers.getContractFactory(ContractBuildName);
    const ContractArtifact  = await hre.artifacts.readArtifact(ContractBuildName);
    const DeployedContract  = await hre.upgrades.deployProxy(ContractFactory, [HubProxy], proxyType);

    await DeployedContract.deployed();
    const signature = await DeployedContract.signature();

    console.log(`${ContractJsonKey}: \x1b[36m${DeployedContract.address}\x1b[0m`);
    console.log(`Signature: \x1b[36m${signature}\x1b[0m`);

    const Implementation = await hre.upgrades.erc1967.getImplementationAddress(DeployedContract.address);
    console.log(`${ContractArtifact.contractName} implementation address: ${Implementation}`);
    
    const HubFactory = await hre.ethers.getContractFactory(HubBuildName);
    const HubArtifact = await hre.artifacts.readArtifact(HubBuildName);
    const HubContract = HubFactory.attach(HubProxy);

    console.log(`HUB_ADDRESS: \x1b[31m${HubContract.address}\x1b[0m`);
    console.log(`Registering \x1b[36m${ContractArtifact.contractName}\x1b[0m to \x1b[31m${HubArtifact.contractName}\x1b[0m...`);

    await HubContract.registerContract(signature, DeployedContract.address, ContractArtifact.contractName);

    // Write the result to deployment data file
    deploymentInfo.Proxies[envKey][ContractJsonKey] = DeployedContract.address;
    deploymentInfo.Implementations[envKey][ContractJsonKey] = Implementation;
    deploymentInfo.Signature[envKey][ContractSigKey] = signature;
    fs.writeFile(dataFileRelativePath, JSON.stringify(deploymentInfo, null, "\t"), err => {
    if (err)
        console.log("Error when trying to write to deployment data file.", err);
    else
        console.log("Information has been written to deployment data file.");
    });

    console.log(`Completed at ${Date(Date.now())}`);
    console.log("===========================\n\r");

}

main()
    .then(() => {})
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });