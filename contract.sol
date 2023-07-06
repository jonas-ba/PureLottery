pragma solidity >=0.8.2 <0.9.0;


contract lottery {

    struct Ticket {
        address payable player;
        uint reachedRound;
        bytes32[] hashes;
    }
    struct Ticket[] public tickets; // tickets[ticketID] returns(Ticket)

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

    function signUp(bytes32[] hashes) public payable returns (uint) {
        soldTickets = tickets.length - refundedTickets.length;
        require(hashes.length == totalRounds)
        require(soldTickets < totalTickets);
        require(msg.value == ticketPrice);
        require(!started);
        Ticket ticket = Ticket(payable(msg.sender), 0, hashes);
        uint ticketNumber;
        if(refundedTickets.length == 0) {
            ticketnumber = players.length;
            tickets.push(ticket);
        } else {
            ticketNumber = redundedTickets.pop();
            tickets[tickerNumber] = ticket;
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
        return tickets.length == totalTickets & refundedTickets.length == 0;
    }

    
    function reveal(uint ticketNumber, uint randomNumber, uint nonce) public {
        refreshTimeConstraints();
        require(!breakOngoing);
        Ticket ticket = tickets[tickerNumber];
        require(ticket.player == msg.sender);
        require(ticket.hashes[currentRound] == hash(randomNumber, nonce));







        uint round = ticket.round;
        uint matchID = ticket.matchID;
        Match lastMatch = getMatch(round, matchID);
        require(lastMatch.winner == msg.sender);

        Match thisMatch = getMatch(round++, matchID/2);
        if(matchID % 2 == 0) {
            uint rndOfOpponent = thisMatch.randomNumber2 = randomNumber;
        } else {
            uint rndOfOpponent = thisMatch.randomNumber2 = randomNumber;
        }
        if(rndOfOpponent == 0) {
            thisMatch.winner = msg.sender;
        } else if(rndOfOpponent < randomNumber) {
            thisMatch.winner = msg.sender;
        } else {
            thisMatch.winner = players[ticketNumber];
        }
        ticket.round = round++;
        ticket.matchID = matchID/2; // TODO make this more efficient by using memory
    }

    function getMatchID(uint round, uint ticketID) private pure returns (uint matchID, bool left) {
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
        Match match = matches[round][matchID];
        uint rnd = match.randomNumberLeft 
        if(left) {
            return match.randomNumberLeft == 0;
        } else {
            return match.randomNumberRight == 0;
        }
    }

    function withdrawPrize() public {
        refreshTimeConstraints();
        require(currentRound == totalRounds + 1);
        uint winnerTicket = matches[totalRounds][0];
        address payable winner = players[winnerTicket]; // TODO
        require(msg.sender == winner);
        msg.sender.call{value: address(this).balance}("");
    }

    function refreshTimeConstraints() public {
        if(block.timestamp > startTime + TIME_FOR_REVEAL) {
            breakOngoing = true;
        }
        if(block.timestamp > startTime + TIME_FOR_REVEAL + TIME_FOR_BREAK) {
            startTime =+ TIME_FOR_REVEAL + TIME_FOR_BREAK;
            breakOngoing = false;
            currentRound++;
            refreshTimeConstraints();
        }
    }

    function hash(uint number, uint nonce) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(number, nonce));
    }

}

// TODO public/private, restructure code, comment, copilot suggestions, split into 2 contracts (signup and reveal)

// TODO questions:
// what is an appropriate time for TIME_FOR_REVEAL and TIME_FOR_BREAK
