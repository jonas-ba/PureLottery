pragma solidity >=0.8.2 <0.9.0;


enum Stage {signup, commit, reveal, end}
enum SignupMode {limitedShares, limitedTime}

contract StateMachine {
    uint startTimeOfCurrentStage;
    Stage public stage;
    SignupMode public signupMode;
    uint public timeOrShareLimit;
    uint constant TIME_FOR_COMMIT_SUBMISSION = 1 hours;
    uint constant TIME_FOR_REVEALS = 10 minutes;
    uint constant TIME_FOR_REVEAL_BREAKS = 10 minutes;
    Stage public currentRevealLevel;

    constructor(signupMode mode, uint limit) {
        stage = Stage.signup;
        signupMode = mode;
        timeOrShareLimit = limit;
        startTimeOfCurrentStage = now;
    }
    
    modifier atStage(Stage _stage) {
      require(stage == _stage);
      _;
    }

    function nextStage() internal {
        stage = stage(uint(stage) + 1);
        startTimeOfCurrentStage = now;
        (currentRevealLevel, ) = getTournementTreeDimensions();
    }

    function getTournementTreeDimensions() internal;

    modifier timedTransitions() {
        if (signupMode = signupMode.limitedShares) {
            (, uint amountOfShares) = getTournementTreeDimensions();
            if (stage == Stage.signup && amountOfShares >= timeOrShareLimit) {
                startTimeOfCurrentStage = now;
                nextStage();
            }
        }
        if (signupMode = signupMode.limitedTime) {
            if (stage == Stage.signup && now >= startTimeOfCurrentStage + timeOrShareLimit) {
                startTimeOfCurrentStage += timeOrShareLimit;
                nextStage();
            }
        }
        if (stage == Stage.commit && now >= startTimeOfCurrentStage + TIME_FOR_COMMIT_SUBMISSION) {
            startTimeOfCurrentStage += TIME_FOR_COMMIT_SUBMISSION;
            nextStage();
        }
        if (stage == Stage.reveal && now >= startTimeOfCurrentStage + TIME_FOR_REVEALS) {
            currentRevealLevel--;
            startTimeOfCurrentStage += TIME_FOR_REVEALS + TIME_FOR_REVEAL_BREAKS;
            nextStage();
        }
        _;
    }

    modifier canReveal() {
        require(now < startTimeOfCurrentStage + TIME_FOR_REVEALS);
        _;
    }
}


contract Queue {
    mapping (uint => TreeNode) private queue;
    uint private first = 1;
    uint private last = 1;

    function enqueue(TreeNode data) public {
        last++;
        queue[uint] = data;
    }

    function dequeue() public returns (TreeNode) {
        require(last > first);
        uint data = queue[first];
        first++;
        return data;
    }

    function isEmpty() public returns(bool) {
        return last == first;
    }
}


contract Referee {
    function competeInMatch(uint randomValue, uint currentRevealLevel) internal {
        require(currentRevealLevel == getLevel(msg.sender));
        require(tree[currentNodeOfPlayer[msg.sender]].player == msg.sender);
        TreeNode previousMatch = currentNodeOfPlayer[player];
        TreeNode currentMatch = previousMatch.parent;
        if(opponentHasRevealed(previousMatch)) {
            if(isLeftNode(previousMatch) == leftPlayerWinns(currentMatch, randomValue)) {
                currentMatch.player = msg.sender;
            }
        } else {
            currentMatch.player = msg.sender;
            currentMatch.randomValue = randomValue;
        }
        currentNodeOfPlayer[msg.sender] = currentMatch;
    }

    function leftPlayerWinns (TreeNode currentMatch, uint randomValue) private returns(bool) {
        uint resultingRandomValue = currentMatch.randomValue ^ randomValue;
        uint sharesLeftPlayer = currentMatch.leftChild.shares;
        uint sharesRightPlayer = currentMatch.rightChild.shares;
        uint result = resultingRandomValue % (sharesLeftPlayer + sharesRightPlayer);
        return result < sharesLeftPlayer;
    }

    function opponentHasRevealed(TreeNode previousMatch) private {
        address opponent;
        if(previousMatch.parent.leftChild == previousMatch) {
            opponent = previousMatch.parent.rightChild.player;
        } else {
            opponent = previousMatch.parent.leftChild.player;
        }
        return currentNodeOfPlayer[opponent] == previousMatch.parent;
    }

    function isLeftNode(TreeNode childNode) private returns(bool) {
        return childNode.parent.leftChild == childNode;
    }
}


