pragma solidity >=0.8.2 <0.9.0;


enum Stage {signup, commit, reveal, end}

struct Tournament {
    uint totalPlayers;
    uint currentRound;
    uint totalRounds;
    mapping (address => uint) positions; // every player is asigned a unique position
    mapping (uint => mapping (uint => address)) playersTree; // playersTree[position][round]
    mapping (address => uint) weights; // more weight gives higher probability of winning
    mapping (address => bytes32) commitments; // player's commitment for next round
    mapping (address => uint) randomNumbers; // player's random number for the current round
}

/* 
Scheme of playersTree for 5 players:

                                                 __________winner___________
round 2                                         /                           \
                                 _position 0/1/2/3__                        position 4
round 1                         /                   \                           |
                    position 0/1                    position 2/3            position 4
round 0             /           \                   /       \                   |
            position 0      position 1      position 2      position 3      position 4

*/


library Math {

    // computes the logarithm base 2 and rounds up to the next integer
    function log2(uint x) public pure returns (uint) {
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
        if(!playerAlreadyAdded(tournament, player)) {
            tournament.totalPlayers++;
            tournament.positions[player] = tournament.totalPlayers;
            tournament.playersTree[tournament.totalPlayers][0] = player;
        }
    }

    // determines if the player has been added already
    function playerAlreadyAdded(Tournament storage tournament, address player) private view returns(bool) {
        return tournament.playersTree[tournament.positions[player]][0] == player;
    }

    // adds weight to a player and hence increases its chance to win
    function addWeight(Tournament storage tournament, address player, uint points) public {
        tournament.weights[player]+= points;
    }

    // removes a players weight (and hence also eliminates its chance to win)
    function removeWeight(Tournament storage tournament, address player) public returns(uint) {
        uint weight = tournament.weights[player];
        tournament.weights[player] = 0;
        return weight;
    }

    function setTotalRounds(Tournament storage tournament) private {
        tournament.totalRounds = Math.log2(tournament.totalPlayers);
    }
}


library RunTournament {
    using Math for uint;
   
    // determines victory for the current round based on a random number
    function compete(Tournament storage tournament, address player, uint randomNumber) internal {
        require(playerAchievedRound(tournament, player, tournament.currentRound), "player has not achieved current round");

        if(hasNoAdversary(tournament, player)) {
            incrementPlayerRound(tournament, player);
            return;
        }

        address adversary = getAdversary(tournament, player);
        if(hasRevealed(tournament, adversary)) {
            if(playerWinsRound(tournament, player, randomNumber)) {
                undoWin(tournament, adversary);
                storeWin(tournament, player, adversary);
            }
        } else {
            storeWin(tournament, player, adversary);
            tournament.randomNumbers[player] = randomNumber;
        }
    }

    // at a maximum of one player in every round may have no adversary
    // this player gets into the next round without competing
    function hasNoAdversary(Tournament storage tournament, address player) private view returns(bool) {
        uint currentPosition = getPosition(tournament.totalPlayers, tournament.currentRound);
        bool isLastPosition = tournament.playersTree[currentPosition][tournament.currentRound] == player;
        return isLastPosition && currentPosition.even();
    }

    // determines if a player winns the round
    function playerWinsRound(Tournament storage tournament, address player, uint randomNumber) private view returns(bool) {
        address adversary = getAdversary(tournament, player);
        require(hasRevealed(tournament, adversary));
        
        uint playerPosition = tournament.positions[player];
        uint adversaryPosition = tournament.positions[adversary];

        uint weight = tournament.weights[player];
        uint totalWeight = tournament.weights[adversary];
        uint result =  tournament.randomNumbers[adversary] + randomNumber % totalWeight;

        if (playerPosition < adversaryPosition) {
            return result < weight;
        } else {
            return result >= totalWeight - weight;
        }
    }

    // stores the victory
    function storeWin(Tournament storage tournament, address player, address adversary) private {
        if(hasRevealed(tournament, adversary)) {
            tournament.weights[player] = tournament.weights[adversary];
        } else {
            tournament.weights[player] += tournament.weights[adversary];
        }
        incrementPlayerRound(tournament, player);
    }

    // reverts the victory of the player who revealed first
    function undoWin(Tournament storage tournament, address player) private {
        delete tournament.weights[player];
    } 

    function incrementPlayerRound(Tournament storage tournament, address player) private {
        require(playerAchievedRound(tournament, player, tournament.currentRound), "player has not achieved current round");
        uint nextRound = tournament.currentRound + 1;
        uint startingPosition = tournament.positions[player];
        uint position = getPosition(startingPosition, nextRound);
        tournament.playersTree[position][nextRound] = player;
    }

    // returns the player's adversary for the current round
    function getAdversary(Tournament storage tournament, address player) public view returns(address) {
        uint round = tournament.currentRound;
        uint startingPosition = tournament.positions[player];
        uint currentPosition = getPosition(startingPosition, round);
        address adversary = tournament.playersTree[currentPosition][round];
        require(adversary != player);
        require(adversary != address(0));
        return adversary;
    }
 
    // get the position in the current round
    function getPosition(uint startingPosition, uint round) private pure returns(uint) {
        return startingPosition / (2^round);
    }

    // determines if a player has already revealed in the current round
    function hasRevealed(Tournament storage tournament, address player) private view returns(bool) {
        return playerAchievedRound(tournament, player, tournament.currentRound + 1);
    }

    function playerAchievedRound(Tournament storage tournament, address player, uint round) private view returns(bool) {
        uint startingPosition = tournament.positions[player];
        uint currentPosition = getPosition(startingPosition, round);
        return tournament.playersTree[currentPosition][round] == player;
    }

    // determines the single winner of the tournament
    function getTournamentWinner(Tournament storage tournament) public view returns(address) {
        require(tournament.currentRound >= tournament.totalRounds);
        return tournament.playersTree[0][tournament.totalRounds];
    }
}

