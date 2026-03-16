const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Standalone Coordination Test", function () {

    it("standalone test: [8,-1,7,7,6,-1] -> [6,0,7,7,6,0]", async function () {
        let recorder;
        let prosumers;

        [recorder, ...prosumers] = await ethers.getSigners();

        const NUM_PROSUMERS = 6;
        prosumers = prosumers.slice(0, NUM_PROSUMERS);

        const EnergyTrading = await ethers.getContractFactory("EnergyTrading");
        const contract = await EnergyTrading.deploy(recorder.address);
        const connectedRecorder = await contract.connect(recorder);

        const STARTING_ETHER = ethers.parseEther("5000");

        for (let i = 0; i < NUM_PROSUMERS; ++i) {
            await contract.connect(prosumers[i]).registerProsumer();
            await contract.connect(prosumers[i]).deposit({ value: STARTING_ETHER });
        }

        const before = [8, -1, 7, 7, 6, -1];
        const expectedAfter = [6, 0, 7, 7, 6, 0];

        async function getActualEnergyArray() {
            const actual = [];
            for (let i = 0; i < NUM_PROSUMERS; ++i) {
                const prosumerData = await contract.prosumers(prosumers[i].address);
                actual.push(Number(prosumerData.prosumerEnergyStat));
            }
            return actual;
        }

        for (let i = 0; i < NUM_PROSUMERS; ++i) {
            await connectedRecorder.updateEnergyStatus(prosumers[i].address, before[i]);
        }

        const actualBefore = await getActualEnergyArray();
        console.log("Before coordination:", actualBefore);

        await connectedRecorder.coordinateTrading();

        const actualAfter = await getActualEnergyArray();
        console.log("After coordination:", actualAfter);

        expect(actualAfter).to.deep.equal(expectedAfter);
    });

    it("standalone test: [1,1,1,-5,0,-4] -> [0,0,0,-3,0,-3]", async function () {
        let recorder;
        let prosumers;

        [recorder, ...prosumers] = await ethers.getSigners();

        const NUM_PROSUMERS = 6;
        prosumers = prosumers.slice(0, NUM_PROSUMERS);

        const EnergyTrading = await ethers.getContractFactory("EnergyTrading");
        const contract = await EnergyTrading.deploy(recorder.address);
        const connectedRecorder = await contract.connect(recorder);

        const STARTING_ETHER = ethers.parseEther("5000");

        for (let i = 0; i < NUM_PROSUMERS; ++i) {
            await contract.connect(prosumers[i]).registerProsumer();
            await contract.connect(prosumers[i]).deposit({ value: STARTING_ETHER });
        }

        const before = [1, 1, 1, -5, 0, -4];
        const expectedAfter = [0, 0, 0, -3, 0, -3];

        async function getActualEnergyArray() {
            const actual = [];
            for (let i = 0; i < NUM_PROSUMERS; ++i) {
                const prosumerData = await contract.prosumers(prosumers[i].address);
                actual.push(Number(prosumerData.prosumerEnergyStat));
            }
            return actual;
        }

        for (let i = 0; i < NUM_PROSUMERS; ++i) {
            await connectedRecorder.updateEnergyStatus(prosumers[i].address, before[i]);
        }

        const actualBefore = await getActualEnergyArray();
        console.log("Before coordination:", actualBefore);

        await connectedRecorder.coordinateTrading();

        const actualAfter = await getActualEnergyArray();
        console.log("After coordination:", actualAfter);

        expect(actualAfter).to.deep.equal(expectedAfter);
    });

});