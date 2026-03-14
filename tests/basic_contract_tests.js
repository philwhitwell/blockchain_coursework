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


describe("withdraw() unit tests", function () {
    let EnergyTrading, contract, recorder, prosumer1, prosumer2, prosumer3;

    beforeEach(async function () {
        [recorder, prosumer1] = await ethers.getSigners();
        EnergyTrading = await ethers.getContractFactory(contractName);
        contract = await EnergyTrading.deploy(recorder.address);
    });

    it("Withdraw when energy surplus and sufficient balance", async function () {
        const intiailBalance = ethers.parseEther("10");
        await contract.connect(prosumer1).registerProsumer();
        await contract.connect(prosumer1).deposit(
            { value: intiailBalance })
        await contract.connect(recorder).updateEnergyStatus(
            prosumer1.address, 1);
        
        const withdrawAmount = ethers.parseEther("3");
        await expect(
            contract.connect(prosumer1).withdraw(withdrawAmount)
        ).to.changeEtherBalance(prosumer1, withdrawAmount);

        const expectedBalance = intiailBalance - withdrawAmount;
        const prosumerData = await contract.prosumers(prosumer1.address);
        expect(prosumerData.prosumerBalance).to.equal(expectedBalance);
    });

    it("Withdraw whenno deficit and suprlut, sufficient balance", async function () {
        const ether = ethers.parseEther("10");
        await contract.connect(prosumer1).registerProsumer();
        await contract.connect(prosumer1).deposit(
            { value: ether })
        
        await expect(
            contract.connect(prosumer1).withdraw(ether)
        ).to.changeEtherBalance(prosumer1, ether);

        const prosumerData = await contract.prosumers(prosumer1.address);
        expect(prosumerData.prosumerBalance).to.equal(0);
    });

    it("Don't allow unregistered prosumerss", async function () {
        await expect(
            contract.connect(prosumer1).withdraw(100)
        ).to.be.revertedWith("Prosumer not registered");
    });

    it("Don't allow attempt to withdraw 0", async function () {
        await contract.connect(prosumer1).registerProsumer();
        await contract.connect(prosumer1).deposit(
            { value: ethers.parseEther("1") }
        )        
        await expect(
            contract.connect(prosumer1).withdraw(0)
        ).to.be.revertedWith("Amount must be greater than 0");
    });

    it("Don't allow attempt to withdraw with energy deficit", async function () {
        await contract.connect(prosumer1).registerProsumer();
        await contract.connect(prosumer1).deposit(
            { value: ethers.parseEther("10") })
        await contract.connect(recorder).updateEnergyStatus(
            prosumer1.address, -1);
        
        await expect(
            contract.connect(prosumer1).withdraw(2)
        ).to.be.revertedWith("Cannot withdraw while in energy deficit");
    });

    it("Don't allow attempt to withdraw with insufficient blaance", async function () {
        await contract.connect(prosumer1).registerProsumer();
        await contract.connect(prosumer1).deposit(
            { value: ethers.parseEther("1") })
        await contract.connect(recorder).updateEnergyStatus(
            prosumer1.address, 5);
        
        await expect(
            contract.connect(prosumer1).withdraw(
                ethers.parseEther("2"))
        ).to.be.revertedWith("Insufficient balance");
    });
});


