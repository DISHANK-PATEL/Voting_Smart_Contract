// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

contract election
{
    address election_commission;// No doubt the election commision is private that doesnt mean that its confidential it just means that its access is private
    address public winner;
    uint public next_voter_id = 1;
    uint public next_candidate_id = 1;
    uint public start_time; // Required to know the duration when the election starts and ends
    uint public end_time;
    bool public stop_voting;
    
    constructor()
    {
        election_commission = msg.sender;
        // msg.sender is the global variable 
        // As soon as we deploy the contract the constructor is called and the control is passed over to election commision
        // Election commision is actually assigned the address which deploys the contract
    }
    
    enum Gender {Not_specified, Male, Female, Other}
    enum voting_status {Not_specified, Not_started, InProgress, Ended}
    
    mapping(uint => voter) public voter_details;
    mapping(uint => candidate) public candidate_details; // map is used to fetch the data in O(1) time complexity

    modifier is_voting_over()
    {
        // Note: block.timestamp is also a global variable
        // This timestamp is set by the miner of the block and is typically the Unix epoch time (number of seconds since January 1, 1970)
        // Note: Its not very accurate and reliable 
        // For applications requiring precise timekeeping
        // You can use decentralized oracles to provide reliable and accurate time data to your smart contracts 
        // Oracles are third-party services that fetch real-world data and provide it to the blockchain.
        // Chainlink: A popular decentralized Oracle network that can be used to get accurate time data.
        require(block.timestamp <= end_time && !stop_voting, "Voting is over");
        _;
        // The "_" symbol is a placeholder where the rest of the function body will be inserted and executed if the condition is met.
    }
    
    // Modifier is used so that you dont have to use the require statement again and again in the every function
    modifier is_commissioner()
    {
        // Only the election commission should have the control
        require(msg.sender == election_commission, "You dont have authority");
        _;
    }

    modifier age_check(uint _age)
    {
        require(_age >= 18, "You are below Age!");
        _;
    }

    struct voter
    {
        string name;
        uint age; // unsigned integer is used since the age cannot be negative
        Gender gender;
        uint voter_id;
        address voter_address;
        uint voted_candidate_id; // Its the candidate id whom the voter has voted
    }

    struct candidate
    {
        string name;
        string party_name;
        uint age;
        uint votes;
        address candidate_address;
        Gender gender;
        uint candidate_id;
    }
    
    // Types of Visibility specifiers:
    // PUBLIC:   Can be internal as well as external
    // INTERNAL: Can only be called within the contract or from the derived contract
    // EXTERNAL: They are part of the contract but can be called from outside the contract
    // Note: To call them internally we need to use the this keyword
    // PRIVATE: Can be called within the same contract itself
    
    // Types of Memory Locations:
    // MEMORY: Memory is used for variables that are only needed temporarily
    //        Such as function arguments, local variables, or arrays that are created dynamically during the execution of a function.
    //        Once the function execution is complete, the memory space is freed up
    // CALLEDATA: Calldata is used for function arguments that are passed in from an external caller 
    //          Such as a user or another smart contract. Calldata is read-only, meaning that it cannot be modified by the function.
    // STORAGE: Storage is used to permanently store data on the blockchain. This data can be accessed and modified by any function within the contract.

    // Use Calldata (immutable) and Storage (mutable)  
    function register_candidate(string calldata _name, string calldata _party, uint _age, Gender _gender) age_check(_age) external 
    {
        require(is_candidate_not_registered(msg.sender), "You are already registered");
        require(msg.sender != election_commission, "Election commision cannot register");
        require(next_candidate_id < 3, "Candidate registration is full");
        
        candidate_details[next_candidate_id] = candidate(_name, _party, _age, 0, msg.sender, _gender, next_candidate_id); // Using the constructor to store all detail in object and then into the map
        // Note: Here the order of passing the entities to the constructor should be same as that of struct
        // To avoid any error due to wrong order prefer the below method like in the register_voter
        next_candidate_id++;
    }
    
    // In the above case if we make the function public then also it works
    // But the main reasons to use External over public are:
    // Firstly we are not registering any candidate inside the contract
    // Calling each function, we can see that the public function uses 496 gas 
    // while the external function uses only 261. 
    // The difference is because in public functions, Solidity immediately copies array arguments to memory
    // While external functions can read directly from calldata

    function register_voter(string calldata _name, uint _age, Gender _gender) age_check(_age) external
    {
        require(Not_yet_voted(msg.sender), "You have only voted");
        
        voter_details[next_voter_id] = voter({
            name: _name,
            voter_id: next_voter_id,
            age: _age,
            gender: _gender, // In this way the order change wont give any error
            voter_address: msg.sender,
            voted_candidate_id: 0
        });

        next_voter_id++;
    } 

    function is_candidate_not_registered(address _person) internal view returns (bool)
    {
        for (uint i = 1; i < next_candidate_id; i++)
        {
            if (candidate_details[i].candidate_address == _person)
                return false;
        }
        return true;
    }
    
    function Not_yet_voted(address _person) internal view returns (bool)
    {
        for (uint i = 1; i < next_voter_id; i++)
        {
            if (voter_details[i].voter_address == _person)
                return false;
        }
        return true;
    }

    function get_candidate_details() public view returns (candidate[] memory)
    {
        candidate[] memory candidates_info = new candidate[](next_candidate_id - 1);
        for (uint i = 0; i < candidates_info.length; i++)
            candidates_info[i] = candidate_details[i + 1];
        return candidates_info;
    }

    function get_voter_list() public view returns (voter[] memory)
    {
        voter[] memory voter_info = new voter[](next_voter_id - 1);
        for (uint i = 0; i < voter_info.length; i++)
            voter_info[i] = voter_details[i + 1];
        return voter_info;
    }

    // Key reasons why mappings cannot be returned in Solidity:
    // STORAGE LAYOUT:  Mappings in Solidity are implemented as hash tables without a defined order or structure that supports iteration or enumeration.
    // GAS COSTS:       Returning a potentially large amount of data from a mapping would result in high gas costs, making such operations impractical and expensive.
    // UNDEFINED SIZE:  Mappings do not maintain information about the number of key-value pairs they contain, which makes it impossible to return the entire mapping efficiently.
    // NO ENUMERATION:  The EVM does not support enumerating over mappings directly, preventing the ability to iterate over and return all keys and values in a mapping.
    // EFFICIENCY:      Solidity is designed to optimize for gas efficiency and security, and allowing mappings to be returned would go against these principles due to the complexities involved.
    
    function cast_vote(uint _voter_id, uint _voted_candidate_id) external is_voting_over
    {
        require(voter_details[_voter_id].voted_candidate_id == 0, "You have already voted");
        require(msg.sender == voter_details[_voter_id].voter_address, "You are not authorized");
        
        voter_details[_voter_id].voted_candidate_id = _voted_candidate_id; // Updated the voter
        candidate_details[_voted_candidate_id].votes++; // Increase votes of the candidate chosen
    }

    function set_voting_period(uint start_time_duration, uint end_time_duration) is_commissioner external
    {
        require(end_time_duration > 3600, "Voting period must be more than 1 hour");
        
        start_time = block.timestamp + start_time_duration; // Voting starts after start_time_duration after the function is called
        end_time = start_time + end_time_duration; // Voting ends after the end_time_duration after the voting starts
    }

    function get_voting_status() public view returns (voting_status)
    {
        if (start_time == 0) return voting_status.Not_started;
        else if (block.timestamp < end_time && !stop_voting) return voting_status.InProgress;
        else return voting_status.Ended;
    }

    function announce_winner() is_commissioner external
    {
        uint max_votes = 0;
        for (uint i = 1; i < next_candidate_id; i++)
        {
            if (candidate_details[i].votes > max_votes)
            {
                max_votes = candidate_details[i].votes;
                winner = candidate_details[i].candidate_address; // The winner of the election will be the candidate with maximum votes
            }
        }
    }

    function emergency_stop_voting() is_commissioner external
    {
        stop_voting = true;
    }
}
