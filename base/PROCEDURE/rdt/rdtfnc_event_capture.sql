SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
        
/******************************************************************************/        
/* Store procedure: rdtfnc_Event_Capture                                      */        
/* Copyright      : IDS                                                       */        
/*                                                                            */        
/* Purpose: To Track the time and date of Pick done                           */        
/*                                                                            */        
/* Modifications log:                                                         */        
/*                                                                            */        
/* Date         Rev  Author     Purposes                                      */        
/* 2019-05-15   1.0  Ung        WMS-9003 Migrate from FN706                   */        
/* 2019-08-20   1.1  YeeKung    WMS-10195 Add print scn and pallet close scn  */    
/* 2020-09-15   1.2  YeeKung    WMS-14829 Add one more option screen          */     
/*                              (yeekung01)                                   */    
/* 2021-04-15   1.3  YeeKung    WMS-16782 Add extendedinfo                    */     
/*                              (yeekung01)                                   */    
/******************************************************************************/        
CREATE  PROC [RDT].[rdtfnc_Event_Capture] (        
   @nMobile    INT,        
   @nErrNo     INT          OUTPUT,        
   @cErrMsg    NVARCHAR(20) OUTPUT        
)        
AS        
        
SET NOCOUNT ON            
SET QUOTED_IDENTIFIER OFF            
SET ANSI_NULLS OFF            
SET CONCAT_NULL_YIELDS_NULL OFF         
        
-- Misc variables        
DECLARE        
   @cSQL                NVARCHAR( MAX),        
   @cSQLParam           NVARCHAR( MAX),         
   @cOption             NVARCHAR( 1)        
        
-- RDT.RDTMobRec variables        
DECLARE        
   @nFunc               INT,        
   @nScn                INT,        
   @nStep               INT,        
   @cLangCode           NVARCHAR( 3),        
   @nInputKey           INT,        
   @nMenu               INT,       
   @cTotalCaptr         INT,      
        
   @cStorerKey          NVARCHAR( 15),        
   @cFacility           NVARCHAR( 5),        
        
   @cLabel1            NVARCHAR( 20),        
   @cLabel2            NVARCHAR( 20),        
   @cLabel3            NVARCHAR( 20),        
   @cLabel4            NVARCHAR( 20),        
   @cLabel5            NVARCHAR( 20),    
   @cRetainValue       NVARCHAR( 10),        
        
   @cValue1            NVARCHAR( 60),        
   @cValue2            NVARCHAR( 60),        
   @cValue3            NVARCHAR( 60),        
   @cValue4            NVARCHAR( 60),        
   @cValue5            NVARCHAR( 60),        
    
   @cSP                NVARCHAR( MAX),  
   @cExtendedinfo      NVARCHAR( 20),
              
   @cInField01 NVARCHAR( 60),  @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1),         
   @cInField02 NVARCHAR( 60),  @cOutField02 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1),         
   @cInField03 NVARCHAR( 60),  @cOutField03 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1),         
   @cInField04 NVARCHAR( 60),  @cOutField04 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1),         
   @cInField05 NVARCHAR( 60),  @cOutField05 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1),         
   @cInField06 NVARCHAR( 60),  @cOutField06 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1),         
   @cInField07 NVARCHAR( 60),  @cOutField07 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1),         
   @cInField08 NVARCHAR( 60),  @cOutField08 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1),         
   @cInField09 NVARCHAR( 60),  @cOutField09 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1),         
   @cInField10 NVARCHAR( 60),  @cOutField10 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1),         
   @cInField11 NVARCHAR( 60),  @cOutField11 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1),         
   @cInField12 NVARCHAR( 60),  @cOutField12 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1),         
   @cInField13 NVARCHAR( 60),  @cOutField13 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1),         
   @cInField14 NVARCHAR( 60),  @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1),         
   @cInField15 NVARCHAR( 60),  @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1)      
        
-- Getting Mobile information        
SELECT        
   @nFunc      = Func,        
   @nScn       = Scn,        
   @nStep      = Step,        
   @nInputKey  = InputKey,        
   @nMenu      = Menu,        
   @cLangCode  = Lang_code,        
                       
   @cStorerKey = StorerKey,        
   @cFacility  = Facility,        
        
   @cLabel1      = V_String1,        
   @cLabel2      = V_String2,         
   @cLabel3      = V_String3,        
   @cLabel4      = V_String4,         
   @cLabel5      = V_String5,         
   @cRetainValue = V_String6,      
   @cOption      = V_String7,     
        
   @cValue1      = V_String41,        
   @cValue2      = V_String42,        
   @cValue3      = V_String43,           
   @cValue4      = V_String44,        
   @cValue5      = V_String45,        
   @cSP          = V_String46,
   @cExtendedinfo= V_String47,      
         
   @cTotalCaptr  = V_Integer1,       
        
   @cInField01 = I_Field01,  @cOutField01 = O_Field01,  @cFieldAttr01  =FieldAttr01,        
   @cInField02 = I_Field02,  @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,        
   @cInField03 = I_Field03,  @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,        
   @cInField04 = I_Field04,  @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,        
   @cInField05 = I_Field05,  @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,        
   @cInField06 = I_Field06,  @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,        
   @cInField07 = I_Field07,  @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,        
   @cInField08 = I_Field08,  @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,          
   @cInField09 = I_Field09,  @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,        
   @cInField10 = I_Field10,  @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,        
   @cInField11 = I_Field11,  @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,        
   @cInField12 = I_Field12,  @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,        
   @cInField13 = I_Field13,  @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,        
   @cInField14 = I_Field14,  @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,        
   @cInField15 = I_Field15,  @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15        
        