describe("updateEnergyPrice() integration testss", function () {
    it("Net Energy Prices for 12/12/2012 7:00 - 21:00", async function () {
        // Hardhat creates max 20 signers,
        // so 1 recorder, 19 prosumers.
        let prosumers;
        let recorder;
        [recorder, ...prosumers] = await ethers.getSigners();
        let EnergyTrading = await ethers.getContractFactory(contractName);
        let contract = await EnergyTrading.deploy(recorder.address);
        const numProsumers = 19;

        // register all prosumers
        for (let i = 0; i < numProsumers; ++i) {
            await contract.connect(prosumers[i]).registerProsumer();
        }
        // GGenereated from the dataset.
        // Net energy deltas for 19 household for the time interval 7:00 - 21:00
        // Each row is one time interval.
        // The updateEnergyStatus expects delta (difference between one time interval to another)
        const household_deltas = [
            [-58, -1674, -39, -88, -134, -348, -1999, -55, -56, -100, -212, -419, -29, -120, -44, -139, -439, -58, -100],
            [135, 1461, 19, -1015, 1, -705, 1906, -52, 45, -204, 2, -130, 58, 42, -410, 78, 39, -692, 12],
            [5, 137, 23, 1046, 30, 657, -8, 114, -3, 184, 77, 161, 43, 54, -372, 62, 68, 726, -94],
            [-90, -115, 26, 48, 66, -32, 91, -68, 47, 14, 16, 87, 63, 19, 853, 48, -39, -103, 163],
            [459, 46, 42, 29, 29, -74, 157, 68, 26, 32, 56, 19, 56, 12, 4, 96, 32, 231, -162],
            [-231, 148, 35, -144, -6, 169, 54, -388, 11, 4, 10, -76, 32, 33, -70, -97, 147, -780, 218],
            [512, 39, 50, 238, -1, -270, -694, 124, 6, 48, -223, 94, -49, 100, 135, 422, 76, 954, 25],
            [-77, 70, 14, -87, 138, 89, 1011, -981, 17, 42, 296, 44, 78, -343, -40, -47, -478, 4, -12],
            [-79, 132, -25, 1, 41, 104, 8, 967, -135, -8, 250, -211, 151, -82, -16, -211, -427, 139, 43],
            [273, -210, 24, -3, -5, 192, 209, 232, 223, 66, 163, 246, -168, 424, 73, -437, -156, -794, -24],
            [-199, 117, 34, 67, -36, -330, 109, 121, -16, -27, 34, -11, 97, -3, 207, 75, -40, 146, 93],
            [-170, -51, 12, -61, -208, 63, -231, -71, 111, 15, 8, 39, 62, -268, -460, -433, 1027, -198, -25],
            [118, 57, -11, 78, 52, 91, -44, 53, -12, 2, 39, -14, -1, 354, -52, 910, 218, 243, -231],
            [146, -372, 80, 106, -16, 3, 1, -21, 38, -342, -7, 135, 90, -57, 179, 294, 371, 506, 300],
            [151, 197, -30, 32, -57, 64, -43, 118, 56, 344, -20, -61, -304, 138, 21, 136, 17, 97, 38],
            [282, 21, 44, 3, 3, 3, 187, -109, -49, -34, -56, -174, 372, 32, 95, -633, 32, -445, 19],
            [-155, 137, 0, -107, 156, -32, -15, 56, -23, 71, -186, 104, 163, 76, -142, -160, -31, 195, -132],
            [-230, -43, -38, -58, 64, -16, -38, -81, 22, 58, -51, 50, 6, -55, 134, -25, 37, 268, 6],
            [411, -33, -69, 51, -23, 106, -39, -6, -73, -25, 27, -25, -21, 8, -41, -369, -62, -51, -25],
            [-77, -84, -20, -31, -54, -722, -149, -8, -25, 4, -68, -25, -252, -53, -58, -45, -147, -37, -112],
            [-202, -56, -119, -37, -29, 124, -533, -31, -193, -40, -196, -127, 128, -48, -180, -177, 8, -85, 12],
            [-226, -20, -84, 11, -56, 116, 120, -362, -672, -61, -178, -202, -22, -85, 135, 55, 42, -1709, -131],
            [-144, -111, -32, -168, 2, 95, -238, -105, 541, -49, 58, 98, -121, -126, 69, -48, -78, -1002, 69],
            [-358, -7, 14, -191, -59, -92, 64, -77, -718, -72, -1427, -102, -200, -1014, -74, 73, -200, 1208, -75],
            [-328, -51, 4, 21, -31, 300, -51, 52, 705, -23, 606, -22, -119, 843, -138, -293, -150, -39, 0],
            [5, -118, -4, -44, 24, -124, -53, 53, -29, -22, 716, -41, -210, -7, 97, 447, 19, 1030, -38],
            [-85, 140, -16, 112, -32, 245, -20, 348, 44, 5, 20, -12, -42, -148, -180, -91, -200, -95, -56],
            [10, -2247, -11, -12, -222, -80, -77, -17, -20, -99, -17, -78, -24, 106, 17, -155, -280, 81, 25],
            [52, 661, 22, -93, -12, -45, 144, 6, -52, 88, 10, 134, 16, 4, 143, 84, -9, -753, -50]
        ];
        
        const expected = [
            5000000000000000000n,
            5000000000000000000n,
            3611000000000000000n,
            2517000000000000000n,
            1359000000000000000n,
            2290000000000000000n,
            704000000000000000n,
            966000000000000000n,
            324000000000000000n,
            100000000000000000n,
            100000000000000000n,
            397000000000000000n,
            100000000000000000n,
            100000000000000000n,
            100000000000000000n,
            100000000000000000n,
            100000000000000000n,
            100000000000000000n,
            100000000000000000n,
            100000000000000000n,
            644000000000000000n,
            3973000000000000000n,
            5000000000000000000n,
            5000000000000000000n,
            5000000000000000000n,
            5000000000000000000n,
            5000000000000000000n,
            5000000000000000000n,
            5000000000000000000n
        ];

        let connected_recorder = contract.connect(recorder);

        for (let i = 0; i < household_deltas.length; ++i) {
            for (let j = 0; j < household_deltas[i].length; ++j) {
                await connected_recorder.updateEnergyStatus(prosumers[j].address, household_deltas[i][j]);
            }
            await connected_recorder.updateEnergyPrice();
            const updated_price = await connected_recorder.getEnergyPrice(); 
            expect(updated_price).to.equal(expected[i]);
        }
    });
})

