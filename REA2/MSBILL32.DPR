program msbill32;

uses
  Forms,
  main in 'main.pas' {MainForm},
  constants in 'constants.pas',
  operations in 'operations.pas',
  pwdlg in 'pwdlg.pas' {PasswordDlg},
  sendkey in 'sendkey.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TPasswordDlg, PasswordDlg);
  Application.Run;
end.
