SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdtfnc_PrintLabelReport                                */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: Print configured label / report                                */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2013-07-02   1.0  Ung      SOS282743 Created                            */
/* 2014-02-28   1.1  James    SOS297732 Add msg screen (james01)           */
/* 2014-03-05   1.2  James    Take out hardcorde sp name & screen (james02)*/
/* 2014-01-29   1.3  Ung      SOS300988 Add EventLog                       */
/* 2014-04-08   1.4  Ung      SOS306082 Retain input param value           */
/* 2014-07-07   1.5  James    SOS301441 - Retain input param value if rdt  */
/*                            config turned on (james03)                   */
/* 2015-04-01   1.6  ChewKp   SOS#334977 Add Codelkup Config (ChewKP01)    */
/* 2016-02-24   1.7  ChewKP   SOS#364275 - Fixes (ChewKP02)                */
/* 2016-09-30   1.8  Ung      Performance tuning                           */
/* 2017-11-21   1.9  ChewKP   WMS-3418 Extend Input field 60char (ChewKP03)*/
/* 2018-04-04   2.0  Ung      WMS-4456 Add new type of SP                  */
/*                            Clean up source                              */
/* 2018-06-19   2.1  Ung      WMS-5435 Fix message screen not clear fields */
/* 2018-09-28   2.2  TungGH   Performance                                  */
/* 2020-08-07   2.3  YeeKung  WMS-14477 Add Continue screen (yeekung01)    */
/* 2022-12-22   2.4  YeeKung  WMS-21359 Extend option length (yeekung02)   */
/***************************************************************************/

CREATE   PROC [RDT].[rdtfnc_PrintLabelReport](
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @cSQL           NVARCHAR(MAX),
   @cSQLParam      NVARCHAR(MAX),
   @nCnt           INT,
   @cReport        NVARCHAR( 20),
   @curLabelReport CURSOR

-- RDT.RDTMobRec variables
DECLARE
   @nFunc          INT,
   @nScn           INT,
   @nStep          INT,
   @cLangCode      NVARCHAR( 3),
   @nInputKey      INT,
   @nMenu          INT,

   @cStorerKey     NVARCHAR( 15),
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cLabelPrinter  NVARCHAR( 10),
   @cPaperPrinter  NVARCHAR( 10),

   @cOption        NVARCHAR( 2), --(yeekung01)
   @cSP            NVARCHAR( 20),
   @cShort         NVARCHAR( 10),
   @cReportName    NVARCHAR( 20),
   @cSPType        NVARCHAR( 10),

   @cParam1Label   NVARCHAR( 20),
   @cParam2Label   NVARCHAR( 20),
   @cParam3Label   NVARCHAR( 20),
   @cParam4Label   NVARCHAR( 20),
   @cParam5Label   NVARCHAR( 20),

   @cParam1Value   NVARCHAR( 60),
   @cParam2Value   NVARCHAR( 60),
   @cParam3Value   NVARCHAR( 60),
   @cParam4Value   NVARCHAR( 60),
   @cParam5Value   NVARCHAR( 60),

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1)

-- Getting Mobile information
SELECT
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @nMenu            = Menu,
   @cLangCode        = Lang_code,

   @cStorerKey       = StorerKey,
   @cFacility        = Facility,
   @cUserName        = UserName,
   @cLabelPrinter    = Printer,
   @cPaperPrinter    = Printer_Paper,

   @cOption          = V_String1,
   @cSP              = V_String2,
   @cShort           = V_String3,
   @cReportName      = V_String4,
   @cSPType          = V_String5,

   @cParam1Label     = V_String11,
   @cParam2Label     = V_String12,
   @cParam3Label     = V_String13,
   @cParam4Label     = V_String14,
   @cParam5Label     = V_String15,

   @cParam1Value     = V_String41,
   @cParam2Value     = V_String42,
   @cParam3Value     = V_String43,
   @cParam4Value     = V_String44,
   @cParam5Value     = V_String45,

   @nCnt             = V_Integer1, --(yeekung01)

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 593
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0       -- Menu. Func = 593
   IF @nStep = 1  GOTO Step_1       -- Scn = 3580. Label/Report. Option
   IF @nStep = 2  GOTO Step_2       -- Scn = 3581. Param1..5
   IF @nStep = 3  GOTO Step_3       -- Scn = 3582. MSG
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 593
********************************************************************************/
Step_0:
BEGIN
   -- Get storer config

   -- Prepare next screen var
   SET @cOption = ''
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''
   SET @cOutField05 = ''
   SET @cOutField06 = ''
   SET @cOutField07 = ''
   SET @cOutField08 = ''
   SET @cOutField09 = ''
   SET @cOutField10 = ''

   -- Populate label report
   SET @nCnt = 1
   SET @curLabelReport = CURSOR FOR
      SELECT LEFT( RTRIM(Code) + '-' + RTRIM(Description), 20)
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTLBLRPT'
         AND StorerKey = @cStorerKey
         AND Code between @nCnt AND (@nCnt+8)  --(yeekung01)
      ORDER BY CAST(code AS INT)
   OPEN @curLabelReport
   FETCH NEXT FROM @curLabelReport INTO @cReport
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @nCnt = 1 SET @cOutField01 = @cReport
      IF @nCnt = 2 SET @cOutField02 = @cReport
      IF @nCnt = 3 SET @cOutField03 = @cReport
      IF @nCnt = 4 SET @cOutField04 = @cReport
      IF @nCnt = 5 SET @cOutField05 = @cReport
      IF @nCnt = 6 SET @cOutField06 = @cReport
      IF @nCnt = 7 SET @cOutField07 = @cReport
      IF @nCnt = 8 SET @cOutField08 = @cReport
      IF @nCnt = 9 SET @cOutField09 = @cReport

      SET @nCnt = @nCnt + 1
      FETCH NEXT FROM @curLabelReport INTO @cReport
   END
   CLOSE @curLabelReport
   DEALLOCATE @curLabelReport

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType     = '1', -- Sign-in
      @cUserID         = @cUserName,
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey,
      @nStep           = @nStep

   -- Go to next screen
   SET @nScn = 3580
   SET @nStep = 1
