const hre = require("hardhat");

async function main() {
    const GhostTokenContract = await hre.ethers.getContractFactory("GhostToken");
    const RouterAdapterContract = await hre.ethers.getContractFactory("HyperswapRouterAdapter");

    const routerAddress = "0xcde540d7eafe93ac5fe6233bee57e1270d3e330f";
    const factoryAddress = "0x01bf7c66c6bd861915cdaae475042d3c4bae16a7";

    // Attach GhostToken
    const ghostToken = await GhostTokenContract.attach("0xEdA4231bd020224E4feCf7b3713f570E4F306dc8");

    // Deploy adapter
    const routerAdapter = await RouterAdapterContract.deploy(ghostToken.address, routerAddress, factoryAddress);
    await routerAdapter.deployed();
    console.log("Adapter deployed to:", routerAdapter.address);

    await new Promise(r => setTimeout(r, 5000));

    // Verify Adapter
    await hre.run("verify:verify", {
        address: routerAdapter.address,
        constructorArguments: [
            ghostToken.address,
            routerAddress,
            factoryAddress
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
