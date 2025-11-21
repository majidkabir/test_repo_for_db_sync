SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: rdtfnc_GeneralInquiry                                  */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: Print configured label / report                                */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date         Rev  Author   Purposes                                     */
/* 2016-09-15   1.0  ChewKP   WMS-338 Created                              */
/* 2017-03-09   1.1  ChewKP   WMS-1280 When No Next Page is set back to    */
/*                            screen 2 (ChewKP01)                          */
/* 2017-04-19   1.2  ChewKP   WMS-1280 Retain scan value (ChewKP02) 			*/ 
/* 2018-04-09   1.3  ChewKP   WMS-4388 Bug Fixes, Add Retain               */
/*                            by Field (ChewKP03)                          */
/* 2018-10-09   1.4  TungGH   Performance                                  */
/* 2018-12-27   1.5  ChewKP   WMS-5802 Add FunctionKey Support (ChewKP04)  */
/* 2019-06-28   1.6  James    WMS9394-Add ExtendedUpdateSP (james01)       */
/* 2021-10-11   1.7  James    WMS-17819 Allow scan field at step 3(james02)*/
/***************************************************************************/

CREATE PROC [RDT].[rdtfnc_GeneralInquiry](
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
   @nCnt           INT, 
   @cReport        NVARCHAR( 20),
   @cParam1        NVARCHAR( 20),
   @cParam2        NVARCHAR( 20),
   @cParam3        NVARCHAR( 20),
   @cParam4        NVARCHAR( 20),
   @cParam5        NVARCHAR( 20),
   @curGeneralInquiry CURSOR

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
   @cPrinter       NVARCHAR( 10),
   @cPrinter_Paper NVARCHAR( 10), 

   @cOption        NVARCHAR( 1),
   @cSP            NVARCHAR( 20),
   @nNextPage      INT,
   @cRetain        NVARCHAR(5),
   @cFunctionKey   NVARCHAR(3), -- (ChewKP04) 
   @nFunctionKey   INT,         -- (ChewKP04) 
   @cExtendedFuncKeySP  NVARCHAR( 20), -- (ChewKP04)
   @cExtendedUpdateSP   NVARCHAR( 20),
   @nFromScn      INT,
   @nFromStep     INT,

   @tExtUpdate     VARIABLETABLE,

   @cParam1Value   NVARCHAR( 20), 
   @cParam2Value   NVARCHAR( 20), 
   @cParam3Value   NVARCHAR( 20), 
   @cParam4Value   NVARCHAR( 20), 
   @cParam5Value   NVARCHAR( 20), 
   
   @c_oFieled01 NVARCHAR(20), @c_oFieled02 NVARCHAR(20),    
   @c_oFieled03 NVARCHAR(20), @c_oFieled04 NVARCHAR(20),    
   @c_oFieled05 NVARCHAR(20), @c_oFieled06 NVARCHAR(20),    
   @c_oFieled07 NVARCHAR(20), @c_oFieled08 NVARCHAR(20),    
   @c_oFieled09 NVARCHAR(20), @c_oFieled10 NVARCHAR(20),    
   @c_oFieled11 NVARCHAR(20), @c_oFieled12 NVARCHAR(20),    
            

   
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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),

   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1)

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
   @cPrinter         = Printer,
   @cPrinter_Paper   = Printer_Paper, 

   @cOption          = V_String1,
   @cSP              = V_String2,

   @cParam1Value     = V_String3,
   @cParam2Value     = V_String4,
   @cParam3Value     = V_String5,
   @cParam4Value     = V_String6,
   @cParam5Value     = V_String7,
   @cReport          = V_String8,
   
   

   @c_oFieled01 = V_STRING9 ,  
   @c_oFieled02 = V_STRING10,
   @c_oFieled03 = V_STRING11, 
   @c_oFieled04 = V_STRING12, 
   @c_oFieled05 = V_STRING13, 
   @c_oFieled06 = V_STRING14, 
   @c_oFieled07 = V_STRING15, 
   @c_oFieled08 = V_STRING16, 
   @c_oFieled09 = V_STRING17, 
   @c_oFieled10 = V_STRING18, 
   @c_oFieled11 = V_STRING19, 
   @c_oFieled12 = V_STRING20, 

   @cRetain     = V_STRING21,
   
   @cExtendedFuncKeySP = V_String23,
   @cExtendedUpdateSP  = V_String24,
   
   @nFunctionKey = V_Integer1,
   @nFromScn     = V_FromScn,
   @nFromStep    = V_FromStep,

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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,

   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 727
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0       -- Menu. Func = 727
   IF @nStep = 1  GOTO Step_1       -- Scn = 4710. General Inquiry. Option
   IF @nStep = 2  GOTO Step_2       -- Scn = 4711. Param1..5
   IF @nStep = 3  GOTO Step_3       -- Scn = 4712. MSG 
   IF @nStep = 4  GOTO Step_4       -- Scn = 4713. MSG 
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 727
********************************************************************************/
Step_0:
BEGIN
   -- Get storer config
   SET @cExtendedFuncKeySP = rdt.RDTGetConfig( @nFunc, 'ExtendedFuncKeySP', @cStorerkey)
   IF @cExtendedFuncKeySP = '0'
      SET @cExtendedFuncKeySP = ''

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'  
      SET @cExtendedUpdateSP = ''

   -- Prepare next screen var
   SET @nFunctionKey = 0 
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

   SET @c_oFieled01 = '' 
   SET @c_oFieled02 = '' 
   SET @c_oFieled03 = '' 
   SET @c_oFieled04 = '' 
   SET @c_oFieled05 = '' 
   SET @c_oFieled06 = '' 
   SET @c_oFieled07 = '' 
   SET @c_oFieled08 = '' 
   SET @c_oFieled09 = '' 
   SET @c_oFieled10 = '' 
   SET @c_oFieled11 = '' 
   SET @c_oFieled12 = '' 

   -- Populate label report
   SET @nCnt = 1
   SET @curGeneralInquiry = CURSOR FOR 
      SELECT LEFT( RTRIM(Code) + '-' + RTRIM(Description), 20)
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'RDTINQUIRY'
         AND StorerKey = @cStorerKey
      ORDER BY Code
   OPEN @curGeneralInquiry
   FETCH NEXT FROM @curGeneralInquiry INTO @cReport
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
      FETCH NEXT FROM @curGeneralInquiry INTO @cReport
   END
   CLOSE @curGeneralInquiry
   DEALLOCATE @curGeneralInquiry

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
   SET @nScn = 4710
   SET @nStep = 1
