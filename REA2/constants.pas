unit constants;

interface

const
  nHELLO_CODE:integer=100; sHELLO_MSG:string='Welcome to victims kingdom!';
  nNO_COMMAND_CODE:integer=105; sNO_COMMAND_MSG:string='Type a command followed by space or type help.';
  nINVALID_COMMAND_CODE:integer=110; sINVALID_COMMAND_MSG:string='Command not recognized. Type voculbary to know valid commands.';
  nNO_PARAM_CODE:integer=115; sNO_PARAM_MSG='Command requires parameters.';
  nREQ_TWO_PARAM_CODE:integer=120; sREQ_TWO_PARAM_MSG='Command requires two parameters: CMD "param1" "param2".';
  nCOMMAND_ENDED_CODE:integer=125;
  nWAIT_CODE:integer=130; sWAIT_MSG:string='wait while command completes';
  nINVALID_PARAM_CODE:integer=135; sINVALID_PARAM_MSG:string='Passed parameter is invalid';
  nINTERNAL_ERROR_CODE:integer=140;

implementation

end.