// _______________________________
/*
            root
        /    |    \
      hash0 hash1 hash2
      /  \   
    rnd nonce   
*/

// TODO implement ⟨x, r, h_nextround⟩ instead of all commitments in the beginning
library hashVerifier {
    function commit(Tournament storage tournament, address player, bytes32 hashRoot) internal {
        tournament.commitments[player] = hashRoot;
    }

    function verifyHashtournament(Tournament storage tournament, address player, bytes32[] memory hashes, uint rnd, uint nonce) 
    internal view returns(bool) {
        bytes32 root = tournament.commitments[player];
        bool rootVerification = keccak256(abi.encodePacked(hashes)) == root;
        bool branchVerification = keccak256(abi.encodePacked(rnd, nonce)) == hashes[tournament.currentRound];
        return rootVerification && branchVerification;
    }

    function generateHashtournament(uint[] calldata randomNumbers, uint[] calldata nonces) internal pure 
    returns(bytes32 root, bytes32[] memory hashes) {
        require(randomNumbers.length <= nonces.length, "Number of random numbers and nonces must be equal");
        uint length = randomNumbers.length;
        hashes = new bytes32[](length);
        for(uint i = 0; i < length; i++) {
            hashes[i] = (keccak256(abi.encodePacked(randomNumbers[i], nonces[i])));
        }
        for(uint i = 0; i < length; i++) {
            root = keccak256(abi.encodePacked(root, hashes[i]));
        }
        return (root, hashes);
    }
}

library RndNumberSubmission {
    using Math for uint;
/*
    function getRndRanges(Tournament storage tournament, address player) internal view 
    returns(uint[] memory ranges) {
        uint position = tournament.positions[player];
        uint levels = getNumberOfRounds(tournament.totalPlayers);
        ranges = new uint[](levels);
        for(uint level = 0; level < levels; level++) {
            ranges[level] = sumOfLeaves(tournament, position, level);
        }
        return ranges;
    }
*/
    function getNumberOfRounds(uint numberOfParticipants) private pure returns(uint) {
        return numberOfParticipants.log2(); // TODO plus 1 because there might be arbitrary number of players
    }
    // TODO function in CreateTournament written
/*
    function sumOfLeaves(Tournament storage tournament, uint position, uint level) private view 
    returns(uint sum){
        (uint start, uint end) = getRange(position, level);
        for(uint i = start; i <= end; i++) {
            sum += tournament.weights[tournament.players[i]];
        }
        return sum;
    }
*/
    function getRange(uint position, uint level) private pure returns(uint start, uint end) {
        start = position - position % (2 ** level);
        end = start + 2 ** level - 1;
        return (start, end);
    } 
}


