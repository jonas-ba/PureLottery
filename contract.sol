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
        uint randomNumberRight;
    }
    mapping (uint => mapping (uint => Match)) public matches; // matches[round][matchID] returns(Match)

    uint public ticketPrice;
    uint public totalTickets;
    uint[] public refundedTickets;

    uint public startTime;
    bool public started;
    uint public totalRounds;
    uint public currentRound;
    bool public breakOngoing;
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
        // TODO problem: if other players revealed before, it somehow influences if a player can also reveal
        require(started);
        refreshTimeConstraints();
        require(!breakOngoing, "Wait until the next round begines");
        stampTicket(ticketID, hash(randomNumber, nonce));
        updateMatch(randomNumber, ticketID);
    }

    function stampTicket(uint ticketID, bytes32 rndHash) private {
        Ticket memory ticket = tickets[ticketID];
        require(ticket.hashes[currentRound] == rndHash, 
            "randomNumber and nonce do not match the comitted hash");
        require(ticket.player == msg.sender);
        require(wonPreviousRound(ticketID));
        require(ticket.highestAdmittedRound == currentRound);
        ticket.highestAdmittedRound++;
        tickets[ticketID] = ticket;
    }

    function wonPreviousRound(uint ticketID) private view returns(bool) {
        if(currentRound == 0) {
            return true;
        } else {
            return isWinner(currentRound-1, ticketID);
        }
    }

    function isWinner(uint round, uint ticketID) private view returns (bool) {
        (uint matchID, bool left) = getMatchID(round, ticketID);
        Match memory assignedMatch = matches[round][matchID];
        uint rnd = assignedMatch.randomNumberLeft ^ assignedMatch.randomNumberRight; 
        bool even = rnd % 2 == 0;
        return left == even;
    }

    function updateMatch(uint randomNumber, uint ticketID) private {
        (uint nextMatchID, bool left) = getMatchID(currentRound, ticketID);
        Match storage currentMatch = matches[currentRound][nextMatchID];
        if(left) {
            currentMatch.randomNumberLeft = randomNumber;
        } else {
            currentMatch.randomNumberRight = randomNumber;
        }
    }

    function getMatchID(uint round, uint ticketID) public pure returns (uint, bool) {
        uint matchID = ticketID / (2 ** (round + 1));
        bool left = (ticketID / (2 ** round) % 2) == 0;
        return (matchID, left);
    }

    function withdrawPrize(uint ticketID) public {
        require(started);
        refreshTimeConstraints();
        require(currentRound >= totalRounds, "lottery not finished");
        uint finalRound = totalRounds - 1;
        require(isWinner(finalRound, ticketID));
        require(tickets[ticketID].player == msg.sender, "only the winner can wihdraw the prize");
        msg.sender.call{value: address(this).balance}("");
    }

    function refreshTimeConstraints() public {
        if(block.timestamp > startTime + TIME_FOR_REVEAL) {
            breakOngoing = true;
        }
        if(block.timestamp > startTime + TIME_FOR_REVEAL + TIME_FOR_BREAK) {
            startTime += (TIME_FOR_REVEAL + TIME_FOR_BREAK);
            breakOngoing = false;
            currentRound++;
            refreshTimeConstraints();
        }
    }

    function hash(uint number, uint nonce) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(number, nonce));
    }

}


// implementation details:
// cases not considere: if the two finalists do not reveal (or in round round no one reveals), the winner stays undetermined
// in this case, the left player is chosen

// further work: Implement arbitrary number of players and arbitrary probabilities

