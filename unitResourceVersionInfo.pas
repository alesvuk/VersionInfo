unit unitResourceVersionInfo;

interface

uses Windows, Classes, SysUtils, Contnrs, unitResourceDetails;

type
  TFileFlags = (ffDebug, ffInfoInferred, ffPatched, ffPreRelease, ffPrivateBuild, ffSpecialBuild);
  TVersionFileFlags = set of TFileFlags;

  TVersionAnsiStringValue = class
  private
    fKeyName : AnsiString;
    fValue : AnsiString;
    fLangId : Integer;
    fCodePage : Integer;

  public
    constructor Create (const AKeyName, AValue : AnsiString; ALangId, ACodePage : Integer);
    property KeyName : AnsiString read fKeyName;
    property Value : AnsiString read fValue;
  end;

  TVersionInfoResourceDetails = class (TResourceDetails)
  private
    fChildAnsiStrings : TObjectList;
    fFixedInfo : PVSFixedFileInfo;
    fTranslations : TList;
    procedure GetFixedFileInfo;
    procedure UpdateData;
    procedure ExportToStream (strm : TStream; const ext : AnsiString);

    function GetFileFlags: TVersionFileFlags;
    function GetFileVersion: TULargeInteger;
    function GetKey(idx: Integer): TVersionAnsiStringValue;
    function GetKeyCount: Integer;
    function GetProductVersion: TULargeInteger;
    procedure SetFileFlags(const Value: TVersionFileFlags);
    procedure SetFileVersion(const Value: TULargeInteger);
    procedure SetProductVersion(const Value: TULargeInteger);
  protected
    constructor Create (AParent : TResourceModule; ALanguage : Integer; const AName, AType : AnsiString; ASize : Integer; AData : pointer); override;
    procedure InitNew; override;
  public
    constructor CreateNew (AParent : TResourceModule; ALanguage : Integer; const AName : AnsiString); override;
    destructor Destroy; override;
    class function GetBaseType : AnsiString; override;
    procedure ChangeData (newData : TMemoryStream); override;
    function SetKeyValue (const AKeyName, AValue : AnsiString) : Integer;
    procedure ChangeKey (const AOldKey, ANewKey : AnsiString);
    procedure DeleteKey (idx : Integer);
    function IndexOf (const AKeyName : AnsiString) : Integer;
    property ProductVersion : TULargeInteger read GetProductVersion write SetProductVersion;
    property FileVersion    : TULargeInteger read GetFileVersion write SetFileVersion;
    property FileFlags : TVersionFileFlags read GetFileFlags write SetFileFlags;
    property KeyCount : Integer read GetKeyCount;
    property Key [idx : Integer] : TVersionAnsiStringValue read GetKey;
  end;

implementation


resourcestring
  rstFlagsChanged = 'change flags';
  rstFileVersionChanged = 'change file version';
  rstProductVersionChanged = 'change product version';
  rstVersion      = 'Version';
  rstInvalidVersionInfoResource = 'Invalid version info resource';
  rstAnsiStringChanged = 'change AnsiString';
  rstAnsiStringAdded = 'add AnsiString';
  rstAnsiStringDeleted = 'delete AnsiString';
  rstCodePageChanged = 'change code page';
  rstKeyNameChanged = 'change AnsiString name';

{ TVersionInfoResourceDetails }

procedure TVersionInfoResourceDetails.ChangeData(newData: TMemoryStream);
begin
  inherited;

  fFixedInfo := nil;
end;

procedure TVersionInfoResourceDetails.ChangeKey(const AOldKey,
  ANewKey: AnsiString);
var
  idx : Integer;
begin
  if AOldKey <> ANewKey then
  begin
    idx := IndexOf (AOldKey);
    if idx > -1 then
    begin
      Key [idx].fKeyName := ANewKey;
      UpdateData
    end
    else
      SetKeyValue (ANewKey, '')
  end
end;

constructor TVersionInfoResourceDetails.Create(AParent: TResourceModule;
  ALanguage: Integer; const AName, AType: AnsiString; ASize: Integer;
  AData: pointer);