FROM rdt.rdtMobRec (NOLOCK)        
WHERE Mobile = @nMobile        
        
IF @nFunc = 706  -- Event capture        
BEGIN        
   -- Redirect to respective screen        
   IF @nStep = 0  GOTO Step_0  -- Menu. Func = 706        
   IF @nStep = 1  GOTO Step_1  -- Scn = 5450. Option      
   IF @nStep = 2  GOTO Step_2  -- Scn = 5451. Label1..5, Value1..5               
   IF @nStep = 3  GOTO Step_3  -- Scn = 5452. Close Pallet              
   IF @nStep = 4  GOTO Step_4  -- Scn = 5453. Print List            
   IF @nStep = 5  GOTO Step_5  -- Scn = 5454. quit       
END        
RETURN -- Do nothing if incorrect step        
        
        
/********************************************************************************        
Step_Start. Func = 706        
********************************************************************************/        
Step_0:        
BEGIN        
   -- Event log        
   EXEC RDT.rdt_STD_EventLog        
      @cActionType   = '1', -- Sign-In        
      @nMobileNo     = @nMobile,        
      @nFunctionID   = @nFunc,        
      @cFacility     = @cFacility,        
      @cStorerKey    = @cStorerKey,        
      @nStep         = @nStep                 
        
   SET @cLabel1 = ''         
   SET @cLabel2 = ''        
   SET @cLabel3 = ''         
   SET @cLabel4 = ''         
   SET @cLabel5 = ''         
   SET @cSP = ''        
   SET @cRetainValue = ''       
   SET @cTotalCaptr = 0                 
        
   -- Prepare next screen var        
   SELECT @cOutField01='1-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='1'      
   SELECT @cOutField02='2-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='2'      
   SELECT @cOutField03='3-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='3'      
   SELECT @cOutField04='4-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='4'      
   SELECT @cOutField05='5-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='5'      
   SELECT @cOutField06='6-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='6'      
   SELECT @cOutField07='7-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='7'      
   SELECT @cOutField08='8-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='8'      
   SELECT @cOutField09='9-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='9'       
           
   -- Go to next screen        
   SET @nScn = 5450        
   SET @nStep = 1        
END        
GOTO Quit    
    
/***********************************************************************************        
Scn = 5450. Option screen        
   (field01)    
   (field02)    
   (field03)    
   (field04)    
   (field05)    
   (field06)    
   (field07)    
   (field08)    
   (field09)    
OPTION: field10    
***********************************************************************************/        
Step_1:        
BEGIN        
   IF @nInputKey = 1 -- ENTER        
   BEGIN        
    
      SET @cOption=@cInField10;    
    
      IF ISNULL(@cOption,'')=''    
      BEGIN    
         SET @nErrNo = 159051        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong Option       
         GOTO Step1_Fail        
      END    
    
      -- Get even to capture           
      SELECT         
         @cLabel1       = UDF01,         
         @cLabel2       = UDF02,         
         @cLabel3       = UDF03,         
         @cLabel4       = UDF04,         
         @cLabel5       = UDF05,         
         @cSP           = Long,         
         @cRetainValue  = Short         
      FROM dbo.CodeLkup WITH (NOLOCK)         
      WHERE StorerKey = @cStorerKey        
         AND ListName = 'RDTEVENT'    
         AND code=@cOption    
          
      -- Check SP setup        
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSP AND type = 'P')        
      BEGIN        
         SET @nErrNo = 159052        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SP NotSetup        
         GOTO step1_Fail        
      END        
    
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- PalletID      
      SET @cTotalCaptr=0    
           
      -- Enable / disable field        
      SET @cFieldAttr02 = CASE WHEN @cLabel1 = '' THEN 'O' ELSE '' END        
      SET @cFieldAttr04 = CASE WHEN @cLabel2 = '' THEN 'O' ELSE '' END        
      SET @cFieldAttr06 = CASE WHEN @cLabel3 = '' THEN 'O' ELSE '' END        
      SET @cFieldAttr08 = CASE WHEN @cLabel4 = '' THEN 'O' ELSE '' END        
      SET @cFieldAttr10 = CASE WHEN @cLabel5 = '' THEN 'O' ELSE '' END        
           
      -- Clear optional in field        
      SET @cInField02 = ''        
      SET @cInField04 = ''        
      SET @cInField06 = ''        
      SET @cInField08 = ''        
      SET @cInField10 = ''        
        
      -- Prepare next screen var        
      SET @cOutField01 = @cLabel1        
      SET @cOutField02 = ''        
      SET @cOutField03 = @cLabel2        
      SET @cOutField04 = ''        
      SET @cOutField05 = @cLabel3        
      SET @cOutField06 = ''        
      SET @cOutField07 = @cLabel4        
    SET @cOutField08 = ''        
      SET @cOutField09 = @cLabel5        
      SET @cOutField10 = ''        
      SET @cOutField11 = @cTotalCaptr        
    
      SET @cValue1 =''    
      SET @cValue2 =''    
      SET @cValue3 =''    
      SET @cValue4 =''    
      SET @cValue5 =''    
      SET @cExtendedinfo=''
      SET @cOutField12=''
           
      -- Go to next screen        
      SET @nScn = @nScn+1        
      SET @nStep = @nStep+1        
   END        
        
   IF @nInputKey = 0 -- ESC        
   BEGIN        
      EXEC RDT.rdt_STD_EventLog        
         @cActionType   = '9', -- Sign Out Function        
         @nMobileNo     = @nMobile,        
         @nFunctionID   = @nFunc,        
         @cFacility     = @cFacility,        
         @cStorerKey    = @cStorerKey,        
         @nStep         = @nStep        
        
      -- Back to menu        
      SET @nFunc = @nMenu        
      SET @nScn  = @nMenu        
      SET @nStep = 0        
   END      
   GOTO Quit      
    
   Step1_Fail:    
   BEGIN    
      SET @cOption=''    
      SET @cInField10=''    
   END    
