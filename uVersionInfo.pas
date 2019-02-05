unit uVersionInfo;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, unitResourceDetails, unitResFile, unitResourceExaminer,
  unitResourceVersionInfo, unitPEFile, ExtCtrls, ComCtrls, Grids, Registry;

type
  TSelectedCell = record
    Col: integer;
    Row: integer;
    Value: string;
  end;
  
  TForm4 = class(TForm)
    btnRead: TButton;
    Panel1: TPanel;
    btnWrite: TButton;
    StringGrid2: TStringGrid;
    rgApp: TRadioGroup;
    rgVersion: TRadioGroup;
    rgLang: TRadioGroup;
    btnUpdate: TButton;
    StatusBar1: TStatusBar;
    tabAppType: TTabControl;
    btnSource: TButton;
    Panel2: TPanel;
    edtSource: TEdit;
    btnUpdateDPR: TButton;
    procedure btnReadClick(Sender: TObject);
    procedure StringGrid2SelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure StringGrid2SetEditText(Sender: TObject; ACol, ARow: Integer;
      const Value: string);
    procedure btnUpdateClick(Sender: TObject);
    procedure btnWriteClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure tabAppTypeChange(Sender: TObject);
    procedure edtSourceChange(Sender: TObject);
    procedure btnUpdateDPRClick(Sender: TObject);
  private
    { Private declarations }
    fResModule: TResourceModule;
    fExaminer : TResourceExaminer;
    fVersionInfo: TVersionInfoResourceDetails;
    fColumsFilled: boolean;
    fSelectedCell: TSelectedCell;
    fFolderBuild: string;
    fFolderRel: string;
  public
    { Public declarations }
    procedure AutoSize(Grid: TStringGrid);
    procedure FillGrid(Grid: TStringGrid; FileName: string);
    function CreateFilter: string;
    function GetFolder: string;
    function GetExt: string;
  end;

var
  Form4: TForm4;

implementation

{$R *.dfm}

const
  RegKeySettings = 'Software\VersionInfo';
  RegSourceFileName = 'Source Dir';

function GetRegStrValue(RegKey, ValueName: string): UnicodeString;
begin
  with TRegistry.Create do
  try
    RootKey:= HKEY_CURRENT_USER;
    if KeyExists(RegKey) then begin
      OpenKeyReadOnly(RegKey);
      Result:= ReadString(ValueName);
    end
    else
      Result := '';
  finally
    Free;
  end;
end;

procedure SetRegStrValue(RegKey, ValueName, Value: string);
begin
  with TRegistry.Create do
  try
    RootKey:= HKEY_CURRENT_USER;
    OpenKey(RegKey,True);
    WriteString(ValueName, Value);
  finally
    Free;
  end;
end;

function VersionToString (version : TULargeInteger) : string;
begin
  with version do
    result := Format ('%d.%d.%d.%d', [HiWord (HighPart), LoWord (HighPart), HiWord (LowPart), LoWord (LowPart)]);
end;

function StringToVersion (const version : string) : TULargeInteger;
var
  p : Integer;
  s : string;
  hh, h, l, ll : word;
  ok : boolean;
begin
  hh := 0;
  ll := 0;
  h := 0;
  l := 0;

  s := version;
  p := Pos ('.', s);
  ok := False;
  if p > 0 then
  begin
    hh := StrToInt (Copy (s, 1, p - 1));
    s := Copy (s, p + 1, MaxInt);
    p := Pos ('.', s);
    if p > 0 then
    begin
      h := StrToInt (Copy (s, 1, p - 1));
      s := Copy (s, p + 1, MaxInt);
      p := Pos ('.', s);
      if p > 0 then
      begin
        l := StrToInt (Copy (s, 1, p - 1));
        ll := StrToInt (Copy (s, p + 1, MaxInt));
        ok := True;
      end
    end
  end;

{
  if not ok then
    raise exception.Create (rstVersionFormatError);
}
  result.HighPart := 65536 * hh + h;
  result.LowPart := 65536 * l + ll;
end;