begin
  fChildAnsiStrings := TObjectList.Create;
  fTranslations := TList.Create;
  inherited Create (AParent, ALanguage, AName, AType, ASize, AData);
end;

constructor TVersionInfoResourceDetails.CreateNew(AParent: TResourceModule;
  ALanguage: Integer; const AName: AnsiString);
begin
  fChildAnsiStrings := TObjectList.Create;
  fTranslations := TList.Create;
  inherited;

end;

procedure TVersionInfoResourceDetails.DeleteKey(idx: Integer);
begin
  fChildAnsiStrings.Delete (idx);
  UpdateData
end;

destructor TVersionInfoResourceDetails.Destroy;
begin
  fChildAnsiStrings.Free;
  fTranslations.Free;
  inherited;
end;

procedure TVersionInfoResourceDetails.ExportToStream(strm: TStream;
  const ext: AnsiString);
var
  zeros, v : DWORD;
  wSize : WORD;
  AnsiStringInfoStream : TMemoryStream;
  strg : TVersionAnsiStringValue;
  i, p, p1 : Integer;
  wValue : WideString;

  procedure PadStream (strm : TStream);
  begin
    if strm.Position mod 4 <> 0 then
      strm.Write (zeros, 4 - (strm.Position mod 4))
  end;

  procedure SaveVersionHeader (strm : TStream; wLength, wValueLength, wType : word; const key : AnsiString; const value);
  var
    wKey : WideString;
    valueLen : word;
    keyLen : word;
  begin
    wKey := key;
    strm.Write (wLength, sizeof (wLength));

    strm.Write (wValueLength, sizeof (wValueLength));
    strm.Write (wType, sizeof (wType));
    keyLen := (Length (wKey) + 1) * sizeof (WideChar);
    strm.Write (wKey [1], keyLen);

    PadStream (strm);

    if wValueLength > 0 then
    begin
      valueLen := wValueLength;
      if wType = 1 then
        valueLen := valueLen * sizeof (WideChar);
      strm.Write (value, valueLen)
    end;
  end;

begin { ExportToStream }
  GetFixedFileInfo;
  if fFixedInfo <> Nil then
  begin
    zeros := 0;

    SaveVersionHeader (strm, 0, sizeof (fFixedInfo^), 0, 'VS_VERSION_INFO', fFixedInfo^);

    if fChildAnsiStrings.Count > 0 then
    begin
      AnsiStringInfoStream := TMemoryStream.Create;
      try
        SaveVersionHeader (AnsiStringInfoStream, 0, 0, 0, IntToHex (ResourceLanguage, 4) + IntToHex (CodePage, 4), zeros);

        for i := 0 to fChildAnsiStrings.Count - 1 do
        begin
          PadStream (AnsiStringInfoStream);

          p := AnsiStringInfoStream.Position;
          strg := TVersionAnsiStringValue (fChildAnsiStrings [i]);
          wValue := strg.fValue;
          SaveVersionHeader (AnsiStringInfoStream, 0, Length (strg.fValue) + 1, 1, strg.KeyName, wValue [1]);
          wSize := AnsiStringInfoStream.Size - p;
          AnsiStringInfoStream.Seek (p, soFromBeginning);
          AnsiStringInfoStream.Write (wSize, sizeof (wSize));
          AnsiStringInfoStream.Seek (0, soFromEnd);

        end;

        AnsiStringInfoStream.Seek (0, soFromBeginning);
        wSize := AnsiStringInfoStream.Size;
        AnsiStringInfoStream.Write (wSize, sizeof (wSize));

        PadStream (strm);
        p := strm.Position;
        SaveVersionHeader (strm, 0, 0, 0, 'StringFileInfo', zeros);
        strm.Write (AnsiStringInfoStream.Memory^, AnsiStringInfoStream.size);
        wSize := strm.Size - p;
      finally
        AnsiStringInfoStream.Free
      end;
      strm.Seek (p, soFromBeginning);
      strm.Write (wSize, sizeof (wSize));
      strm.Seek (0, soFromEnd)
    end;

    if fTranslations.Count > 0 then
    begin
      PadStream (strm);
      p := strm.Position;
      SaveVersionHeader (strm, 0, 0, 0, 'VarFileInfo', zeros);
      PadStream (strm);

      p1 := strm.Position;
      SaveVersionHeader (strm, 0, 0, 0, 'Translation', zeros);

      for i := 0 to fTranslations.Count - 1 do
      begin
        v := Integer (fTranslations [i]);
        strm.Write (v, sizeof (v))
      end;

      wSize := strm.Size - p1;
      strm.Seek (p1, soFromBeginning);
      strm.Write (wSize, sizeof (wSize));
      wSize := sizeof (Integer) * fTranslations.Count;
      strm.Write (wSize, sizeof (wSize));

      wSize := strm.Size - p;
      strm.Seek (p, soFromBeginning);
      strm.Write (wSize, sizeof (wSize));
    end;

    strm.Seek (0, soFromBeginning);
    wSize := strm.Size;
    strm.Write (wSize, sizeof (wSize));
    strm.Seek (0, soFromEnd);
  end
  else
    raise Exception.Create ('Invalid version resource');
