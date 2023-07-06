pragma solidity >=0.8.2 <0.9.0;


contract lottery {

    struct Ticket {
        address payable player;
        uint highestParticpatedRound;
        bytes32[] hashes;
    }
    Ticket[] public tickets; // tickets[ticketID] returns(Ticket)

    struct Match {
        uint randomNumberLeft;
        uint randomNumberRight;
    }
    mapping (uint => mapping (uint => Match)) matches; // matches[round][matchID] returns(Match)

    uint public ticketPrice;
    uint public totalTickets;
    uint[] public refundedTickets;

    uint public startTime;
    bool public started;
    uint public totalRounds;
    uint public currentRound;
    bool public breakOngoing;
    uint public constant TIME_FOR_REVEAL = 1 minutes;
    uint public constant TIME_FOR_BREAK = 1 minutes;

    address public owner;
    address payable public winner;

    constructor(uint numberOfTickets, uint pricePerTicket) {
        totalRounds = log2(numberOfTickets);
        require(numberOfTickets == 2**totalRounds);
        owner = msg.sender;
        totalTickets = numberOfTickets;
        ticketPrice = pricePerTicket;
    }

    function log2(uint x) private pure returns (uint) {
        uint result = 0;
        while (x > 1) {
            x >>= 1;
            result++;
        }
        return result;
    }

    function signUp(bytes32[] calldata hashes) public payable returns (uint) {
        uint soldTickets = tickets.length - refundedTickets.length;
        require(hashes.length == totalRounds);
        require(soldTickets < totalTickets);
        require(msg.value == ticketPrice);
        require(!started);
        Ticket memory newTicket = Ticket(payable(msg.sender), 0, hashes);
        uint ticketNumber;
        if(refundedTickets.length == 0) {
            ticketNumber = tickets.length;
            tickets.push(newTicket);
        } else {
            ticketNumber = refundedTickets[refundedTickets.length-1];
            refundedTickets.pop();
            tickets[ticketNumber] = newTicket;
        }
        return ticketNumber;
    }

    // A player can withdraw from the lottery before the lottery starts
    function refund(uint ticketNumber) public {
        require(!started);
        require(msg.sender == tickets[ticketNumber].player);
        refundedTickets.push(ticketNumber);
        msg.sender.call{value: ticketPrice}("");
    }

    function startLottery() public {
        require(msg.sender == owner);
        require(allTicketsSold());
        require(!started);
        startTime = block.timestamp;
        started = true;
    }

    function allTicketsSold() private view returns (bool) {
        return tickets.length == totalTickets && refundedTickets.length == 0;
    }

    
    function reveal(uint ticketNumber, uint randomNumber, uint nonce) public {
        // TODO think this through
        refreshTimeConstraints();
        require(!breakOngoing);
        Ticket memory ticket = tickets[ticketNumber];
        require(ticket.player == msg.sender);
        require(ticket.hashes[currentRound] == hash(randomNumber, nonce));

        require(isWinner(currentRound, ticketNumber));
        (uint nextMatchID, bool left) = getMatchID(currentRound + 1, ticketNumber);
        Match memory nextMatch = matches[currentRound + 1][nextMatchID];
        if(left) {
            nextMatch.randomNumberLeft = randomNumber;
        } else {
            nextMatch.randomNumberRight = randomNumber;
        }

        require(ticket.highestParticpatedRound == currentRound - 1);

        if(currentRound == totalRounds - 1 && isWinner(currentRound, ticketNumber)) {
            winner = ticket.player;
        }
        ticket.highestParticpatedRound = currentRound;
    }

    function getMatchID(uint round, uint ticketID) private pure returns (uint, bool) {
        if(round == 0) {
            return (ticketID, ticketID % 2 == 0);
        }
        uint matchID = ticketID / (2**round);
        bool left = ticketID / (2**(round-1) ) % 2 == 0;
        return (matchID, left);
    }

    function isWinner(uint round, uint ticketID) private view returns (bool) {
        if(round == 0) {
            return true;
        }
        (uint matchID, bool left) = getMatchID(round, ticketID);
        Match memory assignedMatch = matches[round][matchID];
        uint rnd = assignedMatch.randomNumberLeft ^ assignedMatch.randomNumberRight; 
        bool even = rnd % 2 == 0;
        return left == even;
    }

    function withdrawPrize() public {
        refreshTimeConstraints();
        require(currentRound >= totalRounds);
        require(msg.sender == winner);
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