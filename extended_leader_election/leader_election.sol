pragma solidity >=0.8.2 <0.9.0;


enum Stage {signup, commit, reveal, end}

struct TournamentTree {
    mapping (address => uint) positions;
    mapping (uint => address) players;
    mapping (address => uint) levels;
    mapping (address => uint) points;
    mapping (uint => mapping (uint => uint)) randomNumbers; //leaves are at level 0
    uint totalPlayers;
    uint currentLevel;
    mapping (address => bytes32) commitments; 
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


/*
            root
        /    |    \
      hash0 hash1 hash2
      /  \   
    rnd nonce   
*/
library hashVerifier {
    function commit(TournamentTree storage tree, address player, bytes32 hashRoot) internal {
        tree.commitments[player] = hashRoot;
    }

    function verifyHashTree(TournamentTree storage tree, address player, bytes32[] memory hashes, uint rnd, uint nonce) internal view returns(bool) {
        bytes32 root = tree.commitments[player];
        bool rootVerification = keccak256(abi.encodePacked(hashes)) == root;
        bool branchVerification = keccak256(abi.encodePacked(rnd, nonce)) == hashes[tree.currentLevel];
        return rootVerification && branchVerification;
    }

    function generateHashTree(uint[] calldata randomNumbers, uint[] calldata nonces) internal pure returns(bytes32 root, bytes32[] memory hashes) {
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


library Tournament {
    using Math for uint;

    function addPlayer(TournamentTree storage tree, address player) internal {
        if(!playerAlreadyInTree(tree, player)) {
            tree.positions[player] = tree.totalPlayers;
        tree.players[tree.totalPlayers] = player;
        tree.totalPlayers++;
        }
    }

    function playerAlreadyInTree(TournamentTree storage tree, address player) private view returns(bool) {
        return tree.players[tree.positions[player]] == player;
    }

    function addPoints(TournamentTree storage tree, address player, uint points) internal {
        tree.points[player]+= points;
    }

    function removePoints(TournamentTree storage tree, address player) internal returns(uint points) {
        points = tree.points[player];
        tree.points[player] = 0;
        return points;
    }

    function compete(TournamentTree storage tree, address player, uint randomNumber) internal {
        uint level = tree.levels[player];
        require(tree.currentLevel == level, "Player is not at the expected level");
        uint adversaryPosition = getAdversaryPosition(tree, player);
        address adversary = tree.players[adversaryPosition];
        if(hasRevealedAlready(tree, adversary)) {
            uint points = tree.points[player];
            uint totalPoints = tree.points[adversary];
            uint result = tree.randomNumbers[adversaryPosition][level] ^ randomNumber;
            uint position = tree.positions[player];
            if(playerWins(result, points, totalPoints, position.even())) {
                handleWin(tree, player, adversary);
            }
        } else {
            storeRandom(tree, player, randomNumber, level);
        }
    }

    function handleWin(TournamentTree storage tree, address player, address adversary) private {
        tree.points[player] += tree.points[adversary];
        tree.levels[player]++;
        delete tree.points[adversary];
        tree.levels[adversary]--;
    }

    function storeRandom(TournamentTree storage tree, address player, uint randomValue, uint level) private {
        uint adversaryPosition = getAdversaryPosition(tree, player);
        tree.randomNumbers[adversaryPosition][level] = randomValue;
        tree.points[player] += tree.points[tree.players[adversaryPosition]];
        tree.levels[player]++;
    }

    function playerWins(uint result, uint points, uint totalPoints, bool isLeftSide) private pure returns(bool) {
        result = result % totalPoints;
        if(isLeftSide) {
            return result < points;
        } else {
            return result >= totalPoints - points;
        }
    }

    function getAdversaryPosition(TournamentTree storage tree, address player) private view returns(uint adversaryPosition) {
        uint playerPosition = tree.positions[player];
        if(playerPosition % 2 == 0) {
            adversaryPosition = playerPosition + 1;
        } else {
            adversaryPosition = playerPosition - 1;
        }
        return adversaryPosition;
    }

    function hasRevealedAlready(TournamentTree storage tree, address player) private view returns(bool) {
        return tree.levels[player] > tree.currentLevel;
    }

    function isWinner(TournamentTree storage tree, address player) internal view returns(bool) {
        // TODO
    }
}


library RndNumberGeneration {
    using Math for uint;

    function getRndRanges(TournamentTree storage tree, address player) internal view returns(uint[] memory ranges) {
        uint position = tree.positions[player];
        uint levels = getNumberOfLevels(tree.totalPlayers);
        ranges = new uint[](levels);
        for(uint level = 0; level < levels; level++) {
            ranges[level] = sumOfLeaves(tree, position, level);
        }
        return ranges;
    }

    function getNumberOfLevels(uint numberOfParticipants) private pure returns(uint) {
        return numberOfParticipants.log2();
    }

    function sumOfLeaves(TournamentTree storage tree, uint position, uint level) private view returns(uint sum){
        (uint start, uint end) = getRange(position, level);
        for(uint i = start; i <= end; i++) {
            sum += tree.points[tree.players[i]];
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
    TournamentTree internal tournamentTree;
    uint public pricePerTicket;

    uint public totalTickets;
    uint public ticketsSold;
    uint public totalRevealLevels;

    uint startTimeOfCurrentStage;
    Stage public stage;
    uint public currentRevealLevel; // TODO check if counting upwards
    uint constant TIME_FOR_COMMIT_SUBMISSION = 1 hours;
    uint constant TIME_FOR_REVEALS = 10 minutes;
    uint constant TIME_FOR_REVEAL_BREAKS = 10 minutes;
    
    constructor() {
        stage = Stage.signup;
        startTimeOfCurrentStage = block.timestamp;
    }

    // TODO set number of reveal levels when going form signup to commit

    modifier atStage(Stage _stage) {
      require(stage == _stage, "Not at expected stage");
      _;
    }

    function nextStage() internal {
        stage = Stage(uint(stage) + 1);
        startTimeOfCurrentStage = block.timestamp;
    }

    modifier timedTransitions() {
        if (stage == Stage.signup && ticketsSold >= totalTickets) {
            startTimeOfCurrentStage = block.timestamp;
            nextStage();
        } else if (stage == Stage.commit && block.timestamp >= startTimeOfCurrentStage + TIME_FOR_COMMIT_SUBMISSION) {
            startTimeOfCurrentStage += TIME_FOR_COMMIT_SUBMISSION;
            nextStage();
        } else if (stage == Stage.reveal && block.timestamp >= startTimeOfCurrentStage + TIME_FOR_REVEALS) {
            currentRevealLevel--;
            startTimeOfCurrentStage += TIME_FOR_REVEALS + TIME_FOR_REVEAL_BREAKS;
            nextStage();
        }
        _;
    }

    modifier canReveal() {
        require(block.timestamp < startTimeOfCurrentStage + TIME_FOR_REVEALS, "Reveal time exceeded");
        _;
    }
}


abstract contract Lottery is LeaderElection {
    using Tournament for TournamentTree;
    using RndNumberGeneration for TournamentTree;
    using hashVerifier for TournamentTree;

    constructor(uint ticketPrice, uint numberOfTickets) {
        pricePerTicket = ticketPrice;
        totalTickets = numberOfTickets;
    }

    // can also be used to add shares
    function signup(uint numberOfTickets) public payable timedTransitions atStage(Stage.signup) {
        require(ticketsSold + numberOfTickets <= totalTickets);
        require(numberOfTickets*pricePerTicket == msg.value);
        tournamentTree.addPlayer(msg.sender);
        tournamentTree.addPoints(msg.sender, numberOfTickets);
    }

    function resign() public payable timedTransitions atStage(Stage.signup) returns(uint numberOfTickets) {
        numberOfTickets = tournamentTree.removePoints(msg.sender);
        (bool success, ) = msg.sender.call{value: numberOfTickets*pricePerTicket}("");
        require(success);
    }

    function getRandomNumberRanges() public view atStage(Stage.commit) returns(uint[] memory ranges) {
        return tournamentTree.getRndRanges(msg.sender);
    }

    // notice to the user: Only execute this function locally
    // otherwise it may reveal your secret random numbers
    function generateHashes(uint[] calldata randomNumbers, uint[] calldata nonces) internal pure returns(bytes32 root, bytes32[] memory hashes) {
        return hashVerifier.generateHashTree(randomNumbers, nonces);
    }

    function commit(bytes32 hashTreeRoot) timedTransitions atStage(Stage.commit) public {
        tournamentTree.commit(msg.sender, hashTreeRoot);
    }

    function reveal(bytes32[] memory hashes, uint randomNumber, uint nonce) timedTransitions atStage(Stage.reveal) canReveal public {
        require(tournamentTree.verifyHashTree(msg.sender, hashes, randomNumber, nonce));
        tournamentTree.compete(msg.sender, randomNumber);
    }

    function payout() public payable timedTransitions atStage(Stage.end) {
        require(tournamentTree.isWinner(msg.sender));
        msg.sender.call{value: address(this).balance}("");
    }

}

