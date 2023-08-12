pragma solidity >=0.8.2 <0.9.0;


enum Stage {signup, commit, reveal, end}
enum SignupMode {limitedShares, limitedTime}
struct TreeNode {
    uint parentId;
    uint leftChildId;
    uint rightChildId;
    uint level;
    address player;
    uint randomValue;
    uint shares;
}

abstract contract StateMachine {

    uint startTimeOfCurrentStage;
    Stage public stage;
    SignupMode public signupMode;
    uint public timeOrShareLimit;
    uint constant TIME_FOR_COMMIT_SUBMISSION = 1 hours;
    uint constant TIME_FOR_REVEALS = 10 minutes;
    uint constant TIME_FOR_REVEAL_BREAKS = 10 minutes;
    uint public currentRevealLevel;

    constructor(SignupMode mode, uint limit) {
        stage = Stage.signup;
        signupMode = mode;
        timeOrShareLimit = limit;
        startTimeOfCurrentStage = block.timestamp;
    }

    function getNumberOfRevealLevels() internal virtual returns(uint);
    function getAmountOfShares() internal virtual returns(uint);
    
    modifier atStage(Stage _stage) {
      require(stage == _stage);
      _;
    }

    function nextStage() internal {
        stage = Stage(uint(stage) + 1);
        startTimeOfCurrentStage = block.timestamp;
        if(stage == Stage.reveal) {
            currentRevealLevel = getNumberOfRevealLevels();
        }
    }

    modifier timedTransitions() {
        if (signupMode == SignupMode.limitedShares) {
            if (stage == Stage.signup && getAmountOfShares() >= timeOrShareLimit) {
                startTimeOfCurrentStage = block.timestamp;
                nextStage();
            }
        }
        if (signupMode == SignupMode.limitedTime) {
            if (stage == Stage.signup && block.timestamp >= startTimeOfCurrentStage + timeOrShareLimit) {
                startTimeOfCurrentStage += timeOrShareLimit;
                nextStage();
            }
        }
        if (stage == Stage.commit && block.timestamp >= startTimeOfCurrentStage + TIME_FOR_COMMIT_SUBMISSION) {
            startTimeOfCurrentStage += TIME_FOR_COMMIT_SUBMISSION;
            nextStage();
        }
        if (stage == Stage.reveal && block.timestamp >= startTimeOfCurrentStage + TIME_FOR_REVEALS) {
            currentRevealLevel--;
            startTimeOfCurrentStage += TIME_FOR_REVEALS + TIME_FOR_REVEAL_BREAKS;
            nextStage();
        }
        _;
    }

    modifier canReveal() {
        require(block.timestamp < startTimeOfCurrentStage + TIME_FOR_REVEALS);
        _;
    }
}


contract Queue {

    mapping (uint => uint) private queue;
    uint private first = 1;
    uint private last = 1;

    function enqueue(uint data) public {
        queue[last++] = data;
    }

    function dequeue() public returns(uint) {
        require(last > first);
        uint data = queue[first];
        first++;
        return data;
    }

    function isEmpty() public returns(bool) {
        return last == first;
    }
}