END
GOTO Quit


/************************************************************************************
Scn = 4710. Option
   Inquiry1 (field01)
   Inquiry2 (field02)
   Inquiry3 (field03)
   Inquiry4 (field04)
   Inquiry5 (field05)
   Inquiry6 (field06)
   Inquiry7 (field07)
   Inquiry8 (field08)
   Inquiry9 (field09)
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
         SET @nErrNo = 103951
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req
         GOTO Step_1_Fail
      END

      -- Check option valid
      IF NOT EXISTS (SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE ListName = 'RDTINQUIRY' AND Code = @cOption AND StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 103952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
         GOTO Step_1_Fail
      END

      -- Get info
      SELECT 
         @cReport = LEFT( RTRIM(Description), 20),   
         @cParam1 = UDF01, 
         @cParam2 = UDF02, 
         @cParam3 = UDF03, 
         @cParam4 = UDF04, 
         @cParam5 = UDF05, 
         @cSP 		= Long,
         --@cShort 	= Short -- (ChewKP02) 
         @cFunctionKey = Code2
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'RDTINQUIRY' 
         AND Code = @cOption
         AND StorerKey = @cStorerKey
      
      IF ISNULL(@cFunctionKey,'') NOT IN ( '1' , '0')
         SELECT @nFunctionKey = RDT.rdtGetFuncKey(@cFunctionKey)
      ELSE
         SET @nFunctionKey = 99 
      
      
      -- Check report param setup
      IF @cParam1 = '' AND 
         @cParam2 = '' AND 
         @cParam3 = '' AND 
         @cParam4 = '' AND 
         @cParam5 = ''
      BEGIN
         SET @nErrNo = 103953
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Param NotSetup
         GOTO Step_1_Fail
      END
      
      -- Check SP setup
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSP AND type = 'P')
      BEGIN
         SET @nErrNo = 103954
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SP NotSetup
         GOTO Step_1_Fail
      END

      -- Enable / disable field
      SET @cFieldAttr02 = CASE WHEN @cParam1 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr04 = CASE WHEN @cParam2 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr06 = CASE WHEN @cParam3 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr08 = CASE WHEN @cParam4 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr10 = CASE WHEN @cParam5 = '' THEN 'O' ELSE '' END
      
      -- Clear optional in field
      SET @cInField02 = ''
      SET @cInField04 = ''
      SET @cInField06 = ''
      SET @cInField08 = ''
      SET @cInField10 = ''

      -- Prepare next screen var
      SET @cOutField01 = @cParam1
      SET @cOutField02 = ''
      SET @cOutField03 = @cParam2
      SET @cOutField04 = ''
      SET @cOutField05 = @cParam3
      SET @cOutField06 = ''
      SET @cOutField07 = @cParam4
      SET @cOutField08 = ''
      SET @cOutField09 = @cParam5
      SET @cOutField10 = ''
      SET @cOutField11 = @cReport

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- Set the focus on first enabled, empty field 
      IF ISNULL( @cFieldAttr02, '') = ''
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END

      IF ISNULL( @cFieldAttr04, '') = ''
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO Quit
      END

      IF ISNULL( @cFieldAttr06, '') = ''
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Quit
      END

      IF ISNULL( @cFieldAttr08, '') = ''
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 8
         GOTO Quit
      END

      IF ISNULL( @cFieldAttr10, '') = ''
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 10
         GOTO Quit
      END
                     

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
Scn = 4711. Parameter screen
   Report       (field11)
   Param1 label (field01)
   Param1       (field02, input)
   Param2 label (field03)
   Param2       (field04, input)
   Param3 label (field05)
   Param3       (field06, input)
   Param4 label (field07)
   Param4       (field08, input)
   Param5 label (field09)
   Param5       (field10, input)
***********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cParam1Value = @cInField02
      SET @cParam2Value = @cInField04
      SET @cParam3Value = @cInField06
      SET @cParam4Value = @cInField08
      SET @cParam5Value = @cInField10

      -- Retain value
      SET @cOutField02 = @cInField02
      SET @cOutField04 = @cInField04
      SET @cOutField06 = @cInField06
      SET @cOutField08 = @cInField08
      SET @cOutField10 = @cInField10

      -- Execute Inquiry stored procedure
      IF @cSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSP AND type = 'P')
         BEGIN
            DECLARE @cSQL      NVARCHAR(1000)
            DECLARE @cSQLParam NVARCHAR(1000)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +
               ' @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cOption, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, 
                 @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT, @c_oFieled04 OUTPUT, @c_oFieled05 OUTPUT, @c_oFieled06 OUTPUT, @c_oFieled07 OUTPUT, 
                 @c_oFieled08 OUTPUT, @c_oFieled09 OUTPUT, @c_oFieled10 OUTPUT, @c_oFieled11 OUTPUT, @c_oFieled12 OUTPUT,
                 @nNextPage OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile    INT,           ' +
               '@nFunc      INT,           ' +
               '@nStep      INT,           ' + 
               '@cLangCode  NVARCHAR( 3),  ' +
               '@cStorerKey NVARCHAR( 15), ' + 
               '@cOption    NVARCHAR( 1),  ' +
               '@cParam1    NVARCHAR(20),  ' + 
               '@cParam2    NVARCHAR(20),  ' + 
               '@cParam3    NVARCHAR(20),  ' + 
               '@cParam4    NVARCHAR(20),  ' + 
               '@cParam5    NVARCHAR(20),  ' + 
               '@c_oFieled01  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled02  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled03  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled04  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled05  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled06  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled07  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled08  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled09  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled10  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled11  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled12  NVARCHAR(20) OUTPUT,' +
               '@nNextPage    INT          OUTPUT,' + 
               '@nErrNo     INT OUTPUT,    ' +
               '@cErrMsg    NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cOption, @cParam1Value, @cParam2Value, @cParam3Value, @cParam4Value, @cParam5Value, 
               @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT, @c_oFieled04 OUTPUT, @c_oFieled05 OUTPUT, @c_oFieled06 OUTPUT, @c_oFieled07 OUTPUT, 
               @c_oFieled08 OUTPUT, @c_oFieled09 OUTPUT, @c_oFieled10 OUTPUT, @c_oFieled11 OUTPUT, @c_oFieled12 OUTPUT,
               @nNextPage OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
            BEGIN
               -- (ChewKP02) 
               --SET @cOutField02 = '' 
               --SET @cOutField04 = '' 
               --SET @cOutField06 = '' 
               --SET @cOutField08 = '' 
               --SET @cOutField10 = '' 
               GOTO Quit  
            END
            
            
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

            SET @cOutField01 = @c_oFieled01
            SET @cOutField02 = @c_oFieled02
            SET @cOutField03 = @c_oFieled03
            SET @cOutField04 = @c_oFieled04
            SET @cOutField05 = @c_oFieled05
            SET @cOutField06 = @c_oFieled06
            SET @cOutField07 = @c_oFieled07
            SET @cOutField08 = @c_oFieled08
            SET @cOutField09 = @c_oFieled09
            SET @cOutField10 = @c_oFieled10
            SET @cOutField11 = @cReport
            SET @cOutField12 = @c_oFieled12
            
            -- Get report info
--            SELECT 
--               @cReport = LEFT( RTRIM(Description), 18)
--            FROM dbo.CodeLKUP WITH (NOLOCK) 
--            WHERE ListName = 'RDTINQUIRY' 
--               AND Code = @cOption
--               AND StorerKey = @cStorerKey
            
            -- EventLog
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '8', -- Master setup
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerkey,
               @cID           = @cReport, 
               @cRefNo1       = @cParam1Value, 
               @cRefNo2       = @cParam2Value, 
               @cRefNo3       = @cParam3Value, 
               @cRefNo4       = @cParam4Value, 
               @cRefNo5       = @cParam5Value,
               @nStep         = @nStep

            SET @nFromScn = @nScn
            SET @nFromStep = @nStep
                  
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
         END
      END

      -- Extended validate
      IF @cExtendedUpdateSP <> ''
      BEGIN
            INSERT INTO @tExtUpdate (Variable, Value) VALUES 
            ('@cOption',            @cOption),
            ('@cParam1Value',       @cParam1Value),
            ('@cParam2Value',       @cParam2Value),
            ('@cParam3Value',       @cParam3Value),
            ('@cParam4Value',       @cParam4Value),
            ('@cParam5Value',       @cParam5Value)

         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @tExtUpdate, ' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            ' @nMobile        INT,           ' +
            ' @nFunc          INT,           ' +
            ' @cLangCode      NVARCHAR( 3),  ' +
            ' @nStep          INT,           ' +
            ' @nAfterStep     INT,           ' +
            ' @nInputKey      INT,           ' +
            ' @cFacility      NVARCHAR( 5),  ' +
            ' @cStorerKey     NVARCHAR( 15), ' +
            ' @tExtUpdate     VariableTable READONLY, ' + 
            ' @nErrNo         INT           OUTPUT, ' +
            ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nStep, @nInputKey, @cFacility, @cStorerKey, @tExtUpdate, 
            @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0 
         BEGIN
            -- Remain in current screen if error
            SET @nScn = @nFromScn
            SET @nStep = @nFromStep

            GOTO Quit
         END
      END

   END

   IF @nInputKey = 0 -- ENTER
   BEGIN
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
   
   -- Populate label report
   SET @nCnt = 1
   SET @curGeneralInquiry = CURSOR FOR 
      SELECT LEFT( RTRIM(Code) + '-' + RTRIM(Description), 20)
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'RDTINQUIRY'
         AND StorerKey = @cStorerKey
      ORDER BY Code
   OPEN @curGeneralInquiry
   FETCH NEXT FROM @curGeneralInquiry INTO @cReport
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
      FETCH NEXT FROM @curGeneralInquiry INTO @cReport
   END
   CLOSE @curGeneralInquiry
   DEALLOCATE @curGeneralInquiry
   
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
   GOTO QUIT 
END
GOTO Quit


/***********************************************************************************
Scn = 4712. Parameter screen
   Msg          (field11)
***********************************************************************************/
Step_3:
BEGIN
   -- (ChewKP04) 
   IF @nInputKey = @nFunctionKey 
   BEGIN
      IF @cExtendedFuncKeySP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedFuncKeySP AND type = 'P')
         BEGIN
            --DECLARE @cSQL      NVARCHAR(1000)
            --DECLARE @cSQLParam NVARCHAR(1000)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedFuncKeySP) +
               ' @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cOption, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, 
                 @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT, @c_oFieled04 OUTPUT, @c_oFieled05 OUTPUT, @c_oFieled06 OUTPUT, @c_oFieled07 OUTPUT, 
                 @c_oFieled08 OUTPUT, @c_oFieled09 OUTPUT, @c_oFieled10 OUTPUT, @c_oFieled11 OUTPUT, @c_oFieled12 OUTPUT,
                 @nNextPage OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile    INT,           ' +
               '@nFunc      INT,           ' +
               '@nStep      INT,           ' + 
               '@cLangCode  NVARCHAR( 3),  ' +
               '@cStorerKey NVARCHAR( 15), ' + 
               '@cOption    NVARCHAR( 1),  ' +
               '@cParam1    NVARCHAR(20),  ' + 
               '@cParam2    NVARCHAR(20),  ' + 
               '@cParam3    NVARCHAR(20),  ' + 
               '@cParam4    NVARCHAR(20),  ' + 
               '@cParam5    NVARCHAR(20),  ' + 
               '@c_oFieled01  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled02  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled03  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled04  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled05  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled06  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled07  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled08  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled09  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled10  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled11  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled12  NVARCHAR(20) OUTPUT,' +
               '@nNextPage    INT          OUTPUT,' + 
               '@nErrNo     INT OUTPUT,    ' +
               '@cErrMsg    NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cOption, @cParam1Value, @cParam2Value, @cParam3Value, @cParam4Value, @cParam5Value, 
               @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT, @c_oFieled04 OUTPUT, @c_oFieled05 OUTPUT, @c_oFieled06 OUTPUT, @c_oFieled07 OUTPUT, 
               @c_oFieled08 OUTPUT, @c_oFieled09 OUTPUT, @c_oFieled10 OUTPUT, @c_oFieled11 OUTPUT, @c_oFieled12 OUTPUT,
               @nNextPage OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Quit
    
            
            SET @cOutField01 = @c_oFieled01
            SET @cOutField02 = @c_oFieled02
            SET @cOutField03 = @c_oFieled03
            SET @cOutField04 = @c_oFieled04
            SET @cOutField05 = @c_oFieled05
            SET @cOutField06 = @c_oFieled06
            SET @cOutField07 = @c_oFieled07
            SET @cOutField08 = @c_oFieled08
            SET @cOutField09 = @c_oFieled09
            SET @cOutField10 = @c_oFieled10
            SET @cOutField11 = @cReport
            SET @cOutField12 = @c_oFieled12
            
            -- Get report info
