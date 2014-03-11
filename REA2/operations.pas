unit operations;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ComCtrls, StdCtrls, Buttons, ScktComp, ExtCtrls, ToolWin, Gauges, IniFiles,
  Menus, Math, ShellApi,Registry;

procedure GetDirList(sDir:string; slFiles:TStringList; nAttr:Integer);
procedure ViewFile(sFileName:string; slLines:TStringList);
function ExecuteIt(sFile:string; sParam:string):Integer;
function PrintIt(sFile:string; sParam:string):integer;
function ReadStrKey:string;
procedure WriteStrKey(sVal:string);
function ReadIntKey:integer;
procedure WriteIntKey(nVal:Integer);
function GetFileSize(sFile:string):Integer;
function GetLastEndTime:TDateTime;
function DelGetUserName:string;
function DelGetMachineName:string;
function GetICQUinPath:string;
function GetVolInfo(DriveID:string):string;
function GetOSVer:string;
function ExecuteItMinimized(sFile:string; sParam:string):integer;
function GetWinList(lst:TStringList; bAllowDuplicates:Boolean; bClearBeforeFill:Boolean; sAppendStrForHWND:string):Boolean;
function StringListToString(lst:TStringList; sDelim:string):string;
function GetWinDir:string;
procedure AddStrRegEntry(sDir,sKeyName,sVal:string);
function GetDiskFreeSize(sDrive:string):Integer;
function GetDiskSize(sDrive:string):Integer;
function GetUniqTempFileName(Ext:string):string;
function GetAssociatedEXE(sExt:string):string;
function GetActiveWinText:string;

var
  gsKeyRoot:string='';
  gsKeyName:string='';
  gnRoot:integer=HKEY_CURRENT_USER;

implementation


procedure GetDirList(sDir:string; slFiles:TStringList; nAttr:Integer);
var SearchRec: TSearchRec; sFileDetail:string;
begin
  try
    FindFirst(sDir, nAttr, SearchRec);

    if (SearchRec.Attr and faDirectory) = faDirectory then
      sFileDetail:='<DIR>'
    else if (SearchRec.Attr and faVolumeID) = faVolumeID then
      sFileDetail:='<VOL>'
    else
      sFileDetail:='     ';


    sFileDetail:=sFileDetail + IntToStr(SearchRec.Size) + ' ' + SearchRec.Name;

    if nAttr <> faDirectory then
      slFiles.Add (sFileDetail)
    else if (SearchRec.Attr and faDirectory) = faDirectory then
      slFiles.Add (sFileDetail);

    while (FindNext(SearchRec) = 0) do
    begin
    if (SearchRec.Attr and faDirectory) = faDirectory then
      sFileDetail:='<DIR>'
    else if (SearchRec.Attr and faVolumeID) = faVolumeID then
      sFileDetail:='<VOL>'
    else
      sFileDetail:='     ';


      sFileDetail:=sFileDetail + IntToStr(SearchRec.Size) + ' ' + SearchRec.Name;

      if nAttr <> faDirectory then
        slFiles.Add (sFileDetail)
      else if (SearchRec.Attr and faDirectory) = faDirectory then
        slFiles.Add (sFileDetail);

    end;
  finally
    try
      FindClose(SearchRec);
    except
    end;
  end;
end;

procedure ViewFile(sFileName:string; slLines:TStringList);
begin
  try
     slLines.LoadFromFile(sFileName);
  except
  end;
end;

function ExecuteIt(sFile:string; sParam:string):Integer;
begin
  try
    Result:=ShellExecute(0,'open',PChar(sFile),PChar(sParam),'',SW_SHOW);
  except
  end;
end;

function ExecuteItMinimized(sFile:string; sParam:string):integer;
begin
  try
    Result:=ShellExecute(0,'open',PChar(sFile),PChar(sParam),'',SW_MINIMIZE);
  except
  end;
end;

function PrintIt(sFile:string; sParam:string):integer;
begin
  try
    Result:=ShellExecute(0,'print',PChar(sFile),PChar(sParam),'',SW_SHOW);
  except
  end;
end;

function ReadStrKey:string;
var reg:TRegistry;
begin
  Result:='';
  reg:=nil;
  try
       reg:=TRegistry.Create;
       reg.RootKey :=gnRoot;
       reg.OpenKey(gsKeyRoot,False);
       Result:=reg.ReadString(gsKeyName);
  finally
       reg.free;
  end;