END        
GOTO Quit          
        
        
/***********************************************************************************        
Scn = 5450. Even screen        
   Label1 (field01)        
   Value1 (field02)        
   Label2 (field03)        
   Value2 (field04)        
   Label3 (field05)        
   Value3 (field06)        
   Label4 (field07)        
   Value4 (field08)        
   Label5 (field09)        
   Value5 (field10)        
***********************************************************************************/        
Step_2:        
BEGIN        
   IF @nInputKey = 1 -- ENTER        
   BEGIN        
      -- Screen mapping        
      SET @cValue1 = CASE WHEN @cFieldAttr02 = 'O' THEN @cOutField02 ELSE @cInField02 END        
      SET @cValue2 = CASE WHEN @cFieldAttr04 = 'O' THEN @cOutField04 ELSE @cInField04 END        
      SET @cValue3 = CASE WHEN @cFieldAttr06 = 'O' THEN @cOutField06 ELSE @cInField06 END        
      SET @cValue4 = CASE WHEN @cFieldAttr08 = 'O' THEN @cOutField08 ELSE @cInField08 END        
      SET @cValue5 = CASE WHEN @cFieldAttr10 = 'O' THEN @cOutField10 ELSE @cInField10 END        
        
      -- Retain value        
      SET @cOutField02 = @cInField02        
      SET @cOutField04 = @cInField04        
      SET @cOutField06 = @cInField06        
      SET @cOutField08 = @cInField08        
      SET @cOutField10 = @cInField10        
        
      -- Execute label/report stored procedure        
      IF @cSP <> ''        
      BEGIN        
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption, @cRetainValue,' +        
               ' @cTotalCaptr OUTPUT,@nStep OUTPUT,@nScn OUTPUT,@cLabel1 OUTPUT, @cLabel2 OUTPUT, @cLabel3 OUTPUT, @cLabel4 OUTPUT, @cLabel5 OUTPUT, ' +        
               ' @cValue1 OUTPUT, @cValue2 OUTPUT, @cValue3 OUTPUT, @cValue4 OUTPUT, @cValue5 OUTPUT, ' +        
               ' @cFieldAttr02 OUTPUT, @cFieldAttr04 OUTPUT, @cFieldAttr06 OUTPUT, @cFieldAttr08 OUTPUT, @cFieldAttr10 OUTPUT,@cExtendedinfo OUTPUT,' +         
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
               ' @nMobile       INT,           ' +        
               ' @nFunc         INT,           ' +        
               ' @cLangCode     NVARCHAR( 3),  ' +        
               ' @nInputKey     INT,           ' +         
               ' @cFacility     NVARCHAR( 5),  ' +        
               ' @cStorerKey    NVARCHAR( 15), ' +         
               ' @cOption       NVARCHAR( 1),  ' +        
               ' @cRetainValue  NVARCHAR( 10), ' +      
               ' @cTotalCaptr   INT           OUTPUT, ' +      
               ' @nStep         INT           OUTPUT, ' +      
               ' @nScn          INT           OUTPUT, ' +        
               ' @cLabel1       NVARCHAR( 20) OUTPUT, ' +         
               ' @cLabel2       NVARCHAR( 20) OUTPUT, ' +         
               ' @cLabel3       NVARCHAR( 20) OUTPUT, ' +         
               ' @cLabel4       NVARCHAR( 20) OUTPUT, ' +         
               ' @cLabel5       NVARCHAR( 20) OUTPUT, ' +       
               ' @cValue1       NVARCHAR( 60) OUTPUT, ' +         
               ' @cValue2       NVARCHAR( 60) OUTPUT, ' +         
               ' @cValue3       NVARCHAR( 60) OUTPUT, ' +         
               ' @cValue4       NVARCHAR( 60) OUTPUT, ' +         
               ' @cValue5       NVARCHAR( 60) OUTPUT, ' +         
               ' @cFieldAttr02  NVARCHAR( 1)  OUTPUT, ' +         
               ' @cFieldAttr04  NVARCHAR( 1)  OUTPUT, ' +         
               ' @cFieldAttr06  NVARCHAR( 1)  OUTPUT, ' +         
               ' @cFieldAttr08  NVARCHAR( 1)  OUTPUT, ' +         
               ' @cFieldAttr10  NVARCHAR( 1)  OUTPUT, ' + 
               ' @cExtendedinfo NVARCHAR(20)  OUTPUT, ' +        
               ' @nErrNo        INT           OUTPUT, ' +        
               ' @cErrMsg       NVARCHAR( 20) OUTPUT  '        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption, @cRetainValue,        
               @cTotalCaptr OUTPUT,@nStep OUTPUT,@nScn OUTPUT,@cLabel1 OUTPUT, @cLabel2 OUTPUT, @cLabel3 OUTPUT, @cLabel4 OUTPUT, @cLabel5 OUTPUT,         
               @cValue1 OUTPUT, @cValue2 OUTPUT, @cValue3 OUTPUT, @cValue4 OUTPUT, @cValue5 OUTPUT,          
               @cFieldAttr02 OUTPUT, @cFieldAttr04 OUTPUT, @cFieldAttr06 OUTPUT, @cFieldAttr08 OUTPUT, @cFieldAttr10 OUTPUT,@cExtendedinfo OUTPUT,          
               @nErrNo OUTPUT, @cErrMsg OUTPUT        
        
            SET @cOutField01 = @cLabel1        
            SET @cOutField02 = @cValue1        
            SET @cOutField03 = @cLabel2        
            SET @cOutField04 = @cValue2        
            SET @cOutField05 = @cLabel3        
            SET @cOutField06 = @cValue3        
            SET @cOutField07 = @cLabel4        
            SET @cOutField08 = @cValue4        
            SET @cOutField09 = @cLabel5        
            SET @cOutField10 = @cValue5      
            SET @cOutField11 = @cTotalCaptr  
            SET @cOutField12 = @cExtendedinfo     
         END        
        
         IF @nErrNo <> 0        
            GOTO Quit        
        
         -- Remain in current screen        
         IF CHARINDEX('R', @cRetainValue ) <> 0 OR @cRetainValue <> ''        
         BEGIN        
            -- Retain param value        
            IF CHARINDEX('1', @cRetainValue ) = 0 SET @cValue1 = ''         
            IF CHARINDEX('2', @cRetainValue ) = 0 SET @cValue2 = ''         
            IF CHARINDEX('3', @cRetainValue ) = 0 SET @cValue3 = ''         
            IF CHARINDEX('4', @cRetainValue ) = 0 SET @cValue4 = ''         
            IF CHARINDEX('5', @cRetainValue ) = 0 SET @cValue5 = ''         
                          
            -- Prepare next screen var        
            SET @cOutField01 = @cLabel1        
            SET @cOutField02 = @cValue1        
            SET @cOutField03 = @cLabel2        
            SET @cOutField04 = @cValue2        
            SET @cOutField05 = @cLabel3        
            SET @cOutField06 = @cValue3        
            SET @cOutField07 = @cLabel4        
            SET @cOutField08 = @cValue4        
            SET @cOutField09 = @cLabel5        
            SET @cOutField10 = @cValue5        
                    
            GOTO Quit        
         END        
      
         SET @cOption = ''      
      END        
   END        
        
   IF @nInputKey = 0 -- ESC        
   BEGIN      
      -- Execute label/report stored procedure        
      IF @cSP <> ''        
      BEGIN        
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption, @cRetainValue,' +        
               ' @cTotalCaptr OUTPUT,@nStep OUTPUT,@nScn OUTPUT,@cLabel1 OUTPUT, @cLabel2 OUTPUT, @cLabel3 OUTPUT, @cLabel4 OUTPUT, @cLabel5 OUTPUT,' +        
               ' @cValue1 OUTPUT, @cValue2 OUTPUT, @cValue3 OUTPUT, @cValue4 OUTPUT, @cValue5 OUTPUT, ' +        
               ' @cFieldAttr02 OUTPUT, @cFieldAttr04 OUTPUT, @cFieldAttr06 OUTPUT, @cFieldAttr08 OUTPUT, @cFieldAttr10 OUTPUT,@cExtendedInfo OUTPUT,' +         
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
               ' @nMobile       INT,           ' +        
               ' @nFunc         INT,           ' +        
               ' @cLangCode     NVARCHAR( 3),  ' +        
               ' @nInputKey     INT,           ' +         
               ' @cFacility     NVARCHAR( 5),  ' +        
               ' @cStorerKey  NVARCHAR( 15), ' +         
               ' @cOption       NVARCHAR( 1),  ' +        
               ' @cRetainValue  NVARCHAR( 10), ' +      
               ' @cTotalCaptr   INT           OUTPUT, ' +      
               ' @nStep         INT           OUTPUT, ' +      
               ' @nScn          INT           OUTPUT, ' +        
               ' @cLabel1       NVARCHAR( 20) OUTPUT, ' +         
               ' @cLabel2       NVARCHAR( 20) OUTPUT, ' +         
               ' @cLabel3       NVARCHAR( 20) OUTPUT, ' +         
               ' @cLabel4       NVARCHAR( 20) OUTPUT, ' +         
               ' @cLabel5       NVARCHAR( 20) OUTPUT, ' +        
               ' @cValue1       NVARCHAR( 60) OUTPUT, ' +         
               ' @cValue2       NVARCHAR( 60) OUTPUT, ' +         
               ' @cValue3       NVARCHAR( 60) OUTPUT, ' +         
               ' @cValue4       NVARCHAR( 60) OUTPUT, ' +         
               ' @cValue5       NVARCHAR( 60) OUTPUT, ' +         
               ' @cFieldAttr02  NVARCHAR( 1)  OUTPUT, ' +         
               ' @cFieldAttr04  NVARCHAR( 1)  OUTPUT, ' +         
               ' @cFieldAttr06  NVARCHAR( 1)  OUTPUT, ' +         
               ' @cFieldAttr08  NVARCHAR( 1)  OUTPUT, ' +         
               ' @cFieldAttr10  NVARCHAR( 1)  OUTPUT, ' +  
               ' @cExtendedInfo NVARCHAR( 20) OUTPUT, ' +      
               ' @nErrNo        INT           OUTPUT, ' +        
               ' @cErrMsg       NVARCHAR( 20) OUTPUT  '        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption, @cRetainValue,        
               @cTotalCaptr OUTPUT,@nStep OUTPUT,@nScn OUTPUT,@cLabel1 OUTPUT, @cLabel2 OUTPUT, @cLabel3 OUTPUT, @cLabel4 OUTPUT, @cLabel5 OUTPUT,          
               @cValue1 OUTPUT, @cValue2 OUTPUT, @cValue3 OUTPUT, @cValue4 OUTPUT, @cValue5 OUTPUT,          
               @cFieldAttr02 OUTPUT, @cFieldAttr04 OUTPUT, @cFieldAttr06 OUTPUT, @cFieldAttr08 OUTPUT, @cFieldAttr10 OUTPUT, @cExtendedInfo OUTPUT,         
               @nErrNo OUTPUT, @cErrMsg OUTPUT        
         END        
      END       
    
      IF @nStep=2    
      BEGIN    
         SET @cOutField01= ''    
         SET @cOutField02= ''    
         SET @cOutField03= ''    
         SET @cOutField04= ''    
         SET @cOutField05= ''    
         SET @cOutField06= ''    
         SET @cOutField07= ''    
         SET @cOutField08= ''    
         SET @cOutField09= ''    
    
         SELECT @cOutField01='1-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='1'      
         SELECT @cOutField02='2-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='2'      
         SELECT @cOutField03='3-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='3'      
         SELECT @cOutField04='4-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='4'      
         SELECT @cOutField05='5-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='5'      
         SELECT @cOutField06='6-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='6'      
         SELECT @cOutField07='7-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='7'      
         SELECT @cOutField08='8-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='8'      
         SELECT @cOutField09='9-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='9'       
          
         -- Enable / disable field        
         SET @cFieldAttr02 = ''        
         SET @cFieldAttr04 = ''        
         SET @cFieldAttr06 = ''        
         SET @cFieldAttr08 = ''        
         SET @cFieldAttr10 = ''      
    
         SET @cOption=''    
         SET @nScn  = @nScn-1        
         SET @nStep = @nStep-1       
      END         
   END        
