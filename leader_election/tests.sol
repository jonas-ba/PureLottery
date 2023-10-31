pragma solidity >=0.8.2 <0.9.0;

import "hardhat/console.sol";
import "./leader_election.sol";

contract Test {
    using CreateTournament for Tournament;
    using RunTournament for Tournament;

    Tournament public tournament;

    // create tree with n players with equal shares
    function createTournament(uint playerCount) public {
        for (uint i = 1; i <= playerCount; i++) {
            tournament.addPlayer(player(i));
            tournament.addWeight(player(i), 1);
        }
    }

    function player(uint number) private pure returns(address) {
        return address(uint160(number));
    }

    // Test with 2 players
    function test1() public {
        console.log("step 1");
        createTournament(2);
        console.log("step 2");
        
        tournament.compete(player(1), 0);
        console.log("step 3");
        tournament.compete(player(2), 0);
        console.log("step 4");
        tournament.currentRound++;
        console.log("step 5");
        address winner = tournament.getTournamentWinner();
        console.log("winner is ");
        console.log(winner);
        console.log("step 6");
    }

    function test2() public {
        console.log("step 1");
        createTournament(2);
        console.log("step 2");
        
        tournament.compete(player(1), 0);
        console.log("step 3");
        tournament.compete(player(2), 1);
        console.log("step 4");
        tournament.currentRound++;
        console.log("step 5");
        address winner = tournament.getTournamentWinner();
        console.log("winner is ");
        console.log(winner);
        console.log("step 6");
    }
    
}
