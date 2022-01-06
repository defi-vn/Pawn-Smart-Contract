require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { Proxies } = require('./.deployment_data.json');

const DFY721BuildName = "DFYHard721";
const Evaluation = Proxies.Dev2.EVALUATION_ADDRESS;

const decimals      = 10**18;

async function main() {
    const[deployer] = await hre.ethers.getSigners();

    console.log("==============================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance: ", ((await deployer.getBalance()) / decimals).toString());
    console.log("=================================\n\r");

    const DFY721Factory = await hre.ethers.getContractFactory(DFY721BuildName);
    const DFY721Artifact = await hre.artifacts.readArtifact(DFY721BuildName);
    
    const DFY721Contract = await DFY721Factory.deploy("DF4U","DF4U","0x10D3c9215E122474782c0892954398f8Eaa099CA","aa0","0xB17cbc8967715aE90507E3E231Af741a29361114",Evaluation);

    await DFY721Contract.deployed();

    console.log(`${DFY721Artifact.contractName} implementation address: ${DFY721Contract.address}`);

    console.log("===========================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });