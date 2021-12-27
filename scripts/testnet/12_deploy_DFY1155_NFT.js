require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { Proxies } = require('./.deployment_data.json');

const DFY1155BuildName = "DFYHard1155";

const Evaluation = Proxies.Dev1.EVALUATION_ADDRESS;

const decimals      = 10**18;

async function main() {
    const[deployer] = await hre.ethers.getSigners();

    console.log("==============================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance: ", ((await deployer.getBalance()) / decimals).toString());
    console.log("=================================\n\r");

    const DFY1155Factory = await hre.ethers.getContractFactory(DFY1155BuildName);
    const DFY1155Artifact = await hre.artifacts.readArtifact(DFY1155BuildName);
    const DFY1155Contract = await DFY1155Factory.deploy("test1155","test1155","abc",0,Evaluation,"0x10D3c9215E122474782c0892954398f8Eaa099CA");

    await DFY1155Contract.deployed();

    

   
    console.log(`${DFY1155Artifact.contractName} implementation address: ${DFY1155Contract.address}`);

    console.log("===========================\n\r");

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });