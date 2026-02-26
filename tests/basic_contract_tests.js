const { expect } = require("chai");
const { ethers } = require("hardhat");

contractName = "EnergyTrading";

describe("EnergyTrading basic tests", function () {
    let EnergyTrading, contract, recorder, prosumer1, prosumer2, prosumer3;
    const totalProsumers = 3;

    beforeEach(async function () {
        [recorder, prosumer1, prosumer2, prosumer3] = await ethers.getSigners();
        EnergyTrading = await ethers.getContractFactory(contractName);
        contract = await EnergyTrading.deploy(recorder.address);
    });

    it("Should deploy with correct recorder address", async function () {
        expect(await contract.getRecorder()).to.equal(recorder.address);
    });

    it("Should allow prosumers to register and have correct initial state", async function () {
        await contract.connect(prosumer1).registerProsumer();
        const prosumerData = await contract.prosumers(prosumer1.address);
        expect(prosumerData.prosumerEnergyStat).to.equal(0);
        expect(prosumerData.prosumerBalance).to.equal(0);
        expect(prosumerData.isMember).to.equal(true);
    });

    it("Should allow a registered prosumer to deposit Ethers", async function () {
        await contract.connect(prosumer1).registerProsumer();
        await contract.connect(prosumer1).deposit({ value: ethers.parseEther("1") });
        const prosumerData = await contract.prosumers(prosumer1.address);
        expect(prosumerData.prosumerBalance).to.equal(ethers.parseEther("1"));
    });

    it("Should allow recorder to update energy status of prosumers", async function () {
        await contract.connect(prosumer1).registerProsumer();
        await contract.connect(prosumer2).registerProsumer();
        await contract.connect(recorder).updateEnergyStatus(prosumer1.address, -1);
        await contract.connect(recorder).updateEnergyStatus(prosumer2.address, 1);
        const prosumer1Data = await contract.prosumers(prosumer1.address);
        const prosumer2Data = await contract.prosumers(prosumer2.address);
        expect(prosumer1Data.prosumerEnergyStat).to.equal(-1);
        expect(prosumer2Data.prosumerEnergyStat).to.equal(1);
    });
});