END        
GOTO Quit      
      
/***********************************************************************************        
Scn = 5451. Even screen        
   Close Pallet?      
   1. Yes      
   9. No      
   Option: (field01)      
***********************************************************************************/        
      
Step_3:      
BEGIN      
   IF @nInputKey= 1      
   BEGIN      
            
      SET @cOption = @cInField13     
            
       -- Execute label/report stored procedure        
      IF @cSP <> ''        
      BEGIN          
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption, @cRetainValue,' +        
               ' @cTotalCaptr OUTPUT,@nStep OUTPUT,@nScn OUTPUT,@cLabel1 OUTPUT, @cLabel2 OUTPUT, @cLabel3 OUTPUT, @cLabel4 OUTPUT, @cLabel5 OUTPUT, ' +        
               ' @cValue1 OUTPUT, @cValue2 OUTPUT, @cValue3 OUTPUT, @cValue4 OUTPUT, @cValue5 OUTPUT, ' +        
               ' @cFieldAttr02 OUTPUT, @cFieldAttr04 OUTPUT, @cFieldAttr06 OUTPUT, @cFieldAttr08 OUTPUT, @cFieldAttr10 OUTPUT,@cExtendedInfo OUTPUT,' +         
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
               ' @nMobile       INT,           ' +        
               ' @nFunc         INT,           ' +        
               ' @cLangCode     NVARCHAR( 3),  ' +        
               ' @nInputKey     INT,           ' +         
               ' @cFacility     NVARCHAR( 5),  ' +        
               ' @cStorerKey    NVARCHAR( 15), ' +         
               ' @cOption       NVARCHAR( 1),  ' +        
               ' @cRetainValue  NVARCHAR( 10), ' +      
               ' @cTotalCaptr   INT           OUTPUT, ' +      
               ' @nStep         INT           OUTPUT, ' +      
               ' @nScn          INT           OUTPUT, ' +        
               ' @cLabel1       NVARCHAR( 20) OUTPUT, ' +         
               ' @cLabel2       NVARCHAR( 20) OUTPUT, ' +         
               ' @cLabel3       NVARCHAR( 20) OUTPUT, ' +         
               ' @cLabel4       NVARCHAR( 20) OUTPUT, ' +         
               ' @cLabel5       NVARCHAR( 20) OUTPUT, ' +         
               ' @cValue1       NVARCHAR( 60) OUTPUT, ' +         
               ' @cValue2       NVARCHAR( 60) OUTPUT, ' +         
               ' @cValue3       NVARCHAR( 60) OUTPUT, ' +         
               ' @cValue4       NVARCHAR( 60) OUTPUT, ' +         
               ' @cValue5       NVARCHAR( 60) OUTPUT, ' +         
               ' @cFieldAttr02  NVARCHAR( 1)  OUTPUT, ' +         
               ' @cFieldAttr04  NVARCHAR( 1)  OUTPUT, ' +         
               ' @cFieldAttr06  NVARCHAR( 1)  OUTPUT, ' +         
               ' @cFieldAttr08  NVARCHAR( 1)  OUTPUT, ' +         
               ' @cFieldAttr10  NVARCHAR( 1)  OUTPUT, ' +  
               ' @cExtendedInfo NVARHCAR( 20) OUTPUT,'  +      
               ' @nErrNo        INT           OUTPUT, ' +        
               ' @cErrMsg       NVARCHAR( 20) OUTPUT  '        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption, @cRetainValue,        
               @cTotalCaptr OUTPUT,@nStep OUTPUT,@nScn OUTPUT,@cLabel1 OUTPUT, @cLabel2 OUTPUT, @cLabel3 OUTPUT, @cLabel4 OUTPUT, @cLabel5 OUTPUT,         
               @cValue1 OUTPUT, @cValue2 OUTPUT, @cValue3 OUTPUT, @cValue4 OUTPUT, @cValue5 OUTPUT,          
               @cFieldAttr02 OUTPUT, @cFieldAttr04 OUTPUT, @cFieldAttr06 OUTPUT, @cFieldAttr08 OUTPUT, @cFieldAttr10 OUTPUT,@cExtendedInfo OUTPUT,          
               @nErrNo OUTPUT, @cErrMsg OUTPUT        
        
            SET @cOutField01 = @cLabel1        
            SET @cOutField02 = @cValue1        
            SET @cOutField03 = @cLabel2        
            SET @cOutField04 = @cValue2        
            SET @cOutField05 = @cLabel3        
            SET @cOutField06 = @cValue3        
            SET @cOutField07 = @cLabel4        
            SET @cOutField08 = @cValue4        
            SET @cOutField09 = @cLabel5        
            SET @cOutField10 = @cValue5      
            SET @cOutField11 = @cTotalCaptr       
         END           
        
         IF @nErrNo <> 0        
            GOTO step_3_Fail     
      END       
            
      -- Remain in current screen        
      IF CHARINDEX('R', @cRetainValue ) <> 0 OR @cRetainValue <> ''        
      BEGIN        
         -- Retain param value        
         IF CHARINDEX('1', @cRetainValue ) = 0 SET @cValue1 = ''         
         IF CHARINDEX('2', @cRetainValue ) = 0 SET @cValue2 = ''         
         IF CHARINDEX('3', @cRetainValue ) = 0 SET @cValue3 = ''         
         IF CHARINDEX('4', @cRetainValue ) = 0 SET @cValue4 = ''         
         IF CHARINDEX('5', @cRetainValue ) = 0 SET @cValue5 = ''         
                          
         -- Prepare next screen var        
         SET @cOutField01 = @cLabel1        
         SET @cOutField02 = @cValue1        
         SET @cOutField03 = @cLabel2        
         SET @cOutField04 = @cValue2        
         SET @cOutField05 = @cLabel3        
         SET @cOutField06 = @cValue3        
         SET @cOutField07 = @cLabel4        
         SET @cOutField08 = @cValue4        
         SET @cOutField09 = @cLabel5        
         SET @cOutField10 = @cValue5        
                    
         GOTO Quit        
      END        
      
      SET @cOption = ''       
      
   END      
      
   IF @nInputKey= 0      
   BEGIN      
      -- Prepare prev screen var        
      SET @cOutField01 = @cLabel1        
      SET @cOutField02 = @cValue1        
      SET @cOutField03 = @cLabel2        
      SET @cOutField04 = @cValue2        
      SET @cOutField05 = @cLabel3        
      SET @cOutField06 = @cValue3        
      SET @cOutField07 = @cLabel4        
      SET @cOutField08 = @cValue4        
      SET @cOutField09 = @cLabel5        
      SET @cOutField10 = @cValue5       
              
      SET @nScn  = @nScn-1        
      SET @nStep = @nStep -1        
            
   END     
   GOTO Quit       
    
      
   Step_3_fail:      
   BEGIN      
      SET @cOption = ''        
   END      