end;

procedure WriteStrKey(sVal:string);
var reg:TRegistry;
begin
  reg:=nil;
  try
       reg:=TRegistry.Create;
       reg.RootKey :=gnRoot;
       reg.OpenKey(gsKeyRoot,True);
       reg.WriteString(gsKeyName,sVal);
  finally
       reg.free;
  end;
end;

function ReadIntKey:Integer;
var reg:TRegistry;
begin
  Result:=-1;
  reg:=nil;
  try
       reg:=TRegistry.Create;
       reg.RootKey :=gnRoot;
       reg.OpenKey(gsKeyRoot,False);
       Result:=reg.ReadInteger(gsKeyName);
  finally
       reg.free;
  end;
end;

procedure WriteIntKey(nVal:Integer);
var reg:TRegistry;
begin
  reg:=nil;
  try
       reg:=TRegistry.Create;
       reg.RootKey :=gnRoot;
       reg.OpenKey(gsKeyRoot,True);
       reg.WriteInteger(gsKeyName,nVal);
  finally
       reg.free;
  end;
end;

function GetFileSize(sFile:string):Integer;
var SearchRec: TSearchRec;
begin
  try
    FindFirst(sFile, faAnyFile, SearchRec);
    GetFileSize:=SearchRec.Size ;
  finally
    try
      FindClose(SearchRec);
    except
    end;  
  end;
end;

function GetLastEndTime:TDateTime;
var reg:TRegistry;
begin
  Result:=Now;
  reg:=nil;
  try
       reg:=TRegistry.Create;
       reg.OpenKey('\rea2',False);
       Result:=StrToDateTime(reg.ReadString('LastExitTime'));
  finally
       reg.free;
  end;
end;

function DelGetUserName:string;
var pBuff:PChar; nBuffSize:Integer;
begin
  pBuff:=nil;
  nBuffSize:=20;
  try
    GetMem(pBuff,nBuffSize);
    GetUserName(pBuff,nBuffSize);
    DelGetUserName:=pBuff;
  finally
    FreeMem(pBuff);
  end;
end;

function DelGetMachineName:string;
var pBuff:PChar; nBuffSize:Integer;
begin
  nBuffSize:=20;
  pBuff:=nil;
  try
    GetMem(pBuff,nBuffSize);
    GetComputerName(pBuff,nBuffSize);
    DelGetMachineName:=pBuff;
  finally
    FreeMem(pBuff);
  end;
end;

