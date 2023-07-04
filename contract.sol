pragma solidity >=0.8.2 <0.9.0;


contract binaryLottery {

    uint public ticketPrice;
    uint public totalTickets;
    uint public soldTickets;

    address payable[] public players; // ticket number -> player address
    // (ticket, round) -> match in the next round ???
    mapping (uint => mapping (uint => uint)) results; // results[round][match] --> ticket number TODO built view functions to make code easier readable
    mapping(uint => mapping (uint => bytes32)) hashes; // access via hashes[ticket][round] --> hash
    mapping(uint => mapping (uint => uint)) randomNumbers; // access via randomNumbers[ticket][round] --> rnd number
    // if not revealed yet, is it enough to just store a null?

    uint public startTime;
    bool public started;
    bool public ended;
    uint public rounds;
    uint public currentRound;
    bool public breakActive;
    uint public constant TIME_FOR_REVEAL = 1 minutes;
    uint public constant TIME_FOR_BREAK = 1 minutes; // TODO what is an appropriate time?

    address public owner;

    constructor(uint lotteryRounds, uint pricePerTicket) {
        owner = msg.sender;
        totalTickets = 1 << lotteryRounds; // 2^lotteryRounds
        ticketPrice = pricePerTicket;
        rounds = lotteryRounds;
        //soldTickets = 0;
        //startedLottery = false;
    }

    // returns the ticket number
    function signUp(bytes32[rounds] hashesForEveryRound) public payable returns (uint) {
        require(msg.value == ticketPrice);
        require(soldTickets < totalTickets);
        require(!started);
        players.push(payable(msg.sender));
        soldTickets++;
        uint ticketNumber = players.length - 1;
        for(uint i = 0; i < rounds; i++) {
            hashes[ticketNumber][i] = hashesForEveryRound[i];
        }
        return ticketNumber;
    }

    // A player can withdraw from the lottery and get a refund if it has not started yet
    function refund(uint ticketNumber) public {
        require(!started);
        require(msg.sender == players[ticketNumber]);
        soldTickets--;
        players[ticketNumber] = 0;
        (bool sent, ) = msg.sender.call{value: ticketPrice}("");
        require(sent); // is this necessary? If the money transfer fails, the player is forced to stay in the lottery
    }

    function startLottery() public {
        require(msg.sender == owner);
        require(soldTickets == totalTickets);
        require(!started);
        startTime = block.timestamp;
        started = true;
    }
    // alternative implementation: start lottery when all tickets are sold

    // TODO
    function reveal(uint ticketNumber uint randomNumber, uint nonce) public {
        //require(players[ticketNumber] == msg.sender);
        refreshTimeConstraints();
        require(!breakActive);
        require(hashes[tickerNumber][currentRound] == hash(randomNumber, nonce));
        randomNumbers[ticketNumber][currentRound] = randomNumber;
        // TODO
        // require: ticket is in results for current round
        // update ticket of next round

        // does an alternative state variable make more sense? (ticket, round) -> match in the next round
        // this would be computationally less intensive, because index does not have to be computed
    }

    function withdrawPrize() public {
        refreshTimeConstraints();
        require(ended);
        uint winnerTicketNumber = results[0][0];
        require(msg.sender == players[winnerTicketNumber]);
        msg.sender.call{value: address(this).balance}("");
    }

    function refreshTimeConstraints() public {
        if(block.timestamp > startTime + TIME_FOR_REVEAL) {
            breakActive = true;
        }
        if(block.timestamp > startTime + TIME_FOR_REVEAL + TIME_FOR_BREAK) {
            startTime =+ TIME_FOR_REVEAL + TIME_FOR_BREAK;
            breakActive = false;
            roundsLeft--;
            refreshTimeConstraints();
        }
        if(roundsLeft == 0 & block.timestamp > startTime + TIME_FOR_REVEAL) {
            ended = true;
        }
    }

    function hash(uint number, uint nonce) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(number, nonce));
    }

}
