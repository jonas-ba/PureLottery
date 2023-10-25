pragma solidity >=0.8.2 <0.9.0;
import "./leader_election.sol";

contract Test {
    using CreateTournament for Tournament;
    using RunTournament for Tournament;
    using RndSubmission for Tournament;

    event Log(string message, uint number);
    event PlayerLog(string message, address player, uint number);
    event PlayerArrayLog(string message, address player, uint[] array);

    // create tree with n players with equal shares
    function createTournament(uint playerCount) public returns(Tournament) {
        Tournament public tournament;
        for (uint i = 0; i < playerCount; i++) {
            tournament.addPlayer(player(i));
            addShares(player(i), 1);
        }
        tournament.setTotalRounds();
        emit Log("tree height: ", tournament.totalRounds);
        return tournament;
    }

    function player(uint number) private pure returns(address) {
        return address(uint160(number));
    }

    // Test with 2 players
    function test1() public {
        Tournament public tournament = createTournament(2);
        tournament.compete(player(1), 0);
        tournament.compete(player(2), 0);
        tournament.currentRound++;
        address winner = tournament.getTournamentWinner();
        emit PlayerLog("winner and total weight: ", winner, tournament.weights[winner]);
    }



    
    
}
