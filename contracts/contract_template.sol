// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract EnergyTrading {

    // Define the ProsumerData struct
    struct Prosumer {
        // ID (address) of the prosumer
        address prosumerAddress;
        // positive value means energy to sell, negative value means energy to buy
        int256 prosumerEnergyStat;
        // Store the deposited ethers, we don't expect negative
        uint256 prosumerBalance;
        // true if prosumer has been added to our system
        bool isMember;
    }

    // Hashmap to store prosumer data
    mapping (address => Prosumer) public prosumers;

    // Variable to store the latest energy price
    uint256 private energyPrice;

    // Variable to store the recorder address who can update the energy status of prosumers
    address private recorder;

    // event to emit when coordination is complete
    event CoordinationComplete(uint256 totalMatchedEnergy);

    //PW Added as appears mappings are not iterable
    address[] public prosumerAddresses;
    event EnergyPriceUpdated(uint256 newPrice, int256 totalEnergyStatus);

    constructor(address _recorder) payable {
        recorder=_recorder;
        energyPrice= 1 ether;

    }

    function registerProsumer() external {
        // A function for an unregistered address to register as a new prosumer.
        // A new prosumer has an initial energy status of 0 and a balance of 0. If
        // the address is already registered, the function should raise an error.

        require(!prosumers[msg.sender].isMember,"Prosumer already registered!");
        prosumers[msg.sender]=Prosumer({
            prosumerAddress: msg.sender,
            prosumerEnergyStat:0,
            prosumerBalance: 0,
            isMember: true});

        prosumerAddresses.push(msg.sender);
    }

    function deposit() external payable {
        // A function to enable a registered prosumer to deposit Ethers to the
        // smart contract.
        //PW Check that value is greater than 0? and do we need an event to log all deposits
        require(prosumers[msg.sender].isMember, "Prosumer not registered");
        prosumers[msg.sender].prosumerBalance += msg.value;
    }

    function withdraw(uint256 _value) external {
        // A function to enable a registered prosumer to withdraw Ethers from
        // the smart contract. Prosumers can only withdraw Ethers if they have
        // no energy deficit.
        address mySender=msg.sender;
        require(prosumers[mySender].isMember, "Prosumer not registered");
        require(prosumers[mySender].prosumerEnergyStat >= 0,"Prosumer has an energy deficit" );
        //need to check the balance as well?
        prosumers[mySender].prosumerBalance = prosumers[mySender].prosumerBalance - _value;
    }

    function updateEnergyStatus(address _prosumer, int256 deltaEnergy) external {
        // A function used by the recorder to update the energy status of a regis-
        // tered prosumer. The recorder provides two parameters: (1) the address
        // of the prosumer and (2) a signed integer representing the net energy
        // status. A positive value indicates that the prosumer has a surplus of
        // energy, while a negative value indicates that the prosumer has a deficit,
        // meaning it needs more energy than its locally generated energy.
        require(msg.sender == recorder, "Only recorder can update energy status");
        require(prosumers[_prosumer].isMember, "Prosumer not registered");

        prosumers[_prosumer].prosumerEnergyStat += deltaEnergy;

        //probably should be using emit and recording the event
        //e.g  emit EnergyStatusUpdated(_prosumer, deltaEnergy, p.prosumerEnergyStat);
    }

    function updateEnergyPrice() public {
        // A function to update the energy price based on the energy status of
        // the community. The calculation of the energy price is as follows:
        // • When there is 0 energy surplus or deficit, the energy price is 1
        // Ether per unit of energy.
        // • Each unit of energy deficit increases the energy price by 0.001
        // Ether. The highest energy price is capped at 5 Ether.
        // • Each unit of energy surplus decreases the energy price by 0.001
        // Ether. The lowest energy price is capped at 0.1 Ether.
            // Calculate the total energy status of the community
        int256 total = 0;

    // 1) sum community energy status
        for (uint256 i = 0; i < prosumerAddresses.length; i++) {
            address a = prosumerAddresses[i];
            total += prosumers[a].prosumerEnergyStat;
        }

        // 2) start from base price = 1 ether
        uint256 price = 1 ether;

        // 3) adjustment = |total| * 0.001 ether
        uint256 adjustment;
        if (total < 0) {
            adjustment = uint256(-total) * 0.001 ether; // deficit => increase
            price = price + adjustment;
        } else if (total > 0) {
            adjustment = uint256(total) * 0.001 ether;  // surplus => decrease
            // avoid underflow if adjustment > 1 ether
            if (adjustment >= price) {
                price = 0; // will be capped to 0.1 ether below
            } else {
                price = price - adjustment;
            }
        }

        // 4) cap price: [0.1 ether, 5 ether]
        if (price < 0.1 ether) price = 0.1 ether;
        if (price > 5 ether)   price = 5 ether;

        energyPrice = price;

         emit EnergyPriceUpdated(price, total);
    }

    function buyEnergyFrom(address _seller, uint _requestedEnergy) external {
        // Your implementation here
    }

    function sellEnergyTo(address _buyer, uint _offeredEnergy) external {
        // Your implementation here
    }


    function coordinateTrading() public {
        // Your implementation here
    }
    //delete later -ONLY FOR TESTING
    function contractBalance() external view returns (uint256) {
        // testing delete later
        return address(this).balance;
    }

    ///DELETE ABOVE
    // -------------------------------------
    // Public view functions, do not modify
    // -------------------------------------

    function getRecorder() public view returns (address) {
        return recorder;
    }

    function getEnergyPrice() public view returns (uint256) {
        return energyPrice;
    }
}
