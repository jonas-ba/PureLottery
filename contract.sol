
// further work: 
// - Implement arbitrary number of players and arbitrary probabilities (the extended version of the lottery algorithm)
// - use address instead of ticket number to simplify functions (--> in the revealing process, store the player in the matches)



pragma solidity >=0.8.2 <0.9.0;


contract Lottery {

    struct Ticket {
        address payable player;
        uint highestAdmittedRound;
        bytes32[] hashes;
    }
    Ticket[] public tickets; // tickets[ticketID] returns(Ticket)

    struct Match {
        uint randomNumberLeft;
        bool revealedLeft;
        uint randomNumberRight;
        bool revealedRight;
    }
    mapping (uint => mapping (uint => Match)) public matches; // matches[round][matchID] returns(Match)

    uint public ticketPrice;
    uint public totalTickets;
    uint[] public refundedTickets;

    uint public startTime;
    bool public started;
    uint public totalRounds;
    uint public constant TIME_FOR_REVEAL = 30 seconds; // default 1 minutes;
    uint public constant TIME_FOR_BREAK = 0; // default 1 minutes;

    address public owner;
    address payable public winner;

    constructor(uint numberOfTickets, uint pricePerTicket) {
        totalRounds = log2(numberOfTickets);
        require(numberOfTickets >= 2, "at least 2 tickets required");
        require(numberOfTickets == 2**totalRounds, "numberOfTickets has to be a power of two");
        owner = msg.sender;
        totalTickets = numberOfTickets;
        ticketPrice = pricePerTicket;
        refundedTickets;
    }

    function log2(uint x) private pure returns (uint) {
        uint result = 0;
        while (x > 1) {
            x >>= 1;
            result++;
        }
        return result;
    }

    function signUp(bytes32[] calldata hashedRandomNumbers) public payable returns (uint) {
        uint soldTickets = tickets.length - refundedTickets.length;
        require(hashedRandomNumbers.length == totalRounds, 
            "hash-array has to contain exactly 'totalRounds' elements");
        require(soldTickets < totalTickets, "No tickets left");
        require(msg.value == ticketPrice, "message value not equal to ticket price");
        require(!started, "no sign-up possible anymore, the game already started");
        Ticket memory newTicket = Ticket(payable(msg.sender), 0, hashedRandomNumbers);
        uint ticketID;
        if(refundedTickets.length == 0) {
            ticketID = tickets.length;
            tickets.push(newTicket);} 
         else {
            ticketID = refundedTickets[refundedTickets.length-1];
            refundedTickets.pop();
            tickets[ticketID] = newTicket;}
        return ticketID;
    }

    function refund(uint ticketID) public {
        require(!started, "No refund possible because the game already started");
        require(msg.sender == tickets[ticketID].player);
        refundedTickets.push(ticketID);
        msg.sender.call{value: ticketPrice}("");
    }

    function startLottery() public {
        require(msg.sender == owner);
        require(tickets.length == totalTickets && refundedTickets.length == 0, 
            "All tickets must be sold before starting");
        require(!started);
        startTime = block.timestamp;
        started = true;
    }

    function reveal(uint ticketID, uint randomNumber, uint nonce) public {
        (uint currentRound, bool revealingAllowed) = getCurrentRound();
        require(revealingAllowed, "Wait until the next round begines");
        checkTicket(ticketID, hash(randomNumber, nonce), currentRound);
        updateMatch(randomNumber, ticketID, currentRound);
    }

    function checkTicket(uint ticketID, bytes32 rndHash, uint currentRound) private {
        Ticket memory ticket = tickets[ticketID];
        require(ticket.hashes[currentRound] == rndHash, 
            "randomNumber and nonce do not match the comitted hash");
        require(ticket.player == msg.sender);
        require(currentRound == 0 || isWinner(currentRound-1, ticketID), 
            "ticket must have won in the previous round");
        require(ticket.highestAdmittedRound == currentRound);
        ticket.highestAdmittedRound++;
        tickets[ticketID] = ticket;
    }

    function isWinner(uint round, uint ticketID) private view returns (bool) {
        if(tickets[ticketID].highestAdmittedRound < round+1) {
            return false;
        }
        (uint matchID, bool left) = getMatchID(round, ticketID);
        Match memory assignedMatch = matches[round][matchID];
        // if both players did not reveal, the left player winns
        if(!assignedMatch.revealedRight) {
            return left;
        }
        if(!assignedMatch.revealedLeft) {
            return !left;
        }
        uint rnd = assignedMatch.randomNumberLeft ^ assignedMatch.randomNumberRight; 
        bool even = rnd % 2 == 0;
        return left == even;
    }

    function updateMatch(uint randomNumber, uint ticketID, uint currentRound) private {
        (uint nextMatchID, bool left) = getMatchID(currentRound, ticketID);
        Match storage currentMatch = matches[currentRound][nextMatchID];
        if(left) {
            currentMatch.randomNumberLeft = randomNumber;
            currentMatch.revealedLeft = true;
        } else {
            currentMatch.randomNumberRight = randomNumber;
            currentMatch.revealedRight = true;
        }
    }

    function getMatchID(uint round, uint ticketID) public pure returns (uint, bool) {
        uint matchID = ticketID / (2 ** (round + 1));
        bool left = (ticketID / (2 ** round) % 2) == 0;
        return (matchID, left);
    }

    function withdrawPrize(uint ticketID) public {
        (uint currentRound, ) = getCurrentRound();
        require(currentRound >= totalRounds, "lottery not finished");
        uint finalRound = totalRounds - 1;
        require(isWinner(finalRound, ticketID));
        require(tickets[ticketID].player == msg.sender, "only the winner can wihdraw the prize");
        msg.sender.call{value: address(this).balance}("");
    }

    function getCurrentRound() public view returns(uint, bool) {
        require(started);
        uint duration = block.timestamp - startTime;
        uint period = TIME_FOR_REVEAL + TIME_FOR_BREAK;
        uint currentRound = duration / period;
        bool revealingAllowed = (duration - (currentRound * period)) <= TIME_FOR_REVEAL;
        return (currentRound, revealingAllowed);
    }

    function hash(uint number, uint nonce) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(number, nonce));
    }

}

