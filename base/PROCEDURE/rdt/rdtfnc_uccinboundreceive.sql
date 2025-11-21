SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: ReceiptDetail received base on UCC. 1 UCC consist of        */
/*          multiple ReceiptDetail line                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2006-08-28 1.0  UngDH      Created                                   */
/* 2008-09-03 1.1  Vicky      Modify to cater for SQL2005 (Vicky01)     */
/* 2009-03-26 1.2  Vicky      SOS#128230 - New Screen Looping           */
/*                            ID --> UCC --> ID (Vicky02)               */
/* 2009-07-06 1.3  Vicky      Add in EventLog (Vicky06)                 */
/* 2010-03-18 1.4  James      SOS164060 - Cater receiving with BOM      */
/*                            checking (james01)                        */
/* 2010-11-19 1.5  ChewKP     SOS#195870 Get UCC from ReceiptDetail     */
/*                            UserDefine (ChewKP01)                     */
/* 2011-08-18 1.6  Ung        SOS#223024 Support multiple ASN           */
/*                            Separate out func 576 to another module   */
/* 2012-08-16 1.7  Ung        SOS#253394 Add UCCInboundReceiveIDOptional*/
/* 2012-10-18 1.8  ChewKP     SOS#255485 Addtional Screen Information   */
/*                            Route (chewKP02)                          */
/* 2013-01-03 1.9  James      SOS264868 - By pass ASN checking & not all*/
/*                            ucc received checking (james02)           */
/* 2013-04-22 2.0  James      SOS264868 - Add default loc and by pass   */
/*                            toid update (james03)                     */
/* 2015-04-13 2.1  ChewKP     SOS#338441 - Add RDT StorerConfig         */
/*                            DefaultReceiptDetailLoc                   */
/*                            Add To Print UCCASNLABEL (ChewKP03)       */
/* 2015-05-08 2.2  SPChin     SOS341030 - Bug Fixed                     */
/* 2015-10-20 2.3  James      SOS354977 - Add refno field (james04)     */
/* 2017-03-06 2.4  Ung        Performance tuning                        */
/* 2017-05-17 2.3  ChewKP     WMS-1920-Add ExtendedValidateSP (ChewKP04)*/
/* 2017-10-20 2.4  ChewKP     WMS-3222-Add ExtendedUpdateSP (ChewKP05)  */
/* 2018-07-16 2.5  Ung        WMS-5700 Add FinalizeReceiptDetail        */
/* 2018-10-01 2.6  Gan        Performance                               */
/* 2018-10-11 2.7  James      WMS-6612 Add rdt_decode (james05)         */
/* 2019-07-08 2.8  Ung        Fix performance tuning                    */
/* 2019-07-17 2.9  James      WMS9861 Add loc prefix (james06)          */
/*                            Add RDTFormat to ID                       */
/* 2019-09-23 3.0  YeeKung    INC0844732 Bug Fixed (yeekung01)          */
/* 2019-11-01 3.1  James      WMS-11006 Move ExtendedValidateSP @ step 4*/
/*                            into transaction block (james07)          */
/* 2020-03-03 3.2  James      WMS-12334 Add extinfo @ screen 4 (james08)*/
/* 2021-06-09 3.3  Chermaine  WMS-17155 Add Facility check on st1 (cc01)*/
/* 2022-01-24 3.4  Ung        WMS-18776 Add Carton type                 */
/* 2022-11-23 3.5  James      WMS-21207 Add ExtUpdSp at step 1 (james09)*/
/* 2023-02-20 3.6  Ung        WMS-21436 Fix UCC screen ExtVal sequence  */
/* 2023-06-19 3.7  YeeKung    WMS-22768 Add Extvalidsp at step1(yeekung01)*/
/* 2023-09-04 3.8  James      Ad hoc fix - Change rdt_Decode variable   */
/*                            from UCC -> UCCNO (james10)               */
/* 2023-07-26 3.9  YeeKung    WMS-23108 Add DefaultToLOCSP (yeekung02)  */
/* 2023-10-03 4.0  JihHaur    JSM-181441 reset @cTrackCartonType (JH01) */
/************************************************************************/
CREATE   PROC [RDT].[rdtfnc_UCCInboundReceive] (
   @nMobile    INT,
   @nErrNo     INT            OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @i            INT,
   @bSuccess     INT,
   @cOption      NVARCHAR( 1),
   @cScanUCC     NVARCHAR( 5),
   @cSQL         NVARCHAR( MAX),
   @cSQLParam    NVARCHAR( MAX),
   @curCR        CURSOR,
   @tExtUpdate   VARIABLETABLE

-- RDT.RDTMobRec variable
DECLARE
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5),
   @cPrinter   NVARCHAR(10),

   @cReceiptKey        NVARCHAR( 10),
   @cReceiptKey1       NVARCHAR( 10),
   @cReceiptKey2       NVARCHAR( 10),
   @cReceiptKey3       NVARCHAR( 10),
   @cReceiptKey4       NVARCHAR( 10),
   @cReceiptKey5       NVARCHAR( 10),
   @cExternReceiptKey  NVARCHAR( 20),
   @cLOC               NVARCHAR( 10),
   @cID                NVARCHAR( 18),
   @cUCC               NVARCHAR( 20),
   @cQTY               NVARCHAR( 5),
   @cTotalUCC          NVARCHAR( 5),

   @cUserName          NVARCHAR(18), -- (Vicky06)
   @cUCCReceivedDetail NVARCHAR(1),  -- (ChewKP01)
   @cUCCInboundReceiveIDOptional NVARCHAR(1),
   @cExtendedInfoSP    NVARCHAR(20), -- (ChewKP02)
   @cExecStatements    NVARCHAR(4000),   -- (ChewKP02)
   @cExecArguments     NVARCHAR(4000),   -- (ChewKP02)

   @cBypassASNBlankCheck   NVARCHAR( 1),   -- (james02)
   @cDefaultToLoc          NVARCHAR( 10),  -- (james03)
   @cDefaultToLocSP        NVARCHAR( 20),  -- (yeekung02)
   @cUCCRcvSkipUpdTOID     NVARCHAR( 1),   -- (james03)

   @cDefaultReceiptDetailLoc  NVARCHAR(1), -- (ChewKP03)
   @cDataWindow               NVARCHAR(50),-- (ChewKP03)
   @cTargetDB                 NVARCHAR(20),-- (ChewKP03)
   @cUCCReceiptKey            NVARCHAR(10),-- (ChewKP03)

   @cRefNo                 NVARCHAR( 20), -- (james04)
   @cColumnName            NVARCHAR( 20), -- (james04)
   @cStorerGroup           NVARCHAR( 20),
   @n_Err                  INT,
   @nRowRef                INT,
   @nRowCount              INT,
   @cExtendedValidateSP    NVARCHAR(30),  -- (ChewKP04)
   @cExtendedUpdateSP      NVARCHAR(30),  -- (ChewKP05)
   @tReceiptDetail         VariableTable, -- (ChewKP05)
   @cFinalizeRD            NVARCHAR(1),
   @cDecodeSP              NVARCHAR( 20), -- (james05)
   @cBarcode               NVARCHAR( 60), -- (james05)
   @cLOCLookupSP           NVARCHAR( 20),
   @cExtendedInfo          NVARCHAR( 20), -- (james08)
   @cExtInfoSP             NVARCHAR( 20), -- (james08)
   @tExtInfoVar            VARIABLETABLE, -- (james08)
   @cCartonType            NVARCHAR(10),
   @cTrackCartonType       NVARCHAR(1), 
   @cTrackCartonTypeSP     NVARCHAR(20), 

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)

-- Load RDT.RDTMobRec
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cUserName  = UserName,-- (Vicky06)
   @cPrinter   = Printer, -- (ChewKP03)

   @cLOC       = V_LOC,
   @cID        = V_ID,
   @cUCC       = V_UCC,
   @cQTY       = V_QTY,

   @cReceiptKey1       = V_String1,
   @cReceiptKey2       = V_String2,
   @cReceiptKey3       = V_String3,
   @cReceiptKey4       = V_String4,
   @cReceiptKey5       = V_String5,
   @cExternReceiptKey  = V_String6,
   @cTotalUCC          = V_String7,
   @cUCCReceivedDetail = V_String8, -- (ChewKP01)
   @cUCCInboundReceiveIDOptional = V_String9,
   @cBypassASNBlankCheck     = V_String10,
   @cDefaultReceiptDetailLoc = V_String11, -- (ChewKP03)
   @cRefNo              = V_String12, -- (james04)
   @cExtendedValidateSP = V_String13, -- (ChewKP04)
   @cExtendedUpdateSP   = V_String14, -- (ChewKP05)
   @cFinalizeRD         = V_String15,
   @cDecodeSP           = V_String16,
   @cLOCLookupSP        = V_String17,
   @cExtendedInfoSP     = V_String18,
   @cCartonType         = V_String19,
   @cTrackCartonType    = V_String20,
   @cTrackCartonTypeSP  = V_String21,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15