END       
GOTO Quit      
      
/***********************************************************************************        
Scn = 5452. Even screen        
   Print List?      
   1. Yes      
   9. No      
   Option: (field01)      
***********************************************************************************/        
      
Step_4:      
BEGIN      
   IF @nInputKey= 1      
   BEGIN      
      
      SET @cOption = @cInfield13     
            
         -- Execute label/report stored procedure        
      IF @cSP <> ''        
      BEGIN        
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSP AND type = 'P')        
    BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption, @cRetainValue,' +        
               ' @cTotalCaptr OUTPUT,@nStep OUTPUT,@nScn OUTPUT,@cLabel1 OUTPUT, @cLabel2 OUTPUT, @cLabel3 OUTPUT, @cLabel4 OUTPUT, @cLabel5 OUTPUT,' +        
               ' @cValue1 OUTPUT, @cValue2 OUTPUT, @cValue3 OUTPUT, @cValue4 OUTPUT, @cValue5 OUTPUT, ' +        
               ' @cFieldAttr02 OUTPUT, @cFieldAttr04 OUTPUT, @cFieldAttr06 OUTPUT, @cFieldAttr08 OUTPUT, @cFieldAttr10 OUTPUT,@cExtendedInfo OUTPUT,' +         
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
               ' @nMobile       INT,           ' +        
               ' @nFunc         INT,           ' +        
               ' @cLangCode     NVARCHAR( 3),  ' +        
               ' @nInputKey     INT,           ' +         
               ' @cFacility     NVARCHAR( 5),  ' +        
               ' @cStorerKey    NVARCHAR( 15), ' +         
               ' @cOption       NVARCHAR( 1),  ' +        
               ' @cRetainValue  NVARCHAR( 10), ' +      
               ' @cTotalCaptr   INT           OUTPUT, ' +      
               ' @nStep         INT           OUTPUT, ' +      
               ' @nScn          INT           OUTPUT, ' +                    
               ' @cLabel1       NVARCHAR( 20) OUTPUT, ' +         
               ' @cLabel2       NVARCHAR( 20) OUTPUT, ' +         
               ' @cLabel3       NVARCHAR( 20) OUTPUT, ' +         
               ' @cLabel4       NVARCHAR( 20) OUTPUT, ' +         
               ' @cLabel5       NVARCHAR( 20) OUTPUT, ' +        
               ' @cValue1       NVARCHAR( 60) OUTPUT, ' +         
               ' @cValue2       NVARCHAR( 60) OUTPUT, ' +         
               ' @cValue3       NVARCHAR( 60) OUTPUT, ' +         
               ' @cValue4       NVARCHAR( 60) OUTPUT, ' +         
               ' @cValue5       NVARCHAR( 60) OUTPUT, ' +         
               ' @cFieldAttr02  NVARCHAR( 1)  OUTPUT, ' +         
               ' @cFieldAttr04  NVARCHAR( 1)  OUTPUT, ' +         
               ' @cFieldAttr06  NVARCHAR( 1)  OUTPUT, ' +         
               ' @cFieldAttr08  NVARCHAR( 1)  OUTPUT, ' +         
               ' @cFieldAttr10  NVARCHAR( 1)  OUTPUT, ' + 
               ' @cExtendedInfo NVARCHAR( 20) OUTPUT, ' +        
               ' @nErrNo        INT           OUTPUT, ' +        
               ' @cErrMsg       NVARCHAR( 20) OUTPUT  '        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption, @cRetainValue,        
               @cTotalCaptr OUTPUT,@nStep OUTPUT,@nScn OUTPUT,@cLabel1 OUTPUT, @cLabel2 OUTPUT, @cLabel3 OUTPUT, @cLabel4 OUTPUT, @cLabel5 OUTPUT,    
               @cValue1 OUTPUT, @cValue2 OUTPUT, @cValue3 OUTPUT, @cValue4 OUTPUT, @cValue5 OUTPUT,          
               @cFieldAttr02 OUTPUT, @cFieldAttr04 OUTPUT, @cFieldAttr06 OUTPUT, @cFieldAttr08 OUTPUT, @cFieldAttr10 OUTPUT,@cExtendedInfo OUTPUT,          
               @nErrNo OUTPUT, @cErrMsg OUTPUT        
        
            SET @cOutField01 = @cLabel1        
            SET @cOutField02 = @cValue1        
            SET @cOutField03 = @cLabel2        
            SET @cOutField04 = @cValue2        
            SET @cOutField05 = @cLabel3        
            SET @cOutField06 = @cValue3        
            SET @cOutField07 = @cLabel4        
            SET @cOutField08 = @cValue4        
            SET @cOutField09 = @cLabel5        
            SET @cOutField10 = @cValue5      
            SET @cOutField11 = @cTotalCaptr       
         END        
        
         IF @nErrNo <> 0        
            GOTO step_4_Fail        
       
      END      
      
      -- Remain in current screen        
      IF CHARINDEX('R', @cRetainValue ) <> 0 OR @cRetainValue <> ''        
      BEGIN        
         -- Retain param value        
         IF CHARINDEX('1', @cRetainValue ) = 0 SET @cValue1 = ''         
 IF CHARINDEX('2', @cRetainValue ) = 0 SET @cValue2 = ''         
         IF CHARINDEX('3', @cRetainValue ) = 0 SET @cValue3 = ''         
         IF CHARINDEX('4', @cRetainValue ) = 0 SET @cValue4 = ''         
         IF CHARINDEX('5', @cRetainValue ) = 0 SET @cValue5 = ''         
                          
         -- Prepare next screen var        
         SET @cOutField01 = @cLabel1        
         SET @cOutField02 = @cValue1        
         SET @cOutField03 = @cLabel2        
         SET @cOutField04 = @cValue2        
         SET @cOutField05 = @cLabel3        
         SET @cOutField06 = @cValue3        
         SET @cOutField07 = @cLabel4        
         SET @cOutField08 = @cValue4        
         SET @cOutField09 = @cLabel5        
         SET @cOutField10 = @cValue5        
                    
         GOTO Quit        
      END        
      
      SET @cOption = ''      
               
   END      
      
   IF @nInputKey= 0      
   BEGIN      
      -- Prepare prev screen var        
      SET @cOutField01 = @cLabel1        
      SET @cOutField02 = @cValue1        
      SET @cOutField03 = @cLabel2        
      SET @cOutField04 = @cValue2        
      SET @cOutField05 = @cLabel3        
      SET @cOutField06 = @cValue3        
      SET @cOutField07 = @cLabel4        
      SET @cOutField08 = @cValue4        
      SET @cOutField09 = @cLabel5        
      SET @cOutField10 = @cValue5       
              
      SET @nScn  = @nScn-2        
      SET @nStep = @nStep -2        
            
   END     
   GOTO Quit       
      
   Step_4_fail:      
   BEGIN      
       SET @cOption = ''        
   END      
