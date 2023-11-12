/*

This code is a proof-of-concept implementation of the leader election protocol described in the paper.
The IEEE Blockchain'2023 paper accompaning this piece of code can be accessed here:
https://hal.science/hal-04268058/

This code is released into public domain under Creative Commons Zero v1.0 Universal license.

Disclaimer: 
The code comes with no warranty, even the implied warranty of correctness 
or fitness for a particular purpose, and we assume no liability for any losses incurred 
as a result of deploying it. 

*/


pragma solidity >=0.8.2 <0.9.0;

import "hardhat/console.sol";

enum Stage {signup, commit_reveal, end}

struct Tournament {
    uint totalPlayers;
    uint currentRound;
    uint totalRounds;
    mapping (address => uint) positions; // every player is asigned a unique position
    mapping (address => uint) achievedRounds;
    mapping (address => uint) revealedRounds; //to_reveal_round; // revealed round + 1
    mapping (uint => mapping (uint => address)) playersTree; // playersTree[position][round]
    mapping (uint => mapping (uint => uint)) weights; // weights[position][round]
    mapping (address => uint) randomNumbers; // player's random number for the current round
}

/* 

'round' is like the y-coordinate in the tree
'position' is like the x-coordinate in the tree

Scheme of playersTree with 5 players:

                                                 __________winner___________
round 2                                         /                           \
                                 _position 0/1/2/3__                        position 4
round 1                         /                   \                           |
                    position 0/1                    position 2/3            position 4
round 0             /           \                   /       \                   |
            position 0      position 1      position 2      position 3      position 4      <-- every player starts at this level

*/


library Math {

    // computes the logarithm base 2 and rounds up to the next integer
    function log2up(uint x) public pure returns (uint) {
        uint result = 0;
        uint powerOfTwo = 1;
        while(powerOfTwo < x) {
            powerOfTwo *= 2;
            result++;
        }
        return result;
    }

    function even(uint x) public pure returns(bool) {
        return x % 2 == 0;
    }
}


library CreateTournament {
    // adds an additional player to the tournament
    function addPlayer(Tournament storage tournament, address player) public {
        require(!playerRegistered(tournament, player), "Player already exists");
        tournament.positions[player] = tournament.totalPlayers;
        tournament.playersTree[tournament.totalPlayers][0] = player;
        tournament.totalPlayers++;
        incrementTreeHeight(tournament);
    }

    function incrementTreeHeight(Tournament storage tournament) private {
        uint newTotalRounds = Math.log2up(tournament.totalPlayers);
        uint totalRounds = tournament.totalRounds;
        if(newTotalRounds > totalRounds) {
            tournament.totalRounds = newTotalRounds;
            tournament.weights[0][newTotalRounds] = tournament.weights[0][totalRounds] + tournament.weights[1][totalRounds];
        }
    }

    // determines if the player has been added already
    function playerRegistered(Tournament storage tournament, address player) public view returns(bool) {
        // assume address(0) is never used
        return tournament.playersTree[tournament.positions[player]][0] == player;
    }

    // adds weight to a player and hence increases its chance to win
    // O(log(n)) for player n. 
    // If in another setting that totalPlayers is known in advance, average cost per player is O(1). 
    // Otherwise in the current setting, average cost per player is O(log(N)). 
    function addWeight(Tournament storage tournament, address player, uint weight) public {
        require(playerRegistered(tournament, player), "Player had to be added before adding weight");
        uint position = tournament.positions[player];
        for (uint round=0; round <= tournament.totalRounds; round++) 
        {
            tournament.weights[position][round] += weight;
            position = position / 2;
        }
    }

    // removes a players weight (and hence also eliminates its chance to win)
    function removeWeight(Tournament storage tournament, address player) public returns(uint) {
        uint position = tournament.positions[player];
        uint weight = tournament.weights[position][0];
        for (uint round=0; round <= tournament.totalRounds; round++) 
        {
            tournament.weights[position][round] -= weight;
            position = position/2;
        } 
        return weight;
    }
}


