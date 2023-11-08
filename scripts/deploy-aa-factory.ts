import {ethers} from "hardhat";

async function main() {
    console.log(`Running deploy script for the TokenPocketAAFactory contract`);
    let deployTime = new Date().valueOf();
    const accountImplementation = "0xC9B6dFDC54Dd45958956fc65143a7B107CbC79Fe";
    const factory = await ethers.deployContract("TokenPocketAAFactory", [accountImplementation]);

    await factory.waitForDeployment();

    console.log(
        `TokenPocketAAFactory deployed to ${factory.target}`
    );
    console.log(`✨ TokenPocketAAFactory done in ${(new Date().valueOf() - deployTime) / 1000}s.`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