function TForm4.CreateFilter: string;
var
  lang: string;
  app: string;
  ver: string;
  ext: string;
begin
  if tabAppType.TabIndex = 0 then begin
    case rgApp.ItemIndex of
      0: app := '????????';
      1: app := 'imisscan';
      2: app := 'imisview';
    end;
    case rgVersion.ItemIndex of
      0: ver := '*';
      1: ver := '++';
      2: ver := '+';
      3: ver := '';
      4: ver := '_d';
    end;
    case rgLang.ItemIndex  of
      0: lang := '???_';
      1: lang := 'eng_';
      2: lang := 'slv_';
      3: lang := 'hrv_';
      4: lang := 'hrb_';
      5: lang := 'bsb_';
      6: lang := 'deu_';
      7: lang := 'dea_';
      8: lang := 'del_';
      9: lang := 'des_';
      10: lang := 'dec_';
    end;
    Result := lang + app + ver;
  end
  else begin
    case rgApp.ItemIndex of
      0: app := '????????';
      1: app := 'imisscan';
      2: app := 'imisview';
    end;
    case rgVersion.ItemIndex of
      0: ver := '';
      1: ver := '';
      2: ver := '';
      3: ver := '';
      4: ver := '';
    end;
    case rgLang.ItemIndex  of
      0: lang := '.???';
      1: lang := '.exe';
      2: lang := '.slv';
      3: lang := '.hrv';
      4: lang := '.hrb';
      5: lang := '.bsb';
      6: lang := '.deu';
      7: lang := '.dea';
      8: lang := '.del';
      9: lang := '.des';
      10: lang := '.dec';
    end;
    Result := ver + app + lang;
  end;
end;

procedure TForm4.edtSourceChange(Sender: TObject);
begin
  fFolderBuild := edtSource.Text;
  fFolderRel := fFolderBuild+ '\build';;
  SetRegStrValue(RegKeySettings, RegSourceFileName, fFolderBuild);
end;

function TForm4.GetExt: string;
begin
  case tabAppType.TabIndex of
    0: Result := '.res';
    1: Result := '';
  end;
end;

function TForm4.GetFolder: string;
begin
  case tabAppType.TabIndex of
    0: Result := fFolderBuild + '\res';
    1: Result := fFolderRel;
  end;
end;


procedure TForm4.FillGrid(Grid: TStringGrid; FileName: string);
var
  i: integer;
  Lang: string;
  DPRFilename: string;
  DPRDir: string;
  LangExt: string;