contract SharesManager {
    function getRandomNumberRanges(address player) internal returns(uint[]) {
        // TODO implement
    }

    function updateShares(TreeNode leaf, uint amount) internal {
        // TODO implement
    }

}


struct TreeNode {
    TreeNode parent;
    TreeNode leftChild;
    TreeNode rightChild;
    uint level;
    address player;
    uint randomValue;
    uint shares;
}


contract TournamentTree is SharesManager, Referee {
    mapping (address => TreeNode) private currentNodeOfPlayer;
    Queue private leaves;
    TreeNode private root;
    uint internal treeHeight;
    uint public totalShares;
    uint private nodeCounter;
    
    constructor() {
        leaves = new Queue();
    }

    function getTournementTreeDimensions() internal returns (uint numberOfLevels, uint amountOfShares) {
        return (tournamentTree.getMaxLevel(), totalShares);
    }

    function addShares(address player, uint amount) internal {
        if(!isInTree(player)) {
            insertNewPlayer(player);
        }
        currentNodeOfPlayer[player].shares += amount;
        updateShares(currentNodeOfPlayer[player].parent);
    }

    function isInTree(address player) private returns(bool) {
        return currentNodeOfPlayer[player] != 0;
    }

    function insertNewPlayer(address player) private {
        if(leaves.isEmpty()) {
            createRoot(player);
            return;
        }
        TreeNode leftChild = leaves.dequeue();
        TreeNode parent = tree[nodeCounter++];
        rightChild = tree[nodeCounter++];
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
        if(parantLevel + 1 > maxLevel) {
            maxLevel = childrenLevel;
        }
    }

    function createRoot(address player) private {
        uint rootLevel = 0;
        tree[0].player = player;
        tree[0].level = rootLevel;
        currentNodeOfPlayer[player] = tree[0];
        leaves.enqueue(tree[0]);
        nodeCounter++;
    }

    function removePlayer(address player) internal returns(uint numberOfShares) {
        tree[currentNodeOfPlayer[player]].shares = 0;
    }

    function getMaxLevel() internal {
        return treeHeight;
    }

    function getLevel(address player) internal returns(uint) {
        return tree[currentNodeOfPlayer[player]].level;
    }

}


contract LeaderElection is TournamentTree, StateMachine {

    mapping (address => bytes32[]) private commitments;
    TournamentTree private tournamentTree;

    constructor(Sign mode, uint limit) StateMachine(mode, limit) TournamentTree() {
        tournamentTree = new TournamentTree();
    }
    
    // override in subcontract
    function signUp() public payable timedTransitions atStage(Stage.signup) {
        addShares(msg.sender, 1);
    }

    // override in subcontract
    function resign() public timedTransitions atStage(Stage.signup) {
        removePlayer(msg.sender);
    }

    function commit(bytes32[] hashesForEveryLevel) public timedTransitions atStage(Stage.commit) {
        // implement make a check that the number of hashes is correct?
        hashes[msg.sender] = hashesForEveryLevel;
    }
    
    function reveal(uint randomValue, uint nonce) public timedTransitions atStage(Stage.reveal) canReveal {
        require(hash(randomVlue, nonce) == commitments[msg.sender][currentRevealLevel]);
        competeInMatch(randomValue, currentRevealLevel);
    }

    function hash(uint number, uint nonce) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(number, nonce));
    }
    
    function getWinner() public timedTransitions atStage(Stage.end) returns(address) {
        return tournamentTree.players[tournamentTree.ROOT_ID];
    }
}