--            SELECT 
--               @cReport = LEFT( RTRIM(Description), 18)
--            FROM dbo.CodeLKUP WITH (NOLOCK) 
--            WHERE ListName = 'RDTINQUIRY' 
--               AND Code = @cOption
--               AND StorerKey = @cStorerKey
            
            -- EventLog
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '8', -- Master setup
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerkey,
               @cID           = @cReport, 
               @cRefNo1       = @cParam1Value, 
               @cRefNo2       = @cParam2Value, 
               @cRefNo3       = @cParam3Value, 
               @cRefNo4       = @cParam4Value, 
               @cRefNo5       = @cParam5Value,
               @nStep         = @nStep
         END
      END
   END
   
   IF @nInputKey = 1 
   BEGIN
      -- Execute Inquiry stored procedure
      IF @cSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSP AND type = 'P')
         BEGIN
            --DECLARE @cSQL      NVARCHAR(1000)
            --DECLARE @cSQLParam NVARCHAR(1000)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +
               ' @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cOption, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, 
                 @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT, @c_oFieled04 OUTPUT, @c_oFieled05 OUTPUT, @c_oFieled06 OUTPUT, @c_oFieled07 OUTPUT, 
                 @c_oFieled08 OUTPUT, @c_oFieled09 OUTPUT, @c_oFieled10 OUTPUT, @c_oFieled11 OUTPUT, @c_oFieled12 OUTPUT,
                 @nNextPage OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile    INT,           ' +
               '@nFunc      INT,           ' +
               '@nStep      INT,           ' + 
               '@cLangCode  NVARCHAR( 3),  ' +
               '@cStorerKey NVARCHAR( 15), ' + 
               '@cOption    NVARCHAR( 1),  ' +
               '@cParam1    NVARCHAR(20),  ' + 
               '@cParam2    NVARCHAR(20),  ' + 
               '@cParam3    NVARCHAR(20),  ' + 
               '@cParam4    NVARCHAR(20),  ' + 
               '@cParam5    NVARCHAR(20),  ' + 
               '@c_oFieled01  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled02  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled03  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled04  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled05  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled06  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled07  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled08  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled09  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled10  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled11  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled12  NVARCHAR(20) OUTPUT,' +
               '@nNextPage    INT          OUTPUT,' + 
               '@nErrNo     INT OUTPUT,    ' +
               '@cErrMsg    NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cOption, @cParam1Value, @cParam2Value, @cParam3Value, @cParam4Value, @cParam5Value, 
               @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT, @c_oFieled04 OUTPUT, @c_oFieled05 OUTPUT, @c_oFieled06 OUTPUT, @c_oFieled07 OUTPUT, 
               @c_oFieled08 OUTPUT, @c_oFieled09 OUTPUT, @c_oFieled10 OUTPUT, @c_oFieled11 OUTPUT, @c_oFieled12 OUTPUT,
               @nNextPage OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Quit
    
            
            SET @cOutField01 = @c_oFieled01
            SET @cOutField02 = @c_oFieled02
            SET @cOutField03 = @c_oFieled03
            SET @cOutField04 = @c_oFieled04
            SET @cOutField05 = @c_oFieled05
            SET @cOutField06 = @c_oFieled06
            SET @cOutField07 = @c_oFieled07
            SET @cOutField08 = @c_oFieled08
            SET @cOutField09 = @c_oFieled09
            SET @cOutField10 = @c_oFieled10
            SET @cOutField11 = @cReport
            SET @cOutField12 = @c_oFieled12
            
            -- Get report info
