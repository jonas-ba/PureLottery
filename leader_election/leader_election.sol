pragma solidity >=0.8.2 <0.9.0;


enum Stage {signup, commit_reveal, end}

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
    
    // set the number of rounds, has to be called once before tournament start
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

    // elevates the player into the next round
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

    // check if a player has reached a certain round
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
/*
library hashVerifier {

    function commit(Tournament storage tournament, address player, bytes32 commitment) internal {
        tournament.commitments[player] = commitment;
    }

    function verifyHashtree(Tournament storage tournament, address player, bytes32[] memory hashes, uint rnd, uint nonce) 
    internal view returns(bool) {
        bytes32 root = tournament.commitments[player];
        bool rootVerification = keccak256(abi.encodePacked(hashes)) == root;
        bool branchVerification = keccak256(abi.encodePacked(rnd, nonce)) == hashes[tournament.currentRound];
        return rootVerification && branchVerification;
    }

    function generateHashtree(uint[] calldata randomNumbers, uint[] calldata nonces) internal pure 
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
*/ 

library RndSubmission {
    using Math for uint;

    // returns the range n to chose the random number
    // 0 =< random_number < n
    function getRndRange(Tournament storage tournament, address player) internal view returns(uint) {
// TODO implement
// muss 2 Knoten höher gehen
    }

    function getRange(uint position, uint level) private pure returns(uint start, uint end) {
        start = position - position % (2 ** level);
        end = start + 2 ** level - 1;
        return (start, end);
    } 


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

    function getNumberOfRounds(uint numberOfParticipants) private pure returns(uint) {
        return numberOfParticipants.log2(); // TODO plus 1 because there might be arbitrary number of players
    }
*/

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
}


abstract contract LeaderElection {
    using CreateTournament for Tournament;
    using RunTournament for Tournament;
    using RndSubmission for Tournament;

    Tournament public tournament;
    uint public pricePerTicket;
    uint public totalTickets;
    uint public ticketsSold;

    uint stageStartTime;
    Stage public stage;
    //uint constant TIME_FOR_COMMIT_SUBMISSION = 1 hours;
    uint constant SUBMISSION_INTERVAL = 10 minutes;
    uint constant BREAK_INTERVAL = 10 minutes;
    bool initialCommitRound = true;
    
    constructor() {
        stage = Stage.signup;
        stageStartTime = block.timestamp;
    }
/*
    modifier atStage(Stage _stage) {
      require(stage == _stage, "Not at expected stage");
      if(stage == Stage.reveal) {
          require(canReveal());
      }
      _;
    }
*/
/*
    modifier timedTransitions() {
        // TODO make timedTransition as infividual modifier for every function?
        if (stage == Stage.commit && (block.timestamp >= stageStartTime + TIME_FOR_COMMIT_SUBMISSION)) {
            stageStartTime += TIME_FOR_COMMIT_SUBMISSION;
            nextStage();
        } else if (stage == Stage.reveal && block.timestamp >= stageStartTime + TIME_FOR_REVEALS) {
            tournament.currentRound++;
            stageStartTime += TIME_FOR_REVEALS + TIME_FOR_REVEAL_BREAKS;
            if(tournament.currentRound > tournament.totalRounds) {
                nextStage();
            }
        }
        _;
        if (stage == Stage.signup && ticketsSold >= totalTickets) {
            stageStartTime = block.timestamp;
            tournament.totalRounds = Math.log2(tournament.totalPlayers);
            nextStage();
        }
    }
*/

    modifier signUpStage() {
        require(stage == Stage.signup, "Not at sign-up stage");
        _;
        if(ticketsSold >= totalTickets) {
            tournament.setTotalRounds();
            nextStage();
        }
    }

    modifier commitRevealStage() {
        require(stage == Stage.commit_reveal, "Not at commit-reveal stage");
        require(canReveal());
        if (block.timestamp >= stageStartTime + SUBMISSION_INTERVAL + BREAK_INTERVAL) {
            if(initialCommitRound) {
                initialCommitRound = false;
            } else {
                tournament.currentRound++;
            }
            stageStartTime += SUBMISSION_INTERVAL + BREAK_INTERVAL;
            // additional round is added because the first commit-submission does not contribute to the tournament
            if(tournament.currentRound > tournament.totalRounds + 1) {
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

    function commit(address player, bytes32 commitment) internal {
        tournament.commitments[player] = commitment;
    }

    // only execute this function locally to prevent miners reading your secrets!
    function hash(uint randomNumber, uint nonce) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(randomNumber, nonce));
    }
}


contract Lottery is LeaderElection {
    using CreateTournament for Tournament;
    using RunTournament for Tournament;
    using RndSubmission for Tournament;

    constructor(uint ticketPrice, uint numberOfTickets) {
        pricePerTicket = ticketPrice;
        totalTickets = numberOfTickets;
        
    }

    // can also be used to add weight
    function signup(uint numberOfTickets) public payable signUpStage {
        require(ticketsSold + numberOfTickets <= totalTickets);
        require(numberOfTickets*pricePerTicket == msg.value);
        tournament.addPlayer(msg.sender);
        //tournament.addPoints(msg.sender, numberOfTickets);
        ticketsSold += numberOfTickets;
    }

    function resign() public payable signUpStage returns(uint numberOfTickets) {
        numberOfTickets = tournament.removeWeight(msg.sender);
        (bool success, ) = msg.sender.call{value: numberOfTickets*pricePerTicket}("");
        require(success);
    }

    // returns the range n to chose the random number
    // 0 =< random_number < n
    function getRandomNumberRange() public view returns(uint) {
        return tournament.getRndRange(msg.sender);
    }

/*
    // notice to the user: Only execute this function locally
    // otherwise it may reveal your secret random numbers
    function generateHashes(uint[] calldata randomNumbers, uint[] calldata nonces) public pure returns(bytes32 root, bytes32[] memory hashes) {
        return hashVerifier.generateHashtournament(randomNumbers, nonces);
    }
*/

/*
    function commit(bytes32 hashedRnd) commitRevealStage public {
        tournament.commit(msg.sender, hashtournamentRoot);
    }

    function reveal(bytes32[] memory hashes, uint randomNumber, uint nonce) 
    timedTransitions atStage(Stage.reveal) public {
        require(tournament.verifyHashtournament(msg.sender, hashes, randomNumber, nonce));
        tournament.compete(msg.sender, randomNumber);
    }
*/

    // reveals the player's random number of current round and participates in the tournament
    // at the same time, commitment for the next round has to be submitted
    // First round: Any random numer and nonce can be submitted
    // Final round: Any next commitment can be submitted
    function commitReveal(uint randomNumber, uint nonce, bytes32 nextCommitment) public commitRevealStage {
        address player = msg.sender;
        if(!initialCommitRound) {
            require(hash(randomNumber, nonce) == tournament.commitments[player]);
        }
        tournament.commitments[player] = nextCommitment;
        tournament.compete(player, randomNumber);
    }

    function payout() public payable endStage {
        require(tournament.getTournamentWinner() == msg.sender);
        msg.sender.call{value: address(this).balance}("");
    }

}

