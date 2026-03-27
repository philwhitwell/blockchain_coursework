Your name:Philip Whitwell 
Your student ID: khzp0421

Your teammate's name: Mustafa Adaoglu
Your teammate's student ID: sc20m2a

## Description of the proposed coordination mechanism implemented in the coordinatedTrading() function (no more than 200 words):
The coordinateTrading() function redistributes surplus energy among prosumers in discrete steps. It first iterates through all registered prosumers, separating them into sellers (positive energy) and buyers (negative energy). Temporary memory arrays are used to store their addresses and corresponding surplus or deficit values, as memory is cheaper than storage for short-lived data.
Both groups are then sorted in descending order, prioritising the largest surpluses and deficits. The algorithm proceeds iteratively: in each step, the largest seller and largest buyer are matched, and one unit of energy is transferred. This updates both energy balances and transfers the corresponding payment.
The process continues until no surplus or deficit remains on either side. The total number of trades is tracked, and a CoordinationComplete event is emitted upon completion.
Test cases such as [1,1,1,-5,0,-4] → [0,0,0,-3,0,-3] and [8,-1,7,7,6,-1] → [6,0,7,7,6,0] were used to validate sorting and matching. Attempts to optimise by trading multiple units at once reduced correctness or increased gas usage, so a unit-step approach was retained.
To reduce gas costs, trades are accumulated in memory and written to blockchain state only once per participant at the end, minimising expensive storage operations while preserving correct energy and balance updates.



## Do you use any additional contract variables? If so, what is the purpose of each variable? (no more than 200 words):
An additional contract variable prosumerAddresses (an array of addresses) was introduced because Solidity mappings are not iterable. While the prosumers mapping stores the data associated with each prosumer, it is not possible to loop through all keys in a mapping. The prosumerAddresses array stores the address of every registered prosumer when they call registerProsumer(). This allows the contract to iterate over all participants when performing operations that require knowledge of the entire community, such as calculating the total community energy status in updateEnergyPrice() and identifying buyers and sellers during the coordinateTrading() process.

## Do you use any additional data structures (structs)? If so, what is the purpose of each structure? (no more than 200 words):
No additional structs were introduced in this implementation. The contract uses the Prosumer struct that was provided in the assignment specification. 

## Do you use any additional contract functions? If so, what is the purpose of each function? (no more than 200 words):
Yes. One additional internal helper function, _executeTrade(), was introduced to improve code organisation and reduce duplication. Both buyEnergyFrom() and sellEnergyTo() perform the same core actions: validating that the buyer and seller are registered prosumers, checking that the seller has sufficient surplus energy and the buyer has sufficient deficit and deposited balance, transferring the payment between accounts, and updating the energy status of both parties. Instead of repeating this logic in both functions, the _executeTrade() function performs the common settlement and validation steps. The two public trading functions simply call this helper with the appropriate buyer and seller addresses.

Using an internal function improves maintainability and readability of the contract. If the trade logic needs to be modified, the change only needs to be made in one place rather than duplicated across multiple functions. This approach also reduces the likelihood of inconsistencies or errors between the buy and sell implementations.
Not strictly functions but a number of events were introduced to track the key transactions in the contract. 
These were commented out in the final contract to improve performace.
    event EnergyPriceUpdated(uint256 newPrice, int256 totalEnergyStatus);
    event ProsumerRegistered(address indexed prosumer);
    event Deposit(address indexed prosumer, uint256 amount);
    event Withdraw(address indexed prosumer, uint256 amount);
    event EnergyStatusUpdated(address indexed prosumer,int256 deltaEnergy,int256 newEnergyStatus);
    event EnergyTraded(address indexed seller,address indexed buyer,uint256 energyAmount,uint256 unitPrice,uint256 totalCost);

Plus three modifiers were used to save repeating the same require statements in a number of functions
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

Your name:Philip Whitwell 
Your student ID: khzp0421

Your teammate's name: Mustafa Adaoglu
Your teammate's student ID: sc20m2a

## Description of the proposed coordination mechanism implemented in the coordinatedTrading() function (no more than 200 words):
The coordinateTrading() function redistributes surplus energy among prosumers in discrete steps. It first iterates through all registered prosumers, separating them into sellers (positive energy) and buyers (negative energy). Temporary memory arrays are used to store their addresses and corresponding surplus or deficit values, as memory is cheaper than storage for short-lived data.
Both groups are then sorted in descending order, prioritising the largest surpluses and deficits. The algorithm proceeds iteratively: in each step, the largest seller and largest buyer are matched, and one unit of energy is transferred. This updates both energy balances and transfers the corresponding payment.
The process continues until no surplus or deficit remains on either side. The total number of trades is tracked, and a CoordinationComplete event is emitted upon completion.
Test cases such as [1,1,1,-5,0,-4] → [0,0,0,-3,0,-3] and [8,-1,7,7,6,-1] → [6,0,7,7,6,0] were used to validate sorting and matching. Attempts to optimise by trading multiple units at once reduced correctness or increased gas usage, so a unit-step approach was retained.
To reduce gas costs, trades are accumulated in memory and written to blockchain state only once per participant at the end, minimising expensive storage operations while preserving correct energy and balance updates.



## Do you use any additional contract variables? If so, what is the purpose of each variable? (no more than 200 words):
An additional contract variable prosumerAddresses (an array of addresses) was introduced because Solidity mappings are not iterable. While the prosumers mapping stores the data associated with each prosumer, it is not possible to loop through all keys in a mapping. The prosumerAddresses array stores the address of every registered prosumer when they call registerProsumer(). This allows the contract to iterate over all participants when performing operations that require knowledge of the entire community, such as calculating the total community energy status in updateEnergyPrice() and identifying buyers and sellers during the coordinateTrading() process.

