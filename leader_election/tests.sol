pragma solidity >=0.8.2 <0.9.0;
import "./leader_election.sol";

contract Test is LeaderElection {

    event Log(string message, uint number);
    event PlayerLog(string message, address player, uint number);
    event PlayerArrayLog(string message, address player, uint[] array);

    constructor() TournamentTree() {}

    // Remove this function after testing
    function next() public {
        nextStage();
    }

    function cleanTree() private {
        // TODO
    }

    function test1() public {
        // 2 players

        cleanTree();
        address player1 = address(uint160(1));
        address player2 = address(uint160(2));
        address player3 = address(uint160(3));
        addShares(player1, 1);
        addShares(player2, 1);
        addShares(player3, 1);
        emit Log("tree height: ", treeHeight);
        emit PlayerLog("player level: ", player1, getLevel(player1));
        emit PlayerLog("player level: ", player2, getLevel(player2));
        emit PlayerLog("player level: ", player3, getLevel(player3));
        emit PlayerArrayLog("player random number ranges: ", player1, getRandomNumberRanges(player1));
        emit PlayerArrayLog("player random number ranges: ", player2, getRandomNumberRanges(player2));
        emit PlayerArrayLog("player random number ranges: ", player3, getRandomNumberRanges(player3));
    }

    function test2() public {
        // 3 players
    }

    
    
}