describe("Unit Testing Coordination Mechanism", function () {
    const STARTING_ETHER = ethers.parseEther("500");
    let EnergyTrading, contract,  recorder, connected_recorder, prosumers;

    beforeEach(async function () {
        [recorder, ...prosumers] = await ethers.getSigners();
        EnergyTrading = await ethers.getContractFactory(contractName);
        contract = await EnergyTrading.deploy(recorder.address);
        connected_recorder = await contract.connect(recorder);
    });

    it("Basic case from assessment brief", async function () {
        const NUM_PROSUMERS = 5;
        for (let i = 0; i < NUM_PROSUMERS; ++i) {
            await contract.connect(prosumers[i]).registerProsumer();
            // From assignment brierf:
            // For simplicity, you can assume when the coordination function is called, 
            // all prosumers in deficit have enough Ethers to buy the energy they need at 
            // the latest energy price. 
            await contract.connect(prosumers[i]).deposit({ value: STARTING_ETHER});
        }

        const initialState = [-1, 0, 0, 1, 4]
        const exptectedState = [0, 0, 0, 1, 3]
        for (let i = 0; i < initialState.length; ++i) {
            await connected_recorder.updateEnergyStatus(prosumers[i].address, initialState[i]);
        }

        // Perform coordination and trading, then check emitted event
        await expect(connected_recorder.coordinateTrading())
            .to.emit(contract, "CoordinationComplete") .withArgs(1);  

        let prosumerData;
        for (let i = 0; i < exptectedState.length; ++i) {
            prosumerData = await contract.prosumers(prosumers[i].address);
            expect(prosumerData.prosumerEnergyStat).to.equal(exptectedState[i]);
        }

        // Just a sanity check
        // We expect prosumer1 to buy and prosumer 5 to sell
        prosumerData = await contract.prosumers(prosumers[0].address);
        expect(prosumerData.prosumerBalance).to.be.lessThan(STARTING_ETHER);
        prosumerData = await contract.prosumers(prosumers[4].address);
        expect(prosumerData.prosumerBalance).to.be.greaterThan(STARTING_ETHER);
    });

    it("All zeroes", async function () {
        const NUM_PROSUMERS = 5;
        // Register users and make sure they have more than enough balance.
        for (let i = 0; i < NUM_PROSUMERS; ++i) {
            await contract.connect(prosumers[i]).registerProsumer();
            await contract.connect(prosumers[i]).deposit({ value: STARTING_ETHER});
        }

        // Initial state is already zero by default.
        const exptectedState = [0, 0, 0, 0, 0]

        // Perform coordination and trading, then check emitted event
        await expect(connected_recorder.coordinateTrading())
            .to.emit(contract, "CoordinationComplete")
            .withArgs(0);  

        for (let i = 0; i < exptectedState.length; ++i) {
            const prosumerData = await contract.prosumers(prosumers[i].address);
            expect(prosumerData.prosumerEnergyStat).to.equal(exptectedState[i]);
            
            // Check that nothing is taken out of balance.
            expect(prosumerData.prosumerBalance).to.equal(STARTING_ETHER );
        }
    });

    it("No surplus, all deficit", async function () {
        const NUM_PROSUMERS = 5;
        for (let i = 0; i < NUM_PROSUMERS; ++i) {
            await contract.connect(prosumers[i]).registerProsumer();
            await contract.connect(prosumers[i]).deposit({ value: STARTING_ETHER});
        }
        
        // No surplus so no trade
        const initialState = [-5, -2, -10, -1, -3]
        const exptectedState = [-5, -2, -10, -1, -3]
        for (let i = 0; i < initialState.length; ++i) {
            await connected_recorder.updateEnergyStatus(prosumers[i].address, initialState[i]);
        }

        // Perform coordination and trading, then check emitted event
        await expect(connected_recorder.coordinateTrading())
            .to.emit(contract, "CoordinationComplete")
            .withArgs(0);  

        for (let i = 0; i < exptectedState.length; ++i) {
            const prosumerData = await contract.prosumers(prosumers[i].address);
            expect(prosumerData.prosumerEnergyStat).to.equal(exptectedState[i]);
            // Check that nothing is taken out of balance.
            expect(prosumerData.prosumerBalance).to.equal(STARTING_ETHER );
        }
    });

    it("No deficit, all surplus", async function () {
        const NUM_PROSUMERS = 5;
        for (let i = 0; i < NUM_PROSUMERS; ++i) {
            await contract.connect(prosumers[i]).registerProsumer();
            await contract.connect(prosumers[i]).deposit({ value: STARTING_ETHER});
        }
        
        // No surplus so no trade
        const initialState = [5, 2, 10, 1, 3]
        const exptectedState = [5, 2, 10, 1, 3]
        for (let i = 0; i < initialState.length; ++i) {
            await connected_recorder.updateEnergyStatus(prosumers[i].address, initialState[i]);
        }

        // Perform coordination and trading, then check emitted event
        await expect(connected_recorder.coordinateTrading())
            .to.emit(contract, "CoordinationComplete")
            .withArgs(0);  

        for (let i = 0; i < exptectedState.length; ++i) {
            const prosumerData = await contract.prosumers(prosumers[i].address);
            expect(prosumerData.prosumerEnergyStat).to.equal(exptectedState[i]);
            // Check that nothing is taken out of balance.
            expect(prosumerData.prosumerBalance).to.equal(STARTING_ETHER );
        }
    });

    it("Equailbrium (net zero)", async function () {
        const NUM_PROSUMERS = 5;
        for (let i = 0; i < NUM_PROSUMERS; ++i) {
            await contract.connect(prosumers[i]).registerProsumer();
            await contract.connect(prosumers[i]).deposit({ value: STARTING_ETHER});
        }
        
        const initialState = [-4, -4, -1,  2, 7]
        const exptectedState = [0, 0, 0, 0, 0]
        for (let i = 0; i < initialState.length; ++i) {
            await connected_recorder.updateEnergyStatus(prosumers[i].address, initialState[i]);
        }

        // Perform coordination and trading, then check emitted event
        await expect(connected_recorder.coordinateTrading())
            .to.emit(contract, "CoordinationComplete")
            .withArgs(9);  

        for (let i = 0; i < exptectedState.length; ++i) {
            const prosumerData = await contract.prosumers(prosumers[i].address);
            expect(prosumerData.prosumerEnergyStat).to.equal(exptectedState[i]);
        }
    });

    it("More surplus than deficit", async function () {
        const NUM_PROSUMERS = 5;
        for (let i = 0; i < NUM_PROSUMERS; ++i) {
            await contract.connect(prosumers[i]).registerProsumer();
            await contract.connect(prosumers[i]).deposit({ value: STARTING_ETHER});
        }
        
        const initialState = [-1, 0, 0, 1, 4]
        const exptectedState = [0, 0, 0, 1, 3]
        for (let i = 0; i < initialState.length; ++i) {
            await connected_recorder.updateEnergyStatus(prosumers[i].address, initialState[i]);
        }

        // Perform coordination and trading, then check emitted event
        await expect(connected_recorder.coordinateTrading())
            .to.emit(contract, "CoordinationComplete")
            .withArgs(1);  

        for (let i = 0; i < exptectedState.length; ++i) {
            const prosumerData = await contract.prosumers(prosumers[i].address);
            expect(prosumerData.prosumerEnergyStat).to.equal(exptectedState[i]);
        }
    });

     it("More deficit than surplus", async function () {
        const NUM_PROSUMERS = 5;
        for (let i = 0; i < NUM_PROSUMERS; ++i) {
            await contract.connect(prosumers[i]).registerProsumer();
            await contract.connect(prosumers[i]).deposit({ value: STARTING_ETHER});
        }
        
        const initialState = [1, 0, 0, -1, -4]
        const exptectedState = [0, 0, 0, -1, -3]
        for (let i = 0; i < initialState.length; ++i) {
            await connected_recorder.updateEnergyStatus(prosumers[i].address, initialState[i]);
        }

        // Perform coordination and trading, then check emitted event
        await expect(connected_recorder.coordinateTrading())
            .to.emit(contract, "CoordinationComplete")
            .withArgs(1);  

        for (let i = 0; i < exptectedState.length; ++i) {
            const prosumerData = await contract.prosumers(prosumers[i].address);
            expect(prosumerData.prosumerEnergyStat).to.equal(exptectedState[i]);
        }
    });

    it("Check low variance requirment", async function () {
        const NUM_PROSUMERS = 5;
        for (let i = 0; i < NUM_PROSUMERS; ++i) {
            await contract.connect(prosumers[i]).registerProsumer();
            await contract.connect(prosumers[i]).deposit({ value: STARTING_ETHER});
        }
        
        const initialState = [-2, 4, 4, 0, 0]
        const exptectedState = [0, 3, 3, 0, 0]
        for (let i = 0; i < initialState.length; ++i) {
            await connected_recorder.updateEnergyStatus(prosumers[i].address, initialState[i]);
        }
        // Perform coordination and trading, then check emitted event
        await expect(connected_recorder.coordinateTrading())
            .to.emit(contract, "CoordinationComplete")
            .withArgs(2);  

        for (let i = 0; i < exptectedState.length; ++i) {
            const prosumerData = await contract.prosumers(prosumers[i].address);
            expect(prosumerData.prosumerEnergyStat).to.equal(exptectedState[i]);
        }
    });
});

