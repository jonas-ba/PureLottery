pragma solidity >=0.8.2 <0.9.0;

enum Stage {signup, commit, reveal, end}
enum SignupMode {limitedShares, limitedTime}
struct TreeNode {
    uint id;
    uint parentId;
    uint leftChildId;
    uint rightChildId;
    uint level;
    address player;
    uint randomValue;
    uint shares;
}

abstract contract CommitRevealStateMachine {

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
      require(stage == _stage, "Not at expected stage");
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
        // TOOD use case statement?
        if (stage == Stage.signup && signupMode == SignupMode.limitedShares && getAmountOfShares() >= timeOrShareLimit) {
            startTimeOfCurrentStage = block.timestamp;
            nextStage();
        }
        if (stage == Stage.signup && signupMode == SignupMode.limitedTime && block.timestamp >= startTimeOfCurrentStage + timeOrShareLimit) {
            startTimeOfCurrentStage += timeOrShareLimit;
            nextStage();
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
        require(block.timestamp < startTimeOfCurrentStage + TIME_FOR_REVEALS, "Reveal time exceeded");
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
        delete queue[first];
        first++;
        return data;
    }

    function isEmpty() public view returns(bool) {
        return last == first;
    }
}

// TODO outsource pure tree functions
contract TournamentTree {

    mapping (address => TreeNode) private currentNodes;
    mapping (address => uint) private playerToNodeId;
    mapping (uint => TreeNode) private tree;
    Queue private leaves;
    uint internal nodeCount;
    uint internal treeHeight;
    uint constant internal ROOT_ID = 1;
    
    constructor() {
        leaves = new Queue();
        nodeCount = 1;
    }

    function getNode(uint id) internal view returns(TreeNode memory) {
        return tree[id];
    }

    function getNode(address player) internal view returns(TreeNode memory) {
        return currentNodes[player];
    }

    function addShares(address player, uint amount) internal {
        if(!isInTree(player)) {
            insertNewPlayer(player);
        }
        TreeNode memory currentNode = getNode(player);
        while(currentNode.parentId != 0) {
            currentNode.shares += amount;
            currentNode = getNode(currentNode.parentId);
        }
    }

    function getRandomNumberRanges(address player) internal view returns(uint[] memory) {
        TreeNode memory currentNode = getNode(player);
        uint length = currentNode.level;
        uint[] memory numberRanges = new uint[](length);
        while(currentNode.parentId != 0) {
            uint sharesOfOpponent = getNode(getOpponent(currentNode)).shares;
            uint sumOfShares = sharesOfOpponent + currentNode.shares;
            numberRanges[currentNode.level] = sumOfShares;
            currentNode = getNode(currentNode.parentId);
        }
        return numberRanges;
    }

    function isInTree(address player) private view returns(bool) {
        return getNode(player).id != 0;
    }

    function insertNewPlayer(address player) private {
        if(leaves.isEmpty()) {
            createRoot(player);
            return;
        }
        TreeNode memory leftChild = getNode(leaves.dequeue());
        TreeNode memory parent = getNode(nodeCount++);
        TreeNode memory rightChild = getNode(nodeCount++);
        parent.level = leftChild.level;
        leftChild.level++;
        rightChild.level = leftChild.level;
        leftChild.parentId = parent.id;
        rightChild.parentId = parent.id;
        parent.leftChildId = leftChild.id;
        parent.rightChildId = rightChild.id;
        rightChild.player = player;
        leaves.enqueue(leftChild.id);
        leaves.enqueue(rightChild.id);
        if(parent.level + 1 > treeHeight) {
            treeHeight = leftChild.level;
        }
    }

    function createRoot(address player) private {
        uint rootLevel = 0;
        getNode(ROOT_ID).player = player;
        getNode(ROOT_ID).level = rootLevel;
        getNode(player) = getNode(ROOT_ID);
        leaves.enqueue(ROOT_ID);
        nodeCount++;
    }

    function removePlayer(address player) internal returns(uint numberOfShares) {
        uint shares = getNode(player).shares;
        getNode(player).shares = 0;
        return shares;
    }

    function getLevel(address player) internal view returns(uint) {
        return getNode(player).level;
    }

    function competeInMatch(uint randomValue, uint currentRevealLevel) internal {
        require(currentRevealLevel == getLevel(msg.sender));
        require(getNode(msg.sender).player == msg.sender);
        TreeNode memory previousMatch = getNode(msg.sender);
        TreeNode memory currentMatch = getNode(previousMatch.parentId);
        if(opponentHasRevealed(previousMatch)) {
            if(isLeftNode(previousMatch) == leftPlayerWinns(currentMatch, randomValue)) {
                currentMatch.player = msg.sender;
            }
        } else {
            currentMatch.player = msg.sender;
            currentMatch.randomValue = randomValue;
        }
        getNode(msg.sender) = currentMatch;
    }

    function leftPlayerWinns (TreeNode memory currentMatch, uint randomValue) private view returns(bool) {
        uint resultingRandomValue = currentMatch.randomValue ^ randomValue;
        uint sharesLeftPlayer = getNode(currentMatch.leftChildId).shares;
        uint sharesRightPlayer = getNode(currentMatch.rightChildId).shares;
        uint result = resultingRandomValue % (sharesLeftPlayer + sharesRightPlayer);
        return result < sharesLeftPlayer;
    }

    function opponentHasRevealed(TreeNode memory previousMatch) private view returns(bool) {
        address opponent = getOpponent(previousMatch);
        return getNode(opponent).id == previousMatch.parentId;
    }

    function getOpponent(TreeNode memory node) private view returns(address) {
        TreeNode memory parent = getNode(node.parentId);
        if(parent.leftChildId == node.id) {
            return getNode(parent.rightChildId).player;
        } else {
            return getNode(parent.leftChildId).player;
        }
    }

    function isLeftNode(TreeNode memory childNode) private view returns(bool) {
        return getNode(childNode.parentId).leftChildId == childNode.id;
    }

}


