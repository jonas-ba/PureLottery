pragma solidity >=0.8.2 <0.9.0;

contract LeaderElection { // TODO is TournamentTree is StateMachine ???

    // STATE MACHINE

    enum Stage {signup, commit, reveal, end};
    Stage public stage;
    Stage public currentRevealLevel;
    // TIME_FOR_REVEALS
    // TIME_FOR_REVEAL_BREAKS
    // TIME_FOR_SIGNUP
    // TIME_FOR_COMMIT_SUBMISSION
    // TODO signup mode: max shares, time limit

    modifier atStage(Stages _stage) {
      require(stage == _stage);
      _;
    }

    function nextStage() internal {
        phase = phase(uint(phase) + 1);
        // set currentRevealLevel when finishing sign-up stage
    }

    modifier timedTransitions() public; // TODO


    



    uint public totalShares;
    mapping (address => bytes32[]) private commitments;
    TournamentTree private tournamentTree;

    constructor() {
        tournamentTree = new TournamentTree();
    }
    
    // IMPORTANT: Must be overridden in subcontract
    function signUp(uint shares) public payable timedTransitions atStage(Stage.signup) {
        tournamentTree.addShares(msg.sender, shares);
    }
    // make abstract signUp function and internal addShares function


// redundant
    function resign() public timedTransitions atStage(Stage.signup) {
        tournamentTree.removePlayer(msg.sender);
    }

    function commit(bytes32[] hashesForEveryLevel) public timedTransitions atStage(Stage.commit) {
        // TODO make a check that the number of hashes is correct?
        hashes[msg.sender] = hashesForEveryLevel;
    }
    
    function reveal(uint randomValue, uint nonce) public timedTransitions atStage(Stage.reveal) {
        require(hashing(randomVlue, nonce) == commitments[msg.sender][currentRevealLevel]);
        tournamentTree.competeInMatch(msg.sender, randomValue, currentRevealLevel);
    }

    function hashing(uint number, uint nonce) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(number, nonce));
    }
    
    function getWinner() public timedTransitions atStage(Stage.end) returns(address) {
        return tournamentTree.players[tournamentTree.ROOT_ID];
    }

    // if we decide to use the simple version (not adjusting random numbers to the exact range)
    // implement everything concerning the shares here

}

contract Referee {
    // TODO
    function decideMatch(TreeNode match, address player, uint randomValue) {
        // NodeSide is for left and right child
    }
}

contract TournamentTree {
    // TODO can you put everything into one node and then always use mapping[arg].field 
    // to no write to all fields?
    mapping (address => uint) private currentNodeOfPlayer;
    mapping (uint => TreeNode) private treeByNodeId;
    struct TreeNode {
        uint nodeId; // TODO why not store a reference instead of the id?
        uint parentId;
        uint leftChildId;
        uint rightChildId;
        uint level;
    } 
    Queue private leaves;
    uint constant ROOT_ID = 1;
    mapping (uint => address) private playerOfNode;
    mapping (uint => uint) private randomNumbersOfNode;
    mapping (uint => uint) private sharesOfNode;
    uint treeHeight;
    
    constructor() {
        leaves = new Queue();
        uint nodeCounter = ROOT_ID;
    }

    function addShares(address player, uint amount) internal {
        if(!isInTree(player)) {
            insertNewPlayer(player);
        }
        uint nodeId = furthestNode[player];
        shares[nodeId] += amount;
    }

    function isInTree(address player) private return (bool) {
        return furthestNode[player] != 0;
    }

    // TODO create object for inserting a new payer
    function insertNewPlayer(address player) private {
        // TODO manage shares
        if(leaves.isEmpty()) {
            createRoot(player);
            return;
        }
        uint parentId = leaves.dequeue();
        uint parentLevel = tree[parentId].level;
        (uint leftChildId, uint rightChildId) = sproutNewLeaves(parentId);
        address otherPlayer = players[parentId];
        newLeaf(otherPlayer, leftChildId, parentId, parentLevel + 1);
        newLeaf(player, rightChildId, parentId, parentLevel + 1);
        if(parantLevel + 1 > maxLevel) {
            maxLevel = childrenLevel;
        }
    }

    function sproutNewLeaves(uint leafId) private returns(uint childLeftId, uint childRightId) {
        uint leftChildId = nodeCounter++;
        uint rightChildId = nodeCounter++;
        tree[parentId].leftChildId = leftChildId;
        tree[parentId].rightChildId = rightChildId;
    }

    function newLeaf(address player, uint leafId, uint parentId, uint childrenLevel) private {
        TreeNode leaf = TreeNode(nodeId, parentId, 0, 0, childrenLevel);
        tree[leafId] = leaf;
        currentNode[player] = leafId;
        players[leftChildId] = player;
    }

    function createRoot(address player) private {
        uint rootLevel = 0;
        TreeNode root = TreeNode(ROOT_ID, 0, 0, 0, rootLevel);
            currentNode[player] = ROOT_ID;
            players[ROOT_ID] = player;
            leaves.enqueue(ROOT_ID);
            nodeCounter++;
    }

    function removePlayer(address player) internal returns(uint numberOfShares) {
        // TODO implement
    }

    function competeInMatch(player, randomValue, currentStage) internal {
        // TODO implement
    }

    function getMaxLevel() internal {
        return treeHeight;
    }

    function getRandomNumberRanges(address player) internal returns(uint[]) {
        uint[] numberRangers;
        // TODO implement
    }

    function getLevel(address player) internal returns(uint) {
        return tree[currentNode[player]].level;
    }
}


contract Queue {
    mapping (uint => uint) private queue;
    uint private first = 1;
    uint private last = 1;

    function enqueue(uint data) public {
        last++;
        queue[uint] = data;
    }

    function dequeue() public returns (uint) {
        require(last > first);
        uint data = queue[first];
        first++;
        return data
    }

    function isEmpty() public returns(bool) {
        return last == first;
    }
}

