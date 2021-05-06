const hre = require("hardhat");

async function main() {
    const GhostTokenContract = await hre.ethers.getContractFactory("GhostToken");
    const MasterChefContract = await hre.ethers.getContractFactory("MasterChef");

    const devAddress = "0xC80f259a56cD9a8F25D6Ee6F6c84dC5bD086eCcB";

    // Deploy GhostToken
    const ghostToken = await GhostTokenContract.deploy();
    console.log("GhostToken deployed to:", ghostToken.address);

    await new Promise(r => setTimeout(r, 10000));

    // Verify GhostToken
    await hre.run("verify:verify", {
        address: ghostToken.address
    });

    // Deploy MasterChef
    let ghostPerBlock = ethers.utils.parseEther('10');
    const masterChef = await MasterChefContract.deploy(ghostToken.address, devAddress, ghostPerBlock, 1, 1);
    await masterChef.deployed();
    console.log("MasterChef deployed to:", masterChef.address);

    // Verify MasterChef
    await hre.run("verify:verify", {
        address: masterChef.address,
        constructorArguments: [
            ghostToken.address,
            devAddress,
            ghostPerBlock,
            1,
            1
        ],
    });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
