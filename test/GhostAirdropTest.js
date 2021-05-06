const {expect} = require("chai");

describe("GhostAirdrop", function () {
    let tokenContract;
    let token;
    let airdropContract;
    let airdrop;
    let owner;
    let addr1;
    let addr2;
    let addr3;
    let addrs;
    let airdropAmount;
    let wallets1;
    let wallets2;
    let wallets3;

    // You can change these values to "stress test"
    let nWallets1 = 14;
    let nWallets2 = 23;
    let nWallets3 = 24;

    beforeEach(async function () {
        [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();
        tokenContract = await ethers.getContractFactory("GhostToken");
        airdropContract = await ethers.getContractFactory("GhostAirdrop");

        // Deploy contracts
        token = await tokenContract.deploy();
        airdrop = await airdropContract.deploy();

        airdropAmount = ethers.utils.parseEther('1000000');

        await token.prepareAirdrop(airdrop.address, airdropAmount);
        await airdrop.setToken(token.address);

        wallets1 = createWallets(nWallets1);
        wallets2 = createWallets(nWallets2);
        wallets3 = createWallets(nWallets3);

        // whitelist signers
        wallets1.push(owner.address);
        wallets2.push(addr1.address);
        wallets3.push(addr3.address);
        nWallets1++;
        nWallets2++;
        nWallets3++;

        await airdrop.whitelistAddrs(wallets1, 2);
        await airdrop.whitelistAddrs(wallets2, 3);
        await airdrop.whitelistAddrs(wallets3, 4);
    });


    it("Should claim right amount", async function () {
        await airdrop.closeWhitelist();
        await airdrop.startAirdrop();

        let claimable = await airdrop.claimable();

        let expectedClaimable = airdropAmount.div((nWallets1 * 2) + (nWallets2 * 3) + (nWallets3 * 4));
        expect(claimable).to.equal(expectedClaimable);

        await airdrop.connect(owner).claim();
        await airdrop.connect(addr1).claim();
        await airdrop.connect(addr3).claim();

        let claimed1 = claimable.mul(2);
        let claimed2 = claimable.mul(3);
        let claimed3 = claimable.mul(4);

        let balance1 = await token.balanceOf(owner.address);
        let balance2 = await token.balanceOf(addr1.address);
        let balance3 = await token.balanceOf(addr3.address);

        expect(balance1).to.equal(claimed1.sub(claimed1.div(25)));
        expect(balance2).to.equal(claimed2.sub(claimed2.div(25)));
        expect(balance3).to.equal(claimed3.sub(claimed3.div(25)));

        let totalClaimable = claimable.mul((nWallets1 * 2) + (nWallets2 * 3) + (nWallets3 * 4));
        expect(totalClaimable.lte(airdropAmount)).to.be.true;
    });

    it("Should have ghost in airdrop balance", async function() {
        let balanceAirdrop = await token.balanceOf(airdrop.address);
        expect(balanceAirdrop).to.equal(airdropAmount);
    });

    it("Shouldn't be allow to whitelist with bad weight", async function() {
        await expect(
            airdrop.connect(owner).whitelistAddr(addr2.address, 5)
        ).to.be.revertedWith("GhostAirdrop::whitelistAddr: wrong weight (2-4)");
    });

    it("Shouldn't be allow to whitelist if closed", async function() {
        await airdrop.closeWhitelist();
        await expect(
            airdrop.connect(owner).whitelistAddr(addr2.address, 2)
        ).to.be.revertedWith("GhostAirdrop: whitelist is closed");
    });

    it("Shouldn't claim if not started", async function() {
        await airdrop.closeWhitelist();

        await expect(
            airdrop.connect(owner).claim()
        ).to.be.revertedWith("GhostAirdrop::claim: airdrop must be started");
    });

    it("Shouldn't claim if not whitelisted", async function() {
        await airdrop.closeWhitelist();
        await airdrop.startAirdrop();

        await expect(
            airdrop.connect(addr2).claim()
        ).to.be.revertedWith("GhostAirdrop::claim: you are not whitelisted");
    });

    it("Shouldn't claim twice", async function() {
        await airdrop.closeWhitelist();
        await airdrop.startAirdrop();

        await airdrop.connect(owner).claim();

        await expect(
            airdrop.connect(owner).claim()
        ).to.be.revertedWith("GhostAirdrop::claim: you already claimed your tokens");
    });
});

/*
 * Generate an array (length = number) of random addresses
 */
function createWallets(number) {
    let wallets = [];
    for (i = 0; i < number; i++) {
        let wallet = ethers.Wallet.createRandom();
        wallets.push(wallet.address);
    }
    return wallets;
}
