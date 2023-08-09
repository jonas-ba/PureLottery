pragma solidity >=0.8.2 <0.9.0;


contract Selector {
// TODO 2


    uint sharesCount



    uint maxTreeDepth;

    players;

    uint nodeCount;

    address public owner;

    constructor() {
        
    }

    // SUBCONTRACT REGISTRATOR
    + constructor: signup-modes manual stop/limited shares/time limit
    + signup
        if player already exists, update his shares
        add insertNewPlayer
    + resign
    + pure getRandomNumbersRange
    + commit

    // SUBCONTRACT Selector
    + reveal
    - verify
    + view getCurrentRound
    + isWinner

    currentStage
    stageTime
    TIME_FOR_REVEAL
    TIME_FOR_BREAK


}







enum phase {signup, commit, reveal, end};
contract timeController {
    uint private currentPhase;
    function allow(phase currentPhase) public returns(bool) {
        return (currentPhase == phase.signup 
        || currentPhase == phase.commit 
        || currentPhase == phase.reveal 
        || currentPhase == phase.end);
    }

    function public refresh() {
        // if time is up, change phase
    }


}


struct Match {
    uint shares;
    uint randomNumberOfFirstPlayer;
    bool firstPlayerHasSubmitted;
}


contract tournament is matchScheduleTree {
// TODO 1

    // update shares in the whole tree hierachy when adding a new player

    Queue private leaves;
    mapping (uint => Payload) private matchTree;
    

    constructor() {
        leaves = new Tree();
    }

    // TODO
    // return maximum number of levels
    // get number range sequence

    function addShares(address player, uint amount) {
        // if not alredy exists, add player
    }

    function removeAllShares(address player) {
        
    }

    function competeInCurrentMatch(player, randomValue, currentStage) {

    }
}


// the tree keeps all paylods (matches) at the lowest level
// the tree structure is as flat as possible
contract matchScheduleTree {
    struct Node {
        uint parentNodeId;
        uint nodeLevel;
        Match payload;
        address winner;
    }

    Queue private leaves;
    uint private nodeCounter;
    mapping (uint => Node) private tree;
    mapping (address => mapping (uint => Node)) private nodeIds; //tree[player, level] --> nodeId
    mapping (address => uint) private playerLevel;

    constructor() {
        leaves = new Queue();
    }
    
    function insert(address player, Match baseMatch) internal {
        if(leaves.isEmpty()) {
            tree[0] = Node(0, 0, payload);
            leaves.enqueue(0);
            nodeCounter++;
            return 0;
        }

        uint parentId = leaves.dequeue();
        Match parentPayload = matchTree[parentId].payload;
        address playerLeft = matchTree[parentId].winner;
        matchTree[parentId].payload = Match(0, 0, 0, 0);

        uint newLevel = matchTree[parentId].nodeLevel + 1;
        playerLevel[playerLeft];
        Node nodeLeft = Node(parentId, newLevel, parentPayload);
        uint nodeIdLeft = nodeCounter;
        nodeIds[playerLeft][newLevel] = nodeIdLeft;
        tree[nodeIdLeft] = nodeLeft;

        playerLevel[player] = newLevel;
        Node nodeRight = Node(parentId, newLevel, payload);
        uint nodeIdRight = nodeCounter + 1;
        nodeIds[player][newLevel] = nodeIdRight;
        tree[nodeIdRight] = nodeRight;

        nodeCounter += 2;
        return nodeIdRight;
    }

    function getCurrentNode(address player) private view returns(Node) {
        uint level = playerLevel[player];
        uint nodeId = nodeIds[player][level];
        return tree[nodeId];
    }

    function getPreviousMatch(address player) internal view returns(Match) { // last victorious match
        return getCurrentNode(player).payload;
    }

    function getNextMatch(address player) internal view returns(Match) {
        uint parentId = getCurrentNode(player).payload.parentId;
        return tree[parentId].payload;
    }

    function getPlayerLevel(address player) public view returns(Match) {
        return playerLevel[player];
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