--            SELECT 
--               @cReport = LEFT( RTRIM(Description), 18)
--            FROM dbo.CodeLKUP WITH (NOLOCK) 
--            WHERE ListName = 'RDTINQUIRY' 
--               AND Code = @cOption
--               AND StorerKey = @cStorerKey
            
            -- EventLog
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '8', -- Master setup
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerkey,
               @cID           = @cReport, 
               @cRefNo1       = @cParam1Value, 
               @cRefNo2       = @cParam2Value, 
               @cRefNo3       = @cParam3Value, 
               @cRefNo4       = @cParam4Value, 
               @cRefNo5       = @cParam5Value,
               @nStep         = @nStep
         END
      END
      
      IF @nNextPage = 1 
      BEGIN
          -- Go to prev screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1 
         
         
      END
      ELSE
      BEGIN
         -- (james02)
         -- Stay in current screen
         IF @nNextPage = -1
            GOTO Quit
         ELSE
         BEGIN
            EXEC rdt.rdtSetFocusField @nMobile, 2  -- (ChewKP02) 
            GOTO ESCScreen
         END
      END
     

   END
   
   IF @nInputKey = 0 
   BEGIN
      ESCScreen: 
      
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

      -- Get info
      SELECT 
         @cReport = LEFT( RTRIM(Description), 20),   
         @cParam1 = UDF01, 
         @cParam2 = UDF02, 
         @cParam3 = UDF03, 
         @cParam4 = UDF04, 
         @cParam5 = UDF05, 
         @cSP = Long,
         @cRetain = Short 
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'RDTINQUIRY' 
         AND Code = @cOption
         AND StorerKey = @cStorerKey
      
      -- Check report param setup
      IF @cParam1 = '' AND 
         @cParam2 = '' AND 
         @cParam3 = '' AND 
         @cParam4 = '' AND 
         @cParam5 = ''
      BEGIN
         SET @nErrNo = 103955
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Param NotSetup
         GOTO Step_1_Fail
      END
      
      -- Check SP setup
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSP AND type = 'P')
      BEGIN
         SET @nErrNo = 103956
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SP NotSetup
         GOTO Step_1_Fail
      END

      -- Enable / disable field
      SET @cFieldAttr02 = CASE WHEN @cParam1 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr04 = CASE WHEN @cParam2 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr06 = CASE WHEN @cParam3 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr08 = CASE WHEN @cParam4 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr10 = CASE WHEN @cParam5 = '' THEN 'O' ELSE '' END
      
      -- Clear optional in field
      SET @cInField02 = ''
      SET @cInField04 = ''
      SET @cInField06 = ''
      SET @cInField08 = ''
      SET @cInField10 = ''

      -- Prepare next screen var
      SET @cOutField01 = @cParam1
      SET @cOutField02 = CASE WHEN CHARINDEX( '1' , @cRetain) > 0 THEN @cParam1Value ELSE '' END
      SET @cOutField03 = @cParam2
      SET @cOutField04 = CASE WHEN CHARINDEX( '2' , @cRetain) > 0 THEN @cParam2Value ELSE '' END
      SET @cOutField05 = @cParam3
      SET @cOutField06 = CASE WHEN CHARINDEX( '3' , @cRetain) > 0 THEN @cParam3Value ELSE '' END
      SET @cOutField07 = @cParam4
      SET @cOutField08 = CASE WHEN CHARINDEX( '4' , @cRetain) > 0 THEN @cParam4Value ELSE '' END
      SET @cOutField09 = @cParam5
      SET @cOutField10 = CASE WHEN CHARINDEX( '5' , @cRetain) > 0 THEN @cParam5Value ELSE '' END
      SET @cOutField11 = @cReport

      -- Set the focus on first enabled, empty field 
      IF ISNULL( @cFieldAttr02, '') = '' AND CHARINDEX( '1' , @cRetain) = 0
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO SETSCREEN 
      END

      IF ISNULL( @cFieldAttr04, '') = '' AND CHARINDEX( '2' , @cRetain) = 0
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO SETSCREEN 
      END

      IF ISNULL( @cFieldAttr06, '') = '' AND CHARINDEX( '3' , @cRetain) = 0
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO SETSCREEN 
      END

      IF ISNULL( @cFieldAttr08, '') = '' AND CHARINDEX( '4' , @cRetain) = 0
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 8
         GOTO SETSCREEN 
      END

      IF ISNULL( @cFieldAttr10, '') = '' AND CHARINDEX( '5' , @cRetain) = 0
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 10
         GOTO SETSCREEN 
      END
      
      -- Go to prev screen
      SETSCREEN:
      SET @nScn = @nScn - 1 
      SET @nStep = @nStep - 1

   END
   
   GOTO QUIT 
   
