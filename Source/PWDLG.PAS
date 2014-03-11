unit pwdlg;

interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls, StdCtrls, 
  Buttons;

type
  TPasswordDlg = class(TForm)
    Label1: TLabel;
    PasswordEdit: TEdit;
    OKBtn: TButton;
    CancelBtn: TButton;
    Label2: TLabel;
    LoginEdit: TEdit;
    CheckBox1: TCheckBox;
    MsgLabel: TLabel;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  PasswordDlg: TPasswordDlg;

implementation

{$R *.DFM}

end.
 
