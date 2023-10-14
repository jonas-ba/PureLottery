pragma solidity >=0.8.2 <0.9.0;


enum Stage {signup, commit, reveal, end}

struct Tournament {
    uint totalPlayers;
    uint currentRound;
    uint totalRounds;
    mapping (address => uint) positions; // every player is asigned a unique position
    mapping (uint => address) players;
    mapping (address => uint) rounds;
    mapping (address => uint) weights;
    mapping (address => bytes32) commitments; // commitment for next round
    mapping (uint => mapping (uint => uint)) randomNumbers; //leaves are at round 0
}


library Math {

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
    function addPlayer(Tournament storage tournament, address player) internal {
        if(!playerAlreadyIntournament(tournament, player)) {
            tournament.totalPlayers++;
            tournament.positions[player] = tournament.totalPlayers;
            tournament.players[tournament.totalPlayers] = player;
        }
    }

    // determines if the player has been added already
    function playerAlreadyIntournament(Tournament storage tournament, address player) private view returns(bool) {
        return tournament.players[tournament.positions[player]] == player;
    }

    // adds weight to a player and hence increases its chance to win
    function addWeight(Tournament storage tournament, address player, uint points) internal {
        tournament.weights[player]+= points;
    }

    // removes a players weight (and hence also eliminates its chance to win)
    function removeWeight(Tournament storage tournament, address player) internal returns(uint) {
        uint weight = tournament.weights[player];
        tournament.weights[player] = 0;
        return weight;
    }
}


library RunTournament {
    // determines victory based on a random number
    function compete(Tournament storage tournament, address player, uint randomNumber) internal {
        if(!hasAdversary(tournament, player)) {
            tournament.rounds[player]++;
            return;
        }

        require(tournament.currentRound == tournament.rounds[player], "Player is not at the expected level");
        address adversary = getAdversary(tournament, player);
        if(hasRevealed(tournament, adversary)) {
            if(playerWinsRound(tournament, player, randomNumber)) {
                undoWin(tournament, adversary);
                storeWin(tournament, player, adversary);
                tournament.rounds[player]++;
            }
        } else {
            storeWin(tournament, player, adversary);
            storeRandomNumber(tournament, player, randomNumber);
        }
    }

    // at a maximum of one player in every round may have no adversary
    // this player gets into the next round without competing
    function hasAdversary(Tournament storage tournament, address player) private view returns(bool) {
        return tournament.positions[player] == tournament.totalPlayers;
    }

    // determines if a player has already revealed in the current round
    function hasRevealed(Tournament storage tournament, address player) private view returns(bool) {
        return tournament.rounds[player] > tournament.currentRound;
    }

    // determines if a player winns the round
    function playerWinsRound(Tournament storage tournament, address player, uint randomNumber) private view returns(bool) {
        address adversary = getAdversary(tournament, player);
        
        uint playerPosition = tournament.positions[player];
        uint adversaryPosition = getAdversaryPosition(tournament, player);

        uint weight = tournament.weights[player];
        uint totalWeight = tournament.rounds[adversary];
        require(hasRevealed(tournament, adversary));
        uint result =  getAdversaryRandomNumber(tournament, player) + randomNumber % totalWeight;

        if (playerPosition < adversaryPosition) {
            return result < weight;
        } else {
            return result >= totalWeight - weight;
        }
    }

    // stores the victory
    function storeWin(Tournament storage tournament, address player, address adversary) private {
        tournament.weights[player] += tournament.weights[adversary];
        tournament.rounds[player]++;
    }

    // reverts the victory of the player who revealed first
    function undoWin(Tournament storage tournament, address player) private {
        delete tournament.weights[player];
        tournament.rounds[player]--;
    } 

    // TODO there must be a loop --> Is it actually possible to calculate without additional field in the tournament struct???
    // --> this function has to be eliminated and replaced
    // returns the adversary's position of the current round
    function getAdversaryPosition(Tournament storage tournament, address player) private view returns(uint) {
        uint adversaryPosition;
        uint playerPosition = tournament.positions[player];
        if(playerPosition % 2 == 0) {
            adversaryPosition = playerPosition + 1;
        } else {
            adversaryPosition = playerPosition - 1;
        }
        return adversaryPosition;
    }

    // returns the adversary in the current round
    function getAdversary(Tournament storage tournament, address player) private view returns(address) {
        uint position = getAdversaryPosition(tournament, player);
        return tournament.players[position];
    }

    // stores the random number in the current round for the adversary to access later
    function storeRandomNumber(Tournament storage tournament, address player, uint randomNumber) private {
        uint round = tournament.rounds[player];
        uint position = tournament.positions[player];
        tournament.randomNumbers[round][position/2] = randomNumber;
    }

    // returns the random number for the current round that the adversary has stored earlier
    function getAdversaryRandomNumber(Tournament storage tournament, address player) private view returns(uint) {
        uint round = tournament.rounds[player];
        uint position = tournament.positions[player];
        return tournament.randomNumbers[round][position/2];
    }

    // determines the single winner of the tournament
    function isTournamentWinner(Tournament storage tournament, address player) internal view returns(bool) {
        require(tournament.currentRound >= tournament.totalRounds);
        return tournament.rounds[player] == tournament.totalRounds;
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
        return numberOfParticipants.log2();
    }

    function sumOfLeaves(Tournament storage tournament, uint position, uint level) private view 
    returns(uint sum){
        (uint start, uint end) = getRange(position, level);
        for(uint i = start; i <= end; i++) {
            sum += tournament.weights[tournament.players[i]];
        }
        return sum;
    }

    function getRange(uint position, uint level) private pure returns(uint start, uint end) {
        start = position - position % (2 ** level);
        end = start + 2 ** level - 1;
        return (start, end);
    } 
}


