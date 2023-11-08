import {ethers} from "hardhat";

async function main() {
    console.log(`Running deploy script for the TokenPocketAccount contract`);
    let deployTime = new Date().valueOf();
    const entryPoint = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";
    const account = await ethers.deployContract("TokenPocketAccount", [entryPoint]);

    await account.waitForDeployment();

    console.log(
        `TokenPocketAccount deployed to ${account.target}`
    );
    console.log(`✨ TokenPocketAccount done in ${(new Date().valueOf() - deployTime) / 1000}s.`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
