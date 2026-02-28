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

    modifier onlyRecorder() {
        require(msg.sender == recorder, "Only recorder");
        _;
    }
    //---PW

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
        require(msg.value>0,"0 or negative value deposited, did you want to withdraw?");
        prosumers[msg.sender].prosumerBalance += msg.value;
    }

    function withdraw(uint256 _value) external {
        // A function to enable a registered prosumer to withdraw Ethers from the smart contract. Prosumers can only withdraw Ethers if they have
        // no energy deficit.
   
        Prosumer storage p = prosumers[msg.sender];
        require(p.isMember, "Prosumer not registered");
        require(p.prosumerEnergyStat >= 0, "Prosumer has an energy deficit");
        require(_value > 0, "Amount=0");
        require(p.prosumerBalance >= _value, "Insufficient balance");

        p.prosumerBalance -= _value;

        //value is updated for Balance but nothing changes the sender's ether, perhaps something like...
        // (bool ok, ) = msg.sender.call{value: _value}("");
        // require(ok, "ETH transfer failed");



    }

    function updateEnergyStatus(address _prosumer, int256 deltaEnergy) external {
        // A function used by the recorder to update the energy status of a registered prosumer. The recorder provides two parameters: 
        //(1) the address of the prosumer and 
        //(2) a signed integer representing the net energy status. A positive value indicates that the prosumer has a surplus of
        // energy, while a negative value indicates that the prosumer has a deficit, meaning it needs more energy than its locally generated energy.


        require(msg.sender == recorder, "Only recorder can update energy status");
        require(prosumers[_prosumer].isMember, "Prosumer not registered");

        prosumers[_prosumer].prosumerEnergyStat += deltaEnergy;

        //probably should be using emit and recording the event
        //e.g  emit EnergyStatusUpdated(_prosumer, deltaEnergy, p.prosumerEnergyStat);
    }

    function updateEnergyPrice() public { //onlyRecorder {
        // A function to update the energy price based on the energy status of
        // the community. The calculation of the energy price is as follows:
        // • When there is 0 energy surplus or deficit, the energy price is 1 Ether per unit of energy.
        // • Each unit of energy deficit increases the energy price by 0.001 Ether. The highest energy price is capped at 5 Ether.
        // • Each unit of energy surplus decreases the energy price by 0.001 Ether. The lowest energy price is capped at 0.1 Ether.
        
        
        //PW If we cannot use the modifier
        require(msg.sender == recorder, "Only recorder can update energy status");

        // Calculate the total energy status of the community
        int256 total = 0;

        // sum community energy status
        for (uint256 i = 0; i < prosumerAddresses.length; i++) {
            address a = prosumerAddresses[i];
            total += prosumers[a].prosumerEnergyStat;
        }

        // start from base price = 1 ether
        uint256 price = 1 ether;

        // adjustment = |total| * 0.001 ether
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

        // cap price up to 0.1 ether and down tp  5 ether]
        if (price < 0.1 ether) price = 0.1 ether;
        if (price > 5 ether)   price = 5 ether;

        energyPrice = price;

         emit EnergyPriceUpdated(price, total);
    }

    function buyEnergyFrom(address _seller, uint _requestedEnergy) external {
        // A function for a registered prosumer in deficit to buy energy from a registered prosumer in surplus at the latest energy price. The requested
        // energy is a positive value. The prosumer in deficit can only buy up to its recorded deficit energy.

        require(_requestedEnergy > 0, "Requested energy must be > 0");
        require(_seller != address(0), "Invalid seller");
        require(_seller != msg.sender, "Cannot buy from self");

        Prosumer storage buyer = prosumers[msg.sender];
        Prosumer storage seller = prosumers[_seller];

        require(buyer.isMember, "Buyer not registered");
        require(seller.isMember, "Seller not registered");

        // Buyer must be in deficit (negative)
        require(buyer.prosumerEnergyStat < 0, "Buyer is not in deficit");

        // Seller must be in surplus (positive)
        require(seller.prosumerEnergyStat > 0, "Seller is not in surplus");

        // Buyer can only buy up to its deficit
        uint256 buyerDeficit = uint256(-buyer.prosumerEnergyStat); // safe because buyerEnergyStat < 0
        require(_requestedEnergy <= buyerDeficit, "Requested energy exceeds buyer deficit");

        // Seller must have enough surplus
        uint256 sellerSurplus = uint256(seller.prosumerEnergyStat); // safe because > 0
        require(_requestedEnergy <= sellerSurplus, "Requested energy exceeds seller surplus");

        // Cost = units * price (price is wei per unit - perhaps need to standardise to whole ether?)
        // does the update energy price need to be called first?
        uint256 cost = _requestedEnergy * energyPrice;
        require(buyer.prosumerBalance >= cost, "Insufficient buyer balance");

        // internal settlement
        buyer.prosumerBalance -= cost;
        seller.prosumerBalance += cost;

        // Update energy stats
        buyer.prosumerEnergyStat += int256(_requestedEnergy);
        seller.prosumerEnergyStat -= int256(_requestedEnergy);

        // emit EnergyBought(msg.sender, _seller, _requestedEnergy, energyPrice, cost);
        
    }

    function sellEnergyTo(address _buyer, uint _offeredEnergy) external {
        // A function for a registered prosumer in surplus to sell energy to a registered prosumer in deficit at the latest energy price. The offered
        // energy is a positive value. The prosumer in surplus can only sell up to its recorded surplus energy

        //PW so much copied from above, perhaps an internal function that refactors both buy and sell?
        require(_offeredEnergy > 0, "Offered energy must be > 0");
        require(_buyer != address(0), "Invalid buyer");
        require(_buyer != msg.sender, "Cannot sell to self");

        Prosumer storage seller = prosumers[msg.sender];
        Prosumer storage buyer  = prosumers[_buyer];

        require(seller.isMember, "Seller not registered");
        require(buyer.isMember, "Buyer not registered");

        // Seller must be in surplus (positive)
        require(seller.prosumerEnergyStat > 0, "Seller is not in surplus");

        // Buyer must be in deficit (negative)
        require(buyer.prosumerEnergyStat < 0, "Buyer is not in deficit");

        // Seller can only sell up to its surplus
        uint256 sellerSurplus = uint256(seller.prosumerEnergyStat);
        require(_offeredEnergy <= sellerSurplus, "Offered exceeds seller surplus");

        // Buyer can only buy up to its deficit
        uint256 buyerDeficit = uint256(-buyer.prosumerEnergyStat);
        require(_offeredEnergy <= buyerDeficit, "Offered exceeds buyer deficit");

        // Total cost in wei
        uint256 cost = _offeredEnergy * energyPrice;

        // Buyer must have enough deposited balance to pay
        require(buyer.prosumerBalance >= cost, "Insufficient buyer balance");

        // internal settlement
        buyer.prosumerBalance -= cost;
        seller.prosumerBalance += cost;

        // Update energy stats
        seller.prosumerEnergyStat -= int256(_offeredEnergy);
        buyer.prosumerEnergyStat  += int256(_offeredEnergy);

        //emit EnergyTransaction ? single event shared?
    }


    function coordinateTrading() public {
        //First loop through all the prosumers and create an array of buyers and of sellers
        //Then sort sellers and buyers from biggest defecit and surplus to smallest
        //Then loop until all trades completed
        //PW use the withdraw and deposit functions to make trades?

        //PW If we cannot use the modifier
        require(msg.sender == recorder, "Only recorder can update energy status");

        uint256 n = prosumerAddresses.length;

        // Build sellers/buyers lists in memory.  Memory is cheaper gas, faster, auto-deleted after function than storage arrays
        address[] memory sellers = new address[](n);
        uint256[] memory sellerAmt = new uint256[](n);
        uint256 sellersCount = 0;

        address[] memory buyers = new address[](n);
        uint256[] memory buyerAmt = new uint256[](n);
        uint256 buyersCount = 0;

        for (uint256 i = 0; i < n; i++) {
            address a = prosumerAddresses[i];
            int256 e = prosumers[a].prosumerEnergyStat;

            if (e > 0) {
                sellers[sellersCount] = a;
                sellerAmt[sellersCount] = uint256(e);
                sellersCount++;
            } else if (e < 0) {
                buyers[buyersCount] = a;
                buyerAmt[buyersCount] = uint256(-e); 
                buyersCount++;
            }
        }

        // Sort sellers by surplus big to little
        for (uint256 i = 0; i + 1 < sellersCount; i++) {
            uint256 maxIdx = i;
            for (uint256 j = i + 1; j < sellersCount; j++) {
                if (sellerAmt[j] > sellerAmt[maxIdx]) maxIdx = j;
            }
            if (maxIdx != i) {
                //address tempSeller = sellers[i];
                //sellers[i] = sellers[maxIdx];
                //sellers[maxIdx] = tempSeller;  
                //https://docs.soliditylang.org/en/latest/control-structures.html#destructuring-assignments-and-returning-multiple-values helps to save on the gas
                (sellers[i], sellers[maxIdx]) = (sellers[maxIdx], sellers[i]);
                (sellerAmt[i], sellerAmt[maxIdx]) = (sellerAmt[maxIdx], sellerAmt[i]);
            }
        }

        // Sort buyers by deficit big to little
        for (uint256 i = 0; i + 1 < buyersCount; i++) {
            uint256 maxIdx = i;
            for (uint256 j = i + 1; j < buyersCount; j++) {
                if (buyerAmt[j] > buyerAmt[maxIdx]) maxIdx = j;
            }
            if (maxIdx != i) {
                (buyers[i], buyers[maxIdx]) = (buyers[maxIdx], buyers[i]);
                (buyerAmt[i], buyerAmt[maxIdx]) = (buyerAmt[maxIdx], buyerAmt[i]);
            }
        }

        // Match with two pointers
        uint256 si = 0;
        uint256 bi = 0;
        uint256 totalMatched = 0;

        while (si < sellersCount && bi < buyersCount) {
        //keep looping whilst there are buyers and sellers
        //PW not sure if this is right, feel like we should be able to break earlier in some situations and save some gas
            //https://docs.soliditylang.org/en/latest/types.html#operators
            //condition ? value_if_true : value_if_false; 
            uint256 trade = sellerAmt[si] < buyerAmt[bi] ? sellerAmt[si] : buyerAmt[bi];

            if (trade == 0) break;

            address seller = sellers[si];
            address buyer  = buyers[bi];

            uint256 cost = trade * energyPrice;

            // PDF says assume buyers have enough ETH, but worth a check
            require(prosumers[buyer].prosumerBalance >= cost, "Buyer lacks money (ETH)");

            // Exchange money
            prosumers[buyer].prosumerBalance -= cost;
            prosumers[seller].prosumerBalance += cost;

            // Exchange energy stats
            prosumers[buyer].prosumerEnergyStat += int256(trade);
            prosumers[seller].prosumerEnergyStat -= int256(trade);

            totalMatched += trade;

            // Decrease remaining amounts in memory arrays
            sellerAmt[si] -= trade;
            buyerAmt[bi] -= trade;

            if (sellerAmt[si] == 0) si++;
            if (buyerAmt[bi] == 0) bi++;
        }

        emit CoordinationComplete(totalMatched);
    }


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
