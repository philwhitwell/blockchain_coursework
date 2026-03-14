Your name:Philip Whitwell 
Your student ID: khzp0421

Your teammate's name: Mustafa Adaoglu
Your teammate's student ID: sc20m2a

## Description of the proposed coordination mechanism implemented in the coordinatedTrading() function (no more than 200 words):
The coordination mechanism repeatedly matches the prosumer with the largest energy deficit (buyer) with the prosumer holding the largest energy surplus (seller). Each trade transfers one unit of energy and the system re-evaluates all prosumers after every trade. This approach ensures that the most extreme surplus and deficit are always prioritised, which helps minimise the overall imbalance in the community. Performing trades one unit at a time also improves fairness in tie situations. 
For example, starting from [-2, 4, 4, 0, 0], unit-by-unit re-evaluation produces [0, 3, 3, 0, 0], which distributes the reduction evenly across the two largest sellers. A batched approach could instead produce [0, 2, 4, 0, 0], which has higher variance and is therefore less balanced. Although batching could reduce gas consumption, the assignment prioritises balanced outcomes over gas efficiency, so the unit-by-unit coordination strategy was chosen.

## Do you use any additional contract variables? If so, what is the purpose of each variable? (no more than 200 words):
An additional contract variable prosumerAddresses (an array of addresses) was introduced because Solidity mappings are not iterable. While the prosumers mapping stores the data associated with each prosumer, it is not possible to loop through all keys in a mapping. The prosumerAddresses array stores the address of every registered prosumer when they call registerProsumer(). This allows the contract to iterate over all participants when performing operations that require knowledge of the entire community, such as calculating the total community energy status in updateEnergyPrice() and identifying buyers and sellers during the coordinateTrading() process.

## Do you use any additional data structures (structs)? If so, what is the purpose of each structure? (no more than 200 words):
No additional structs were introduced in this implementation. The contract uses the Prosumer struct that was provided in the assignment specification. 

## Do you use any additional contract functions? If so, what is the purpose of each function? (no more than 200 words):
Yes. One additional internal helper function, _executeTrade(), was introduced to improve code organisation and reduce duplication. Both buyEnergyFrom() and sellEnergyTo() perform the same core actions: validating that the buyer and seller are registered prosumers, checking that the seller has sufficient surplus energy and the buyer has sufficient deficit and deposited balance, transferring the payment between accounts, and updating the energy status of both parties. Instead of repeating this logic in both functions, the _executeTrade() function performs the common settlement and validation steps. The two public trading functions simply call this helper with the appropriate buyer and seller addresses.

Using an internal function improves maintainability and readability of the contract. If the trade logic needs to be modified, the change only needs to be made in one place rather than duplicated across multiple functions. This approach also reduces the likelihood of inconsistencies or errors between the buy and sell implementations.
Not strictly functions but a number of events were introduced to track the key transactions in the coordinated trading process.

    event EnergyPriceUpdated(uint256 newPrice, int256 totalEnergyStatus);
    event ProsumerRegistered(address indexed prosumer);
    event Deposit(address indexed prosumer, uint256 amount);
    event Withdraw(address indexed prosumer, uint256 amount);
    event EnergyStatusUpdated(address indexed prosumer,int256 deltaEnergy,int256 newEnergyStatus);
    event EnergyTraded(address indexed seller,address indexed buyer,uint256 energyAmount,uint256 unitPrice,uint256 totalCost);

Plus three modifiers to save repeating the same reqquire statements in a number of functions
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


## Did you implement any additional test cases to test your smart contract? If so, what are these tests?
<!-- Example: My contract passed an additional test case of ...  --