end;

class function TVersionInfoResourceDetails.GetBaseType: AnsiString;
begin
  result := IntToStr (Integer (RT_VERSION));
end;

function TVersionInfoResourceDetails.GetFileFlags: TVersionFileFlags;
var
  flags : Integer;
begin
  GetFixedFileInfo;
  result := [];
  flags := fFixedInfo^.dwFileFlags and fFixedInfo^.dwFileFlagsMask;

  if (flags and VS_FF_DEBUG)        <> 0 then result := result + [ffDebug];
  if (flags and VS_FF_INFOINFERRED) <> 0 then result := result + [ffInfoInferred];
  if (flags and VS_FF_PATCHED)      <> 0 then result := result + [ffPatched];
  if (flags and VS_FF_PRERELEASE)   <> 0 then result := result + [ffPreRelease];
  if (flags and VS_FF_PRIVATEBUILD) <> 0 then result := result + [ffPrivateBuild];
  if (flags and VS_FF_SPECIALBUILD) <> 0 then result := result + [ffSpecialBuild];
end;

function TVersionInfoResourceDetails.GetFileVersion: TULargeInteger;
begin
  GetFixedFileInfo;
  result.LowPart := fFixedInfo^.dwFileVersionLS;
  result.HighPart := fFixedInfo^.dwFileVersionMS;
end;

procedure TVersionInfoResourceDetails.GetFixedFileInfo;
var
  p : PAnsiChar;
  t, wLength, wValueLength, wType : word;
  key : AnsiString;

  varwLength, varwValueLength, varwType : word;
  varKey : AnsiString;

  function GetVersionHeader (var p : PAnsiChar; var wLength, wValueLength, wType : word; var key : AnsiString) : Integer;
  var
    szKey : PWideChar;
    baseP : PAnsiChar;
  begin
    baseP := p;
    wLength := PWord (p)^;
    Inc (p, sizeof (word));
    wValueLength := PWord (p)^;
    Inc (p, sizeof (word));
    wType := PWord (p)^;
    Inc (p, sizeof (word));
    szKey := PWideChar (p);
    Inc (p, (lstrlenw (szKey) + 1) * sizeof (WideChar));
    while Integer (p) mod 4 <> 0 do
      Inc (p);
    result := p - baseP;
    key := szKey;
  end;

  procedure GetAnsiStringChildren (var base : PAnsiChar; len : word);
  var
    p, strBase : PAnsiChar;
    t, wLength, wValueLength, wType, wStrLength, wStrValueLength, wStrType : word;
    key, value : AnsiString;
    langID, codePage : Integer;

  begin
    p := base;
    while (p - base) < len do
    begin
      t := GetVersionHeader (p, wLength, wValueLength, wType, key);
      Dec (wLength, t);

      langID := StrToInt ('$' + Copy (key, 1, 4));
      codePage := StrToInt ('$' + Copy (key, 5, 4));

      strBase := p;
      fChildAnsiStrings.Clear;
      fTranslations.Clear;

      while (p - strBase) < wLength do
      begin
        t := GetVersionHeader (p, wStrLength, wStrValueLength, wStrType, key);
        Dec (wStrLength, t);

        if wStrValueLength = 0 then
          value := ''
        else
          value := PWideChar (p);
        Inc (p, wStrLength);
        while Integer (p) mod 4 <> 0 do
          Inc (p);

        if codePage = 0 then
          codePage := self.codePage;
        fChildAnsiStrings.Add (TVersionAnsiStringValue.Create (key, Value, langID, codePage));
      end
    end;
    base := p
  end;

  procedure GetVarChildren (var base : PAnsiChar; len : word);
  var
    p, strBase : PAnsiChar;
    t, wLength, wValueLength, wType: word;
    key : AnsiString;
    v : DWORD;
  begin
    p := base;
    while (p - base) < len do
    begin
      t := GetVersionHeader (p, wLength, wValueLength, wType, key);
      Dec (wLength, t);

      strBase := p;
      fTranslations.Clear;

      while (p - strBase) < wLength do
      begin
        v := PDWORD (p)^;
        Inc (p, sizeof (DWORD));
        fTranslations.Add (pointer (v));
      end
    end;
    base := p
  end;

