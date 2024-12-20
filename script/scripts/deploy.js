async function main() {
    const SimpleCTF = await ethers.getContractFactory("SimpleCTF");
    const ctf = await SimpleCTF.deploy();
    await ctf.waitForDeployment(); // или по-другому await ctf.deployed();

    console.log(`CTF task deployed to: ${ctf.address}`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