abstract contract LeaderElection is TournamentTree, CommitRevealStateMachine {

    mapping (address => bytes32[]) private commitments;
    uint public totalShares;

    constructor(SignupMode mode, uint limit) StateMachine(mode, limit) TournamentTree() {}
    
    function signUp(uint shares) virtual public payable timedTransitions atStage(Stage.signup) {
        addShares(msg.sender, shares);
    }

    function resign() virtual public payable timedTransitions atStage(Stage.signup) {
        removePlayer(msg.sender);
    }

    function commit(bytes32[] calldata hashesForEveryLevel) public timedTransitions atStage(Stage.commit) {
        // implement make a check that the number of hashes is correct?
        commitments[msg.sender] = hashesForEveryLevel;
    }
    
    function reveal(uint randomValue, uint nonce) public timedTransitions atStage(Stage.reveal) canReveal {
        require(hash(randomValue, nonce) == commitments[msg.sender][currentRevealLevel]);
        competeInMatch(randomValue, currentRevealLevel);
    }

    function hash(uint number, uint nonce) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(number, nonce));
    }
    
    // put this function into TournamentTree?
    function getWinner() public timedTransitions atStage(Stage.end) returns(address) {
        return getNode(ROOT_ID).player;
    }

    function getNumberOfRevealLevels() internal view override returns(uint) {
        return treeHeight;
    }

    function getAmountOfShares() internal view override returns(uint) {
        return totalShares;
    }
}

contract Lottery is LeaderElection {
    uint public pricePerTicket;

    constructor(uint _pricePerTicket, uint totalTickets) LeaderElection(SignupMode.limitedShares, totalTickets) {
        pricePerTicket = _pricePerTicket;
    }

    function signUp(uint shares) override public payable timedTransitions atStage(Stage.signup) {
        require(msg.value == shares*pricePerTicket, "Number of coins does not fit number of tickets");
        addShares(msg.sender, shares);
    }

    function resign() override public payable timedTransitions atStage(Stage.signup) {
        uint refund = removePlayer(msg.sender);
        (bool success, ) = address(msg.sender).call{value: refund}("");
        require(success, "Failed to send coins");
    }
}