## Do you use any additional data structures (structs)? If so, what is the purpose of each structure? (no more than 200 words):
No additional structs were introduced in this implementation. The contract uses the Prosumer struct that was provided in the assignment specification. 

## Do you use any additional contract functions? If so, what is the purpose of each function? (no more than 200 words):
Yes. One additional internal helper function, _executeTrade(), was introduced to improve code organisation and reduce duplication. Both buyEnergyFrom() and sellEnergyTo() perform the same core actions: validating that the buyer and seller are registered prosumers, checking that the seller has sufficient surplus energy and the buyer has sufficient deficit and deposited balance, transferring the payment between accounts, and updating the energy status of both parties. Instead of repeating this logic in both functions, the _executeTrade() function performs the common settlement and validation steps. The two public trading functions simply call this helper with the appropriate buyer and seller addresses.

Using an internal function improves maintainability and readability of the contract. If the trade logic needs to be modified, the change only needs to be made in one place rather than duplicated across multiple functions. This approach also reduces the likelihood of inconsistencies or errors between the buy and sell implementations.
Not strictly functions but a number of events were introduced to track the key transactions in the contract. 
These were commented out in the final contract to improve performance.
  ```  
    event EnergyPriceUpdated(uint256 newPrice, int256 totalEnergyStatus);
    event ProsumerRegistered(address indexed prosumer);
    event Deposit(address indexed prosumer, uint256 amount);
    event Withdraw(address indexed prosumer, uint256 amount);
    event EnergyStatusUpdated(address indexed prosumer,int256 deltaEnergy,int256 newEnergyStatus);
    event EnergyTraded(address indexed seller,address indexed buyer,uint256 energyAmount,uint256 unitPrice,uint256 totalCost);
  ```  
Plus three modifiers were used to save repeating the same require statements in a number of functions
  ```  
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
        
```

## Did you implement any additional test cases to test your smart contract? If so, what are these tests?
We implemented a battery of unit tests as well as integration testing for the coordination mechanism.

### Unit Tests
Below we list out the additional unit tests we added.

#### registerProsumer() Test
- Check that registered prosumer cannot register again

#### sellEnergyTo() Tests
- Valid selling transaction
- Cannot sell to buyer with insufficient balance
- Don't allow sell to self
- Don't allow unregistered user to sell
- Don't allow registered user to sell to unregistered user
- Cannot sell 0 energy
- Don't allow seller with no surplus to sell
- Don't sell to buyer in suprlus or not in deficit
- Seller cannot oversell

#### buyEnergyFrom() Tests
- Registered prosumer with sufficient balance should be able to buy form registered user in surplus
- Registered prosumer with sufficient balance should be able to buy exactly their deficit
- Don't allow user with surplus to buy
- Don't allow user with net 0 to buy
- Don't allow buy from user with no surplus
- Don't allow buying more than the seller has
- Don't allow buying more than deficit
- Don't allow unregistered user to buy
- Don't allow registered user to buy from unregistered user
- Don't allow buy from self
- Cannot request to buy 0 energy
- Don't allow buying more than balance

#### withdraw() Tests
- Withdraw when energy surplus and sufficient balance
- Withdraw when net 0, sufficient balance
- Don't allow unregistered account to withdraw
- Don't allow attempt to withdraw 0
- Don't allow attempt to withdraw with energy deficit
- Don't allow attempt to withdraw with insufficient blaance

#### coordinateTrading() tests
- Test case/data from brief
- Coordination when all net zero
- No surplus, all deficit
- No deficit, all surplus
- Equal negative, equal positive, all zero after coordination
- More surplus than deficit
- More deficit than surplus
- Check optimal low variance after coordination
    -   before = [-2, 4, 4, 0, 0], after = [0, 3, 3, 0, 0]

### Integration Testing
For integration testing we used the [Open Power System Data household dataset](https://www.kaggle.com/datasets/youssefboutaleb/ausgrid-2024?resource=download)

#### Coordination Tests
We wrote a Python/Pandas script to extract net household energy (generated - consumed) data for 6 households for 23 time periods, from 7:00 to 18:00 in 30 minute intervals.  6 households were chosen to make hand calculation of expected values more manageable and less error-prone.

The energy measurements in the dataset are in floating point kWh values, but the contract assumes energy in integer "units". We used a floor method to convert the floating point values to integers.
Below is a sample output of processing the dataset:
```
Time 11:30
net_each_household = [2, 1, 1, 1, 1, -1]
----------------------------------------
Time 12:00
net_each_household = [2, -2, 1, 1, 1, -2]
----------------------------------------
Time 12:30
net_each_household = [2, -3, 1, 1, 1, -2]
```

We use this data to create a simulation of the trading, in the following loop over the time periods, starting with a net energy of 0. The expected states after coordination are worked out in advance by hand.
1. Update net energy of each household using data from the dataset.
2. Call coordinateTrading function
3. Assert that the actual value is equal to expected.

#### Update Energy Price tests
Similar to the coordination tests, we use the dataset to get sample net household energy values. For this test, we use Wh instead of kWh to get a wider "spread" of energy price changes.
We use this data to test the updateEnergyPrice function, in the following loop over the time periods, starting with a net energy of 0. The expected energy prices are worked out in advance by hand.
1. Update net energy of each household using data from the dataset.
2. Call updateEnergyPrice function
3. Assert that the actual value is equal to expected.
