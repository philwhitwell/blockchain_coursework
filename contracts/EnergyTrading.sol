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

    //PW Variables added
    address[] public prosumerAddresses; //Added as appears mappings are not iterable
    // event EnergyPriceUpdated(uint256 newPrice, int256 totalEnergyStatus);
    // event ProsumerRegistered(address indexed prosumer);
    // event Deposit(address indexed prosumer, uint256 amount);
    // event Withdraw(address indexed prosumer, uint256 amount);
    // event EnergyStatusUpdated(address indexed prosumer,int256 deltaEnergy,int256 newEnergyStatus);
    // event EnergyTraded(address indexed seller,address indexed buyer,uint256 energyAmount,uint256 unitPrice,uint256 totalCost);

    modifier onlyRecorder() {
        require(msg.sender == recorder, "Only recorder allowed");
        _;
    }
    modifier isMember(){
        require(prosumers[msg.sender].isMember, "Prosumer not registered");
        _;
    }
    modifier isRegistered(address prosumerAddr) {
        require(prosumers[prosumerAddr].isMember, "Prosumer not registered");
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
        // emit ProsumerRegistered(msg.sender); //This uses gas but improves understanding
    }

    function deposit() isMember external payable {
        // A function to enable a registered prosumer to deposit Ethers to the
        // smart contract.
        //PW Check that value is greater than 0? and do we need an event to log all deposits
        //added as modifier require(prosumers[msg.sender].isMember, "Prosumer not registered");
        require(msg.value > 0, "Deposit must be greater than 0");
        prosumers[msg.sender].prosumerBalance += msg.value;
        // emit Deposit(msg.sender, msg.value);
    }
    
    function withdraw(uint256 _value) external isMember {
        // A function to enable a registered prosumer to withdraw Ethers from the smart contract. Prosumers can only withdraw Ethers if they have
        // no energy deficit.
   
        Prosumer storage p = prosumers[msg.sender];
        //added as modifier require(p.isMember, "Prosumer not registered");
        require(p.prosumerEnergyStat >= 0, "Cannot withdraw while in energy deficit");
        require(_value > 0, "Amount must be greater than 0");
        require(p.prosumerBalance >= _value, "Insufficient balance");

        p.prosumerBalance -= _value;

        //value is updated for Balance but then update the sender's ether
        (bool ok, ) = msg.sender.call{value: _value}("");
        require(ok, "ETH transfer failed");
        // emit Withdraw(msg.sender, _value);
    }


    function updateEnergyStatus(address _prosumer, int256 deltaEnergy)
            external
            onlyRecorder
            isRegistered(_prosumer)
        {
        // A function used by the recorder to update the energy status of a registered prosumer. The recorder provides two parameters: 
        //(1) the address of the prosumer and 
        //(2) a signed integer representing the net energy status. A positive value indicates that the prosumer has a surplus of
        // energy, while a negative value indicates that the prosumer has a deficit, meaning it needs more energy than its locally generated energy.

        //added as modfier require(msg.sender == recorder, "Only recorder can update energy status");

            Prosumer storage p = prosumers[_prosumer];
            p.prosumerEnergyStat += deltaEnergy;

            // emit EnergyStatusUpdated(_prosumer, deltaEnergy, p.prosumerEnergyStat);
        }


    function updateEnergyPrice() public onlyRecorder{ 
        // A function to update the energy price based on the energy status of
        // the community. The calculation of the energy price is as follows:
        // • When there is 0 energy surplus or deficit, the energy price is 1 Ether per unit of energy.
        // • Each unit of energy deficit increases the energy price by 0.001 Ether. The highest energy price is capped at 5 Ether.
        // • Each unit of energy surplus decreases the energy price by 0.001 Ether. The lowest energy price is capped at 0.1 Ether.
        
        
        //PW If we cannot use the modifier
        //Added as modifier require(msg.sender == recorder, "Only recorder can update energy status");

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

        // cap price between 0.1 ether and 5 ether
        if (price < 0.1 ether) price = 0.1 ether;
        if (price > 5 ether)   price = 5 ether;

        energyPrice = price;

        // emit EnergyPriceUpdated(price, total);
    }
    function _executeTrade(address _seller, address _buyer, uint256 _energyAmount) internal {
        //Internal function, as realised that buy and sell energy had a lot of repeated code
        Prosumer storage seller = prosumers[_seller];
        Prosumer storage buyer  = prosumers[_buyer];

        require(_energyAmount > 0, "Energy amount must be > 0");
        require(_seller != address(0), "Invalid seller");
        require(_buyer != address(0), "Invalid buyer");
        require(_seller != _buyer, "Cannot trade with self");

        require(seller.isMember, "Seller not registered");
        require(buyer.isMember, "Buyer not registered");

        // Seller must be in surplus (positive)
        require(seller.prosumerEnergyStat > 0, "Seller is not in surplus");

        // Buyer must be in deficit (negative)
        require(buyer.prosumerEnergyStat < 0, "Buyer is not in deficit");

        // Seller can only sell up to its surplus
        uint256 sellerSurplus = uint256(seller.prosumerEnergyStat);
        require(_energyAmount <= sellerSurplus, "Energy exceeds seller surplus");

        // Buyer can only buy up to its deficit
        uint256 buyerDeficit = uint256(-buyer.prosumerEnergyStat);
        require(_energyAmount <= buyerDeficit, "Energy exceeds buyer deficit");

        // Total cost in wei
        uint256 cost = _energyAmount * energyPrice;

        // Buyer must have enough deposited balance to pay
        require(buyer.prosumerBalance >= cost, "Insufficient buyer balance");

        // internal settlement
        buyer.prosumerBalance -= cost;
        seller.prosumerBalance += cost;

        // Update energy stats
        seller.prosumerEnergyStat -= int256(_energyAmount);
        buyer.prosumerEnergyStat  += int256(_energyAmount);

        // emit EnergyTraded(_seller, _buyer, _energyAmount, energyPrice, cost);
}


    function buyEnergyFrom(address _seller, uint256 _requestedEnergy) external isMember{
        // A function for a registered prosumer in deficit to buy energy from a registered prosumer in surplus at the latest energy price. The requested
        // energy is a positive value. The prosumer in deficit can only buy up to its recorded deficit energy.

        require(_seller != msg.sender, "Cannot buy from self");

        _executeTrade(_seller, msg.sender, _requestedEnergy);
    }

    function sellEnergyTo(address _buyer, uint256 _offeredEnergy) external isMember{
        // A function for a registered prosumer in surplus to sell energy to a registered prosumer in deficit at the latest energy price. The offered
        // energy is a positive value. The prosumer in surplus can only sell up to its recorded surplus energy

        require(_buyer != msg.sender, "Cannot sell to self");

        _executeTrade(msg.sender, _buyer, _offeredEnergy);
    }

    function coordinateTrading() public onlyRecorder {
        // First loop through all the prosumers and create an array of buyers and of sellers
        // Then sort sellers and buyers from biggest deficit and surplus to smallest
        // Then loop until all trades completed
        // PW use the withdraw and deposit functions to make trades?

        uint256 n = prosumerAddresses.length;

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

        uint256 totalMatched = 0;

        // Repeatedly trade ONE unit at a time.
        // Each round:
        // - choose buyer with largest remaining deficit
        // - choose seller with largest remaining surplus
        //
        // PW remember 
        // Use ">" not ">=" in the scans below.
        // That means if values are tied, the FIRST entry already in the sorted array is kept.
        //
        // This gives:
        // [1,1,1,-5,0,-4] -> [0,0,0,-3,0,-3]
        // [8,-1,7,7,6,-1] -> [6,0,7,7,6,0]
        while (true) {
            uint256 maxBuyerIdx = type(uint256).max;
            uint256 maxDeficit = 0;

            // Find buyer with largest remaining deficit
            // IMPORTANT: use ">" not ">=" so ties keep the first buyer found
            for (uint256 bi = 0; bi < buyersCount; bi++) {
                if (buyerAmt[bi] > maxDeficit) {
                    maxDeficit = buyerAmt[bi];
                    maxBuyerIdx = bi;
                }
            }

            uint256 maxSellerIdx = type(uint256).max;
            uint256 maxSurplus = 0;

            // Find seller with largest remaining surplus
            // IMPORTANT: use ">" not ">=" so ties keep the first seller found
            for (uint256 si = 0; si < sellersCount; si++) {
                if (sellerAmt[si] > maxSurplus) {
                    maxSurplus = sellerAmt[si];
                    maxSellerIdx = si;
                }
            }

            // No buyer left with deficit or no seller left with surplus
            if (maxDeficit == 0 || maxSurplus == 0) {
                break;
            }

            address buyer = buyers[maxBuyerIdx];
            Prosumer storage buyerP = prosumers[buyer];

            address seller = sellers[maxSellerIdx];
            Prosumer storage sellerP = prosumers[seller];

            uint256 cost = energyPrice; // 1 unit per step

            // The brief allows us to assume buyers have enough Ether
            require(buyerP.prosumerBalance >= cost, "Buyer has insufficient balance");

            buyerP.prosumerBalance -= cost;
            sellerP.prosumerBalance += cost;

            buyerP.prosumerEnergyStat += 1;
            sellerP.prosumerEnergyStat -= 1;

            buyerAmt[maxBuyerIdx] -= 1;
            sellerAmt[maxSellerIdx] -= 1;
            totalMatched += 1;
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