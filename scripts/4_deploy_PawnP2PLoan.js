require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { Proxies, PawnConfig } = require('./.deployment_data.json');
const proxies = Proxies.Staging;

const PawnP2PLoanBuildName = "PawnP2PLoanContract";
const PawnProxyAddr = proxies.PAWN_CONTRACT_ADDRESS;

const proxyType = { kind: "uups" };

const decimals      = 10**18;

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    
    console.log("============================================================\n\r");
    console.log("Deploying contracts with the account:", deployer.address);  
    console.log("Account balance:", ((await deployer.getBalance())/decimals).toString());
    console.log("============================================================\n\r");

    const PawnP2PLoanFactory    = await hre.ethers.getContractFactory(PawnP2PLoanBuildName);
    const PawnP2PLoanArtifact   = await hre.artifacts.readArtifact(PawnP2PLoanBuildName);

    const PawnP2PLoanContract   = await hre.upgrades.deployProxy(PawnP2PLoanFactory, [PawnConfig.ZOOM], proxyType ?? "");

    await PawnP2PLoanContract.deployed();

    console.log(`PAWN_P2PLOAN_CONTRACT_ADDRESS: ${PawnP2PLoanContract.address}`);

    implementationAddress = await hre.upgrades.erc1967.getImplementationAddress(PawnP2PLoanContract.address);
    console.log(`${PawnP2PLoanArtifact.contractName} implementation address: ${implementationAddress}`);

    console.log("============================================================\n\r");

    console.log(`Setting Pawn contract address...`);
    await PawnP2PLoanContract.setPawnContract(PawnProxyAddr);
    console.log(`Pawn contract set at address: ${PawnProxyAddr}`);

    console.log("============================================================\n\r");
}
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });