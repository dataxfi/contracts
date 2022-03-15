import {ethers} from "hardhat";
import {BN, expectRevert , expectRevert } from "@openzeppelin/test-helpers";
import "mocha";

describe('FeeCollector' , async() {

    beforeEach('deploy the contracts with params',async () => {
      const [newFeeCollector ,owner] = await ethers.getSigners();
      const FeeCollector = await ethers.getContractFactory("CoomunityFeeCollector");  
    });
    it("init the contract with params", async () => { 
        const [] = await

    });




});