contract TournamentTree {

    mapping (address => TreeNode) private currentNodeOfPlayerAddress;
    mapping (uint => TreeNode) private treeNodeById;
    Queue private leaves;
    TreeNode private root;
    uint private nodeCounter;
    uint public treeHeight;
    
    constructor() {
        leaves = new Queue();
    }

    function addShares(address player, uint amount) internal {
        if(!isInTree(player)) {
            insertNewPlayer(player);
        }
        currentNodeOfPlayerAddress[player].shares += amount;
        updateShares(currentNodeOfPlayerAddress[player].parentId);
    }

    function getRandomNumberRanges(address player) internal returns(uint[] memory) {
        // TODO implement
    }

    function updateShares(TreeNode memory leaf, uint amount) internal {
        // TODO implement
    }

    function isInTree(address player) private returns(bool) {
        return currentNodeOfPlayerAddress[player] != 0;
    }

// TODO überall, wo TreeNode genutzt wird, wird der gesamte Node abgerufen!
    function insertNewPlayer(address player) private {
        if(leaves.isEmpty()) {
            createRoot(player);
            return;
        }
        TreeNode memory leftChild = leaves.dequeue();
        TreeNode memory parent = treeNodeById[nodeCounter++];
        TreeNode memory rightChild = treeNodeById[nodeCounter++];
        parent.level = leftChild.level;
        leftChild.level++;
        rightChild.level = leftChild.level;
        leftChild.parent = parent;
        rightChild.parent = parent;
        parent.leftChild = leftChild;
        parent.rightChild = rightChild;
        rightChild.player = player;
        leaves.enqueue(leftChild);
        leaves.enqueue(rightChild);
        if(parent.level + 1 > treeHeight) {
            treeHeight = leftChild.level;
        }
    }

    function createRoot(address player) private {
        uint rootLevel = 0;
        treeNodeById[0].player = player;
        treeNodeById[0].level = rootLevel;
        currentNodeOfPlayerAddress[player] = treeNodeById[0];
        leaves.enqueue(treeNodeById[0]);
        nodeCounter++;
    }

    function removePlayer(address player) internal returns(uint numberOfShares) {
        treeNodeById[currentNodeOfPlayerAddress[player]].shares = 0;
    }

    function getLevel(address player) internal returns(uint) {
        return treeNodeById[currentNodeOfPlayerAddress[player]].level;
    }

    function competeInMatch(uint randomValue, uint currentRevealLevel) internal {
        require(currentRevealLevel == getLevel(msg.sender));
        require(treeNodeById[currentNodeOfPlayerAddress[msg.sender]].player == msg.sender);
        TreeNode memory previousMatch = currentNodeOfPlayerAddress[msg.sender];
        TreeNode memory currentMatch = previousMatch.parent;
        if(opponentHasRevealed(previousMatch)) {
            if(isLeftNode(previousMatch) == leftPlayerWinns(currentMatch, randomValue)) {
                currentMatch.player = msg.sender;
            }
        } else {
            currentMatch.player = msg.sender;
            currentMatch.randomValue = randomValue;
        }
        currentNodeOfPlayerAddress[msg.sender] = currentMatch;
    }

    function leftPlayerWinns (TreeNode memory currentMatch, uint randomValue) private returns(bool) {
        uint resultingRandomValue = currentMatch.randomValue ^ randomValue;
        uint sharesLeftPlayer = currentMatch.leftChild.shares;
        uint sharesRightPlayer = currentMatch.rightChild.shares;
        uint result = resultingRandomValue % (sharesLeftPlayer + sharesRightPlayer);
        return result < sharesLeftPlayer;
    }

    function opponentHasRevealed(TreeNode memory previousMatch) private {
        address opponent;
        if(previousMatch.parent.leftChild == previousMatch) {
            opponent = previousMatch.parent.rightChild.player;
        } else {
            opponent = previousMatch.parent.leftChild.player;
        }
        return treeNodeById[opponent] == previousMatch.parent;
    }

    function isLeftNode(TreeNode memory childNode) private returns(bool) {
        return childNode.parent.leftChild == childNode;
    }

}


abstract contract LeaderElection is TournamentTree, StateMachine {

    mapping (address => bytes32[]) private commitments;
    TournamentTree private tournamentTree;
    uint public totalShares;

    constructor(SignupMode mode, uint limit) StateMachine(mode, limit) TournamentTree() {
        tournamentTree = new TournamentTree();
    }
    
    function signUp(uint shares) public payable timedTransitions atStage(Stage.signup) {
        addShares(msg.sender, shares);
    }

    function resign() public timedTransitions atStage(Stage.signup) {
        removePlayer(msg.sender);
    }

    function commit(bytes32[] calldata hashesForEveryLevel) public timedTransitions atStage(Stage.commit) {
        // implement make a check that the number of hashes is correct?
        hash[msg.sender] = hashesForEveryLevel;
    }
    
    function reveal(uint randomValue, uint nonce) public timedTransitions atStage(Stage.reveal) canReveal {
        require(hash(randomValue, nonce) == commitments[msg.sender][currentRevealLevel]);
        competeInMatch(randomValue, currentRevealLevel);
    }

    function hash(uint number, uint nonce) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(number, nonce));
    }
    
    function getWinner() public timedTransitions atStage(Stage.end) returns(address) {
        return tournamentTree.players[tournamentTree.ROOT_ID];
    }

    function getNumberOfRevealLevels() internal returns(uint) {
        return treeHeight;
    }

    function getAmountOfShares() internal returns(uint) {
        return totalShares;
    }
}

contract Lottery is LeaderElection {
    // TODO implement
}