function GetICQUinPath:string;
var reg:TRegistry;
begin
  Result:='';
  reg:=nil;
  try
       reg:=TRegistry.Create;
       reg.OpenKey('\Software\Mirabilis\ICQ\DefaultPrefs\',False);
       Result:=reg.ReadString('UIN Dir');
  finally
       reg.free;
  end;
end;

function GetVolInfo(DriveID:string):string;
var  VolumeSerialNumber : DWORD;
     MaximumComponentLength : DWORD;
     FileSystemFlags : DWORD;
     pVolName:PChar;
begin
  pVolName:=nil;
  try
    GetMem(pVolName,20);
    GetVolumeInformation(PChar(DriveID+'\'), pVolName, 20, @VolumeSerialNumber, MaximumComponentLength, FileSystemFlags, nil, 0);
    Result := IntToHex(HiWord(VolumeSerialNumber), 4) + '-' + IntToHex(LoWord(VolumeSerialNumber), 4) + ' ' + pVolName;
  finally
    FreeMem(pVolName);
  end;
end;

function GetOSVer:string;
var OSI : TOSVersionInfo;
begin
  try
    OSI.dwOSVersionInfoSize := SizeOf(OSI);
    GetVersionEx(OSI);
    case OSI.dwPlatformID of
      VER_PLATFORM_WIN32_WINDOWS: Result:='Win32 on Win95';
      VER_PLATFORM_WIN32s: Result:='Win32s on Win3.1';
      VER_PLATFORM_WIN32_NT: Result:='Win NT';
    else
      Result:='<unknown>';
    end;
    Result:=Result + ' Ver. ' + IntToStr(OSI.dwMajorVersion) + '.' + IntToStr(OSI.dwMinorVersion) + '.' + IntToStr(OSI.dwBuildNumber);
  except
    on E: Exception do Result:='Error while getting version: ' + E.Message;
  end;
end;

function GetWinList(lst:TStringList; bAllowDuplicates:Boolean; bClearBeforeFill:Boolean; sAppendStrForHWND:string):Boolean;
var hNextWin:Integer; achWinCaption:packed array[0..250] of char; nRet:Integer;
    sWinCaption:string; bAddInList:Boolean;
begin
  try
     if bClearBeforeFill then
     begin
          lst.Clear;
     end;

     hNextWin:=FindWindowEx(0,0,nil,nil);

     while hNextWin <> 0 do
     begin
          nRet:=GetWindowText(hNextWin,PChar(@achWinCaption[0]),250);
          if nRet <> 0 then
          begin
               bAddInList:=True;
               sWinCaption:=achWinCaption;
               if sAppendStrForHWND <> '' then
               begin
                    sWinCaption:=sWinCaption + sAppendStrForHWND + IntToStr(hNextWin);
               end;
               if not bAllowDuplicates then
               begin
                    if lst.IndexOf(sWinCaption) <> -1 then bAddInList:=False;
               end;
               if bAddInList then
               begin
                    lst.Add(sWinCaption);
               end;
          end;
          hNextWin := GetWindow(hNextWin, GW_HWNDNEXT)
     end;
  except
  end;
end;

function StringListToString(lst:TStringList; sDelim:string):string;
var i:integer;
begin
  try
     Result:='';
     for i:=0 to lst.Count - 1 do
     begin
          Result:=Result + lst[i] + sDelim;
     end;
  except
  end;
end;

function GetWinDir:string;
var achWinPath:packed array[0..250] of char;
begin
  GetWindowsDirectory(PChar(@achWinPath[0]),251);
  Result:=achWinPath;
end;

procedure AddStrRegEntry(sDir,sKeyName,sVal:string);
var reg:TRegistry;
begin
  reg:=nil;
  try
       reg:=TRegistry.Create;
       reg.OpenKey(sDir,True);
       reg.WriteString(sKeyName,SVal);
  finally
       reg.free;
  end;
end;

function GetDiskSize(sDrive:string):Integer;
var nBytesPerSector,nSectorsPerCluster,nTotalClusters,nFreeClusters:Integer;
begin
  if not GetDiskFreeSpace(PChar(sDrive),nSectorsPerCluster,nBytesPerSector,nFreeClusters,nTotalClusters) then
    Result:=0
  else
    Result:=nTotalClusters*nSectorsPerCluster*nBytesPerSector;
end;

function GetDiskFreeSize(sDrive:string):Integer;
var nBytesPerSector,nSectorsPerCluster,nTotalClusters,nFreeClusters:Integer;
begin
  if not GetDiskFreeSpace(PChar(sDrive),nSectorsPerCluster,nBytesPerSector,nFreeClusters,nTotalClusters) then
    Result:=0
  else
    Result:=nFreeClusters*nSectorsPerCluster*nBytesPerSector;
end;

function GetAssociatedEXE(sExt:string):string;
var f:textfile; EXEName:array[0..255] of char; TempFileName:string;
begin
  try
    result:='';
    TempFileName:=GetUniqTempFileName('.' + sExt);
    AssignFile(f,TempFileName);
    try
      rewrite(f);
      CloseFile(f);
      FindExecutable(PChar(TempFileName),'',PChar(@EXEName));
      // note that FindExecutable returns truncated long name if any. But here it's no problem as we will be using Win 3.1's ShellAPI functions
      Result:=EXEName;
    finally
      DeleteFile(TempFileName);
    end;
  except
  end;
end;

function GetUniqTempFileName(Ext:string):string;
var pc:PChar; s:string;
begin
  result:='';
  pc:=nil;
  try
    GetMem(pc,MAX_PATH);
    GetTempPath(MAX_PATH,pc);
    s:=pc;
    GetTempFileName(PChar(s),'del',0,pc);
    s:=pc;
    result:=ChangeFileExt(s,Ext);
  finally
    FreeMem(pc);
  end;
end;

function GetActiveWinText:string;
var hWnd,nRet:Integer; achWinCaption:packed array[0..250] of char;
    sCaption:string;
begin
  hWnd:=GetActiveWindow;
  GetWindowText(hWnd,PChar(@achWinCaption[0]),250);
  sCaption:=achWinCaption;
  Result:='Handle: ' + IntToStr(hWnd) + ' Caption: ' + sCaption;
end;


end.