begin
  if fFixedInfo <> nil then Exit;

  p := data.memory;
  GetVersionHeader (p, wLength, wValueLength, wType, key);

  if wValueLength <> 0 then
  begin
    fFixedInfo := PVSFixedFileInfo (p);
    if fFixedInfo^.dwSignature <> $feef04bd then
      raise Exception.Create (rstInvalidVersionInfoResource);

    Inc (p, wValueLength);
    while Integer (p) mod 4 <> 0 do
      Inc (p);
  end
  else
    fFixedInfo := Nil;

  while wLength > (p - data.memory) do
  begin
    t := GetVersionHeader (p, varwLength, varwValueLength, varwType, varKey);
    Dec (varwLength, t);

    if varKey = 'StringFileInfo' then
      GetAnsiStringChildren (p, varwLength)
    else
      if varKey = 'VarFileInfo' then
        GetVarChildren (p, varwLength)
      else
        break;
  end
end;

function TVersionInfoResourceDetails.GetKey(
  idx: Integer): TVersionAnsiStringValue;
begin
  GetFixedFileInfo;
  result := TVersionAnsiStringValue (fChildAnsiStrings [idx])
end;

function TVersionInfoResourceDetails.GetKeyCount: Integer;
begin
  GetFixedFileInfo;
  result := fChildAnsiStrings.Count
end;

function TVersionInfoResourceDetails.GetProductVersion: TULargeInteger;
begin
  GetFixedFileInfo;
  result.LowPart := fFixedInfo^.dwProductVersionLS;
  result.HighPart := fFixedInfo^.dwProductVersionMS
end;

function TVersionInfoResourceDetails.IndexOf(
  const AKeyName: AnsiString): Integer;
var
  i : Integer;
  k : TVersionAnsiStringValue;
begin
  result := -1;
  for i := 0 to KeyCount - 1 do
  begin
    k := Key [i];
    if CompareText (k.KeyName, AKeyName) = 0 then
    begin
      result := i;
      break
    end
  end
end;

procedure TVersionInfoResourceDetails.InitNew;
var
  w, l : word;
  fixedInfo : TVSFixedFileInfo;
  ws : WideString;
begin
  l := 0;

  w := 0;
  Data.Write(w, sizeof (w));

  w := sizeof (fixedInfo);
  Data.Write (w, sizeof (w));

  w := 0;
  Data.Write (w, sizeof (w));

  ws := 'VS_VERSION_INFO';
  Data.Write(ws [1], (Length (ws) + 1) * sizeof (WideChar));

  w := 0;
  while Data.Size mod sizeof (DWORD) <> 0 do
    Data.Write (w, sizeof (w));

  FillChar (fixedInfo, 0, sizeof (fixedInfo));
  fixedInfo.dwSignature        := $FEEF04BD;
  fixedInfo.dwStrucVersion     := $00010000;
  fixedInfo.dwFileVersionMS    := $00010000;
  fixedInfo.dwFileVersionLS    := $00000000;
  fixedInfo.dwProductVersionMS := $00010000;
  fixedInfo.dwProductVersionLS := $00000000;
  fixedInfo.dwFileFlagsMask    := $3f;
  fixedInfo.dwFileFlags        := 0;
  fixedInfo.dwFileOS           := 4;
  fixedInfo.dwFileType         := VFT_UNKNOWN;
  fixedInfo.dwFileSubtype      := VFT2_UNKNOWN;
  fixedInfo.dwFileDateMS       := 0;
  fixedInfo.dwFileDateLS       := 0;

  Data.Write(fixedInfo, sizeof (fixedInfo));

  w := 0;
  while Data.Size mod sizeof (DWORD) <> 0 do
    Data.Write (w, sizeof (w));

  l := Data.Size;
  Data.Seek(0, soFromBeginning);

  Data.Write(l, sizeof (l))