END
GOTO Quit


/************************************************************************************
Scn = 3200. Label Option
   LabelReport1 (field01)
   LabelReport2 (field02)
   LabelReport3 (field03)
   LabelReport4 (field04)
   LabelReport5 (field05)
   LabelReport6 (field06)
   LabelReport7 (field07)
   LabelReport8 (field08)
   LabelReport9 (field09)
   Option       (field10, input)
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cOption = @cInField10

      -- Check blank
      IF @cOption = ''
      BEGIN
         IF EXISTS ( SELECT 1                        --(yeekung01)
                     FROM dbo.CodeLKUP WITH (NOLOCK)
                     WHERE ListName = 'RDTLBLRPT'
                        AND StorerKey = @cStorerKey
                        AND CAST(code AS INT)>9)
         BEGIN

            SET @cOutField01 = ''
            SET @cOutField02 = ''
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = ''
            SET @cOutField08 = ''
            SET @cOutField09 = ''

            IF @nCnt>10
            BEGIN
               SET @nCnt = 1
            END
            ELSE
               SET @nCnt = 10


            SET @curLabelReport = CURSOR FOR
               SELECT LEFT( RTRIM(Code) + '-' + RTRIM(Description), 20)
               FROM dbo.CodeLKUP WITH (NOLOCK)
               WHERE ListName = 'RDTLBLRPT'
                  AND StorerKey = @cStorerKey
                  AND Code between @nCnt AND (@nCnt+8)
                  ORDER BY CAST(code AS INT)
            OPEN @curLabelReport
            FETCH NEXT FROM @curLabelReport INTO @cReport
            WHILE @@FETCH_STATUS = 0
            BEGIN
               IF @nCnt IN(1,10) SET @cOutField01 = @cReport
               IF @nCnt IN(2,11) SET @cOutField02 = @cReport
               IF @nCnt IN(3,12) SET @cOutField03 = @cReport
               IF @nCnt IN(4,13) SET @cOutField04 = @cReport
               IF @nCnt IN(5,14) SET @cOutField05 = @cReport
               IF @nCnt IN(6,15) SET @cOutField06 = @cReport
               IF @nCnt IN(7,16) SET @cOutField07 = @cReport
               IF @nCnt IN(8,17) SET @cOutField08 = @cReport
               IF @nCnt IN(9,18) SET @cOutField09 = @cReport

               SET @nCnt = @nCnt + 1
               FETCH NEXT FROM @curLabelReport INTO @cReport
            END
            CLOSE @curLabelReport
            DEALLOCATE @curLabelReport

            GOTO QUIT
         END
         ELSE
         BEGIN
            SET @nErrNo = 81501
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req
            GOTO Step_1_Fail
         END
      END

      -- Check option valid
      IF NOT EXISTS (SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTLBLRPT' AND Code = @cOption AND StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 81502
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_1_Fail
      END

      -- Get report info
      SELECT
         @cReportName = LEFT( RTRIM(Description), 20),
         @cParam1Label = UDF01,
         @cParam2Label = UDF02,
         @cParam3Label = UDF03,
         @cParam4Label = UDF04,
         @cParam5Label = UDF05,
         @cSP = Long,
         @cShort = RTRIM( ISNULL( Short, ''))
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTLBLRPT'
         AND Code = @cOption
         AND StorerKey = @cStorerKey

      -- Check report param setup
      IF @cParam1Label = '' AND
         @cParam2Label = '' AND
         @cParam3Label = '' AND
         @cParam4Label = '' AND
         @cParam5Label = ''
      BEGIN
         SET @nErrNo = 81503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Param NotSetup
         GOTO Step_1_Fail
      END

      -- Check SP setup
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSP AND type = 'P')
      BEGIN
         SET @nErrNo = 81504
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SP NotSetup
         GOTO Step_1_Fail
      END

      -- Enable / disable field
      SET @cFieldAttr02 = CASE WHEN @cParam1Label = '' THEN 'O' ELSE '' END
      SET @cFieldAttr04 = CASE WHEN @cParam2Label = '' THEN 'O' ELSE '' END
      SET @cFieldAttr06 = CASE WHEN @cParam3Label = '' THEN 'O' ELSE '' END
      SET @cFieldAttr08 = CASE WHEN @cParam4Label = '' THEN 'O' ELSE '' END
      SET @cFieldAttr10 = CASE WHEN @cParam5Label = '' THEN 'O' ELSE '' END

      -- Clear optional in field
      SET @cInField02 = ''
      SET @cInField04 = ''
      SET @cInField06 = ''
      SET @cInField08 = ''
      SET @cInField10 = ''

      -- Prepare next screen var
      SET @cOutField01 = @cParam1Label
      SET @cOutField02 = ''
      SET @cOutField03 = @cParam2Label
      SET @cOutField04 = ''
      SET @cOutField05 = @cParam3Label
      SET @cOutField06 = ''
      SET @cOutField07 = @cParam4Label
      SET @cOutField08 = ''
      SET @cOutField09 = @cParam5Label
      SET @cOutField10 = ''
      SET @cOutField11 = @cReportName

	  ----DB for demo - BDI048--1
	  SET @cOutField02 = CASE WHEN @cFacility = 'BD-F1' THEN '0000001055' ELSE '' END
	  SET @cOutField04 = CASE WHEN @cFacility = 'BD-F1' THEN '000IQ00030OS' ELSE '' END
	  SET @cOutField06 = CASE WHEN @cFacility = 'BD-F1' THEN '2' ELSE '' END		  	  	  
	   ----DB for demo - BDI048--1--End

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- Set the focus on first enabled field
      IF @cFieldAttr02 = '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
      IF @cFieldAttr04 = '' EXEC rdt.rdtSetFocusField @nMobile, 4 ELSE
      IF @cFieldAttr06 = '' EXEC rdt.rdtSetFocusField @nMobile, 6 ELSE
      IF @cFieldAttr07 = '' EXEC rdt.rdtSetFocusField @nMobile, 8 ELSE
      IF @cFieldAttr10 = '' EXEC rdt.rdtSetFocusField @nMobile, 10
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Logging
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

      -- Reset all variables
      SET @cOption = ''
      SET @cOutField01 = ''

      -- Enable field
      SET @cFieldAttr01 = ''
      SET @cFieldAttr02 = ''
      SET @cFieldAttr03 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr05 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr07 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr09 = ''
      SET @cFieldAttr10 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cOption = ''
      SET @cOutField10 = ''
   END
END
GOTO Quit


/***********************************************************************************
Scn = 3201. Parameter screen
   Report       (field11)
   Param1 label (field01)
   Param1 value (field02, input)
   Param2 label (field03)
   Param2 value (field04, input)
   Param3 label (field05)
   Param3 value (field06, input)
   Param4 label (field07)
   Param4 value (field08, input)
   Param5 label (field09)
   Param5 value (field10, input)
***********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cParam1Value = CASE WHEN @cFieldAttr02 = 'O' THEN @cOutField02 ELSE @cInField02 END
      SET @cParam2Value = CASE WHEN @cFieldAttr04 = 'O' THEN @cOutField04 ELSE @cInField04 END
      SET @cParam3Value = CASE WHEN @cFieldAttr06 = 'O' THEN @cOutField06 ELSE @cInField06 END
      SET @cParam4Value = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE @cInField08 END
      SET @cParam5Value = CASE WHEN @cFieldAttr10 = 'O' THEN @cOutField10 ELSE @cInField10 END

      -- Retain value
      SET @cOutField02 = @cInField02
      SET @cOutField04 = @cInField04
      SET @cOutField06 = @cInField06
      SET @cOutField08 = @cInField08
      SET @cOutField10 = @cInField10


      IF @cOption <= 9  --(yeekung01)
      BEGIN
         -- Execute label/report stored procedure
         IF @cSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSP AND type = 'P')
            BEGIN
               IF EXISTS( SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID( 'rdt.' + @cSP) AND name = '@cParam1Label')
               BEGIN
                  SET @cSPType = 'NEW'
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, @cOption, ' +
                     ' @cParam1Label OUTPUT, @cParam2Label OUTPUT, @cParam3Label OUTPUT, @cParam4Label OUTPUT, @cParam5Label OUTPUT, ' +
                     ' @cParam1Value OUTPUT, @cParam2Value OUTPUT, @cParam3Value OUTPUT, @cParam4Value OUTPUT, @cParam5Value OUTPUT, ' +
                     ' @cFieldAttr02 OUTPUT, @cFieldAttr04 OUTPUT, @cFieldAttr06 OUTPUT, @cFieldAttr08 OUTPUT, @cFieldAttr10 OUTPUT, ' +
                     ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     ' @nMobile       INT,           ' +
                     ' @nFunc         INT,           ' +
                     ' @cLangCode     NVARCHAR( 3),  ' +
                     ' @nStep         INT,           ' +
                     ' @nInputKey     INT,           ' +
                     ' @cFacility     NVARCHAR( 5),  ' +
                     ' @cStorerKey    NVARCHAR( 15), ' +
                     ' @cLabelPrinter NVARCHAR( 10), ' +
                     ' @cPaperPrinter NVARCHAR( 10), ' +
                     ' @cOption       NVARCHAR( 2),  ' + --(yeekung02)
                     ' @cParam1Label  NVARCHAR( 20) OUTPUT, ' +
                     ' @cParam2Label  NVARCHAR( 20) OUTPUT, ' +
                     ' @cParam3Label  NVARCHAR( 20) OUTPUT, ' +
                     ' @cParam4Label  NVARCHAR( 20) OUTPUT, ' +
                     ' @cParam5Label  NVARCHAR( 20) OUTPUT, ' +
                     ' @cParam1Value  NVARCHAR( 60) OUTPUT, ' +
                     ' @cParam2Value  NVARCHAR( 60) OUTPUT, ' +
                     ' @cParam3Value  NVARCHAR( 60) OUTPUT, ' +
                     ' @cParam4Value  NVARCHAR( 60) OUTPUT, ' +
                     ' @cParam5Value  NVARCHAR( 60) OUTPUT, ' +
                     ' @cFieldAttr02  NVARCHAR( 1)  OUTPUT, ' +
                     ' @cFieldAttr04  NVARCHAR( 1)  OUTPUT, ' +
                     ' @cFieldAttr06  NVARCHAR( 1)  OUTPUT, ' +
                     ' @cFieldAttr08  NVARCHAR( 1)  OUTPUT, ' +
                     ' @cFieldAttr10  NVARCHAR( 1)  OUTPUT, ' +
                     ' @nErrNo        INT           OUTPUT, ' +
                     ' @cErrMsg       NVARCHAR( 20) OUTPUT  '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, @cOption,
                     @cParam1Label OUTPUT, @cParam2Label OUTPUT, @cParam3Label OUTPUT, @cParam4Label OUTPUT, @cParam5Label OUTPUT,
                     @cParam1Value OUTPUT, @cParam2Value OUTPUT, @cParam3Value OUTPUT, @cParam4Value OUTPUT, @cParam5Value OUTPUT,
                     @cFieldAttr02 OUTPUT, @cFieldAttr04 OUTPUT, @cFieldAttr06 OUTPUT, @cFieldAttr08 OUTPUT, @cFieldAttr10 OUTPUT,
                     @nErrNo OUTPUT, @cErrMsg OUTPUT

                  SET @cOutField01 = @cParam1Label
                  SET @cOutField02 = @cParam1Value
                  SET @cOutField03 = @cParam2Label
                  SET @cOutField04 = @cParam2Value
                  SET @cOutField05 = @cParam3Label
                  SET @cOutField06 = @cParam3Value
                  SET @cOutField07 = @cParam4Label
                  SET @cOutField08 = @cParam4Value
                  SET @cOutField09 = @cParam5Label
                  SET @cOutField10 = @cParam5Value
               END
               ELSE
               BEGIN
                  SET @cSPType = 'OLD'
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +
                     ' @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cOption, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     '@nMobile    INT,           ' +
                     '@nFunc      INT,           ' +
                     '@nStep      INT,           ' +
                     '@cLangCode  NVARCHAR( 3),  ' +
                     '@cStorerKey NVARCHAR( 15), ' +
                     '@cOption    NVARCHAR( 1),  ' +
                     '@cParam1    NVARCHAR(60),  ' + --(ChewKP03)
                     '@cParam2    NVARCHAR(60),  ' + --(ChewKP03)
                     '@cParam3    NVARCHAR(60),  ' + --(ChewKP03)
                     '@cParam4    NVARCHAR(60),  ' + --(ChewKP03)
                     '@cParam5    NVARCHAR(60),  ' + --(ChewKP03)
                     '@nErrNo     INT OUTPUT,    ' +
                     '@cErrMsg    NVARCHAR( 20) OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cOption, @cParam1Value, @cParam2Value, @cParam3Value, @cParam4Value, @cParam5Value,
                     @nErrNo OUTPUT, @cErrMsg OUTPUT
               END

               IF @nErrNo <> 0
                  GOTO Quit

               -- EventLog
               EXEC RDT.rdt_STD_EventLog
                  @cActionType   = '8', -- Master setup
                  @cUserID       = @cUserName,
                  @nMobileNo     = @nMobile,
                  @nFunctionID   = @nFunc,
                  @cFacility     = @cFacility,
                  @cStorerKey    = @cStorerkey,
                  @cID           = @cReportName,
                  @cRefNo1       = @cParam1Value,
                  @cRefNo2       = @cParam2Value,
                  @cRefNo3       = @cParam3Value,
                  @cRefNo4       = @cParam4Value,
                  @cRefNo5       = @cParam5Value,
                  @nStep         = @nStep

               IF rdt.RDTGetConfig( @nFunc, 'ShowPrintJobSentMsg', @cStorerKey) = '1'
               BEGIN
                  SET @nScn = @nScn + 1
                  SET @nStep = @nStep + 1

                  GOTO Quit
               END
               ELSE
               BEGIN
                  -- Remain in current screen
                  IF CHARINDEX('R', @cShort ) <> 0 OR @cShort <> ''
                  BEGIN
                     -- Retain param value
                     IF CHARINDEX('1', @cShort ) = 0 SET @cParam1Value = ''
                     IF CHARINDEX('2', @cShort ) = 0 SET @cParam2Value = ''
                     IF CHARINDEX('3', @cShort ) = 0 SET @cParam3Value = ''
                     IF CHARINDEX('4', @cShort ) = 0 SET @cParam4Value = ''
                     IF CHARINDEX('5', @cShort ) = 0 SET @cParam5Value = ''

                     -- Prepare next screen var
                     SET @cOutField01 = @cParam1Label
                     SET @cOutField02 = @cParam1Value
                     SET @cOutField03 = @cParam2Label
                     SET @cOutField04 = @cParam2Value
                     SET @cOutField05 = @cParam3Label
                     SET @cOutField06 = @cParam3Value
                     SET @cOutField07 = @cParam4Label
                     SET @cOutField08 = @cParam4Value
                     SET @cOutField09 = @cParam5Label
                     SET @cOutField10 = @cParam5Value
                     SET @cOutField11 = @cReportName

                     -- Focus next empty field
                     IF @cSPType = 'OLD'
                     BEGIN
                        IF @cFieldAttr02 = '' AND @cOutField02 = '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
                        IF @cFieldAttr04 = '' AND @cOutField04 = '' EXEC rdt.rdtSetFocusField @nMobile, 4 ELSE
                        IF @cFieldAttr06 = '' AND @cOutField06 = '' EXEC rdt.rdtSetFocusField @nMobile, 6 ELSE
                        IF @cFieldAttr08 = '' AND @cOutField08 = '' EXEC rdt.rdtSetFocusField @nMobile, 8 ELSE
                        IF @cFieldAttr10 = '' AND @cOutField10 = '' EXEC rdt.rdtSetFocusField @nMobile, 10
                     END

                     GOTO Quit
                  END
               END
            END
         END
      END
      ELSE
      BEGIN
         -- Execute label/report stored procedure
         IF @cSP <> ''
         BEGIN
            IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSP AND type = 'P')
            BEGIN
               IF EXISTS( SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID( 'rdt.' + @cSP) AND name = '@cParam1Label')
               BEGIN
                  SET @cSPType = 'NEW'
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, @cOption, ' +
                     ' @cParam1Label OUTPUT, @cParam2Label OUTPUT, @cParam3Label OUTPUT, @cParam4Label OUTPUT, @cParam5Label OUTPUT, ' +
                     ' @cParam1Value OUTPUT, @cParam2Value OUTPUT, @cParam3Value OUTPUT, @cParam4Value OUTPUT, @cParam5Value OUTPUT, ' +
                     ' @cFieldAttr02 OUTPUT, @cFieldAttr04 OUTPUT, @cFieldAttr06 OUTPUT, @cFieldAttr08 OUTPUT, @cFieldAttr10 OUTPUT, ' +
                     ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
                  SET @cSQLParam =
                     ' @nMobile       INT,           ' +
                     ' @nFunc         INT,           ' +
                     ' @cLangCode     NVARCHAR( 3),  ' +
                     ' @nStep         INT,           ' +
                     ' @nInputKey     INT,           ' +
                     ' @cFacility     NVARCHAR( 5),  ' +
                     ' @cStorerKey    NVARCHAR( 15), ' +
                     ' @cLabelPrinter NVARCHAR( 10), ' +
                     ' @cPaperPrinter NVARCHAR( 10), ' +
                     ' @cOption       NVARCHAR( 2),  ' + --(yeekung02)
                     ' @cParam1Label  NVARCHAR( 20) OUTPUT, ' +
                     ' @cParam2Label  NVARCHAR( 20) OUTPUT, ' +
                     ' @cParam3Label  NVARCHAR( 20) OUTPUT, ' +
                     ' @cParam4Label  NVARCHAR( 20) OUTPUT, ' +
                     ' @cParam5Label  NVARCHAR( 20) OUTPUT, ' +
                     ' @cParam1Value  NVARCHAR( 60) OUTPUT, ' +
                     ' @cParam2Value  NVARCHAR( 60) OUTPUT, ' +
                     ' @cParam3Value  NVARCHAR( 60) OUTPUT, ' +
                     ' @cParam4Value  NVARCHAR( 60) OUTPUT, ' +
                     ' @cParam5Value  NVARCHAR( 60) OUTPUT, ' +
                     ' @cFieldAttr02  NVARCHAR( 1)  OUTPUT, ' +
                     ' @cFieldAttr04  NVARCHAR( 1)  OUTPUT, ' +
                     ' @cFieldAttr06  NVARCHAR( 1)  OUTPUT, ' +
                     ' @cFieldAttr08  NVARCHAR( 1)  OUTPUT, ' +
                     ' @cFieldAttr10  NVARCHAR( 1)  OUTPUT, ' +
                     ' @nErrNo        INT           OUTPUT, ' +
                     ' @cErrMsg       NVARCHAR( 20) OUTPUT  '

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, @cOption,
                     @cParam1Label OUTPUT, @cParam2Label OUTPUT, @cParam3Label OUTPUT, @cParam4Label OUTPUT, @cParam5Label OUTPUT,
                     @cParam1Value OUTPUT, @cParam2Value OUTPUT, @cParam3Value OUTPUT, @cParam4Value OUTPUT, @cParam5Value OUTPUT,
                     @cFieldAttr02 OUTPUT, @cFieldAttr04 OUTPUT, @cFieldAttr06 OUTPUT, @cFieldAttr08 OUTPUT, @cFieldAttr10 OUTPUT,
                     @nErrNo OUTPUT, @cErrMsg OUTPUT

                  SET @cOutField01 = @cParam1Label
                  SET @cOutField02 = @cParam1Value
                  SET @cOutField03 = @cParam2Label
                  SET @cOutField04 = @cParam2Value
                  SET @cOutField05 = @cParam3Label
                  SET @cOutField06 = @cParam3Value
                  SET @cOutField07 = @cParam4Label
                  SET @cOutField08 = @cParam4Value
                  SET @cOutField09 = @cParam5Label
                  SET @cOutField10 = @cParam5Value
               END
               ELSE
               BEGIN
                  SET @cSPType = 'OLD'
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +
                     ' @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cOption, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, @nErrNo OUTPUT, @cErrMsg OUTPUT'
                  SET @cSQLParam =
                     '@nMobile    INT,           ' +
                     '@nFunc      INT,           ' +
                     '@nStep      INT,           ' +
                     '@cLangCode  NVARCHAR( 3),  ' +
                     '@cStorerKey NVARCHAR( 15), ' +
                     '@cOption    NVARCHAR( 2),  ' +
                     '@cParam1    NVARCHAR(60),  ' + --(ChewKP03)
                     '@cParam2    NVARCHAR(60),  ' + --(ChewKP03)
                     '@cParam3    NVARCHAR(60),  ' + --(ChewKP03)
                     '@cParam4    NVARCHAR(60),  ' + --(ChewKP03)
                     '@cParam5    NVARCHAR(60),  ' + --(ChewKP03)
                     '@nErrNo     INT OUTPUT,    ' +
                     '@cErrMsg    NVARCHAR( 20) OUTPUT'

                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                     @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cOption, @cParam1Value, @cParam2Value, @cParam3Value, @cParam4Value, @cParam5Value,
                     @nErrNo OUTPUT, @cErrMsg OUTPUT
               END

               IF @nErrNo <> 0
                  GOTO Quit

               -- EventLog
               EXEC RDT.rdt_STD_EventLog
                  @cActionType   = '8', -- Master setup
                  @cUserID       = @cUserName,
                  @nMobileNo     = @nMobile,
                  @nFunctionID   = @nFunc,
                  @cFacility     = @cFacility,
                  @cStorerKey    = @cStorerkey,
                  @cID           = @cReportName,
                  @cRefNo1       = @cParam1Value,
                  @cRefNo2       = @cParam2Value,
                  @cRefNo3       = @cParam3Value,
                  @cRefNo4       = @cParam4Value,
                  @cRefNo5       = @cParam5Value,
                  @nStep         = @nStep

               IF rdt.RDTGetConfig( @nFunc, 'ShowPrintJobSentMsg', @cStorerKey) = '1'
               BEGIN
                  SET @nScn = @nScn + 1
                  SET @nStep = @nStep + 1

                  GOTO Quit
               END
               ELSE
               BEGIN
                  -- Remain in current screen
                  IF CHARINDEX('R', @cShort ) <> 0 OR @cShort <> ''
                  BEGIN
                     -- Retain param value
                     IF CHARINDEX('1', @cShort ) = 0 SET @cParam1Value = ''
                     IF CHARINDEX('2', @cShort ) = 0 SET @cParam2Value = ''
                     IF CHARINDEX('3', @cShort ) = 0 SET @cParam3Value = ''
                     IF CHARINDEX('4', @cShort ) = 0 SET @cParam4Value = ''
                     IF CHARINDEX('5', @cShort ) = 0 SET @cParam5Value = ''

                     -- Prepare next screen var
                     SET @cOutField01 = @cParam1Label
                     SET @cOutField02 = @cParam1Value
                     SET @cOutField03 = @cParam2Label
                     SET @cOutField04 = @cParam2Value
                     SET @cOutField05 = @cParam3Label
                     SET @cOutField06 = @cParam3Value
                     SET @cOutField07 = @cParam4Label
                     SET @cOutField08 = @cParam4Value
                     SET @cOutField09 = @cParam5Label
                     SET @cOutField10 = @cParam5Value
                     SET @cOutField11 = @cReportName

                     -- Focus next empty field
                     IF @cSPType = 'OLD'
                     BEGIN
                        IF @cFieldAttr02 = '' AND @cOutField02 = '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
                        IF @cFieldAttr04 = '' AND @cOutField04 = '' EXEC rdt.rdtSetFocusField @nMobile, 4 ELSE
                        IF @cFieldAttr06 = '' AND @cOutField06 = '' EXEC rdt.rdtSetFocusField @nMobile, 6 ELSE
                        IF @cFieldAttr08 = '' AND @cOutField08 = '' EXEC rdt.rdtSetFocusField @nMobile, 8 ELSE
                        IF @cFieldAttr10 = '' AND @cOutField10 = '' EXEC rdt.rdtSetFocusField @nMobile, 10
                     END

                     GOTO Quit
                  END
               END
            END
         END
      END
   END

   -- Prepare prev screen var
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''
   SET @cOutField05 = ''
   SET @cOutField06 = ''
   SET @cOutField07 = ''
   SET @cOutField08 = ''
   SET @cOutField09 = ''

   IF @nCnt>10    --(yeekung01)
   BEGIN
      SET @nCnt = 10
   END
   ELSE
      SET @nCnt = 1

   SET @curLabelReport = CURSOR FOR
   SELECT LEFT( RTRIM(Code) + '-' + RTRIM(Description), 20)
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RDTLBLRPT'
      AND StorerKey = @cStorerKey
      AND Code between @nCnt AND (@nCnt+8)
   ORDER BY CAST(code AS INT)
   OPEN @curLabelReport
   FETCH NEXT FROM @curLabelReport INTO @cReport
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @nCnt IN(1,10) SET @cOutField01 = @cReport
      IF @nCnt IN(2,11) SET @cOutField02 = @cReport
      IF @nCnt IN(3,12) SET @cOutField03 = @cReport
      IF @nCnt IN(4,13) SET @cOutField04 = @cReport
      IF @nCnt IN(5,14) SET @cOutField05 = @cReport
      IF @nCnt IN(6,15) SET @cOutField06 = @cReport
      IF @nCnt IN(7,16) SET @cOutField07 = @cReport
      IF @nCnt IN(8,17) SET @cOutField08 = @cReport
      IF @nCnt IN(9,18) SET @cOutField09 = @cReport

      SET @nCnt = @nCnt + 1
      FETCH NEXT FROM @curLabelReport INTO @cReport
   END
   CLOSE @curLabelReport
   DEALLOCATE @curLabelReport

   -- Enable / disable field
   SET @cFieldAttr02 = ''
   SET @cFieldAttr04 = ''
   SET @cFieldAttr06 = ''
   SET @cFieldAttr08 = ''
   SET @cFieldAttr10 = ''
   
   -- Go to prev screen
   SET @nScn = @nScn - 1
   SET @nStep = @nStep - 1
   
END
GOTO Quit


/***********************************************************************************
Scn = 3582. Parameter screen
   Msg          (field11)
***********************************************************************************/
Step_3:
BEGIN	

 ----DB for demo - BDI048 --2
   IF (@nInputKey = 1 or @nInputKey = 0) and @cFacility = 'BD-F1' -- ENTER:1 , ESC:0
	BEGIN
	   -- Get storer config

	   -- Prepare next screen var
	   SET @cOption = ''
	   SET @cOutField01 = ''
	   SET @cOutField02 = ''
	   SET @cOutField03 = ''
	   SET @cOutField04 = ''
	   SET @cOutField05 = ''
	   SET @cOutField06 = ''
	   SET @cOutField07 = ''
	   SET @cOutField08 = ''
	   SET @cOutField09 = ''
	   SET @cOutField10 = ''

	   -- Populate label report
	   SET @nCnt = 1
	   SET @curLabelReport = CURSOR FOR
		  SELECT LEFT( RTRIM(Code) + '-' + RTRIM(Description), 20)
		  FROM dbo.CodeLKUP WITH (NOLOCK)
		  WHERE ListName = 'RDTLBLRPT'
			 AND StorerKey = @cStorerKey
			 AND Code between @nCnt AND (@nCnt+8)  --(yeekung01)
		  ORDER BY CAST(code AS INT)
	   OPEN @curLabelReport
	   FETCH NEXT FROM @curLabelReport INTO @cReport
	   WHILE @@FETCH_STATUS = 0
	   BEGIN
		  IF @nCnt = 1 SET @cOutField01 = @cReport
		  IF @nCnt = 2 SET @cOutField02 = @cReport
		  IF @nCnt = 3 SET @cOutField03 = @cReport
		  IF @nCnt = 4 SET @cOutField04 = @cReport
		  IF @nCnt = 5 SET @cOutField05 = @cReport
		  IF @nCnt = 6 SET @cOutField06 = @cReport
		  IF @nCnt = 7 SET @cOutField07 = @cReport
		  IF @nCnt = 8 SET @cOutField08 = @cReport
		  IF @nCnt = 9 SET @cOutField09 = @cReport

		  SET @nCnt = @nCnt + 1
		  FETCH NEXT FROM @curLabelReport INTO @cReport
	   END
	   CLOSE @curLabelReport
	   DEALLOCATE @curLabelReport

	   -- Logging
	   EXEC RDT.rdt_STD_EventLog
		  @cActionType     = '1', -- Sign-in
		  @cUserID         = @cUserName,
		  @nMobileNo       = @nMobile,
		  @nFunctionID     = @nFunc,
		  @cFacility       = @cFacility,
		  @cStorerKey      = @cStorerKey,
		  @nStep           = @nStep

	   -- Go to next screen
	   SET @nScn = 3580
	   SET @nStep = 1
	   SET @cFieldAttr10 = ''
	   --EXEC RDT.rdtSetFocusField @nMobile,@cOption 
	   GOTO Quit
	END	
	 ----DB for demo - BDI048 --2--End
	
 IF CHARINDEX('R', @cShort ) <> 0 OR @cShort <> ''
   BEGIN
      -- Retain param value
      IF CHARINDEX('1', @cShort ) = 0 SET @cParam1Value = ''
      IF CHARINDEX('2', @cShort ) = 0 SET @cParam2Value = ''
      IF CHARINDEX('3', @cShort ) = 0 SET @cParam3Value = ''
      IF CHARINDEX('4', @cShort ) = 0 SET @cParam4Value = ''
      IF CHARINDEX('5', @cShort ) = 0 SET @cParam5Value = ''

      -- Prepare next screen var
      SET @cOutField01 = @cParam1Label
      SET @cOutField02 = @cParam1Value
      SET @cOutField03 = @cParam2Label
      SET @cOutField04 = @cParam2Value
      SET @cOutField05 = @cParam3Label
      SET @cOutField06 = @cParam3Value
      SET @cOutField07 = @cParam4Label
      SET @cOutField08 = @cParam4Value
      SET @cOutField09 = @cParam5Label
      SET @cOutField10 = @cParam5Value
      SET @cOutField11 = @cReport

      -- Focus next empty field
      IF @cSPType = 'OLD'
      BEGIN
         IF @cFieldAttr02 = '' AND @cOutField02 = '' EXEC rdt.rdtSetFocusField @nMobile, 2 ELSE
         IF @cFieldAttr04 = '' AND @cOutField04 = '' EXEC rdt.rdtSetFocusField @nMobile, 4 ELSE
         IF @cFieldAttr06 = '' AND @cOutField06 = '' EXEC rdt.rdtSetFocusField @nMobile, 6 ELSE
         IF @cFieldAttr08 = '' AND @cOutField08 = '' EXEC rdt.rdtSetFocusField @nMobile, 8 ELSE
         IF @cFieldAttr10 = '' AND @cOutField10 = '' EXEC rdt.rdtSetFocusField @nMobile, 10
      END

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1	  
   END
   ELSE
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''
      SET @cOutField07 = ''
      SET @cOutField08 = ''
      SET @cOutField09 = ''

      -- Populate label report
      IF @nCnt>10     --(yeekung01)
      BEGIN
         SET @nCnt = 10
      END
      ELSE
         SET @nCnt = 1

      SET @curLabelReport = CURSOR FOR
      SELECT LEFT( RTRIM(Code) + '-' + RTRIM(Description), 20)
      FROM dbo.CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'RDTLBLRPT'
         AND StorerKey = @cStorerKey
         AND Code between @nCnt AND (@nCnt+8)
      ORDER BY CAST(code AS INT)
      OPEN @curLabelReport
      FETCH NEXT FROM @curLabelReport INTO @cReport
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @nCnt IN(1,10) SET @cOutField01 = @cReport
         IF @nCnt IN(2,11) SET @cOutField02 = @cReport
         IF @nCnt IN(3,12) SET @cOutField03 = @cReport
         IF @nCnt IN(4,13) SET @cOutField04 = @cReport
         IF @nCnt IN(5,14) SET @cOutField05 = @cReport
         IF @nCnt IN(6,15) SET @cOutField06 = @cReport
         IF @nCnt IN(7,16) SET @cOutField07 = @cReport
         IF @nCnt IN(8,17) SET @cOutField08 = @cReport
         IF @nCnt IN(9,18) SET @cOutField09 = @cReport

         SET @nCnt = @nCnt + 1
         FETCH NEXT FROM @curLabelReport INTO @cReport
      END
      CLOSE @curLabelReport
      DEALLOCATE @curLabelReport

      -- Enable / disable field
     SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      -- Go to prev screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END   
END


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.rdtMobRec WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      V_String1  = @cOption,
      V_String2  = @cSP,
      V_String3  = @cShort,
      V_String4  = @cReportName,
      V_String5  = @cSPType,

      V_String11 = @cParam1Label,
      V_String12 = @cParam2Label,
      V_String13 = @cParam3Label,
      V_String14 = @cParam4Label,
      V_String15 = @cParam5Label,

      V_String41 = @cParam1Value,
      V_String42 = @cParam2Value,
      V_String43 = @cParam3Value,
      V_String44 = @cParam4Value,
      V_String45 = @cParam5Value,

      V_Integer1 = @nCnt, --(yeekung01)

      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile
END

GO