begin
  Lang := '';
  fVersionInfo := nil;
  try
    fResModule.LoadFromFile(FileName);
  except
    Exit;
  end;
  fExaminer := TResourceExaminer.Create(fResModule);
  i:= fExaminer.SectionCount;
  for i := 0 to fExaminer.ResourceCount - 1 do
    if fExaminer.Resource[i].ResourceType ='16' then begin
      fVersionInfo := fResModule.ResourceDetails[i] as TVersionInfoResourceDetails;
      Lang := Languages.NameFromLocaleID[fResModule.ResourceDetails[i].ResourceLanguage];
    end;
  if not Assigned(fVersionInfo) then Exit;
  
  Grid.DefaultRowHeight := 16;
  if not fColumsFilled then begin
    fColumsFilled := True;
    Grid.ColCount := fVersionInfo.KeyCount + 3; // +Langugage +FileName+ DPR filename
    for i :=0 to fVersionInfo.KeyCount - 1 do
      Grid.Cols[i].Clear;

    Grid.Rows[0].Add('FileName');
    for i :=0 to fVersionInfo.KeyCount - 1 do begin
      Grid.Rows[0].Add(fVersionInfo.Key[i].KeyName);
    end;
    Grid.RowCount := 2;
    Grid.Rows[0].Add('Language');
    Grid.Rows[0].Add('DPR file');
  end;

  Grid.Rows[Grid.RowCount-1].Add(ExtractFileName(FileName));
  for i :=0 to fVersionInfo.KeyCount - 1 do begin
    Grid.Rows[Grid.RowCount-1].Add(fVersionInfo.Key[i].Value);
  end;
  Grid.Rows[Grid.RowCount-1].Add(Lang);

  // Create DPR filename from resource file
  DPRDir := ExtractFileDir(FileName);
  DPRFilename := ExtractFileName(FileName);
  LangExt := Copy(DPRFilename, 0, 3);
  if LangExt <> 'eng' then begin
    DPRFilename := Copy(DPRFilename, 5, 8) + '.dpr';
    DPRDir := StringReplace(DPRDir, '\res', '\' + LangExt, [rfIgnoreCase]);
    Grid.Rows[Grid.RowCount-1].Add(DPRDir + '\' + DPRFilename );
  end;

  StatusBar1.SimpleText := Format('%d file(s)', [(Grid.RowCount-1)]);
  Grid.RowCount := Grid.RowCount + 1;
end;

procedure TForm4.FormCreate(Sender: TObject);
begin
  edtSource.Text := GetRegStrValue(RegKeySettings, RegSourceFileName);
  if edtSource.Text = '' then
    edtSource.Text := 'C:\imis\imisclientwin\IMiS';
  fFolderBuild := edtSource.Text;
  fFolderRel := fFolderBuild+ '\build';;
end;

procedure TForm4.StringGrid2SelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
  with fSelectedCell do begin
    Col := ACol;
    Row := ARow;
    Value := TStringGrid(Sender).Cells[ACol, ARow];
  end;
end;

procedure TForm4.StringGrid2SetEditText(Sender: TObject; ACol, ARow: Integer;
  const Value: string);
begin
  with fSelectedCell do begin
    Col := ACol;
    Row := ARow;
  end;
  fSelectedCell.Value := Value;
end;

procedure TForm4.tabAppTypeChange(Sender: TObject);
begin
  btnRead.Click;
end;

procedure TForm4.btnReadClick(Sender: TObject);
var
  FileName, FileNameFilter: String;
  i: integer;
  SearchRec: TSearchRec;
begin
  fColumsFilled := False;
  // Clear string grid
  for i := 0 to StringGrid2.RowCount - 1 do
    StringGrid2.Rows[i].Clear;

  fResModule := TPEResourceModule.Create;

  FileNameFilter := GetFolder + '\' + CreateFilter + GetExt;
  if FindFirst(FileNameFilter, faArchive, SearchRec) = 0 then begin
    repeat
      if tabAppType.TabIndex = 0 then
        fResModule := TResModule.Create
      else
        fResModule := TPEResourceModule.Create;
      FillGrid(StringGrid2, GetFolder + '\' + SearchRec.Name);
      fResModule.Free;
    until FindNext(SearchRec) <> 0;
  end;
  AutoSize(StringGrid2);

end;

procedure TForm4.btnUpdateClick(Sender: TObject);
var i: integer;
begin
  for i := 1 to StringGrid2.RowCount - 1 do
    StringGrid2.Cells[fSelectedCell.Col, i] := fSelectedCell.Value;
end;

procedure TForm4.btnUpdateDPRClick(Sender: TObject);
var
  i, j: integer;
  DPRFile: TStringList;
  DPRFilename: string;
  ResFilename: string;
  DPRCol: integer;
  index: integer;
begin
  DPRFile := TStringList.Create;
  try
    DPRCol := StringGrid2.ColCount - 1;
    for i := 1 to StringGrid2.RowCount - 1 do begin
      DPRFilename := StringGrid2.Cells[DPRCol, i];
      if DPRFilename = '' then Continue;

      DPRFile.Clear;
      DPRFile.LoadFromFile(DPRFilename);

      ResFilename := StringGrid2.Cells[0, i];
      // Find any existing resource entries
      ResFilename := '\res\'+ Copy(ResFilename, 0, 3+1+8);
      for j := DPRFile.Count - 1 downto 0 do begin
        index := AnsiPos(ResFilename, DPRFile[j]);
        if index > 0 then
          DPRFile.Delete(j);
      end;

      index := DPRFile.IndexOf('begin');
      if index > 1 then begin
        ResFilename := StringGrid2.Cells[0, i];
        // {$R '..\res\bsb_imisview.res'}
        DPRFile.Insert(index - 1, Format('{$R ''..\res\%s''}', [ResFilename]));
        DPRFile.SaveToFile(DPRFilename);
      end;
    end;
  finally
    DPRFile.Free;
  end;
end;

procedure TForm4.btnWriteClick(Sender: TObject);
var
  i, j, indx: integer;
  Filename: string;
begin

  for j := 1 to StringGrid2.RowCount - 1 do begin
    Filename:= GetFolder + '\' + StringGrid2.Cells[0, j];
    if not FileExists(Filename) then Continue;

    fResModule := TResModule.Create;
    fResModule.LoadFromFile(Filename);
    fExaminer := TResourceExaminer.Create(fResModule);
    for i := 0 to fExaminer.ResourceCount - 1 do begin
      if fExaminer.Resource[i].ResourceType ='16' then begin
        fVersionInfo := fResModule.ResourceDetails[i] as TVersionInfoResourceDetails;
        //Lang := Languages.NameFromLocaleID[fResModule.ResourceDetails[i].ResourceLanguage];
      end;
    end;
    // FileName is skipped
    for i:= 1 to StringGrid2.ColCount -1  do begin
      if StringGrid2.Cells[i, 0] = 'Language' then begin
        Continue;
      end;
      indx := fVersionInfo.IndexOf(StringGrid2.Cells[i, 0]);
      if indx <> -1 then
        if fVersionInfo.Key[indx].Value <> StringGrid2.Cells[i, j] then
          fVersionInfo.SetKeyValue(StringGrid2.Cells[i, 0], StringGrid2.Cells[i, j]);
      if StringGrid2.Cells[i, 0] = 'FileVersion' then begin
        fVersionInfo.ProductVersion := StringToVersion(StringGrid2.Cells[i, j]);
        fVersionInfo.FileVersion := StringToVersion(StringGrid2.Cells[i, j]);
      end;
    end;
    fResModule.SaveToFile(Filename);
    fResModule.Free;
  end;
end;

procedure TForm4.AutoSize(Grid: TStringGrid);
const
  WidthMin = 10;
  WidthMax = 1400;
  HeightMin = 5;
var
  wmax: integer;
  w: integer;
  h: integer;
  i,j: integer;
  sumwidth, sumheight: integer;
begin
  sumwidth := 0;
  sumheight := 0;
  for i := 0 to Grid.ColCount - 1 do
  begin
    sumheight := 0;
    wmax := 0;
    for j := 0 to Grid.RowCount - 1 do
    begin
      w := Grid.Canvas.TextWidth(Grid.Cells[i,j]);
      h := (w div WidthMax + 1)*Grid.Canvas.TextHeight(Grid.Cells[i,j]);
      if h < HeightMin then
        h := HeightMin;
      h := h + +2*Grid.GridLineWidth+2;
      if i = 0 then
        Grid.RowHeights[j] := h
      else if h > Grid.RowHeights[j] then
        Grid.RowHeights[j] := h;

      if w > wmax then
        wmax := w;
      sumheight := sumheight + Grid.RowHeights[j];
    end;
    if wmax < WidthMin then
      wmax := WidthMin;
    if wmax > WidthMax then
      wmax := WidthMax;
    Grid.ColWidths[i] := wmax+2*Grid.GridLineWidth+3;
    sumwidth := sumwidth + Grid.ColWidths[i];
  end;
  Self.Left := 0;
  Self.ClientWidth := sumwidth + Grid.ColCount * Grid.GridLineWidth+10;
  Self.ClientHeight := sumheight + Panel1.Height + Grid.RowCount * Grid.GridLineWidth+3 +
    Ord(Self.HorzScrollBar.Visible) * 80;
  if Self.Width >= Self.Monitor.Width then
    Self.Width := Self.Monitor.Width;
  if Self.Height >= Self.Monitor.WorkareaRect.Bottom then begin
    Self.Top := 0;
    Self.Height := Self.Monitor.WorkareaRect.Bottom;
  end;

end;

end.
