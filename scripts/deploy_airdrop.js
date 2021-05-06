const hre = require("hardhat");

async function main() {
    const GhostTokenContract = await hre.ethers.getContractFactory("GhostToken");
    const GhostAirdropContract = await hre.ethers.getContractFactory("GhostAirdrop");
    const GhostTokenAddress = "0xEdA4231bd020224E4feCf7b3713f570E4F306dc8";

    // Attach GhostToken
    const ghostToken = await GhostTokenContract.attach(GhostTokenAddress);

    // Deploy GhostAirdrop
    const airdrop = await GhostAirdropContract.deploy();
    await airdrop.deployed();
    console.log("GhostAirdrop deployed to:", airdrop.address);

    await new Promise(r => setTimeout(r, 5000));

    // Verify GhostAirdrop
    await hre.run("verify:verify", {
        address: airdrop.address
    });

    console.log("GhostAirdrop verified");

    await airdrop.setToken(ghostToken.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