abstract contract LeaderElection {
    Tournament internal tournamenttournament;
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
            tournamenttournament.currentRound++;
            startTimeOfCurrentStage += TIME_FOR_REVEALS + TIME_FOR_REVEAL_BREAKS;
            if(tournamenttournament.currentRound > tournamenttournament.totalRounds) {
                nextStage();
            }
        }
        _;
        if (stage == Stage.signup && ticketsSold >= totalTickets) {
            startTimeOfCurrentStage = block.timestamp;
            tournamenttournament.totalRounds = Math.log2(tournamenttournament.totalPlayers);
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
        tournamenttournament.addPlayer(msg.sender);
        tournamenttournament.addPoints(msg.sender, numberOfTickets);
        ticketsSold += numberOfTickets;
    }

    function resign() public payable 
    timedTransitions atStage(Stage.signup) returns(uint numberOfTickets) {
        numberOfTickets = tournamenttournament.removePoints(msg.sender);
        (bool success, ) = msg.sender.call{value: numberOfTickets*pricePerTicket}("");
        require(success);
    }

    function getRandomNumberRanges() public view 
    atStage(Stage.commit) returns(uint[] memory ranges) {
        return tournamenttournament.getRndRanges(msg.sender);
    }

    // notice to the user: Only execute this function locally
    // otherwise it may reveal your secret random numbers
    function generateHashes(uint[] calldata randomNumbers, uint[] calldata nonces) 
    public pure returns(bytes32 root, bytes32[] memory hashes) {
        return hashVerifier.generateHashtournament(randomNumbers, nonces);
    }

    function commit(bytes32 hashtournamentRoot) 
    timedTransitions atStage(Stage.commit) public {
        tournamenttournament.commit(msg.sender, hashtournamentRoot);
    }

    function reveal(bytes32[] memory hashes, uint randomNumber, uint nonce) 
    timedTransitions atStage(Stage.reveal) public {
        require(tournamenttournament.verifyHashtournament(msg.sender, hashes, randomNumber, nonce));
        tournamenttournament.compete(msg.sender, randomNumber);
    }

    function payout() public payable timedTransitions atStage(Stage.end) {
        require(tournamenttournament.isTournamentWinner(msg.sender));
        msg.sender.call{value: address(this).balance}("");
    }

    // Remove this function after testing
    function next() public {
        nextStage();
    }

}

