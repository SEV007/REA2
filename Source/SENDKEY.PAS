unit sendkey;

interface
uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ComCtrls, StdCtrls, Buttons, ScktComp, ExtCtrls, ToolWin, Gauges, IniFiles,
  Menus, Math, ShellApi,Registry;


procedure SimulateKeyDown(Key : byte);
procedure SimulateKeyUp(Key : byte);
procedure SimulateKeystroke(Key : byte;
                            extra : DWORD);
procedure SendKeys(s : string);
procedure SendKeyToWin(hWnd:Integer;sKeys:string);                            

implementation

procedure SimulateKeyDown(Key : byte);
begin
  keybd_event(Key, 0, 0, 0);
end;

procedure SimulateKeyUp(Key : byte);
begin
  keybd_event(Key, 0, KEYEVENTF_KEYUP, 0);
end;

procedure SimulateKeystroke(Key : byte;
                            extra : DWORD);
begin
  keybd_event(Key,
              extra,
              0,
              0);
  keybd_event(Key,
              extra,
              KEYEVENTF_KEYUP,
              0);
end;

procedure SendKeys(s : string);
var
  i : integer;
  flag : bool;
  w : word;
begin
  try
   {Get the state of the caps lock key}
    flag := not GetKeyState(VK_CAPITAL) and 1 = 0;
   {If the caps lock key is on then turn it off}
    if flag then
      SimulateKeystroke(VK_CAPITAL, 0);
    for i := 1 to Length(s) do begin
      w := VkKeyScan(s[i]);
     {If there is not an error in the key translation}
      if ((HiByte(w) <> $FF) and
          (LoByte(w) <> $FF)) then begin
       {If the key requires the shift key down - hold it down}
        if HiByte(w) and 1 = 1 then
          SimulateKeyDown(VK_SHIFT);
       {Send the VK_KEY}
        SimulateKeystroke(LoByte(w), 0);
       {If the key required the shift key down - release it}
        if HiByte(w) and 1 = 1 then
          SimulateKeyUp(VK_SHIFT);
      end;
    end;
   {if the caps lock key was on at start, turn it back on}
    if flag then
      SimulateKeystroke(VK_CAPITAL, 0);
  except
  end;
end;

procedure SendKeyToWin(hWnd:Integer;sKeys:string);
var hLastFocusedWin:Integer;
begin
  try
    hLastFocusedWin:=GetFocus();
    SetFocus(hWnd);
    SendKeys(sKeys);
    SetFocus(hLastFocusedWin);
  except
  end;
end;


end.
 