library RunTournament {
    using Math for uint;
    using CreateTournament for Tournament;
   
    // determines victory for the current round based on a random number
    // 1. if the player has no opponent in the current round, he wins
    // 2. if the player has an opponent, but the opponent has not revealed, record his random number and mark him as temporary winner
    // 3. if the player has an opponent, and the opponent also revealed, compare the random number and set the winner
    function compete(Tournament storage tournament, address player, uint randomNumber) public {
        // check that the player participates in the tournament
        require(tournament.playerRegistered(player));
        // check the player is eligible at the current round
        require(tournament.achievedRounds[player]==tournament.currentRound);
        // check the player has not revealed at the current round
        require(tournament.revealedRounds[player]==tournament.currentRound);
        
        tournament.randomNumbers[player] = randomNumber;
 
        if(hasNoAdversary(tournament, player)) {
            storeWin(tournament, player, address(0));
            return;
        }
        address adversary = getAdversary(tournament, player);
        if(hasRevealed(tournament, adversary)) {
            if(playerWinsRound(tournament, player, randomNumber, adversary)) {
                storeWin(tournament, player, adversary);
            }
        } else {
            storeWin(tournament, player, adversary);
        }
    }

    // if true, the player gets into the next round without competing
    function hasNoAdversary(Tournament storage tournament, address player) private view returns(bool) {
        // there are two cases when a player has no adversary
        // 1) players in the adversary branch did not reveal and hence did not reach the current round
        address adversary = getAdversary(tournament, player);
        if(adversary == address(0)) {
            return true;
        }
        // 2) the player is in the last position and due to an uneven number of player he has none to match
        // a maximum of one player in every round may have no adversary
        uint currentPosition = getPosition(tournament.totalPlayers, tournament.currentRound);
        bool isLastPosition = tournament.playersTree[currentPosition][tournament.currentRound] == player;
        if (isLastPosition && currentPosition.even()) {
            return true;
        }
        return false;
    }

    // determines if a player winns the round
    function playerWinsRound(Tournament storage tournament, address player, uint randomNumber, address adversary) private view returns(bool) {
        uint round = tournament.currentRound;
        uint weight = getWeight(tournament, player, round);
        uint totalWeight = getWeight(tournament, player, round+1);

        uint playerPosition = tournament.positions[player];
        uint adversaryPosition = tournament.positions[adversary];
        
        uint result =  (tournament.randomNumbers[adversary] + randomNumber) % totalWeight;
        if (playerPosition < adversaryPosition) {
            return result < weight;
        } else {
            return result >= weight;
        }
    }

    // stores the victory
    function storeWin(Tournament storage tournament, address player, address adversary) private {
        uint nextRound = tournament.currentRound + 1;
        uint startingPosition = tournament.positions[player];
        uint position = getPosition(startingPosition, nextRound);
        tournament.playersTree[position][nextRound] = player;
        tournament.revealedRounds[player] = nextRound; 
        
        tournament.achievedRounds[player] = nextRound; // this is tentative, might be reversed if lose the competition later
        if (tournament.achievedRounds[adversary] == nextRound) // revert the adversary's tentative win
            tournament.achievedRounds[adversary] = tournament.currentRound; 
    }

    // returns the player's adversary for the current round
    function getAdversary(Tournament storage tournament, address player) public view returns(address) {      
        uint round = tournament.currentRound;
        uint startingPosition = tournament.positions[player];
        uint currentPosition = getPosition(startingPosition, round);

        uint left = currentPosition - currentPosition%2;
        uint right = left + 1;
        
        if(currentPosition == left) {
            return tournament.playersTree[right][round];
        } else {
            return tournament.playersTree[left][round];
        }
    }

    // get the position in the current round
    function getPosition(uint startingPosition, uint round) private pure returns(uint) {
        return startingPosition / (2**round);
    }

    // determines if a player has already revealed in the current round
    function hasRevealed(Tournament storage tournament, address player) private view returns(bool) {
        return tournament.revealedRounds[player] == (tournament.currentRound + 1);
    }

    function getWeight(Tournament storage tournament, address player, uint round) public view returns(uint) {
        uint playerPosition = tournament.positions[player];
        return tournament.weights[getPosition(playerPosition, round)][round];
    }

    // determines the single winner of the tournament
    function getTournamentWinner(Tournament storage tournament) public view returns(address) {
        require(tournament.totalRounds <= tournament.currentRound);
        return tournament.playersTree[0][tournament.totalRounds];
    }
}


