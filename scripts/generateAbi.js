const hre = require('hardhat');
const fs = require('fs');
const path = process.cwd() + '/abi';

async function exportABI(contractName){
    const artifact = await hre.artifacts.readArtifact(contractName);
    console.log(JSON.stringify(artifact.abi));
    try {
        fs.writeFileSync(`${path}/${contractName}.json`, JSON.stringify(artifact.abi));
        console.log(`File stored successfully at  -, ${path}/${contractName}.json`);
      } catch (err) {
        console.error(err);
      }
}

exportABI('UniV2Adapter');