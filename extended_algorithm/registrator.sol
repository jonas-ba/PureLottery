pragma solidity >=0.8.2 <0.9.0;


contract Registrator {

uint sharesCount



uint maxTreeDepth;

players;

uint nodeCount;

address public owner;

enum phase {signup, commit, reveal, end};
phase public currentPhase;






constructor() {
    
}

+ constructor: signup-modes manual stop/limited shares/time limit
+ signup
    if player already exists, update his shares
    add insertNewPlayer
+ resign
+ pure getRandomNumbersRange
+ commit




}




/*
contract Matches is ShallowTree {
    
// matches --> this methods in the MatchTree or in the Node
    // insert(player)
    // addShares(player, amount)
    // remove(player) --> set shares to 0
    // competeInCurrentMatch(player, randomValue)

}
*/


struct Payload {
    address player;
    uint shares;
    uint randomNumberOfFirstPlayer;
    bool onePlayerHasSubmitted;
}


// creates a tree that is as shallow as possible
// all data is stored in the leaves
contract ShallowTree {

    // mapping player->currentMatchIndex

    struct node {
        uint id;
        uint parentId;
        uint nodeLevel;
        Payload payload;
    }

    Queue private leaves;
    mapping (uint => Payload) private matchTree;
    uint nodeCounter;

    constructor() {
        leaves = new Queue();
    }

    function insert(Payload _payload) public {
        // if tree is empty
        uint index = leaves.dequeue();
        matchNode data = matchTree[index];
        delete matchTree[index];
        // ...
        nodeCounter++;
    }

    function updatePayload(address player, Payload _payload) public {
        matchTree[id] = node;
    }

    function getPayload(address player) public returns(Payload) {
        return matchTree[id];
    }

    function getParentPayload(address player) public returns(Payload) {
        //return matchTree[id];
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
}