contract Lottery {
    using CreateTournament for Tournament;
    using RunTournament for Tournament;


    Tournament public tournament;

    mapping (address => bytes32) commitments; // player's commitment for next round
    
    uint stageStartTime;
    Stage public stage;
    uint constant SUBMISSION_INTERVAL = 10 minutes;
    uint constant BREAK_INTERVAL = 10 minutes;
    bool initialCommitRound = true;

    uint public pricePerTicket;
    uint public totalTickets;
    uint public ticketsSold;


    constructor(uint ticketPrice, uint numberOfTickets) {
        stage = Stage.signup;
        pricePerTicket = ticketPrice;
        totalTickets = numberOfTickets;
    }

    
    modifier signUpStage() {
        require(stage == Stage.signup, "Current stage is not at sign-up stage");
        _;
        if(ticketsSold >= totalTickets) {
            nextStage();
        }
    }

    modifier commitRevealStage() {
        require(stage == Stage.commit_reveal, "Current stage is not at commit-reveal stage");
        require(canReveal());
        if (block.timestamp >= stageStartTime + SUBMISSION_INTERVAL + BREAK_INTERVAL) {
            // additional round is added because the first commit-submission does not contribute to the tournament
            if(initialCommitRound) {
                initialCommitRound = false;
            } else {
                tournament.currentRound++;
            }
            stageStartTime += SUBMISSION_INTERVAL + BREAK_INTERVAL;
            if(tournament.currentRound >= tournament.totalRounds + 1) {
                nextStage();
            }
        }
        _;
    }

    function canReveal() private view returns(bool) {
        return block.timestamp < stageStartTime + SUBMISSION_INTERVAL;
    }

    modifier endStage() {
        require(stage == Stage.end, "Not at end stage");
        _;
    }

    function nextStage() internal {
        stage = Stage(uint(stage) + 1);
        stageStartTime = block.timestamp;
    }


    // signs the player up for the leader election
    // can also be used to add weight
    function signup(uint numberOfTickets) public payable signUpStage {
        require(ticketsSold + numberOfTickets <= totalTickets);
        require(numberOfTickets*pricePerTicket == msg.value);
        tournament.addPlayer(msg.sender);
        tournament.addWeight(msg.sender, numberOfTickets);
        ticketsSold += numberOfTickets;
    }

    // quit from the lottery and get a refund
    function resign() public payable signUpStage returns(uint numberOfTickets) {
        numberOfTickets = tournament.removeWeight(msg.sender);
        (bool success, ) = msg.sender.call{value: numberOfTickets*pricePerTicket}("");
        require(success);
    }

    // reveals the player's random number of current round and participates in the tournament
    // at the same time, commitment for the next round has to be submitted
    // First round: Any random numer and nonce can be submitted
    // Final round: Any next commitment can be submitted
    function commitReveal(uint randomNumber, uint nonce, bytes32 commitmentNextRound) public commitRevealStage {
        address player = msg.sender;
        if(!initialCommitRound) {
            require(hash(randomNumber, nonce, commitmentNextRound) == commitments[player]);
        }
        commitments[player] = commitmentNextRound;
        // check eligibility in compete()
        tournament.compete(player, randomNumber);
    }

    // the winner can withdraw the prize
    function payout() public payable endStage {
        require(tournament.getTournamentWinner() == msg.sender);
        msg.sender.call{value: address(this).balance}("");
    }

    // only execute this function locally to prevent miners from reading your secrets!
    function hash(uint randomNumber, uint nonce, bytes32 nextCommitment) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(randomNumber, nonce, nextCommitment));
    }
}

