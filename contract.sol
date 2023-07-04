pragma solidity >=0.8.2 <0.9.0;


contract binaryLottery {

    uint public ticketPrice;
    uint public totalTickets;
    uint public soldTickets;

    address[][] public payable participants;
    uint[][] public hashes; 
    uint[][] public randomNumbers; // if not revealed yet, is it enough to just store a null?
    // TODO more efficient way to store data like mapping? 
    // Use one dimensional array if 2-dimensional not possible

    bool public started;
    bool public ended;
    uint public startTime;
    uint public roundsLeft;
    uint public timeForReveal = 1 minutes;
    uint public timeForBreak = 1 minutes; // TODO what is an appropriate time?

    address public owner;

    constructor(uint lotteryRounds, uint pricePerTicket) {
        owner = msg.sender;
        totalTickets = 1 << lotteryRounds; // 2^lotteryRounds
        ticketPrice = pricePerTicket;
        roundsLeft = lotteryRounds;
        //soldTickets = 0;
        //startedLottery = false;
    }

    function startLottery public {
        require(msg.sender == owner);
        require(soldTickets == totalTickets);
        require(!started);
        startTime = block.timestamp;
        started = true;
    }

    function hash(uint number, uint nonce) public pure returns (uint) {
        
    }

    // returns the tickets number
    function signUp() public payable returns (uint) {

    }

    function reveal(uint number, uint nonce) public {
        // call startNextRound()

        // check hash value for the current round and deermine winner
        // require(reveal-phase not ended)
        // update participant of next round
    }

    function withdrawPrize() public {
        // roundsleft == 0 AND currentPhase has to be over
    }

    // A player can withdraw from the lottery and get a refund if it has not started yet
    function refund() public {
       
    }

    function startNextRound() public {
        // currentRound++
    }

    // TODO consider case when one partcicipant buys several tickets
}