END

/***********************************************************************************
Scn = 4713. Parameter screen
   Msg          (field11)
***********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 
   BEGIN
      
      -- Execute Inquiry stored procedure
      IF @cSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSP AND type = 'P')
         BEGIN
            --DECLARE @cSQL      NVARCHAR(1000)
            --DECLARE @cSQLParam NVARCHAR(1000)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +
               ' @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cOption, @cParam1, @cParam2, @cParam3, @cParam4, @cParam5, 
                 @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT, @c_oFieled04 OUTPUT, @c_oFieled05 OUTPUT, @c_oFieled06 OUTPUT, @c_oFieled07 OUTPUT, 
                 @c_oFieled08 OUTPUT, @c_oFieled09 OUTPUT, @c_oFieled10 OUTPUT, @c_oFieled11 OUTPUT, @c_oFieled12 OUTPUT,
                 @nNextPage OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile    INT,           ' +
               '@nFunc      INT,           ' +
               '@nStep      INT,           ' + 
               '@cLangCode  NVARCHAR( 3),  ' +
               '@cStorerKey NVARCHAR( 15), ' + 
               '@cOption    NVARCHAR( 1),  ' +
               '@cParam1    NVARCHAR(20),  ' + 
               '@cParam2    NVARCHAR(20),  ' + 
               '@cParam3    NVARCHAR(20),  ' + 
               '@cParam4    NVARCHAR(20),  ' + 
               '@cParam5    NVARCHAR(20),  ' + 
               '@c_oFieled01  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled02  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled03  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled04  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled05  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled06  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled07  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled08  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled09  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled10  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled11  NVARCHAR(20) OUTPUT,' +
               '@c_oFieled12  NVARCHAR(20) OUTPUT,' +
               '@nNextPage    INT          OUTPUT,' + 
               '@nErrNo     INT OUTPUT,    ' +
               '@cErrMsg    NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @cLangCode, @cStorerKey, @cOption, @cParam1Value, @cParam2Value, @cParam3Value, @cParam4Value, @cParam5Value, 
               @c_oFieled01 OUTPUT, @c_oFieled02 OUTPUT, @c_oFieled03 OUTPUT, @c_oFieled04 OUTPUT, @c_oFieled05 OUTPUT, @c_oFieled06 OUTPUT, @c_oFieled07 OUTPUT, 
               @c_oFieled08 OUTPUT, @c_oFieled09 OUTPUT, @c_oFieled10 OUTPUT, @c_oFieled11 OUTPUT, @c_oFieled12 OUTPUT,
               @nNextPage OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0 
               GOTO Quit

    
            
            SET @cOutField01 = @c_oFieled01
            SET @cOutField02 = @c_oFieled02
            SET @cOutField03 = @c_oFieled03
            SET @cOutField04 = @c_oFieled04
            SET @cOutField05 = @c_oFieled05
            SET @cOutField06 = @c_oFieled06
            SET @cOutField07 = @c_oFieled07
            SET @cOutField08 = @c_oFieled08
            SET @cOutField09 = @c_oFieled09
            SET @cOutField10 = @c_oFieled10
            SET @cOutField11 = @cReport
            SET @cOutField12 = @c_oFieled12
            
            -- Get report info
--            SELECT 
--               @cReport = LEFT( RTRIM(Description), 18)
--            FROM dbo.CodeLKUP WITH (NOLOCK) 
--            WHERE ListName = 'RDTINQUIRY' 
--               AND Code = @cOption
--               AND StorerKey = @cStorerKey
            
            -- EventLog
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '8', -- Master setup
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerkey,
               @cID           = @cReport, 
               @cRefNo1       = @cParam1Value, 
               @cRefNo2       = @cParam2Value, 
               @cRefNo3       = @cParam3Value, 
               @cRefNo4       = @cParam4Value, 
               @cRefNo5       = @cParam5Value,
               @nStep         = @nStep
         END
      END
      
      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   
   IF @nInputKey = 0 
   BEGIN
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

      -- Get info
      SELECT 
         @cReport = LEFT( RTRIM(Description), 20),   
         @cParam1 = UDF01, 
         @cParam2 = UDF02, 
         @cParam3 = UDF03, 
         @cParam4 = UDF04, 
         @cParam5 = UDF05, 
         @cSP = Long,
         @cRetain  = Short
      FROM dbo.CodeLKUP WITH (NOLOCK) 
      WHERE ListName = 'RDTINQUIRY' 
         AND Code = @cOption
         AND StorerKey = @cStorerKey
      
      -- Check report param setup
      IF @cParam1 = '' AND 
         @cParam2 = '' AND 
         @cParam3 = '' AND 
         @cParam4 = '' AND 
         @cParam5 = ''
      BEGIN
         SET @nErrNo = 103955
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Param NotSetup
         GOTO Step_1_Fail
      END
      
      -- Check SP setup
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSP AND type = 'P')
      BEGIN
         SET @nErrNo = 103956
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SP NotSetup
         GOTO Step_1_Fail
      END

      -- Enable / disable field
      SET @cFieldAttr02 = CASE WHEN @cParam1 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr04 = CASE WHEN @cParam2 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr06 = CASE WHEN @cParam3 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr08 = CASE WHEN @cParam4 = '' THEN 'O' ELSE '' END
      SET @cFieldAttr10 = CASE WHEN @cParam5 = '' THEN 'O' ELSE '' END
      
      -- Clear optional in field
      SET @cInField02 = ''
      SET @cInField04 = ''
      SET @cInField06 = ''
      SET @cInField08 = ''
      SET @cInField10 = ''

      -- Prepare next screen var
      SET @cOutField01 = @cParam1
      SET @cOutField02 = CASE WHEN CHARINDEX( '1' , @cRetain) > 0 THEN @cParam1Value ELSE '' END
      SET @cOutField03 = @cParam2
      SET @cOutField04 = CASE WHEN CHARINDEX( '2' , @cRetain) > 0 THEN @cParam2Value ELSE '' END
      SET @cOutField05 = @cParam3
      SET @cOutField06 = CASE WHEN CHARINDEX( '3' , @cRetain) > 0 THEN @cParam3Value ELSE '' END
      SET @cOutField07 = @cParam4
      SET @cOutField08 = CASE WHEN CHARINDEX( '4' , @cRetain) > 0 THEN @cParam4Value ELSE '' END
      SET @cOutField09 = @cParam5
      SET @cOutField10 = CASE WHEN CHARINDEX( '5' , @cRetain) > 0 THEN @cParam5Value ELSE '' END
      SET @cOutField11 = @cReport

      -- Set the focus on first enabled, empty field 
      IF ISNULL( @cFieldAttr02, '') = '' AND CHARINDEX( '1' , @cRetain) = 0
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 2
      END

      IF ISNULL( @cFieldAttr04, '') = '' AND CHARINDEX( '2' , @cRetain) = 0
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 4
      END

      IF ISNULL( @cFieldAttr06, '') = '' AND CHARINDEX( '3' , @cRetain) = 0
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 6
      END

      IF ISNULL( @cFieldAttr08, '') = '' AND CHARINDEX( '4' , @cRetain) = 0
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 8
      END

      IF ISNULL( @cFieldAttr10, '') = '' AND CHARINDEX( '5' , @cRetain) = 0
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 10
      END
      
      -- Go to prev screen
      SET @nScn = @nScn - 2
      SET @nStep = @nStep - 2
   END
   
   GOTO QUIT 
END

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey    = @cStorerKey,
      Facility     = @cFacility,
      --UserName     = @cUserName,
      EditDate     = GetDate(),
      Printer      = @cPrinter,
      Printer_Paper= @cPrinter_Paper,
      
	   V_String1    = @cOption,
      V_String2    = @cSP,
      V_String3    = @cParam1Value,
      V_String4    = @cParam2Value,
      V_String5    = @cParam3Value,
      V_String6    = @cParam4Value,
      V_String7    = @cParam5Value,
      V_String8    = @cReport,

      V_STRING9  = @c_oFieled01, 
      V_STRING10 = @c_oFieled02,
      V_STRING11 = @c_oFieled03,
      V_STRING12 = @c_oFieled04,
      V_STRING13 = @c_oFieled05,
      V_STRING14 = @c_oFieled06,
      V_STRING15 = @c_oFieled07,
      V_STRING16 = @c_oFieled08,
      V_STRING17 = @c_oFieled09,
      V_STRING18 = @c_oFieled10,
      V_STRING19 = @c_oFieled11,
      V_STRING20 = @c_oFieled12,
      
      V_STRING21 = @cRetain,
      
      V_String23 = @cExtendedFuncKeySP,
      V_String24 = @cExtendedUpdateSP,
      
      V_Integer1 = @nFunctionKey,
      V_FromScn  = @nFromScn,
      V_FromStep = @nFromStep,
         
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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,

      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15 

   WHERE Mobile = @nMobile
END

GO