END       
GOTO Quit      
    
/***********************************************************************************        
Scn = 5454. Even screen        
   Quit:      
   1. Yes      
   9. No      
   Option: (field01)      
***********************************************************************************/        
      
Step_5:      
BEGIN      
   IF @nInputKey= 1      
   BEGIN      
            
      SET @cOption = @cInField13      
      IF  @cOption='1'    
      BEGIN    
         SET @cOutField01= ''    
         SET @cOutField02= ''    
         SET @cOutField03= ''    
         SET @cOutField04= ''    
         SET @cOutField05= ''    
         SET @cOutField06= ''    
         SET @cOutField07= ''    
         SET @cOutField08= ''    
         SET @cOutField09= ''    
    
         SELECT @cOutField01='1-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='1'      
         SELECT @cOutField02='2-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='2'      
         SELECT @cOutField03='3-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='3'      
         SELECT @cOutField04='4-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='4'      
         SELECT @cOutField05='5-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='5'      
         SELECT @cOutField06='6-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='6'      
         SELECT @cOutField07='7-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='7'      
         SELECT @cOutField08='8-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='8'      
         SELECT @cOutField09='9-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTEVENT' AND code='9'       
          
         -- Enable / disable field        
         SET @cFieldAttr02 = ''        
         SET @cFieldAttr04 = ''        
         SET @cFieldAttr06 = ''        
         SET @cFieldAttr08 = ''        
         SET @cFieldAttr10 = ''      
    
         SET @cOption=''    
         SET @nScn  = @nScn-4        
         SET @nStep = @nStep-4       
             
      END    
      ELSE    
      BEGIN    
            
       -- Enable / disable field        
         SET @cFieldAttr02 = CASE WHEN @cLabel1 = '' THEN 'O' ELSE '' END        
         SET @cFieldAttr04 = CASE WHEN @cLabel2 = '' THEN 'O' ELSE '' END        
         SET @cFieldAttr06 = CASE WHEN @cLabel3 = '' THEN 'O' ELSE '' END        
         SET @cFieldAttr08 = CASE WHEN @cLabel4 = '' THEN 'O' ELSE '' END        
         SET @cFieldAttr10 = CASE WHEN @cLabel5 = '' THEN 'O' ELSE '' END        
           
         -- Clear optional in field        
         SET @cInField02 = ''        
         SET @cInField04 = ''        
         SET @cInField06 = ''        
         SET @cInField08 = ''        
         SET @cInField10 = ''        
        
         SET @cOutField01 = @cLabel1        
         SET @cOutField02 = @cValue1        
         SET @cOutField03 = @cLabel2        
         SET @cOutField04 = @cValue2        
         SET @cOutField05 = @cLabel3        
         SET @cOutField06 = @cValue3        
         SET @cOutField07 = @cLabel4        
         SET @cOutField08 = @cValue4        
         SET @cOutField09 = @cLabel5        
         SET @cOutField10 = @cValue5      
         SET @cOutField11 = @cTotalCaptr       
    
         SET @cOption = ''      
    
         SET @nScn  = @nScn-3      
         SET @nStep = @nStep-3      
      END     
      
   END      
      
   IF @nInputKey= 0      
   BEGIN      
      -- Enable / disable field        
      SET @cFieldAttr02 = CASE WHEN @cLabel1 = '' THEN 'O' ELSE '' END        
      SET @cFieldAttr04 = CASE WHEN @cLabel2 = '' THEN 'O' ELSE '' END        
      SET @cFieldAttr06 = CASE WHEN @cLabel3 = '' THEN 'O' ELSE '' END        
      SET @cFieldAttr08 = CASE WHEN @cLabel4 = '' THEN 'O' ELSE '' END        
      SET @cFieldAttr10 = CASE WHEN @cLabel5 = '' THEN 'O' ELSE '' END        
           
      -- Clear optional in field        
      SET @cInField02 = ''        
      SET @cInField04 = ''        
      SET @cInField06 = ''        
      SET @cInField08 = ''        
      SET @cInField10 = ''        
        
      SET @cOutField01 = @cLabel1        
      SET @cOutField02 = @cValue1        
      SET @cOutField03 = @cLabel2        
      SET @cOutField04 = @cValue2        
      SET @cOutField05 = @cLabel3        
      SET @cOutField06 = @cValue3        
      SET @cOutField07 = @cLabel4        
      SET @cOutField08 = @cValue4        
      SET @cOutField09 = @cLabel5        
      SET @cOutField10 = @cValue5      
      SET @cOutField11 = @cTotalCaptr       
    
      SET @cOption = ''      
              
      SET @nScn  = @nScn-3      
      SET @nStep = @nStep -3        
            
   END     
   GOTO Quit       
    
   Step_5_fail:      
   BEGIN      
      SET @cOption = ''        
   END      