describe("Integration Testing Coordination Mechanism", function () {
    it("Data for 6 households from 5/01/2013 7:00 - 18:00", async function () {
        let recorder;
        let prosumers;
        [recorder, ...prosumers] = await ethers.getSigners();
        let EnergyTrading = await ethers.getContractFactory(contractName);
        let contract = await EnergyTrading.deploy(recorder.address);
        let connectedRecorder = await contract.connect(recorder);

        const STARTING_ETHER = ethers.parseEther("5000");
        const NUM_PROSUMERS = 6;
        for (let i = 0; i < NUM_PROSUMERS; ++i) {
            await contract.connect(prosumers[i]).registerProsumer();
            await contract.connect(prosumers[i]).deposit({ value: STARTING_ETHER});
        }

        const hosueholdData = [
            [-1, -1, -1, -1, -1, -1],
            [-1, -1, 1, -1, -1, -1],
            [-1, 1, 1, -1, -1, -1],
            [1, 1, 1, -1, 1, -1],
            [1, 1, 1, -1, 1, -1],
            [1, 1, 1, -1, 1, -1],
            [1, 1, 1, 1, 1, -1],
            [2, 1, 1, 1, 1, -1],
            [2, 1, 1, 1, 1, -1],
            [2, 1, 1, 1, 1, -1],
            [2, -2, 1, 1, 1, -2],
            [2, -3, 1, 1, 1, -2],
            [2, 1, 1, 1, 1, -1],
            [2, -1, 1, 1, 1, -1],
            [2, -1, 1, 1, 1, -1],
            [2, -1, 1, 1, -1, -1],
            [2, -1, 1, 1, 1, -1],
            [2, -2, 1, 1, 1, -2],
            [1, -1, 1, 1, 1, -2],
            [1, -2, 1, 1, 1, -1],
            [1, -2, 0, 1, -1, -1],
            [1, -2, -1, 1, -1, -1],
            [1, -2, -1, -1, -1, -2]
        ];

        const expected = [
            [-1, -1, -1, -1, -1, -1],
            [-2, -2,  0, -2, -2, -2],
            [-2, -1,  0, -3, -3, -3],
            [-1,  0,  0, -3, -2, -4],
            [0, 0, 0, -4, -1, -3],
            [ 0,  0,  0, -3,  0, -3],
            [ 0,  0,  0, -1,  0, -1],
            [ 0,  1,  1,  0,  1,  0],
            [ 1,  2,  2,  1,  2,  0],
            [ 2,  3,  3,  2,  3,  0],
            [ 3,  1,  3,  3,  4,  0],
            [ 3,  0,  3,  4,  4,  0],
            [ 4,  1,  4,  5,  5,  0],
            [ 5,  0,  5,  6,  6,  0],
            [ 6,  0,  6,  6,  7,  0],
            [ 6,  0,  7,  7,  6,  0],
            [ 7,  0,  7,  8,  7,  0],
            [ 7,  0,  7,  8,  8,  0],
            [ 7,  0,  8,  8,  8,  0],
            [ 8,  0,  8,  8,  8,  0],
            [ 7,  0,  8,  8,  7,  0],
            [ 7,  0,  7,  7,  6,  0],
            [ 5,  0,  5,  6,  5,  0]
        ];

        // This is the value expected to be emitted by event
        // It should be the amount of total energy excahnged at end of coordiantion.
        const expectyedEmtis = [0, 0, 1, 1, 2, 3, 4, 2, 1, 1, 2, 4, 1, 1, 2, 2, 2, 4, 3, 3, 3, 3, 4]

        for (let i = 0; i < hosueholdData.length; ++i) {
            // Update hosuehold net values and run the market.
            for (let j = 0; j < hosueholdData[i].length; ++j) {
                await connectedRecorder.updateEnergyStatus(prosumers[j].address, hosueholdData[i][j]);
            }
            // TODO: CHeck emitted event
            await expect(connectedRecorder.coordinateTrading())
                .to.emit(contract, "CoordinationComplete")
                .withArgs(expectyedEmtis[i]);  
            
            // Check against expected.
            for (let k =0; k < expected[i].length; ++k) {
                const prosumerData = await contract.prosumers(prosumers[k].address);
                expect(prosumerData.prosumerEnergyStat).to.equal(expected[i][k]);
            }
        }
    });
});