FROM RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc IN (573, 575)  -- UCC Outbound receive, UCC Outbound receive (Bulk Shipment)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = UCC Outbound verification
   IF @nStep = 1 GOTO Step_1   -- Scn = 690. ReceiveKey, ExternReceiptKey
   IF @nStep = 2 GOTO Step_2   -- Scn = 691. LOC
   IF @nStep = 3 GOTO Step_3   -- Scn = 692. ID
   IF @nStep = 4 GOTO Step_4   -- Scn = 693. UCC, QTY, counter
   IF @nStep = 5 GOTO Step_5   -- Scn = 694. Message, counter, option
   IF @nStep = 6 GOTO Step_6   -- Scn = 695. Pre carton type
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 573. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Get storer config
   SET @cBypassASNBlankCheck = rdt.RDTGetConfig( @nFunc, 'BypassASNBlankCheck', @cStorerKey) -- (james02)
   SET @cFinalizeRD = rdt.RDTGetConfig( @nFunc, 'FinalizeReceiptDetail', @cStorerKey)
   SET @cUCCInboundReceiveIDOptional = rdt.RDTGetConfig( @nFunc, 'UCCInboundReceiveIDOptional', @cStorerKey)
   SET @cUCCReceivedDetail = rdt.RDTGetConfig( @nFunc, 'UCCFromReceivedDetail', @cStorerKey)

   SET @cDefaultReceiptDetailLoc = rdt.RDTGetConfig( @nFunc, 'DefaultReceiptDetailLoc', @cStorerKey) -- (ChewKP03)
   IF @cDefaultReceiptDetailLoc = '0'
		SET @cDefaultReceiptDetailLoc = ''
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
   SET @cTrackCartonTypeSP = rdt.rdtGetConfig( @nFunc, 'TrackCartonTypeSP', @cStorerKey)
   IF @cTrackCartonTypeSP = '0'
      SET @cTrackCartonTypeSP = ''
      
   -- (james05)
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)
   IF @cDecodeSP = '0'
      SET @cDecodeSP = ''

   -- (james06)
   SET @cLOCLookupSP = rdt.rdtGetConfig( @nFunc, 'LOCLookupSP', @cStorerKey)

   -- (james08)
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''

   -- Clear log table
   DELETE FROM rdt.rdtConReceiveLog WHERE Mobile = @nMobile

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerKey,
      @nStep       = @nStep

   -- Set the entry point
   SET @nScn = 690
   SET @nStep = 1

   -- Initiate var
   SET @cReceiptKey = ''
   SET @cReceiptKey1 = ''
   SET @cReceiptKey2 = ''
   SET @cReceiptKey3 = ''
   SET @cReceiptKey4 = ''
   SET @cReceiptKey5 = ''
   SET @cExternReceiptKey = ''
   SET @cRefNo = ''
   SET @cLOC = ''
   SET @cID = ''
   SET @cUCC = ''
   SET @cQTY = ''
   SET @cTotalUCC = ''
   SET @cTrackCartonType = ''  /*(JH01)*/
	
   -- Init screen
   SET @cOutField01 = '' -- ReceiptKey1
   SET @cOutField02 = '' -- ReceiptKey2
   SET @cOutField03 = '' -- ReceiptKey3
   SET @cOutField04 = '' -- ReceiptKey4
   SET @cOutField05 = '' -- ReceiptKey5
   SET @cOutField06 = '' -- ExternReceiptKey
   SET @cOutField07 = '' -- RefNo
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 690. ReceiptKey screen
   ReceiptKey1      (field01, input)
   ReceiptKey2      (field02, input)
   ReceiptKey3      (field03, input)
   ReceiptKey4      (field04, input)
   ReceiptKey5      (field05, input)
   ExternReceiptKey (field06)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      SET @i = 1

      -- Screen mapping
      SET @cReceiptKey1 = @cInField01
      SET @cReceiptKey2 = @cInField02
      SET @cReceiptKey3 = @cInField03
      SET @cReceiptKey4 = @cInField04
      SET @cReceiptKey5 = @cInField05
      SET @cRefNo       = @cInField07

      -- Validate blank
      IF @cReceiptKey1 = '' AND
         @cReceiptKey2 = '' AND
         @cReceiptKey3 = '' AND
         @cReceiptKey4 = '' AND
         @cReceiptKey5 = '' AND
         -- If ASN is blank and rdt config not setup, prompt error
         ISNULL(@cBypassASNBlankCheck, '') <> '1' AND -- (james02)
         ISNULL( @cRefNo, '') = ''  -- (james04)
      BEGIN
         SET @nErrNo = 62226
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ASN/Ref needed
         GOTO Step_1_Fail
      END

      --Check ASN facility (cc01)
      IF EXISTS (SELECT facility FROM receipt (NOLOCK) WHERE ReceiptKey in (@cReceiptKey1 ,@cReceiptKey2,@cReceiptKey3,@cReceiptKey4,@cReceiptKey5)
                  EXCEPT
                  SELECT @cFacility)
      BEGIN
      	SET @nErrNo = 62247
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff facility
         GOTO Step_1_Fail
      END

      IF ISNULL( @cRefNo, '') <> ''
      BEGIN
         -- Get storer config
         SET @cColumnName = rdt.RDTGetConfig( @nFunc, 'RefNoLookupColumn', @cStorerKey)

         -- Get lookup field data type
         DECLARE @cDataType NVARCHAR(128)
         SET @cDataType = ''
         SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Receipt' AND COLUMN_NAME = @cColumnName

         -- Check lookup field
         IF @cDataType = ''
         BEGIN
            SET @nErrNo = 62242
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad RefNoSetup
            EXEC rdt.rdtSetFocusField @nMobile, 7 -- RefNo
            GOTO Quit
         END

         -- Check data is correct type
         IF @cDataType = 'nvarchar' SET @n_Err = 1                                ELSE
         IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cRefNo)     ELSE
         IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cRefNo)     ELSE
         IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cRefNo, 20)
         IF @n_Err = 0
         BEGIN
            SET @nErrNo = 62243
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo
            EXEC rdt.rdtSetFocusField @nMobile, 7 -- RefNo
            GOTO Quit
         END

         -- Clear log
         IF EXISTS( SELECT 1 FROM rdt.rdtConReceiveLog WITH (NOLOCK) WHERE Mobile = @nMobile)
         BEGIN
            SET @curCR = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT RowRef FROM rdt.rdtConReceiveLog WITH (NOLOCK) WHERE Mobile = @nMobile
            OPEN @curCR
            FETCH NEXT FROM @curCR INTO @nRowRef
            WHILE @@FETCH_STATUS = 0
            BEGIN
               DELETE rdt.rdtConReceiveLog WHERE RowRef = @nRowRef
               FETCH NEXT FROM @curCR INTO @nRowRef
            END
         END

         -- Insert log
         SET @cSQL =
            ' INSERT INTO rdt.rdtConReceiveLog (Mobile, ReceiptKey) ' +
            ' SELECT @nMobile, ReceiptKey ' +
            ' FROM dbo.Receipt WITH (NOLOCK) ' +
            ' WHERE Facility = @cFacility ' +
               ' AND Status <> ''9'' ' +
               CASE WHEN @cDataType IN ('int', 'float')
                    THEN ' AND ISNULL( ' + @cColumnName + ', 0) = @cRefNo '
                    ELSE ' AND ISNULL( ' + @cColumnName + ', '''') = @cRefNo '
               END +
            ' AND StorerKey = @cStorerKey ' +
            ' ORDER BY ReceiptKey ' +
            ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT '
         SET @cSQLParam =
            ' @nMobile      INT, ' +
            ' @cFacility    NVARCHAR(5),  ' +
            ' @cStorerKey   NVARCHAR(15), ' +
            ' @cColumnName  NVARCHAR(20), ' +
            ' @cRefNo       NVARCHAR(20), ' +
            ' @nRowCount    INT OUTPUT,   ' +
            ' @nErrNo       INT OUTPUT    '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile,
            @cFacility,
            @cStorerKey,
            @cColumnName,
            @cRefNo,
            @nRowCount OUTPUT,
            @nErrNo    OUTPUT

         IF @nErrNo <> 0
            GOTO Quit

         -- Check RefNo in ASN
         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 62244
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
            GOTO Quit
         END

         IF EXISTS (SELECT 1
                    FROM rdt.rdtConReceiveLog C WITH (NOLOCK)
                    JOIN dbo.Receipt R WITH (NOLOCK) ON ( C.ReceiptKey = R.ReceiptKey)
                    WHERE Mobile = @nMobile
                    AND   ( (Status >= '9') OR (ASNStatus >= '9')))
         BEGIN
            SET @nErrNo = 62245
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN Closed
            GOTO Quit
         END

         -- Get total UCC
         IF @cUCCReceivedDetail <> '1'
         BEGIN
            SELECT @cTotalUCC = COUNT( DISTINCT IsNull( RTRIM(PODetail.UserDefine01), '')) -- (Vicky01)
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            JOIN dbo.PODetail PODetail WITH (NOLOCK) ON (RD.POKey = PODetail.POKey AND RD.POLineNumber = PODetail.POLineNumber)
            JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
            WHERE CR.Mobile = @nMobile
         END
         ELSE
         BEGIN
            SELECT @cTotalUCC = COUNT( DISTINCT IsNull( RTRIM(RD.UserDefine01), ''))
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
            WHERE CR.Mobile = @nMobile
         END


         IF EXISTS ( SELECT 1 FROM rdt.rdtConReceiveLog WITH (NOLOCK)
                     WHERE Mobile = @nMobile
                     GROUP BY Mobile
                     HAVING COUNT( 1) = 1)
         BEGIN
            SELECT TOP 1
               @cExternReceiptKey = ExternReceiptKey
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
            WHERE CR.Mobile = @nMobile
            AND   RD.ExternReceiptKey <> ''
         END
      END
      ELSE
      BEGIN
         -- Check duplicate
         IF (@cReceiptKey1 <> '' AND @cReceiptKey1 IN (@cReceiptKey2, @cReceiptKey3, @cReceiptKey4, @cReceiptKey5)) OR
            (@cReceiptKey2 <> '' AND @cReceiptKey2 IN (@cReceiptKey1, @cReceiptKey3, @cReceiptKey4, @cReceiptKey5)) OR
            (@cReceiptKey3 <> '' AND @cReceiptKey3 IN (@cReceiptKey1, @cReceiptKey2, @cReceiptKey4, @cReceiptKey5)) OR
            (@cReceiptKey4 <> '' AND @cReceiptKey4 IN (@cReceiptKey1, @cReceiptKey2, @cReceiptKey3, @cReceiptKey5)) OR
            (@cReceiptKey5 <> '' AND @cReceiptKey5 IN (@cReceiptKey1, @cReceiptKey2, @cReceiptKey3, @cReceiptKey4))
         BEGIN
            SET @nErrNo = 62241
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Duplicate ASN
            GOTO Quit
         END

         -- If there is changes
         IF @cOutField01 <> @cInField01 OR
            @cOutField02 <> @cInField02 OR
            @cOutField03 <> @cInField03 OR
            @cOutField04 <> @cInField04 OR
            @cOutField05 <> @cInField05
         BEGIN
            -- Loop ReceiptKey1..5
            SET @cReceiptKey = ''
            WHILE @i <= 5
            BEGIN
               IF @i = 1 SET @cReceiptKey = @cReceiptKey1
               IF @i = 2 SET @cReceiptKey = @cReceiptKey2
               IF @i = 3 SET @cReceiptKey = @cReceiptKey3
               IF @i = 4 SET @cReceiptKey = @cReceiptKey4
               IF @i = 5 SET @cReceiptKey = @cReceiptKey5

               -- Validate each ReceiptKey
               IF @cReceiptKey <> ''
               BEGIN
                  -- Get ASN info
                  DECLARE @cStatus NVARCHAR( 10)
                  SELECT @cStatus = Status
                  FROM dbo.Receipt WITH (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey

                  -- Validate ReceiptKey
                  IF @@ROWCOUNT = 0
                  BEGIN
                     SET @nErrNo = 62227
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid ASN
                     GOTO Step_1_Fail
                  END

                  -- Validate ASN status
                  IF @cStatus >= '9' -- 9=Closed, C-Cancel
                  BEGIN
                     SET @nErrNo = 62228
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- ASN closed
                     GOTO Step_1_Fail
                  END

                  -- Get ReceiptDetail info
                  -- NOTE: ECCO had 1 ASN 1 ExternReceiptKey
                  DECLARE @nOutstandingQTY INT
                  SELECT @nOutstandingQTY = IsNULL( SUM( QTYExpected - BeforeReceivedQty), 0)
                  FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                  WHERE RD.ReceiptKey = @cReceiptKey
                     AND (QTYExpected - BeforeReceivedQty) > 0 -- Not received
                     AND FinalizeFlag <> 'Y' -- Not finalize
                  -- Validate ASN fully received
                  IF @nOutstandingQTY = 0
                  BEGIN
                     SET @nErrNo = 62229
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --ASN received
                     GOTO Step_1_Fail
                  END
               END
               SET @i = @i + 1

               IF NOT EXISTS ( SELECT 1 FROM rdt.rdtConReceiveLog WITH (NOLOCK)
                               WHERE Mobile = @nMobile
                               AND   ReceiptKey = @cReceiptKey)
               BEGIN
                  INSERT INTO rdt.rdtConReceiveLog (Mobile, ReceiptKey) VALUES (@nMobile, @cReceiptKey)

                  IF @@ERROR <> 0
                  BEGIN
                     DELETE FROM rdt.rdtConReceiveLog WHERE Mobile = @nMobile
                     GOTO Quit
                  END
               END
            END

            -- Find and position cursor on next empty ASN field
            SELECT @i =
            CASE
               WHEN @cReceiptKey1 = '' THEN 1
               WHEN @cReceiptKey2 = '' THEN 2
               WHEN @cReceiptKey3 = '' THEN 3
               WHEN @cReceiptKey4 = '' THEN 4
               WHEN @cReceiptKey5 = '' THEN 5
               ELSE 1
            END
            EXEC rdt.rdtSetFocusField @nMobile, @i

            -- Retain ReceiptKey
            SET @cOutField01 = @cInField01
            SET @cOutField02 = @cInField02
            SET @cOutField03 = @cInField03
            SET @cOutField04 = @cInField04
            SET @cOutField05 = @cInField05

            GOTO Quit
         END

         -- If no changes
         IF @cOutField01 = @cInField01 AND
            @cOutField02 = @cInField02 AND
            @cOutField03 = @cInField03 AND
            @cOutField04 = @cInField04 AND
            @cOutField05 = @cInField05
         BEGIN
            -- Get total UCC
            IF @cUCCReceivedDetail <> '1'
            BEGIN
               SELECT @cTotalUCC = COUNT( DISTINCT IsNull( RTRIM(PODetail.UserDefine01), '')) -- (Vicky01)
               FROM dbo.ReceiptDetail RD WITH (NOLOCK)
               JOIN dbo.PODetail PODetail WITH (NOLOCK) ON (RD.POKey = PODetail.POKey AND RD.POLineNumber = PODetail.POLineNumber)
               JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
               WHERE CR.Mobile = @nMobile
            END
            ELSE
            BEGIN
               SELECT @cTotalUCC = COUNT( DISTINCT IsNull( RTRIM(RD.UserDefine01), ''))
               FROM dbo.ReceiptDetail RD WITH (NOLOCK)
               JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
               WHERE CR.Mobile = @nMobile
            END

            -- Get ExternReceiptKey, if only 1 ASN
            SET @cExternReceiptKey = ''
            SET @i = 0
            IF @cReceiptKey1 <> '' SET @i = @i + 1
            IF @cReceiptKey2 <> '' SET @i = @i + 1
            IF @cReceiptKey3 <> '' SET @i = @i + 1
            IF @cReceiptKey4 <> '' SET @i = @i + 1
            IF @cReceiptKey5 <> '' SET @i = @i + 1
            IF @i = 1
               SELECT TOP 1
                  @cExternReceiptKey = ExternReceiptKey
               FROM dbo.ReceiptDetail RD WITH (NOLOCK)
               JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
               WHERE CR.Mobile = @nMobile
                  AND RD.ExternReceiptKey <> ''
         END
      END

      --(yeekung01)
      IF @cExtendedValidateSP <> ''
	   BEGIN
	      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
                                    ' @nMobile                 ' +
	                                 ' , @nFunc                 ' +
	                                 ' , @cLangCode             ' +
	                                 ' , @nStep                 ' +
	                                 ' , @cStorerKey            ' +
	                                 ' , @cFacility             ' +
                                    ' , @cReceiptKey1          ' +
                                    ' , @cReceiptKey2          ' +
                                    ' , @cReceiptKey3          ' +
                                    ' , @cReceiptKey4          ' +
                                    ' , @cReceiptKey5          ' +
                                    ' , @cLoc                  ' +
                                    ' , @cID                   ' +
                                    ' , @cUCC                  ' +
                                    ' , @nErrNo       OUTPUT   ' +
                                    ' , @cErrMSG      OUTPUT   '


            SET @cExecArguments =
                      N'@nMobile     INT, ' +
	                    '@nFunc       INT, ' +
	                    '@cLangCode   NVARCHAR(3), ' +
	                    '@nStep       INT, ' +
	                    '@cStorerKey  NVARCHAR(15), ' +
	                    '@cFacility   NVARCHAR(5), '  +
                       '@cReceiptKey1 NVARCHAR(20),          ' +
                       '@cReceiptKey2 NVARCHAR(20),          ' +
                       '@cReceiptKey3 NVARCHAR(20),          ' +
                       '@cReceiptKey4 NVARCHAR(20),          ' +
                       '@cReceiptKey5 NVARCHAR(20),          ' +
                       '@cLoc        NVARCHAR(20),           ' +
                       '@cID         NVARCHAR(18),           ' +
                       '@cUCC        NVARCHAR(20),           ' +
                       '@nErrNo      INT  OUTPUT,            ' +
                       '@cErrMsg     NVARCHAR(1024) OUTPUT  '


            EXEC sp_executesql @cExecStatements, @cExecArguments,
                                @nMobile
                              , @nFunc
                              , @cLangCode
                              , @nStep
                              , @cStorerKey
                              , @cFacility
                              , @cReceiptKey1
                              , @cReceiptKey2
                              , @cReceiptKey3
                              , @cReceiptKey4
                              , @cReceiptKey5
                              , @cLoc
                              , @cID
                              , @cUCC
                              , @nErrNo       OUTPUT
                              , @cErrMSG      OUTPUT


           IF @nErrNo <> 0
           BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_1_Fail
           END
         END
	   END

      IF @cExtendedUpdateSP <> ''        
      BEGIN        
          IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')        
          BEGIN        
          	SET @nErrNo = 0
             SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +                          
                ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' + 
                ' @cReceiptKey1, @cReceiptKey2, @cReceiptKey3, @cReceiptKey4, @cReceiptKey5, @cLoc, @cID, @cUCC, @cCartonType, ' +
                ' @tExtUpdate, @nErrNo OUTPUT, @cErrMsg OUTPUT'                         
             SET @cSQLParam =                          
                '@nMobile        INT, ' +                          
                '@nFunc          INT, ' +                          
                '@cLangCode      NVARCHAR( 3),  ' +                          
                '@nStep          INT, ' +                          
                '@nInputKey      INT,  ' +                    
                '@cStorerKey     NVARCHAR( 15), ' +                          
                '@cFacility      NVARCHAR( 5), ' +                          
                '@cReceiptKey1   NVARCHAR( 20), ' +                          
                '@cReceiptKey2   NVARCHAR( 20), ' +
                '@cReceiptKey3   NVARCHAR( 20), ' +
                '@cReceiptKey4   NVARCHAR( 20), ' +
                '@cReceiptKey5   NVARCHAR( 20), ' +
                '@cLoc           NVARCHAR( 20), ' +                          
                '@cID            NVARCHAR( 18), ' +                          
                '@cUCC           NVARCHAR( 20), ' +                          
                '@cCartonType    NVARCHAR( 10), ' +                        
                '@tExtUpdate     VariableTable READONLY, ' +                          
                '@nErrNo         INT           OUTPUT,   ' +                          
                '@cErrMsg        NVARCHAR( 20) OUTPUT '   
          
             EXEC sp_ExecuteSQL @cSQL, @cSQLParam,                          
                @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 
                @cReceiptKey1, @cReceiptKey2, @cReceiptKey3, @cReceiptKey4, @cReceiptKey5, @cLoc, @cID, @cUCC, @cCartonType, 
                @tExtUpdate, @nErrNo OUTPUT, @cErrMsg OUTPUT 
                        
             IF @nErrNo <> 0 
               GOTO Step_1_Fail
          END        
      END       
      
      -- (james03)
      SET @cDefaultToLoc = ''
      SET @cDefaultToLocSP = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey) -- Parse in Function (yeekung02)
      IF @cDefaultToLocSP = '0'
      BEGIN
         SET @cDefaultToLoc = ''
      END
      ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDefaultToLocSP AND type = 'P') --(yeekung02)
      BEGIN
         SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cDefaultToLocSP) +
                              ' @nMobile                 ' +
	                           ' , @nFunc                 ' +
	                           ' , @cLangCode             ' +
	                           ' , @nStep                 ' +
	                           ' , @cStorerKey            ' +
	                           ' , @cFacility             ' +
                              ' , @cReceiptKey1          ' +
                              ' , @cReceiptKey2          ' +
                              ' , @cReceiptKey3          ' +
                              ' , @cReceiptKey4          ' +
                              ' , @cReceiptKey5          ' +
                              ' , @cLoc                  ' +
                              ' , @cID                   ' +
                              ' , @cUCC                  ' +
                              ' , @cDefaultToLoc OUTPUT  ' +
                              ' , @nErrNo       OUTPUT   ' +
                              ' , @cErrMSG      OUTPUT   '


         SET @cExecArguments =
                     N'@nMobile     INT, ' +
	                  '@nFunc       INT, ' +
	                  '@cLangCode   NVARCHAR(3), ' +
	                  '@nStep       INT, ' +
	                  '@cStorerKey  NVARCHAR(15), ' +
	                  '@cFacility   NVARCHAR(5), '  +
                     '@cReceiptKey1 NVARCHAR(20),          ' +
                     '@cReceiptKey2 NVARCHAR(20),          ' +
                     '@cReceiptKey3 NVARCHAR(20),          ' +
                     '@cReceiptKey4 NVARCHAR(20),          ' +
                     '@cReceiptKey5 NVARCHAR(20),          ' +
                     '@cLoc        NVARCHAR(20),           ' +
                     '@cID         NVARCHAR(18),           ' +
                     '@cUCC        NVARCHAR(20),           ' +
                     '@cDefaultToLoc NVARCHAR(20) OUTPUT,  ' +  
                     '@nErrNo      INT  OUTPUT,            ' +
                     '@cErrMsg     NVARCHAR(1024) OUTPUT   '


         EXEC sp_executesql @cExecStatements, @cExecArguments,
                              @nMobile
                           , @nFunc
                           , @cLangCode
                           , @nStep
                           , @cStorerKey
                           , @cFacility
                           , @cReceiptKey1
                           , @cReceiptKey2
                           , @cReceiptKey3
                           , @cReceiptKey4
                           , @cReceiptKey5
                           , @cLoc
                           , @cID
                           , @cUCC
                           , @cDefaultToLoc OUTPUT
                           , @nErrNo       OUTPUT
                           , @cErrMSG      OUTPUT
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Step_2_Fail
         END
      END
      ELSE
      BEGIN
         SET @cDefaultToLoc = @cDefaultToLocSP
      END

      -- Prepare next screen var
      SET @cLOC = ''
      SET @cOutField01 = @cReceiptKey1
      SET @cOutField02 = @cReceiptKey2
      SET @cOutField03 = @cReceiptKey3
      SET @cOutField04 = @cReceiptKey4
      SET @cOutField05 = @cReceiptKey5
      SET @cOutField06 = @cExternReceiptKey
      SET @cOutField07 = CASE WHEN ISNULL(@cDefaultToLoc, '') <> '' THEN @cDefaultToLoc ELSE '' END   --LOC  (james03)
      SET @cOutField08 = @cRefNo

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
     -- EventLog
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey,
       @nStep       = @nStep

      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      EXEC rdt.rdtSetFocusField @nMobile, @i -- ReceiptKey1..5
   END
END
GOTO Quit


/********************************************************************************
Step 2. Scn = 691. LOC screen
   ReceiptKey     (field01)
   ReceiptKey     (field02)
   ReceiptKey     (field03)
   ReceiptKey     (field04)
   ReceiptKey     (field05)
   ExternOrderKey (field06)
   LOC            (field07, input)
   ID             (field08)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField07 -- LOC

      IF ISNULL(RTRIM(@cDefaultReceiptDetailLoc),'')  = '' -- (ChewKP03)
      BEGIN
         -- Validate compulsary field
         IF @cLOC = '' OR @cLOC IS NULL
         BEGIN
            SET @nErrNo = 62230
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LOC needed'
            GOTO Step_2_Fail
         END

		   -- (james06)
		   IF @cLOCLookupSP = 1
		   BEGIN
			   EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
			      @cLOC       OUTPUT,
			      @nErrNo     OUTPUT,
			      @cErrMsg    OUTPUT

			   IF @nErrNo <> 0
				   GOTO Step_2_Fail
		   END

         -- Get the location
         DECLARE @cChkFacility NVARCHAR( 5)
         SELECT
            @cChkFacility = Facility
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cLOC

         -- Validate location
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 62231
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid LOC'
            GOTO Step_2_Fail
         END

         -- Validate location not in facility
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 62232
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Facility diff'
            GOTO Step_2_Fail
         END
      END
      ELSE
      BEGIN
		   -- (james06)
		   IF @cLOCLookupSP = 1
		   BEGIN
			   EXEC rdt.rdt_LOCLookUp @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cFacility,
			      @cLOC       OUTPUT,
			      @nErrNo     OUTPUT,
			      @cErrMsg    OUTPUT

			   IF @nErrNo <> 0
				   GOTO Step_2_Fail
		   END
      END

      -- Prepare next screen var
      SET @cID = ''
      SET @cOutField01 = @cReceiptKey1
      SET @cOutField02 = @cReceiptKey2
      SET @cOutField03 = @cReceiptKey3
      SET @cOutField04 = @cReceiptKey4
      SET @cOutField05 = @cReceiptKey5
      SET @cOutField06 = @cExternReceiptKey
      SET @cOutField07 = @cLOC
      SET @cOutField08 = ''
      SET @cOutField09 = @cRefNo

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Get UCC scanned
      IF @cUCCReceivedDetail <> '1'
      BEGIN
         SELECT @cScanUCC = COUNT( DISTINCT IsNull( RTRIM(PODetail.UserDefine01), '')) -- (Vicky01)
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN dbo.PODetail PODetail WITH (NOLOCK) ON (RD.POKey = PODetail.POKey AND RD.POLineNumber = PODetail.POLineNumber)
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
         WHERE CR.Mobile = @nMobile
            AND BeforeReceivedQty > 0 -- Received
      END
      ELSE
      BEGIN
         SELECT @cScanUCC = COUNT( DISTINCT IsNull( RTRIM(RD.UserDefine01), ''))
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
         WHERE CR.Mobile = @nMobile
            AND BeforeReceivedQty > 0 -- Received
      END

      IF @cScanUCC <> @cTotalUCC AND ISNULL(@cBypassASNBlankCheck, '') <> '1' -- (james02)
      BEGIN
         -- Prepare next screen var
         DECLARE @nRemain INT
         SET @nRemain = CAST( @cTotalUCC AS INT) - CAST( @cScanUCC AS INT)
         SET @cOutField01 = @cTotalUCC
         SET @cOutField02 = @cScanUCC
         SET @cOutField03 = CAST( @nRemain AS NVARCHAR( 5))
         SET @cOutField04 = '' -- Option

         -- Go to message screen
         SET @nScn = @nScn + 3
         SET @nStep = @nStep + 3

         GOTO Quit
      END

      -- Clear log
      IF EXISTS( SELECT 1 FROM rdt.rdtConReceiveLog WITH (NOLOCK) WHERE Mobile = @nMobile)
      BEGIN
         SET @curCR = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef FROM rdt.rdtConReceiveLog WITH (NOLOCK) WHERE Mobile = @nMobile
         OPEN @curCR
         FETCH NEXT FROM @curCR INTO @nRowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE rdt.rdtConReceiveLog WHERE RowRef = @nRowRef
            FETCH NEXT FROM @curCR INTO @nRowRef
         END
      END

      -- Prepare prev screen var
      SET @cReceiptKey1 = ''
      SET @cReceiptKey2 = ''
      SET @cReceiptKey3 = ''
      SET @cReceiptKey4 = ''
      SET @cReceiptKey5 = ''
      SET @cExternReceiptKey = ''
      SET @cRefNo = ''

      SET @cOutField01 = ''  -- ReceiptKey1
      SET @cOutField02 = ''  -- ReceiptKey2
      SET @cOutField03 = ''  -- ReceiptKey3
      SET @cOutField04 = ''  -- ReceiptKey4
      SET @cOutField05 = ''  -- ReceiptKey5
      SET @cOutField06 = ''  -- ExternReceiptKey
      SET @cOutField07 = ''  -- RefNo

      EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey1

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      -- (james03)
      -- (james03)
      SET @cDefaultToLoc = ''
      SET @cDefaultToLocSP = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey) -- Parse in Function (yeekung02)
      IF @cDefaultToLocSP = '0'
      BEGIN
         SET @cDefaultToLoc = ''
      END
      ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDefaultToLocSP AND type = 'P') --(yeekung02)
      BEGIN
         SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cDefaultToLocSP) +
                     ' @nMobile                 ' +
	                  ' , @nFunc                 ' +
	                  ' , @cLangCode             ' +
	                  ' , @nStep                 ' +
	                  ' , @cStorerKey            ' +
	                  ' , @cFacility             ' +
                     ' , @cReceiptKey1          ' +
                     ' , @cReceiptKey2          ' +
                     ' , @cReceiptKey3          ' +
                     ' , @cReceiptKey4          ' +
                     ' , @cReceiptKey5          ' +
                     ' , @cLoc                  ' +
                     ' , @cID                   ' +
                     ' , @cUCC                  ' +
                     ' , @cDefaultToLoc OUTPUT  ' +
                     ' , @nErrNo       OUTPUT   ' +
                     ' , @cErrMSG      OUTPUT   '


         SET @cExecArguments =
                     N'@nMobile     INT, ' +
	                  '@nFunc       INT, ' +
	                  '@cLangCode   NVARCHAR(3), ' +
	                  '@nStep       INT, ' +
	                  '@cStorerKey  NVARCHAR(15), ' +
	                  '@cFacility   NVARCHAR(5), '  +
                     '@cReceiptKey1 NVARCHAR(20),          ' +
                     '@cReceiptKey2 NVARCHAR(20),          ' +
                     '@cReceiptKey3 NVARCHAR(20),          ' +
                     '@cReceiptKey4 NVARCHAR(20),          ' +
                     '@cReceiptKey5 NVARCHAR(20),          ' +
                     '@cLoc        NVARCHAR(20),           ' +
                     '@cID         NVARCHAR(18),           ' +
                     '@cUCC        NVARCHAR(20),           ' +
                     '@cDefaultToLoc NVARCHAR(20) OUTPUT,  ' +  
                     '@nErrNo      INT  OUTPUT,            ' +
                     '@cErrMsg     NVARCHAR(1024) OUTPUT   '


         EXEC sp_executesql @cExecStatements, @cExecArguments,
                              @nMobile
                           , @nFunc
                           , @cLangCode
                           , @nStep
                           , @cStorerKey
                           , @cFacility
                           , @cReceiptKey1
                           , @cReceiptKey2
                           , @cReceiptKey3
                           , @cReceiptKey4
                           , @cReceiptKey5
                           , @cLoc
                           , @cID
                           , @cUCC
                           , @cDefaultToLoc OUTPUT
                           , @nErrNo       OUTPUT
                           , @cErrMSG      OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Step_2_Fail
         END
      END
      ELSE
      BEGIN
         SET @cDefaultToLoc = @cDefaultToLocSP
      END


      -- Reset this screen var
      SET @cLOC = ''
      SET @cOutField07 = CASE WHEN ISNULL(@cDefaultToLoc, '') <> '' THEN @cDefaultToLoc ELSE '' END   --LOC  (james03)
   END
END
GOTO Quit


/********************************************************************************
Step 3. Scn = 692. ID screen
   ReceiptKey1    (field01)
   ReceiptKey2    (field02)
   ReceiptKey3    (field03)
   ReceiptKey4    (field04)
   ReceiptKey5    (field05)
   ExternOrderKey (field06)
   LOC            (field07)
   ID             (field08, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cID = @cInField08
      SET @cBarcode = @cInField08

      -- Validate blank
      IF (@cID = '' OR @cID IS NULL) AND @cUCCInboundReceiveIDOptional <> '1'
      BEGIN
         SET @nErrNo = 62233
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- ID needed
         GOTO Step_3_Fail
      END

      -- (james06)
      -- Check barcode format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cBarcode) = 0
      BEGIN
         SET @nErrNo = 62246
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         GOTO Step_3_Fail
      END

      -- (james05)
      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cID     = @cID     OUTPUT,
               @nErrNo  = @nErrNo  OUTPUT,
               @cErrMsg = @cErrMsg OUTPUT,
               @cType   = 'ID'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
               ' @cReceiptKey, @cLOC, @cID OUTPUT, @cUCC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cReceiptKey  NVARCHAR( 10), ' +
               ' @cLOC         NVARCHAR( 10), ' +
               ' @cID          NVARCHAR( 18)  OUTPUT, ' +
               ' @cUCC         NVARCHAR( 20)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode,
               @cReceiptKey, @cLOC, @cID OUTPUT, @cUCC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         END

         IF @nErrNo <> 0
            GOTO Step_3_Fail
      END

      -- Validate duplicate pallet ID
      DECLARE @nDisAllowDuplicateIdsOnRFRcpt INT
      SELECT @nDisAllowDuplicateIdsOnRFRcpt = NSQLValue
      FROM .NSQLConfig WITH (NOLOCK)
      WHERE ConfigKey = 'DisAllowDuplicateIdsOnRFRcpt'

      IF (@nDisAllowDuplicateIdsOnRFRcpt = '1') AND
         (@cID <> '' AND @cID IS NOT NULL)
      BEGIN
         IF EXISTS( SELECT [ID]
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LLI.[ID] = @cID
               AND LLI.QTY > 0
               AND LOC.Facility = @cFacility)
         BEGIN
            SET @nErrNo = 62234
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Duplicate ID'
            GOTO Step_3_Fail
         END
      END

      -- Track carton type
      IF @cTrackCartonTypeSP <> ''
      BEGIN
         SET @cTrackCartonType = ''
         IF @cTrackCartonTypeSP = '1'
            SET @cTrackCartonType = '1'

         ELSE IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cTrackCartonTypeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cTrackCartonTypeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cReceiptKey1, @cReceiptKey2, @cReceiptKey3, @cReceiptKey4, @cReceiptKey5, ' + 
               ' @cLoc, @cID, @cUCC, @cTrackCartonType OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               ' @nMobile           INT,           ' +
               ' @nFunc             INT,           ' +
               ' @cLangCode         NVARCHAR( 3),  ' +
               ' @nStep             INT,           ' +
               ' @nInputKey         INT,           ' +
               ' @cFacility         NVARCHAR( 5),  ' +
               ' @cStorerKey        NVARCHAR( 15), ' +
               ' @cReceiptKey1      NVARCHAR(20),  ' + 
               ' @cReceiptKey2      NVARCHAR(20),  ' + 
               ' @cReceiptKey3      NVARCHAR(20),  ' + 
               ' @cReceiptKey4      NVARCHAR(20),  ' + 
               ' @cReceiptKey5      NVARCHAR(20),  ' + 
               ' @cLoc              NVARCHAR( 10), ' +
               ' @cID               NVARCHAR( 18), ' +
               ' @cUCC              NVARCHAR( 20), ' +
               ' @cTrackCartonType  NVARCHAR( 1)  OUTPUT, ' + 
               ' @nErrNo            INT           OUTPUT, ' +
               ' @cErrMsg           NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cReceiptKey1, @cReceiptKey2, @cReceiptKey3, @cReceiptKey4, @cReceiptKey5,
               @cLoc, @cID, @cUCC, @cTrackCartonType OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      IF @cTrackCartonType = '1'
      BEGIN
         SET @cOutField01 = ''

         SET @nStep = @nStep + 3
         SET @nScn = @nScn + 3

         GOTO Quit
      END

      -- Get UCC scanned
      IF @cUCCReceivedDetail <> '1'
      BEGIN
         SELECT @cScanUCC = COUNT( DISTINCT IsNull( RTRIM(PODetail.UserDefine01), '')) -- (Vicky01)
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN dbo.PODetail PODetail WITH (NOLOCK) ON (RD.POKey = PODetail.POKey AND RD.POLineNumber = PODetail.POLineNumber)
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
         WHERE CR.Mobile = @nMobile
            AND BeforeReceivedQty > 0 -- Received
      END
      ELSE
      BEGIN
         SELECT @cScanUCC = COUNT( DISTINCT IsNull( RTRIM(RD.UserDefine01), ''))
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
         WHERE CR.Mobile = @nMobile
            AND BeforeReceivedQty > 0 -- Received
      END

      -- Prepare next screen var
      SET @cUCC = ''
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = '' --UCC
      SET @cOutField04 = '' --QTY
      SET @cOutField05 = CASE WHEN ISNULL(@cBypassASNBlankCheck, '') <> '1' THEN @cScanUCC + '/' + @cTotalUCC ELSE '' END  -- (james02)

      -- (ChewKP04)

      SET @cExtInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfo', @cStorerKey)

      -- Extended info
      IF @cExtInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtInfoSP AND type = 'P')
         BEGIN
            SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cExtInfoSP) +
                                    '   @nMobile               ' +
                                    ' , @nFunc                 ' +
                                    ' , @nStep                 ' +
                                    ' , @cStorerKey            ' +
                                    ' , @cReceiptKey           ' +
                                    ' , @cLoc                  ' +
                                    ' , @cID                   ' +
                                    ' , @cUCC                  ' +
                                    ' , @nErrNo       OUTPUT   ' +
                                    ' , @cErrMSG      OUTPUT   ' +
                                    ' , @cOutField01  OUTPUT   ' +
                                    ' , @cOutField02  OUTPUT   ' +
                                    ' , @cOutField03  OUTPUT   ' +
                                    ' , @cOutField04  OUTPUT   ' +
                                    ' , @cOutField05  OUTPUT   ' +
                                    ' , @cOutField06  OUTPUT   ' +
                                    ' , @cOutField07  OUTPUT   ' +
                                    ' , @cOutField08  OUTPUT   ' +
                                    ' , @cOutField09  OUTPUT   ' +
                                    ' , @cOutField10  OUTPUT   '

             SET @cExecArguments =
                      N'@nMobile     int,                    ' +
                       '@nFunc       int,                    ' +
                       '@nStep       int,                    ' +
                       '@cStorerKey  nvarchar(15),           ' +
                       '@cReceiptKey nvarchar(20),           ' +
                       '@cLoc        nvarchar(20),           ' +
                       '@cID         nvarchar(18),           ' +
                       '@cUCC        nvarchar(20),           ' +
                       '@nErrNo      int  OUTPUT,            ' +
                       '@cErrMsg     nvarchar(1024) OUTPUT,  ' +
                       '@cOutField01 nvarchar(60) OUTPUT ,   ' +
                       '@cOutField02 nvarchar(60) OUTPUT,    ' +
                       '@cOutField03 nvarchar(60) OUTPUT,    ' +
                       '@cOutField04 nvarchar(60) OUTPUT,    ' +
                       '@cOutField05 nvarchar(60) OUTPUT,    ' +
                       '@cOutField06 nvarchar(60) OUTPUT,    ' +
                       '@cOutField07 nvarchar(60) OUTPUT,    ' +
                       '@cOutField08 nvarchar(60) OUTPUT,    ' +
                       '@cOutField09 nvarchar(60) OUTPUT,    ' +
                       '@cOutField10 nvarchar(60) OUTPUT     '

            EXEC sp_executesql @cExecStatements, @cExecArguments,
                                  @nMobile
                                , @nFunc
                                , @nStep
                                , @cStorerKey
                                , @cReceiptKey
                                , @cLoc
                                , @cID
                                , @cUCC
                                , @nErrNo       OUTPUT
                                , @cErrMSG      OUTPUT
                                , @cOutField01  OUTPUT
                                , @cOutField02  OUTPUT
                                , @cOutField03  OUTPUT
                                , @cOutField04  OUTPUT
                                , @cOutField05  OUTPUT
                                , @cOutField06  OUTPUT
                                , @cOutField07  OUTPUT
                                , @cOutField08  OUTPUT
                                , @cOutField09  OUTPUT
                                , @cOutField10  OUTPUT
         END
      END
      ELSE
      BEGIN
         SET @cOutField06 = '' -- (ChewKP02)
         SET @cOutField07 = '' -- (ChewKP02)
         SET @cOutField08 = '' -- (ChewKP02)
      END

      -- (james08)
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLoc, @cID, @cUCC, @tExtInfoVar, @cExtendedInfo OUTPUT '
            SET @cSQLParam =
               ' @nMobile           INT,           ' +
               ' @nFunc             INT,           ' +
               ' @cLangCode         NVARCHAR( 3),  ' +
               ' @nStep             INT,           ' +
               ' @nInputKey         INT,           ' +
               ' @cFacility         NVARCHAR( 5),  ' +
               ' @cStorerKey        NVARCHAR( 15), ' +
               ' @cLoc              NVARCHAR( 10), ' +
               ' @cID               NVARCHAR( 18), ' +
               ' @cUCC              NVARCHAR( 20), ' +
               ' @tExtInfoVar       VariableTable READONLY, ' +
               ' @cExtendedInfo     NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLoc, @cID, @cUCC, @tExtInfoVar, @cExtendedInfo OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            SET @cOutField15 = @cExtendedInfo
         END
      END

      -- Remain in current screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- (james03)
      SET @cDefaultToLoc = ''
      SET @cDefaultToLocSP = rdt.RDTGetConfig( @nFunc, 'ReceiveDefaultToLoc', @cStorerKey) -- Parse in Function (yeekung02)
      IF @cDefaultToLocSP = '0'
      BEGIN
         SET @cDefaultToLoc = ''
      END
      ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDefaultToLocSP AND type = 'P') --(yeekung02)
      BEGIN
         SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cDefaultToLocSP) +
                     ' @nMobile                 ' +
	                  ' , @nFunc                 ' +
	                  ' , @cLangCode             ' +
	                  ' , @nStep                 ' +
	                  ' , @cStorerKey            ' +
	                  ' , @cFacility             ' +
                     ' , @cReceiptKey1          ' +
                     ' , @cReceiptKey2          ' +
                     ' , @cReceiptKey3          ' +
                     ' , @cReceiptKey4          ' +
                     ' , @cReceiptKey5          ' +
                     ' , @cLoc                  ' +
                     ' , @cID                   ' +
                     ' , @cUCC                  ' +
                     ' , @cDefaultToLoc OUTPUT  ' +
                     ' , @nErrNo       OUTPUT   ' +
                     ' , @cErrMSG      OUTPUT   '


         SET @cExecArguments =
                     N'@nMobile     INT, ' +
	                  '@nFunc       INT, ' +
	                  '@cLangCode   NVARCHAR(3), ' +
	                  '@nStep       INT, ' +
	                  '@cStorerKey  NVARCHAR(15), ' +
	                  '@cFacility   NVARCHAR(5), '  +
                     '@cReceiptKey1 NVARCHAR(20),          ' +
                     '@cReceiptKey2 NVARCHAR(20),          ' +
                     '@cReceiptKey3 NVARCHAR(20),          ' +
                     '@cReceiptKey4 NVARCHAR(20),          ' +
                     '@cReceiptKey5 NVARCHAR(20),          ' +
                     '@cLoc        NVARCHAR(20),           ' +
                     '@cID         NVARCHAR(18),           ' +
                     '@cUCC        NVARCHAR(20),           ' +
                     '@cDefaultToLoc NVARCHAR(20) OUTPUT,  ' +  
                     '@nErrNo      INT  OUTPUT,            ' +
                     '@cErrMsg     NVARCHAR(1024) OUTPUT   '


         EXEC sp_executesql @cExecStatements, @cExecArguments,
                              @nMobile
                           , @nFunc
                           , @cLangCode
                           , @nStep
                           , @cStorerKey
                           , @cFacility
                           , @cReceiptKey1
                           , @cReceiptKey2
                           , @cReceiptKey3
                           , @cReceiptKey4
                           , @cReceiptKey5
                           , @cLoc
                           , @cID
                           , @cUCC
                           , @cDefaultToLoc OUTPUT
                           , @nErrNo       OUTPUT
                           , @cErrMSG      OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO Step_3_Fail
         END
      END
      ELSE
      BEGIN
         SET @cDefaultToLoc = @cDefaultToLocSP
      END

      -- Prepare prev screen var
      SET @cLOC = ''
      SET @cID = ''
      SET @cOutField01 = @cReceiptKey1
      SET @cOutField02 = @cReceiptKey2
      SET @cOutField03 = @cReceiptKey3
      SET @cOutField04 = @cReceiptKey4
      SET @cOutField05 = @cReceiptKey5
      SET @cOutField06 = @cExternReceiptKey
      SET @cOutField07 = CASE WHEN ISNULL(@cDefaultToLoc, '') <> '' THEN @cDefaultToLoc ELSE '' END   --LOC  (james03)
      SET @cOutField08 = '' -- ID

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      -- Reset this screen var
      SET @cID = ''
      SET @cOutField08 = '' -- ID
   END
END
GOTO Quit


/********************************************************************************
Step 4. Scn = 693. UCC screen
   LOC     (field01)
   ID      (field02)
   UCC     (field03)
   QTY     (field04)
   Counter (field05)
********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCC = @cInField03
      SET @cBarcode = @cInField03

      -- Validate blank
      IF @cUCC = '' OR @cUCC IS NULL
      BEGIN
         SET @nErrNo = 62235
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UCC needed
         GOTO Step_4_Fail
      END

      -- (james05)
      -- Decode
      IF @cDecodeSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,
               @cUCCNo  = @cUCC    OUTPUT,
               @nErrNo  = @nErrNo  OUTPUT,
               @cErrMsg = @cErrMsg OUTPUT,
               @cType   = 'UCCNO'
         END

         -- Customize decode
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +
               ' @cReceiptKey, @cLOC, @cID OUTPUT, @cUCC OUTPUT, @nErrNo OUTPUT, @cErrMsg  OUTPUT'
            SET @cSQLParam =
               ' @nMobile      INT,           ' +
               ' @nFunc        INT,           ' +
               ' @cLangCode    NVARCHAR( 3),  ' +
               ' @nStep        INT,           ' +
               ' @nInputKey    INT,           ' +
               ' @cFacility    NVARCHAR( 5),  ' +
               ' @cStorerKey   NVARCHAR( 15), ' +
               ' @cBarcode     NVARCHAR( 60), ' +
               ' @cReceiptKey  NVARCHAR( 10), ' +
               ' @cLOC         NVARCHAR( 10), ' +
               ' @cID          NVARCHAR( 18)  OUTPUT, ' +
               ' @cUCC         NVARCHAR( 20)  OUTPUT, ' +
               ' @nErrNo       INT            OUTPUT, ' +
               ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode,
               @cReceiptKey, @cLOC, @cID OUTPUT, @cUCC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
         END

         IF @nErrNo <> 0
            GOTO Step_4_Fail
      END

      -- For ReceiptDetail
      DECLARE @tRD TABLE
      (
         ReceiptKey NVARCHAR( 10) NOT NULL,
         ReceiptLineNumber NVARCHAR( 5) NOT NULL,
         QTYExpected INT NOT NULL,
         BeforeReceivedQTY INT NOT NULL
      )

      -- Get ReceiptDetail
      IF @cUCCReceivedDetail <> '1'
      BEGIN
         IF ISNULL(@cBypassASNBlankCheck, '') <> '1'
         BEGIN
            INSERT INTO @tRD (ReceiptKey, ReceiptLineNumber, QTYExpected, BeforeReceivedQTY)
            SELECT RD.ReceiptKey, RD.ReceiptLineNumber, RD.QTYExpected, RD.BeforeReceivedQTY
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            JOIN dbo.PODetail PODetail WITH (NOLOCK) ON (RD.POKey = PODetail.POKey AND RD.POLineNumber = PODetail.POLineNumber)
            JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
            WHERE CR.Mobile = @nMobile
            AND   PODetail.UserDefine01 = @cUCC
         END
         ELSE  -- (james02)
         BEGIN
            INSERT INTO @tRD (ReceiptKey, ReceiptLineNumber, QTYExpected, BeforeReceivedQTY)
            SELECT RD.ReceiptKey, RD.ReceiptLineNumber, RD.QTYExpected, RD.BeforeReceivedQTY
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            JOIN dbo.PODetail PODetail WITH (NOLOCK) ON (RD.POKey = PODetail.POKey AND RD.POLineNumber = PODetail.POLineNumber)
            JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
            WHERE CR.Mobile = @nMobile
            AND   PODetail.UserDefine01 = @cUCC
         END
      END
      ELSE
      BEGIN
         IF ISNULL(@cBypassASNBlankCheck, '') <> '1'
         BEGIN
            INSERT INTO @tRD (ReceiptKey, ReceiptLineNumber, QTYExpected, BeforeReceivedQTY)
            SELECT RD.ReceiptKey, RD.ReceiptLineNumber, RD.QTYExpected, RD.BeforeReceivedQTY
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
            WHERE CR.Mobile = @nMobile
            AND   RD.UserDefine01 = @cUCC
         END
         ELSE  -- (james02)
         BEGIN
            INSERT INTO @tRD (ReceiptKey, ReceiptLineNumber, QTYExpected, BeforeReceivedQTY)
            SELECT RD.ReceiptKey, RD.ReceiptLineNumber, RD.QTYExpected, RD.BeforeReceivedQTY
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
            WHERE CR.Mobile = @nMobile
            AND   RD.UserDefine01 = @cUCC
         END
      END

      -- Validate UCC
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 62236
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid UCC
         GOTO Step_4_Fail
      END

      -- Validate UCC double scan
      IF EXISTS( SELECT 1
         FROM @tRD
         WHERE BeforeReceivedQTY > 0)
      BEGIN
         SET @nErrNo = 62237
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Double scan
         GOTO Step_4_Fail
      END

      -- (ChewKP04)
	   IF @cExtendedValidateSP <> ''
	   BEGIN
	      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
                                    ' @nMobile                 ' +
	                                 ' , @nFunc                 ' +
	                                 ' , @cLangCode             ' +
	                                 ' , @nStep                 ' +
	                                 ' , @cStorerKey            ' +
	                                 ' , @cFacility             ' +
                                    ' , @cReceiptKey1          ' +
                                    ' , @cReceiptKey2          ' +
                                    ' , @cReceiptKey3          ' +
                                    ' , @cReceiptKey4          ' +
                                    ' , @cReceiptKey5          ' +
                                    ' , @cLoc                  ' +
                                    ' , @cID                   ' +
                                    ' , @cUCC                  ' +
                                    ' , @nErrNo       OUTPUT   ' +
                                    ' , @cErrMSG      OUTPUT   '


            SET @cExecArguments =
                      N'@nMobile     INT, ' +
	                    '@nFunc       INT, ' +
	                    '@cLangCode   NVARCHAR(3), ' +
	                    '@nStep       INT, ' +
	                    '@cStorerKey  NVARCHAR(15), ' +
	                    '@cFacility   NVARCHAR(5), '  +
                       '@cReceiptKey1 NVARCHAR(20),          ' +
                       '@cReceiptKey2 NVARCHAR(20),          ' +
                       '@cReceiptKey3 NVARCHAR(20),          ' +
                       '@cReceiptKey4 NVARCHAR(20),          ' +
                       '@cReceiptKey5 NVARCHAR(20),          ' +
                       '@cLoc        NVARCHAR(20),           ' +
                       '@cID         NVARCHAR(18),           ' +
                       '@cUCC        NVARCHAR(20),           ' +
                       '@nErrNo      INT  OUTPUT,            ' +
                       '@cErrMsg     NVARCHAR(1024) OUTPUT  '


            EXEC sp_executesql @cExecStatements, @cExecArguments,
                                @nMobile
                              , @nFunc
                              , @cLangCode
                              , @nStep
                              , @cStorerKey
                              , @cFacility
                              , @cReceiptKey1
                              , @cReceiptKey2
                              , @cReceiptKey3
                              , @cReceiptKey4
                              , @cReceiptKey5
                              , @cLoc
                              , @cID
                              , @cUCC
                              , @nErrNo       OUTPUT
                              , @cErrMSG      OUTPUT


           IF @nErrNo <> 0
           BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO Step_4_Fail
           END
         END
	   END

      -- Print UCC ASN Label -- (ChewKP03)
      SELECT   @cDataWindow = DataWindow,
               @cTargetDB = TargetDB
      FROM rdt.rdtReport WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ReportType = 'UCCASNLBL'

      IF ISNULL(RTRIM(@cDataWindow),'')  <> ''
      BEGIN
         IF @cUCCReceivedDetail <> '1'
         BEGIN
            IF ISNULL(@cBypassASNBlankCheck, '') <> '1'
            BEGIN

               SELECT TOP 1 @cUCCReceiptKey = RD.ReceiptKey
               FROM dbo.ReceiptDetail RD WITH (NOLOCK)
               JOIN dbo.PODetail PODetail WITH (NOLOCK) ON (RD.POKey = PODetail.POKey AND RD.POLineNumber = PODetail.POLineNumber)
               JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
               WHERE CR.Mobile = @nMobile
               AND   PODetail.UserDefine01 = @cUCC
            END
            ELSE
            BEGIN

               SELECT TOP 1 @cUCCReceiptKey = RD.ReceiptKey
               FROM dbo.ReceiptDetail RD WITH (NOLOCK)
               JOIN dbo.PODetail PODetail WITH (NOLOCK) ON (RD.POKey = PODetail.POKey AND RD.POLineNumber = PODetail.POLineNumber)
               JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
               WHERE CR.Mobile = @nMobile
               AND   PODetail.UserDefine01 = @cUCC
            END
         END
         ELSE
         BEGIN
            IF ISNULL(@cBypassASNBlankCheck, '') <> '1'
            BEGIN

               SELECT TOP 1 @cUCCReceiptKey = RD.ReceiptKey
               FROM dbo.ReceiptDetail RD WITH (NOLOCK)
               JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
               WHERE CR.Mobile = @nMobile
               AND   RD.UserDefine01 = @cUCC
            END
            ELSE
            BEGIN
               SELECT TOP 1 @cUCCReceiptKey = RD.ReceiptKey
               FROM dbo.ReceiptDetail RD WITH (NOLOCK)
               JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
               WHERE CR.Mobile = @nMobile
               AND   RD.UserDefine01 = @cUCC
            END
         END

         EXEC RDT.rdt_BuiltPrintJob
             @nMobile,
             @cStorerKey,
             'UCCASNLBL',              -- ReportType
             'UCCASNLBL',              -- PrintJobName
             @cDataWindow,
             @cPrinter,
             @cTargetDB,
             @cLangCode,
             @nErrNo  OUTPUT,
             @cErrMsg OUTPUT,
             @cUCCReceiptKey,
             @cUCC
      END

      DECLARE @nQTY INT
      DECLARE @nQTYExpected INT
      DECLARE @cReceiptLineNumber NVARCHAR( 5)

      -- (james03)
      SET @cUCCRcvSkipUpdTOID = ''
      SET @cUCCRcvSkipUpdTOID = rdt.RDTGetConfig( @nFunc, 'UCCRcvSkipUpdTOID', @cStorerKey)

      -- Prepare cursor for @tRD
      DECLARE @curRD CURSOR
      SET @curRD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT ReceiptKey, ReceiptLineNumber, QTYExpected
         FROM @tRD
      OPEN @curRD
      FETCH NEXT FROM @curRD INTO @cReceiptKey, @cReceiptLineNumber, @nQTYExpected

      -- Handling transaction
      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdtfnc_UCCInboundReceive -- For rollback or commit only our own transaction

      -- Loop @tRD
      SET @nQTY = 0
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF (@cFinalizeRD = '0' OR  @cFinalizeRD = '2') --(yeekung01)
         BEGIN
            -- Update ReceiptDetail
            UPDATE dbo.ReceiptDetail SET
               ToLOC = CASE WHEN @cDefaultReceiptDetailLoc = '1' THEN ToLoc ELSE @cLOC END , -- stamp LOC  -- (ChewKP03)
               ToID = CASE WHEN @cUCCRcvSkipUpdTOID = '1' THEN ToID ELSE @cID END, -- stamp ID  (james03)
               BeforeReceivedQTY = QTYExpected,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            FROM dbo.ReceiptDetail RD
            WHERE ReceiptKey = @cReceiptKey
               AND ReceiptLineNumber = @cReceiptLineNumber
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
         END
         ELSE IF @cFinalizeRD = '1'
         BEGIN
            UPDATE dbo.ReceiptDetail SET
               ToLOC = CASE WHEN @cDefaultReceiptDetailLoc = '1' THEN ToLoc ELSE @cLOC END , -- stamp LOC  -- (ChewKP03)
               ToID = CASE WHEN @cUCCRcvSkipUpdTOID = '1' THEN ToID ELSE @cID END, -- stamp ID  (james03)
               BeforeReceivedQTY = QTYExpected,
               QTYReceived = QTYExpected,
               FinalizeFlag = 'Y',
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            FROM dbo.ReceiptDetail RD
            WHERE ReceiptKey = @cReceiptKey
               AND ReceiptLineNumber = @cReceiptLineNumber
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
         END
         IF @cFinalizeRD = '2'
         BEGIN
            EXEC dbo.ispFinalizeReceipt
                @c_ReceiptKey        = @cReceiptKey
               ,@b_Success           = @bSuccess   OUTPUT
               ,@n_err               = @nErrNo     OUTPUT
               ,@c_ErrMsg            = @cErrMsg    OUTPUT
               ,@c_ReceiptLineNumber = @cReceiptLineNumber
            IF @nErrNo <> 0 OR @bSuccess = 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
         END

         -- EventLog
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '2', -- Receiving
            @cUserID       = @cUserName,
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerkey,
            @cLocation     = @cLOC,
            @cID           = @cID,
            @nQTY          = @nQTYExpected,
            @cReceiptKey    = @cReceiptKey,
            --@cReceiptLineNumber = @cReceiptLineNumber,
            @cUCC          = @cUCC,
            @nStep         = @nStep

         SET @nQTY = @nQTY + @nQTYExpected
         FETCH NEXT FROM @curRD INTO @cReceiptKey, @cReceiptLineNumber, @nQTYExpected
      END

      -- ExtendedUpdate -- (ChewKP05)
      IF @cExtendedUpdateSP <> ''
	   BEGIN
	      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
                                    ' @nMobile                 ' +
	                                 ' , @nFunc                 ' +
	                                 ' , @cLangCode             ' +
	                                 ' , @nStep                 ' +
	                                 ' , @nInputKey             ' +
	                                 ' , @cStorerKey            ' +
	                                 ' , @cFacility             ' +
                                    ' , @cReceiptKey1          ' +
                                    ' , @cReceiptKey2          ' +
                                    ' , @cReceiptKey3          ' +
                                    ' , @cReceiptKey4          ' +
                                    ' , @cReceiptKey5          ' +
                                    ' , @cLoc                  ' +
                                    ' , @cID                   ' +
                                    ' , @cUCC                  ' +
                                    ' , @cCartonType           ' +
                                    ' , @tExtUpdate            ' +
                                    ' , @nErrNo       OUTPUT   ' +
                                    ' , @cErrMSG      OUTPUT   '


            SET @cExecArguments =
                      N'@nMobile     INT, ' +
	                    '@nFunc       INT, ' +
	                    '@cLangCode   NVARCHAR(3), ' +
	                    '@nStep       INT, ' +
	                    '@nInputKey   INT, ' +
	                    '@cStorerKey  NVARCHAR(15), ' +
	                    '@cFacility   NVARCHAR(5), '  +
                       '@cReceiptKey1 NVARCHAR(20),          ' +
                       '@cReceiptKey2 NVARCHAR(20),          ' +
                       '@cReceiptKey3 NVARCHAR(20),          ' +
                       '@cReceiptKey4 NVARCHAR(20),          ' +
                       '@cReceiptKey5 NVARCHAR(20),          ' +
                       '@cLoc        NVARCHAR(20),           ' +
                       '@cID         NVARCHAR(18),           ' +
                       '@cUCC        NVARCHAR(20),           ' +
                       '@cCartonType NVARCHAR(10),           ' +
                       '@tExtUpdate  VariableTable  READONLY,' +
                       '@nErrNo      INT            OUTPUT,  ' +
                       '@cErrMsg     NVARCHAR(1024) OUTPUT   '


            EXEC sp_executesql @cExecStatements, @cExecArguments,
                                @nMobile
                              , @nFunc
                              , @cLangCode
                              , @nStep
                              , @nInputKey
                              , @cStorerKey
                              , @cFacility
                              , @cReceiptKey1
                              , @cReceiptKey2
                              , @cReceiptKey3
                              , @cReceiptKey4
                              , @cReceiptKey5
                              , @cLoc
                              , @cID
                              , @cUCC
                              , @cCartonType
                              , @tExtUpdate
                              , @nErrNo       OUTPUT
                              , @cErrMSG      OUTPUT


           IF @nErrNo <> 0
           BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
           END
         END
	   END

      COMMIT TRAN rdtfnc_UCCInboundReceive -- Only commit change made here
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

      -- Get UCC scanned
      IF @cUCCReceivedDetail <> '1'
      BEGIN
         SELECT @cScanUCC = COUNT( DISTINCT IsNull( RTRIM(PODetail.UserDefine01), '')) -- (Vicky01)
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN dbo.PODetail PODetail WITH (NOLOCK) ON (RD.POKey = PODetail.POKey AND RD.POLineNumber = PODetail.POLineNumber)
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
         WHERE CR.Mobile = @nMobile
         AND   RD.BeforeReceivedQTY > 0 -- Received
      END
      ELSE
      BEGIN
         SELECT @cScanUCC = COUNT( DISTINCT IsNull( RTRIM(RD.UserDefine01), '')) -- (Vicky01)
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
         WHERE CR.Mobile = @nMobile
         AND   RD.BeforeReceivedQTY > 0 -- Received
      END

      -- (Vicky02) - Start
      IF @nFunc = 575
      BEGIN
         SET @cID = ''
         SET @cOutField01 = @cReceiptKey1
         SET @cOutField02 = @cReceiptKey2
         SET @cOutField03 = @cReceiptKey3
         SET @cOutField04 = @cReceiptKey4
         SET @cOutField05 = @cReceiptKey5
         SET @cOutField06 = @cExternReceiptKey
         SET @cOutField07 = @cLOC
         SET @cOutField08 = '' -- ID

         -- Loop back to ID screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
      ELSE  -- (Vicky02) - End
      BEGIN
         -- Refresh current screen var
         SET @cQTY = CAST( @nQTY AS NVARCHAR( 5))
         SET @cOutField04 = @cQTY
         SET @cOutField05 = CASE WHEN ISNULL(@cBypassASNBlankCheck, '') <> '1' THEN @cScanUCC + '/' + @cTotalUCC ELSE '' END
      END

      -- (ChewKP02)

      SET @cExtInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfo', @cStorerKey)

      -- Extended info
      IF @cExtInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtInfoSP AND type = 'P')
         BEGIN
            SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cExtInfoSP) +
                                    '   @nMobile               ' +
                                    ' , @nFunc                 ' +
                                    ' , @nStep                 ' +
                                    ' , @cStorerKey            ' +
                                    ' , @cReceiptKey           ' +
                                    ' , @cLoc                  ' +
                                    ' , @cID                   ' +
                                    ' , @cUCC                  ' +
                                    ' , @nErrNo       OUTPUT   ' +
                                    ' , @cErrMSG      OUTPUT   ' +
                                    ' , @cOutField01  OUTPUT   ' +
                                    ' , @cOutField02  OUTPUT   ' +
                                    ' , @cOutField03  OUTPUT   ' +
                                    ' , @cOutField04  OUTPUT   ' +
                                    ' , @cOutField05  OUTPUT   ' +
                                    ' , @cOutField06  OUTPUT   ' +
                                    ' , @cOutField07  OUTPUT   ' +
                                    ' , @cOutField08  OUTPUT   ' +
                                    ' , @cOutField09  OUTPUT   ' +
                                    ' , @cOutField10  OUTPUT   '

             SET @cExecArguments =
                      N'@nMobile     int,                    ' +
                       '@nFunc       int,                    ' +
                       '@nStep       int,                    ' +
                       '@cStorerKey  nvarchar(15),           ' +
                       '@cReceiptKey nvarchar(20),           ' +
                       '@cLoc        nvarchar(20),           ' +
                       '@cID         nvarchar(18),           ' +
                       '@cUCC        nvarchar(20),           ' +
                       '@nErrNo      int  OUTPUT,            ' +
                       '@cErrMsg     nvarchar(1024) OUTPUT,  ' +
                       '@cOutField01 nvarchar(60) OUTPUT ,   ' +
                       '@cOutField02 nvarchar(60) OUTPUT,    ' +
                       '@cOutField03 nvarchar(60) OUTPUT,    ' +
                       '@cOutField04 nvarchar(60) OUTPUT,    ' +
                       '@cOutField05 nvarchar(60) OUTPUT,    ' +
                       '@cOutField06 nvarchar(60) OUTPUT,    ' +
                       '@cOutField07 nvarchar(60) OUTPUT,    ' +
                       '@cOutField08 nvarchar(60) OUTPUT,    ' +
                       '@cOutField09 nvarchar(60) OUTPUT,    ' +
                       '@cOutField10 nvarchar(60) OUTPUT     '

            EXEC sp_executesql @cExecStatements, @cExecArguments,
                                  @nMobile
                                , @nFunc
                                , @nStep
                                , @cStorerKey
                                , @cReceiptKey
                                , @cLoc
                                , @cID
                                , @cUCC
                                , @nErrNo       OUTPUT
                                , @cErrMSG      OUTPUT
                                , @cOutField01  OUTPUT
                                , @cOutField02  OUTPUT
                                , @cOutField03  OUTPUT
                                , @cOutField04  OUTPUT
                                , @cOutField05  OUTPUT
                                , @cOutField06  OUTPUT
                                , @cOutField07  OUTPUT
                                , @cOutField08  OUTPUT
                                , @cOutField09  OUTPUT
                                , @cOutField10  OUTPUT
         END
      END
      ELSE
      BEGIN

         SET @cOutField06 = ''
         SET @cOutField07 = ''
      END

     -- (james08)
      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLoc, @cID, @cUCC, @tExtInfoVar, @cExtendedInfo OUTPUT '
            SET @cSQLParam =
               ' @nMobile           INT,           ' +
               ' @nFunc             INT,           ' +
               ' @cLangCode         NVARCHAR( 3),  ' +
               ' @nStep             INT,           ' +
               ' @nInputKey         INT,           ' +
               ' @cFacility         NVARCHAR( 5),  ' +
               ' @cStorerKey        NVARCHAR( 15), ' +
               ' @cLoc              NVARCHAR( 10), ' +
               ' @cID               NVARCHAR( 18), ' +
               ' @cUCC              NVARCHAR( 20), ' +
               ' @tExtInfoVar       VariableTable READONLY, ' +
               ' @cExtendedInfo     NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLoc, @cID, @cUCC, @tExtInfoVar, @cExtendedInfo OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            SET @cOutField15 = @cExtendedInfo
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cID = ''
      SET @cOutField01 = @cReceiptKey1
      SET @cOutField02 = @cReceiptKey2
      SET @cOutField03 = @cReceiptKey3
      SET @cOutField04 = @cReceiptKey4
      SET @cOutField05 = @cReceiptKey5
      SET @cOutField06 = @cExternReceiptKey
      SET @cOutField07 = @cLOC
      SET @cOutField08 = '' -- ID

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   RollBackTran:
   BEGIN
      ROLLBACK TRAN rdtfnc_UCCInboundReceive -- Only rollback change made here
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
   END

   Step_4_Fail:
   BEGIN
      -- Reset this screen var
      SET @cUCC = ''
      SET @cOutField03 = '' -- UCC
   END
END
GOTO Quit


/********************************************************************************
Step 5. Scn = 683. NOT ALL UCC RECEIVED, Exit?
   Total  (field01)
   Scan   (field02)
   Remain (field03)
   Option (field04)
********************************************************************************/
Step_5:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField04

      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 62239
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Option needed
         GOTO Step_5_Fail
      END

      -- Validate option
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 62240
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Option
         GOTO Step_5_Fail
      END

      IF @cOption = '1' -- Yes
      BEGIN
         -- Clear log
         IF EXISTS( SELECT 1 FROM rdt.rdtConReceiveLog WITH (NOLOCK) WHERE Mobile = @nMobile)
         BEGIN
            SET @curCR = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT RowRef FROM rdt.rdtConReceiveLog WITH (NOLOCK) WHERE Mobile = @nMobile
            OPEN @curCR
            FETCH NEXT FROM @curCR INTO @nRowRef
            WHILE @@FETCH_STATUS = 0
            BEGIN
               DELETE rdt.rdtConReceiveLog WHERE RowRef = @nRowRef
               FETCH NEXT FROM @curCR INTO @nRowRef
            END
         END

         -- Prepare ASN screen var
         SET @cReceiptKey1 = ''
         SET @cReceiptKey2 = ''
         SET @cReceiptKey3 = ''
         SET @cReceiptKey4 = ''
         SET @cReceiptKey5 = ''
         SET @cExternReceiptKey = ''
         SET @cRefNo = ''
         SET @cOutField01 = @cReceiptKey1
         SET @cOutField02 = @cReceiptKey2
         SET @cOutField03 = @cReceiptKey3
         SET @cOutField04 = @cReceiptKey4
         SET @cOutField05 = @cReceiptKey5
         SET @cOutField06 = @cExternReceiptKey
         SET @cOutField07 = @cRefNo

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- ReceiptKey1

         -- Go to ASN screen
         SET @nScn = @nScn - 4
         SET @nStep = @nStep - 4

         GOTO Quit
      END
   END

   -- Prepare LOC screen var
   SET @cLOC = ''
   SET @cOutField01 = @cReceiptKey1
   SET @cOutField02 = @cReceiptKey2
   SET @cOutField03 = @cReceiptKey3
   SET @cOutField04 = @cReceiptKey4
   SET @cOutField05 = @cReceiptKey5
   SET @cOutField06 = @cExternReceiptKey
   SET @cOutField07 = '' -- LOC
   SET @cOutField08 = '' -- ID

   -- Go to LOC screen
   SET @nScn = @nScn - 3
   SET @nStep = @nStep - 3

   GOTO Quit

   Step_5_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOption = ''
      SET @cOutField04 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Step 6. screen = 695
   CartonType (Field01, input)
********************************************************************************/
Step_6:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cCartonTypeBarcode  NVARCHAR(30)

      -- Screen mapping
      SET @cCartonType = LEFT( @cInField01, 10)
      SET @cCartonTypeBarcode = @cInField01

      -- Check blank
      IF @cCartonType = ''
      BEGIN
         SET @nErrNo = 62248
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedCartonType
         GOTO Quit
      END

      -- Check carton type
      IF NOT EXISTS( SELECT TOP 1 1
         FROM Cartonization C WITH (NOLOCK)
            JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
         WHERE S.StorerKey = @cStorerKey
            AND C.CartonType = @cCartonType)
      BEGIN
         -- Get carton type base on barcode
         SELECT @cCartonType = CartonType
         FROM Cartonization C WITH (NOLOCK)
            JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
         WHERE S.StorerKey = @cStorerKey
            AND C.Barcode = @cCartonTypeBarcode
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 62249
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CartonType
            GOTO Quit
         END
      END

      -- Get UCC scanned
      IF @cUCCReceivedDetail <> '1'
      BEGIN
         SELECT @cScanUCC = COUNT( DISTINCT IsNull( RTRIM(PODetail.UserDefine01), '')) -- (Vicky01)
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN dbo.PODetail PODetail WITH (NOLOCK) ON (RD.POKey = PODetail.POKey AND RD.POLineNumber = PODetail.POLineNumber)
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
         WHERE CR.Mobile = @nMobile
            AND BeforeReceivedQty > 0 -- Received
      END
      ELSE
      BEGIN
         SELECT @cScanUCC = COUNT( DISTINCT IsNull( RTRIM(RD.UserDefine01), ''))
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
         WHERE CR.Mobile = @nMobile
            AND BeforeReceivedQty > 0 -- Received
      END

      -- Prepare next screen var
      SET @cUCC = ''
      SET @cOutField01 = @cLOC
      SET @cOutField02 = @cID
      SET @cOutField03 = '' --UCC
      SET @cOutField04 = '' --QTY
      SET @cOutField05 = CASE WHEN ISNULL(@cBypassASNBlankCheck, '') <> '1' THEN @cScanUCC + '/' + @cTotalUCC ELSE '' END  -- (james02)
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField15 = '' -- ExtInfo

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cExtendedInfo = ''
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLoc, @cID, @cUCC, @tExtInfoVar, @cExtendedInfo OUTPUT '
            SET @cSQLParam =
               ' @nMobile           INT,           ' +
               ' @nFunc             INT,           ' +
               ' @cLangCode         NVARCHAR( 3),  ' +
               ' @nStep             INT,           ' +
               ' @nInputKey         INT,           ' +
               ' @cFacility         NVARCHAR( 5),  ' +
               ' @cStorerKey        NVARCHAR( 15), ' +
               ' @cLoc              NVARCHAR( 10), ' +
               ' @cID               NVARCHAR( 18), ' +
               ' @cUCC              NVARCHAR( 20), ' +
               ' @tExtInfoVar       VariableTable READONLY, ' +
               ' @cExtendedInfo     NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cLoc, @cID, @cUCC, @tExtInfoVar, @cExtendedInfo OUTPUT

            IF @nErrNo <> 0
               GOTO Quit

            SET @cOutField15 = @cExtendedInfo
         END
      END

      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cID = ''
      SET @cOutField01 = @cReceiptKey1
      SET @cOutField02 = @cReceiptKey2
      SET @cOutField03 = @cReceiptKey3
      SET @cOutField04 = @cReceiptKey4
      SET @cOutField05 = @cReceiptKey5
      SET @cOutField06 = @cExternReceiptKey
      SET @cOutField07 = @cLOC
      SET @cOutField08 = '' -- ID

      -- Go to prev screen
      SET @nScn = @nScn - 3
      SET @nStep = @nStep - 3
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      -- UserName  = @cUserName,-- (Vicky06)
      Printer   = @cPrinter, -- (ChewKP03)

      V_LOC     = @cLOC,
      V_ID      = @cID,
      V_UCC     = @cUCC,
      V_QTY     = @cQTY,

      V_String1  = @cReceiptKey1,
      V_String2  = @cReceiptKey2,
      V_String3  = @cReceiptKey3,
      V_String4  = @cReceiptKey4,
      V_String5  = @cReceiptKey5,
      V_String6  = @cExternReceiptKey,
      V_String7  = @cTotalUCC,
      V_String8  = @cUCCReceivedDetail, -- (ChewKP01)
      V_String9  = @cUCCInboundReceiveIDOptional,
      V_String10 = @cBypassASNBlankCheck,
      V_String11 = @cDefaultReceiptDetailLoc, -- (ChewKP01)
      V_String12 = @cRefNo,   -- (james04)
      V_String13 = @cExtendedValidateSP, -- (ChewKP04)
      V_String14 = @cExtendedUpdateSP, -- (ChewKP05)
      V_String15 = @cFinalizeRD,
      V_String16 = @cDecodeSP,
      V_String17 = @cLOCLookupSP,
      V_String18 = @cExtendedInfoSP,
      V_String19 = @cCartonType,
      V_String20 = @cTrackCartonType,
      V_String21 = @cTrackCartonTypeSP,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15

   WHERE Mobile = @nMobile
END

GO