abstract contract LeaderElection {
    Tournament internal tournament;
    uint public pricePerTicket;
    uint public totalTickets;
    uint public ticketsSold;

    uint startTimeOfCurrentStage;
    Stage public stage;
    uint constant TIME_FOR_COMMIT_SUBMISSION = 1 hours;
    uint constant TIME_FOR_REVEALS = 10 minutes;
    uint constant TIME_FOR_REVEAL_BREAKS = 10 minutes;
    
    constructor() {
        stage = Stage.signup;
        startTimeOfCurrentStage = block.timestamp;
    }

    modifier atStage(Stage _stage) {
      require(stage == _stage, "Not at expected stage");
      if(stage == Stage.reveal) {
          require(canReveal());
      }
      _;
    }

    function canReveal() private view returns(bool) {
        return block.timestamp < startTimeOfCurrentStage + TIME_FOR_REVEALS;
    }

    modifier timedTransitions() {
        // TODO make timedTransition as infividual modifier for every function?
        if (stage == Stage.commit && (block.timestamp >= startTimeOfCurrentStage + TIME_FOR_COMMIT_SUBMISSION)) {
            startTimeOfCurrentStage += TIME_FOR_COMMIT_SUBMISSION;
            nextStage();
        } else if (stage == Stage.reveal && block.timestamp >= startTimeOfCurrentStage + TIME_FOR_REVEALS) {
            tournament.currentRound++;
            startTimeOfCurrentStage += TIME_FOR_REVEALS + TIME_FOR_REVEAL_BREAKS;
            if(tournament.currentRound > tournament.totalRounds) {
                nextStage();
            }
        }
        _;
        if (stage == Stage.signup && ticketsSold >= totalTickets) {
            startTimeOfCurrentStage = block.timestamp;
            tournament.totalRounds = Math.log2(tournament.totalPlayers);
            nextStage();
        }
    }

    function nextStage() internal {
        stage = Stage(uint(stage) + 1);
        startTimeOfCurrentStage = block.timestamp;
    }
}


contract Lottery is LeaderElection {
    
    using CreateTournament for Tournament;
    using RunTournament for Tournament;
    using RndNumberSubmission for Tournament;
    using hashVerifier for Tournament;

    constructor(uint ticketPrice, uint numberOfTickets) {
        pricePerTicket = ticketPrice;
        totalTickets = numberOfTickets;
    }

    // can also be used to add shares
    function signup(uint numberOfTickets) public payable 
    timedTransitions atStage(Stage.signup) {
        require(ticketsSold + numberOfTickets <= totalTickets);
        require(numberOfTickets*pricePerTicket == msg.value);
        tournament.addPlayer(msg.sender);
        //tournament.addPoints(msg.sender, numberOfTickets);
        ticketsSold += numberOfTickets;
    }

    function resign() public payable 
    timedTransitions atStage(Stage.signup) returns(uint numberOfTickets) {
        numberOfTickets = tournament.removeWeight(msg.sender);
        (bool success, ) = msg.sender.call{value: numberOfTickets*pricePerTicket}("");
        require(success);
    }
/*
    function getRandomNumberRanges() public view 
    atStage(Stage.commit) returns(uint[] memory ranges) {
        return tournament.getRndRanges(msg.sender);
    }
*/
    // notice to the user: Only execute this function locally
    // otherwise it may reveal your secret random numbers
    function generateHashes(uint[] calldata randomNumbers, uint[] calldata nonces) 
    public pure returns(bytes32 root, bytes32[] memory hashes) {
        return hashVerifier.generateHashtournament(randomNumbers, nonces);
    }

    function commit(bytes32 hashtournamentRoot) 
    timedTransitions atStage(Stage.commit) public {
        tournament.commit(msg.sender, hashtournamentRoot);
    }

    function reveal(bytes32[] memory hashes, uint randomNumber, uint nonce) 
    timedTransitions atStage(Stage.reveal) public {
        require(tournament.verifyHashtournament(msg.sender, hashes, randomNumber, nonce));
        tournament.compete(msg.sender, randomNumber);
    }

    function payout() public payable timedTransitions atStage(Stage.end) {
        require(tournament.getTournamentWinner() == msg.sender);
        msg.sender.call{value: address(this).balance}("");
    }

    // Remove this function after testing
    function next() public {
        nextStage();
    }

}