end;

procedure TVersionInfoResourceDetails.SetFileFlags(
  const Value: TVersionFileFlags);
var
  flags : DWORD;
begin
  GetFixedFileInfo;

  flags := 0;
  if ffDebug in value then flags := flags or VS_FF_DEBUG;
  if ffInfoInferred in value then flags := flags or VS_FF_INFOINFERRED;
  if ffPatched in value then flags := flags or VS_FF_PATCHED;
  if ffPreRelease in value then flags := flags or VS_FF_PRERELEASE;
  if ffPrivateBuild in value then flags := flags or VS_FF_PRIVATEBUILD;
  if ffSpecialBuild in value then flags := flags or VS_FF_SPECIALBUILD;

  if (fFixedInfo^.dwFileFlags and fFixedInfo^.dwFileFlagsMask) <> flags then
    fFixedInfo^.dwFileFlags := (fFixedInfo^.dwFileFlags and not fFixedInfo^.dwFileFlagsMask) or flags;
end;

procedure TVersionInfoResourceDetails.SetFileVersion(
  const Value: TULargeInteger);
begin
  GetFixedFileInfo;
  if (value.LowPart <> fFixedInfo^.dwFileVersionLS) or (value.HighPart <> fFixedInfo^.dwFileVersionMS) then
  begin
    fFixedInfo^.dwFileVersionLS := value.LowPart;
    fFixedInfo^.dwFileVersionMS := value.HighPart;
  end
end;

function TVersionInfoResourceDetails.SetKeyValue(const AKeyName,
  AValue: AnsiString): Integer;
var
  idx : Integer;
  k : TVersionAnsiStringValue;
begin
  idx := IndexOf (AKeyName);

  if idx = -1 then
  begin
    if AKeyName <> '' then
      idx := fChildAnsiStrings.Add (TVersionAnsiStringValue.Create (AKeyNAme, AValue, ResourceLanguage, CodePage))
  end
  else
  begin
    k := Key [idx];
    if (AValue <> k.fValue) or (AKeyName <> k.fKeyName) then
    begin
      k.fKeyName := AKeyName;
      k.fValue := AValue;
    end
  end;

  result := idx;
  UpdateData
end;

procedure TVersionInfoResourceDetails.SetProductVersion(
  const Value: TULargeInteger);
begin
  GetFixedFileInfo;
  if (value.LowPart <> fFixedInfo^.dwProductVersionLS) or (value.HighPart <> fFixedInfo^.dwProductVersionMS) then
  begin
    fFixedInfo^.dwProductVersionLS := value.LowPart;
    ffixedInfo^.dwProductVersionMS := value.HighPart;
  end
end;

procedure TVersionInfoResourceDetails.UpdateData;
var
  st : TMemoryStream;
begin
  st := TMemoryStream.Create;
  try
    ExportToStream (st, '');
    st.Seek (0, soFromBeginning);
    data.Seek (0, soFromBeginning);
    data.size := 0;
    data.CopyFrom (st, st.Size);
  finally
    st.Free
  end
end;

{ TVersionAnsiStringValue }

constructor TVersionAnsiStringValue.Create(const AKeyName, AValue: AnsiString; ALangId, ACodePage : Integer);
begin
  fKeyName := AKeyName;
  fValue := AValue;
  fLangId := ALangId;
  fCodePage := ACodePage;
end;

initialization
  RegisterResourceDetails (TVersionInfoResourceDetails);
finalization
  UnregisterResourceDetails (TVersionInfoResourceDetails);
end.