describe("Coordination Gas Consumption Estimate", function () {
    it("Simulate 25 hsoueholds over 500 time intervals", async function () {
        const timePeriods = 500;
        const numHouseholds = 25;
        const min = -200;
        const max = 200;
        const randomData = Array.from({ length: timePeriods }, () =>
        Array.from({ length: numHouseholds }, () => 
            Math.floor(Math.random() * (max - min + 1)) + min
        ));
        
        let prosumers;
        let recorder;
        [recorder, ...prosumers] = await ethers.getSigners();
        let EnergyTrading = await ethers.getContractFactory(contractName);
        let contract = await EnergyTrading.deploy(recorder.address);

        // register all prosumers and make sure they have neough ether
        const STARTING_ETHER = ethers.parseEther("10000");
        for (let i = 0; i < numHouseholds; ++i) {
            await contract.connect(prosumers[i]).registerProsumer();
            await contract.connect(prosumers[i]).deposit({ value: STARTING_ETHER});
        }
        
        let connectedRecorder = await contract.connect(recorder);

        let totalGas = 0n;
        for (let i = 0; i < randomData.length; ++i) {
            // Update hosuehold net values and run the market.
            for (let j = 0; j < randomData[i].length; ++j) {
                await connectedRecorder.updateEnergyStatus(prosumers[j].address, randomData[i][j]);
            }
            const tx = await connectedRecorder.coordinateTrading();
            const receipt = await tx.wait();
            totalGas += receipt.gasUsed;
        }
        let averageGas = totalGas / BigInt(randomData.length);
        console.log(`Average gas consumed by coordination: ${averageGas.toString()}`);
    });
});