END       
GOTO Quit      
        
        
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
        
      StorerKey = @cStorerKey,        
      Facility  = @cFacility,        
        
      V_String1 = @cLabel1,        
      V_String2 = @cLabel2,        
      V_String3 = @cLabel3,        
      V_String4 = @cLabel4,        
      V_String5 = @cLabel5,        
      V_String6 = @cRetainValue,      
      V_String7 = @cOption,      
               
      V_String41 = @cValue1,        
      V_String42 = @cValue2,        
      V_String43 = @cValue3,        
      V_String44 = @cValue4,        
      V_String45 = @cValue5,        
      V_String46 = @cSP,       
      V_String47 = @cExtendedinfo,

      V_Integer1 = @cTotalCaptr,         
             
      I_Field01 = @cInField01,  O_Field01 = @cOutField01,  FieldAttr01 = @cFieldAttr01,        
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,  FieldAttr02 = @cFieldAttr02,        
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,  FieldAttr03 = @cFieldAttr03,        
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,  FieldAttr04 = @cFieldAttr04,        
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,  FieldAttr05 = @cFieldAttr05,        
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,  FieldAttr06 = @cFieldAttr06,        
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,  FieldAttr07 = @cFieldAttr07,        
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,  FieldAttr08 = @cFieldAttr08,         
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,  FieldAttr09 = @cFieldAttr09,        
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,  FieldAttr10 = @cFieldAttr10,        
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,  FieldAttr11 = @cFieldAttr11,        
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,  FieldAttr12 = @cFieldAttr12,        
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,  FieldAttr13 = @cFieldAttr13,        
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,  FieldAttr14 = @cFieldAttr14,        
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,  FieldAttr15 = @cFieldAttr15            
              
   WHERE Mobile = @nMobile        
END 

GO