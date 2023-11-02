pragma solidity >=0.8.2 <0.9.0;

import "hardhat/console.sol";
import "./leader_election.sol";

contract Tests {
    /*
        Re-depoly this contract between executing the different tests
        to de-initialize all storage variables
    */

    using CreateTournament for Tournament;
    using RunTournament for Tournament;

    Tournament public tournament;

    // create tree with n players with equal shares
    function createTournament(uint playerCount) private {
        for (uint i = 1; i <= playerCount; i++) {
            tournament.addPlayer(player(i));
            tournament.addWeight(player(i), 1);
        }
    }

    // do not use player(0) for testing
    function player(uint number) private pure returns(address) {
        return address(uint160(number));
    }

    function printTournament() private view {
        uint i = tournament.totalRounds;
        console.log("PRINT TOURNAMENT TREE");
        while (true) {
            console.log("round ", i);
            uint positions = tournament.totalPlayers / (2**i);
            for (uint j = 0; j <= positions; j++) {
                console.log(uint160(tournament.playersTree[j][i]), ": weight ", tournament.weights[j][i]);
            }
            if(i==0) break;
            i--;
        }
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

    // Test with 2 players
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

    function test3() public {
        createTournament(3);
        tournament.compete(player(1), 0);
        tournament.compete(player(2), 0);
        tournament.compete(player(3), 0);
        tournament.currentRound++;
        tournament.compete(player(1), 0);
        tournament.compete(player(3), 0);
        tournament.currentRound++;
        assert(tournament.getTournamentWinner() == player(1));
    }

    function test4() public {
        createTournament(3);
        tournament.compete(player(1), 0);
        tournament.compete(player(2), 1);
        tournament.compete(player(3), 0);
        tournament.currentRound++;
        tournament.compete(player(2), 0);
        tournament.compete(player(3), 0);
        tournament.currentRound++;
        assert(tournament.getTournamentWinner() == player(2));
    }

    function test5() public {
        createTournament(3);
        tournament.compete(player(1), 0);
        tournament.compete(player(2), 1);
        tournament.compete(player(3), 0);
        tournament.currentRound++;
        tournament.compete(player(2), 1);
        tournament.compete(player(3), 0);
        tournament.currentRound++;
        assert(tournament.getTournamentWinner() == player(3));
    }

    function test6() public {
        createTournament(4);
        tournament.compete(player(1), 0);
        tournament.compete(player(2), 0);
        tournament.compete(player(3), 0);
        tournament.compete(player(4), 0);
        tournament.currentRound++;
        tournament.compete(player(1), 0);
        tournament.compete(player(3), 0);
        tournament.currentRound++;
        assert(tournament.getTournamentWinner() == player(1));
    }

    function test7() public {
        createTournament(5);
        tournament.compete(player(1), 0);
        tournament.compete(player(2), 0);
        tournament.compete(player(3), 0);
        tournament.compete(player(4), 0);
        tournament.compete(player(5), 0);
        tournament.currentRound++;
        tournament.compete(player(1), 0);
        tournament.compete(player(3), 0);
        tournament.compete(player(5), 0);
        tournament.currentRound++;
        tournament.compete(player(1), 0);
        tournament.compete(player(5), 0);
        printTournament();
        tournament.currentRound++;
        assert(tournament.getTournamentWinner() == player(1));
    }

    function test8() public {
        createTournament(5);
        tournament.compete(player(5), 1);
        tournament.compete(player(1), 1);
        tournament.compete(player(4), 0);
        tournament.compete(player(2), 0);
        tournament.compete(player(3), 1);
        printTournament();
        tournament.currentRound++;
        tournament.compete(player(4), 2);
        tournament.compete(player(5), 1);
        tournament.compete(player(2), 0);
        printTournament();
        tournament.currentRound++;
        tournament.compete(player(5), 0);
        tournament.compete(player(4), 4);
        printTournament();
        tournament.currentRound++;
        assert(tournament.getTournamentWinner() == player(5));
    }

    // TESTS THAT SHOULD FAIL:

    function testFail1() public {
        createTournament(3);
        tournament.compete(player(1), 1);
        tournament.compete(player(2), 1);
        tournament.compete(player(3), 0);
        printTournament();
        tournament.compete(player(4), 0);
        printTournament();
        tournament.currentRound++;
        tournament.compete(player(1), 0);
        tournament.compete(player(3), 1);
        tournament.currentRound++;
        assert(tournament.getTournamentWinner() == player(3));
    }
    
}
