SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
      
/***************************************************************************/      
/* Store procedure: rdtfnc_MbolCreation                                    */      
/* Copyright      : LF Logistics                                           */      
/*                                                                         */      
/* Purpose: Populate orders into MBOL, MBOLDetail                          */      
/*                                                                         */      
/* Modifications log:                                                      */      
/*                                                                         */      
/* Date         Rev  Author   Purposes                                     */      
/* 2021-07-27   1.0  James    WMS-17484 Created                            */     
/* 2021-08-09   1.1  James    WMS-17621 Add capture data (james01)         */    
/* 2022-08-03   1.2  James    WMS-20213 Add custom lookup field (james02)  */    
/* 2022-12-15   1.3  James    WMS-21350 Allow create mbol with header      */
/*                            only (james03)                               */
/* 2022-12-22   1.4  yeekung  JSM-118875 blank mbolkey (yeekung01)         */
/* 2023-03-27   1.5  James    WMS-22063 Add ExtUpdSP to step 4 (james04)   */
/***************************************************************************/      
      
CREATE   PROC [RDT].[rdtfnc_MbolCreation](      
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
   @cSQLParam      NVARCHAR(MAX)      
      
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
   @cExtendedInfo       NVARCHAR( 20),      
   @cExtendedInfoSP     NVARCHAR( 20),      
   @cExtendedUpdateSP   NVARCHAR( 20),      
   @cExtendedValidateSP NVARCHAR( 20),      
   @cOption             NVARCHAR( 1),       
   @cLoadKey            NVARCHAR( 10),      
   @cOrderKey           NVARCHAR( 10),      
   @cMBOLKey            NVARCHAR( 10),    
   @cRefNo1             NVARCHAR( 20),    
   @cRefNo2             NVARCHAR( 20),    
   @cRefNo3             NVARCHAR( 20),    
   @cRefNoLookupColumn  NVARCHAR( 20),    
   @cLockFacility       NVARCHAR( 1),    
   @nOrderCnt           INT,    
   @tMbolCreate         VARIABLETABLE,    
   @tExtValidate        VariableTable,       
   @tExtUpdate          VariableTable,       
   @tExtInfo            VariableTable,    
   @tCaptureVar         VARIABLETABLE,    
   @cCaptureInfoSP      NVARCHAR( 20),    
   @cCloseMbol          NVARCHAR( 1),    
   @cData1              NVARCHAR( 60),    
   @cData2              NVARCHAR( 60),    
   @cData3              NVARCHAR( 60),    
   @cData4              NVARCHAR( 60),    
   @cData5              NVARCHAR( 60),    
   @cMbolCriteria       NVARCHAR( 20),    
   @cRefnoLabel1        NVARCHAR( 20),    
   @cRefnoLabel2        NVARCHAR( 20),    
   @cRefnoLabel3        NVARCHAR( 20),    
   @cColumnName         NVARCHAR( 20), 
   @cBlankMBOL          NVARCHAR( 20), --(yeekung01)
   @nTranCount          INT,
   
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
      
   @nOrderCnt        = V_Integer1,      
      
   @cOrderKey        = V_OrderKey,    
   @cLoadKey         = V_LoadKey,    
   @cExtendedUpdateSP   = V_String1,      
   @cExtendedValidateSP = V_String2,      
   @cExtendedInfoSP     = V_String3,      
   @cMBOLKey            = V_String4,       
   @cCloseMbol          = V_String5,    
   @cRefNo1             = V_String6,      
   @cRefNo2             = V_String7,    
   @cRefNo3             = V_String8,    
   @cLockFacility       = V_String9,      
   @cRefNoLookupColumn  = V_String10,    
   @cCaptureInfoSP      = V_String11,    
   @cMbolCriteria       = V_String12,    
   @cRefnoLabel1        = V_String13,    
   @cRefnoLabel2        = V_String14,    
   @cRefnoLabel3        = V_String15,    
   @cBlankMBOL          = V_String16,
       
   @cData1              = V_String41,    
   @cData2              = V_String42,    
   @cData3              = V_String43,    
   @cData4              = V_String44,    
   @cData5              = V_String45,    
       
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
         
FROM rdt.rdtMobRec WITH (NOLOCK)      
WHERE Mobile = @nMobile      
      
-- Screen constant      
DECLARE      
   @nStep_Facility            INT,  @nScn_Facility          INT,      
   @nStep_Scan                INT,  @nScn_Scan              INT,      
   @nStep_CloseMbol           INT,  @nScn_CloseMbol         INT,    
   @nStep_CaptureData         INT,  @nScn_CaptureData       INT    
      
SELECT      
   @nStep_Facility            = 1,  @nScn_Facility             = 5930,      
   @nStep_Scan                = 2,  @nScn_Scan                 = 5931,      
   @nStep_CloseMbol           = 3,  @nScn_CloseMbol            = 5932,    
   @nStep_CaptureData         = 4,  @nScn_CaptureData          = 5933    
      
      
IF @nFunc = 1856      
BEGIN      
   -- Redirect to respective screen      
   IF @nStep = 0  GOTO Step_Start            -- Menu. Func = 1856      
   IF @nStep = 1  GOTO Step_Facility         -- Scn = 5930. Facility    
   IF @nStep = 2  GOTO Step_Scan             -- Scn = 5931. Scan OrderKey, LoadKey, Ref No      
   IF @nStep = 3  GOTO Step_CloseMbol        -- Scn = 5932. Close Mbol      
   IF @nStep = 4  GOTO Step_CaptureData      -- Scn = 5933. Capture data    
END      
      
RETURN -- Do nothing if incorrect step      
      
/********************************************************************************      
Step_Start. Func = 1856      
********************************************************************************/      
Step_Start:      
BEGIN      
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)      
   IF @cExtendedValidateSP = '0'        
      SET @cExtendedValidateSP = ''      
      
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)      
   IF @cExtendedUpdateSP = '0'        
      SET @cExtendedUpdateSP = ''      
      
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)      
   IF @cExtendedInfoSP = '0'      
      SET @cExtendedInfoSP = ''      
       
   SET @cLockFacility = rdt.rdtGetConfig( @nFunc, 'LockFacility', @cStorerKey)    
      
   SET @cRefNoLookupColumn = rdt.rdtGetConfig( @nFunc, 'RefNoLookupColumn', @cStorerKey)    
    
   SET @cCaptureInfoSP = rdt.RDTGetConfig( @nFunc, 'CaptureInfoSP', @cStorerKey)    
   IF @cCaptureInfoSP = '0'    
      SET @cCaptureInfoSP = ''    
    
   SET @cCloseMbol = rdt.rdtGetConfig( @nFunc, 'CloseMbol', @cStorerKey)    
    
   SET @cMbolCriteria = rdt.rdtGetConfig( @nFunc, 'MbolCriteria', @cStorerKey)    
   IF @cMbolCriteria = '0'    
      SET @cMbolCriteria = ''    

   SET @cBlankMBOL =  rdt.rdtGetConfig( @nFunc, 'BlankMBOLKey', @cStorerKey)  
   IF @cBlankMBOL = '0'    
      SET @cBlankMBOL = ''    
          
   -- Prepare next screen var      
   SET @cOutField01 = @cFacility      
   SET @cFieldAttr01 = CASE WHEN @cLockFacility = '1' THEN 'O' ELSE '' END    
    
   -- Logging      
   EXEC RDT.rdt_STD_EventLog      
      @cActionType     = '1', -- Sign-in      
      @cUserID         = @cUserName,      
      @nMobileNo       = @nMobile,      
      @nFunctionID     = @nFunc,      
      @cFacility       = @cFacility,      
      @cStorerKey      = @cStorerKey,      
      @nStep           = @nStep      
    
  SET @cMBOLKey = ''    
  SET @cOrderKey = ''    
  SET @cLoadKey = ''    
  SET @cRefNo1 = ''    
  SET @cRefNo2 = ''    
  SET @cRefNo3 = ''    
      
   -- Go to next screen      
   SET @nScn = @nScn_Facility      
   SET @nStep = @nStep_Facility      
END      
GOTO Quit      
      
/************************************************************************************      
Scn = 5930. Scan Facility      
   Facility    (field01, input)      
************************************************************************************/      
Step_Facility:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
      -- Screen mapping        
      SET @cFacility = CASE WHEN @cFieldAttr01 = '' THEN @cInField01 ELSE @cOutField01 END        
        
      -- Check blank        
      IF @cFacility = ''        
      BEGIN        
         SET @nErrNo = 172101        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Facility        
         GOTO Step_Facility_Fail        
      END        
        
      -- Check facility valid        
      IF NOT EXISTS( SELECT 1 FROM dbo.FACILITY WITH (NOLOCK) WHERE Facility = @cFacility)        
      BEGIN        
         SET @nErrNo = 172102        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Facility        
         GOTO Step_Facility_Fail        
      END        
        
      -- Extended validate      
      IF @cExtendedValidateSP <> ''      
      BEGIN      
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')      
         BEGIN      
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +      
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +       
               ' @cMBOLKey, @cOrderKey, @cLoadKey, @cRefNo1, @cRefNo2, @cRefNo3, @tExtValidate, ' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '      
      
            SET @cSQLParam =      
               ' @nMobile        INT,           ' +      
               ' @nFunc          INT,           ' +      
               ' @cLangCode      NVARCHAR( 3),  ' +      
               ' @nStep          INT,           ' +      
               ' @nInputKey      INT,           ' +      
               ' @cFacility      NVARCHAR( 5),  ' +      
               ' @cStorerKey     NVARCHAR( 15), ' +    
               ' @cMBOLKey       NVARCHAR( 10), ' +      
               ' @cOrderKey      NVARCHAR( 10), ' +      
               ' @cLoadKey       NVARCHAR( 10), ' +      
               ' @cRefNo1        NVARCHAR( 20), ' +      
               ' @cRefNo2        NVARCHAR( 20), ' +    
               ' @cRefNo3        NVARCHAR( 20), ' +    
               ' @tExtValidate   VariableTable READONLY, ' +       
               ' @nErrNo         INT           OUTPUT, ' +      
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '      
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,       
               @cMBOLKey, @cOrderKey, @cLoadKey, @cRefNo1, @cRefNo2, @cRefNo3, @tExtValidate,     
               @nErrNo OUTPUT, @cErrMsg OUTPUT      
      
            IF @nErrNo <> 0       
               GOTO Step_Facility_Fail      
         END      
      END      
    
      -- MBOL criteria    
      IF @cMbolCriteria <> ''    
      BEGIN    
         -- Get MBOL criteria label    
         SELECT    
            @cRefnoLabel1 = UDF01,    
            @cRefnoLabel2 = UDF02,    
            @cRefnoLabel3 = UDF03    
         FROM dbo.CodeLKUP WITH (NOLOCK)    
         WHERE ListName = 'RDTBuildMB'    
         AND   Code = @cMbolCriteria    
         AND   StorerKey = @cStorerKey    
         AND   code2 = @cFacility    
    
         -- Check pallet criteria setup    
         IF @cRefnoLabel1 = '' AND    
            @cRefnoLabel2 = '' AND    
            @cRefnoLabel3 = ''     
         BEGIN    
            SET @nErrNo = 172113    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Param NotSetup    
            GOTO Quit    
         END    
    
         DECLARE @curMBOLRule CURSOR    
         SET @curMBOLRule = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR    
         SELECT UDF01    
         FROM dbo.CODELKUP WITH (NOLOCK)    
         WHERE LISTNAME = @cMbolCriteria    
         AND   StorerKey = @cStorerKey    
         AND   code2 = @cFacility    
         ORDER BY Code    
         OPEN @curMBOLRule    
         FETCH NEXT FROM @curMBOLRule INTO @cColumnName    
         WHILE @@FETCH_STATUS = 0    
         BEGIN    
            IF NOT EXISTS (SELECT 1    
                           FROM INFORMATION_SCHEMA.COLUMNS     
                           WHERE TABLE_NAME = 'ORDERS'     
                           AND COLUMN_NAME = @cColumnName)    
            BEGIN    
               SET @nErrNo = 172114    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Param NotValid    
               GOTO Quit    
            END    
    
            FETCH NEXT FROM @curMBOLRule INTO @cColumnName    
         END    
             
         -- Enable / disable field    
         SET @cFieldAttr06 = CASE WHEN @cRefnoLabel1 = '' THEN 'O' ELSE '' END    
         SET @cFieldAttr08 = CASE WHEN @cRefnoLabel2 = '' THEN 'O' ELSE '' END    
         SET @cFieldAttr10 = CASE WHEN @cRefnoLabel3 = '' THEN 'O' ELSE '' END    
    
         -- Clear optional in field    
         SET @cInField06 = ''    
         SET @cInField08 = ''    
         SET @cInField10 = ''    
    
         -- Prepare next screen var    
         SET @cOutField05 = @cRefnoLabel1    
         SET @cOutField06 = ''    
         SET @cOutField07 = @cRefnoLabel2    
         SET @cOutField08 = ''    
         SET @cOutField09 = @cRefnoLabel3    
         SET @cOutField10 = ''    
      END    
      ELSE    
      BEGIN    
         SET @cOutField05 = ''    
         SET @cOutField06 = ''    
         SET @cOutField07 = ''    
         SET @cOutField08 = ''    
         SET @cOutField09 = ''    
         SET @cOutField10 = ''    
    
         SET @cFieldAttr05 = 'O' 
         SET @cFieldAttr06 = 'O'
         SET @cFieldAttr07 = 'O'
         SET @cFieldAttr08 = 'O'
         SET @cFieldAttr09 = 'O'
         SET @cFieldAttr10 = 'O'
      END    
          
      -- Prepare next screen var      
      SET @cOutField01 = @cFacility      
      SET @cOutField02 = ''      
      SET @cOutField03 = ''      
      SET @cOutField04 = ''      
      SET @cOutField15 = ''    
          
      SET @cMBOLKey = ''      
      SET @cOrderKey = ''      
      SET @cLoadKey = ''      
      SET @cRefNo1 = ''      
      SET @cRefNo2 = ''    
      SET @cRefNo3 = ''    
      SET @nOrderCnt = 0    
          
      EXEC rdt.rdtSetFocusField @nMobile, 2    
          
      -- Go to next screen      
      SET @nScn = @nScn_Scan      
      SET @nStep = @nStep_Scan       
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
      
   Step_Facility_Fail:      
   BEGIN      
      SET @cFacility = ''      
      SET @cOutField01 = ''      
   END      
         
   GOTO Quit      
END      
GOTO Quit      
      
/***********************************************************************************      
Scn = 5931. Scan screen      
   Facility    (field01)      
   MBOLKey     (field02)          
   OrderKey    (field03, input)          
   LoadKey     (field04, input)          
   RefNo       (field05, input)          
   Order #     (field06)          
***********************************************************************************/      
Step_Scan:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
      -- Screen mapping      
      SET @cMBOLKey = @cInField02    
      SET @cOrderKey = @cInField03      
      SET @cLoadKey = @cInField04    
      SET @cRefNo1 = @cInField06    
      SET @cRefNo2 = @cInField08    
      SET @cRefNo3 = @cInField10    
      
      -- Validate blank      
      --IF ISNULL( @cOrderKey, '') = '' AND ISNULL( @cLoadKey, '') = '' AND     
      --   ( @cMbolCriteria <> '' AND ( ISNULL( @cRefNo1, '') = ''))      
      --BEGIN      
      --   SET @nErrNo = 172103      
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value req      
      --   GOTO Step_Scan_Fail      
      --END      
        
      IF @cMbolCriteria = ''  
      BEGIN  
       IF ISNULL( @cOrderKey, '') = '' AND ISNULL( @cLoadKey, '') = '' AND ISNULL( @cMBOLKey, '') = ''
         BEGIN      
            SET @nErrNo = 172103      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value req      
            GOTO Step_Scan_Fail      
         END      
      END  
      ELSE  
      BEGIN  
        IF ISNULL( @cOrderKey, '') = '' AND ISNULL( @cLoadKey, '') = '' AND ISNULL( @cRefNo1, '') = ''  
         BEGIN      
          SET @nErrNo = 172103      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Value req      
            GOTO Step_Scan_Fail      
         END      
      END  
         
      -- Either 1 value      
      IF ISNULL( @cOrderKey, '') <> '' AND (ISNULL( @cLoadKey, '') <> '' OR ( @cMbolCriteria <> '' AND ( ISNULL( @cRefNo1, '') <> ''))) OR     
         ISNULL( @cLoadKey, '') <> '' AND (ISNULL( @cOrderKey, '') <> '' OR ( @cMbolCriteria <> '' AND ( ISNULL( @cRefNo1, '') <> ''))) OR    
         ( @cMbolCriteria <> '' AND ( ISNULL( @cRefNo1, '') <> '')) AND (ISNULL( @cOrderKey, '') <> '' OR ISNULL( @cLoadKey, '') <> '')     
      BEGIN      
         SET @nErrNo = 172112      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Either 1 value      
         GOTO Step_Scan_Fail      
      END      
    
      -- Orderkey    
      IF @cOrderkey <> ''    
      BEGIN    
         IF NOT EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)    
                         WHERE OrderKey = @cOrderKey    
                         AND   Facility = @cFacility)    
         BEGIN      
            SET @nErrNo = 172104      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Orders     
            SET @cOutField02 = @cMBOLKey    
            SET @cOutField04 = @cLoadKey    
            SET @cOutField06 = @cRefNo1    
            SET @cOutField08 = @cRefNo2    
            SET @cOutField10 = @cRefNo3    
            EXEC rdt.rdtSetFocusField @nMobile, 3    
            GOTO Step_Scan_Fail      
         END      
      END    
          
      -- LoadKey    
      IF @cLoadKey <> ''    
      BEGIN    
         IF NOT EXISTS ( SELECT 1 FROM dbo.LoadPlan WITH (NOLOCK)    
                         WHERE LoadKey = @cLoadKey    
                         AND   Facility = @cFacility)    
         BEGIN      
            SET @nErrNo = 172105      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Load     
            SET @cOutField02 = @cMBOLKey    
            SET @cOutField04 = @cOrderKey    
            SET @cOutField06 = @cRefNo1    
            SET @cOutField08 = @cRefNo2    
            SET @cOutField10 = @cRefNo3    
            EXEC rdt.rdtSetFocusField @nMobile, 4    
            GOTO Step_Scan_Fail      
         END      
      END    
          
      -- MBOLKey    
      IF @cMBOLKey <> '' AND @cMBOLKey <> 'NOORDER'   
      BEGIN    
         IF NOT EXISTS ( SELECT 1 FROM dbo.MBOL WITH (NOLOCK)    
                       WHERE MbolKey = @cMBOLKey    
                       AND   Facility = @cFacility    
                       AND   [Status] < '5')    
         BEGIN      
            SET @nErrNo = 172115      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid MBOL     
            SET @cOutField02 = ''    
            SET @cOutField03 = @cOrderKey    
            SET @cOutField04 = @cLoadKey    
            SET @cOutField06 = @cRefNo1    
            SET @cOutField08 = @cRefNo2    
            SET @cOutField10 = @cRefNo3    
            EXEC rdt.rdtSetFocusField @nMobile, 2    
            GOTO Step_Scan_Fail      
         END      
             
         IF @cOrderKey = '' AND @cLoadKey = ''   
         BEGIN      
            SET @nErrNo = 172116      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrdOrLoad Req     
            SET @cOutField02 = @cMBOLKey    
            SET @cOutField03 = ''    
            SET @cOutField04 = ''    
            SET @cOutField06 = @cRefNo1    
            SET @cOutField08 = @cRefNo2    
            SET @cOutField10 = @cRefNo3    
            EXEC rdt.rdtSetFocusField @nMobile, 3    
            GOTO Step_Scan_Fail      
         END     
      END    
    
      -- Extended validate      
      IF @cExtendedValidateSP <> ''      
      BEGIN      
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')      
         BEGIN      
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +      
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +       
               ' @cMBOLKey, @cOrderKey, @cLoadKey, @cRefNo1, @cRefNo2, @cRefNo3, @tExtValidate, ' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '      
      
            SET @cSQLParam =      
               ' @nMobile        INT,           ' +      
               ' @nFunc          INT,           ' +      
               ' @cLangCode      NVARCHAR( 3),  ' +      
               ' @nStep          INT,           ' +      
               ' @nInputKey      INT,           ' +      
               ' @cFacility      NVARCHAR( 5),  ' +      
               ' @cStorerKey     NVARCHAR( 15), ' +    
               ' @cMBOLKey       NVARCHAR( 10), ' +      
               ' @cOrderKey      NVARCHAR( 10), ' +      
               ' @cLoadKey       NVARCHAR( 10), ' +      
               ' @cRefNo1        NVARCHAR( 20), ' +      
               ' @cRefNo2        NVARCHAR( 20), ' +    
               ' @cRefNo3        NVARCHAR( 20), ' +    
               ' @tExtValidate   VariableTable READONLY, ' +       
               ' @nErrNo         INT           OUTPUT, ' +      
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '      
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,       
               @cMBOLKey, @cOrderKey, @cLoadKey, @cRefNo1, @cRefNo2, @cRefNo3, @tExtValidate,     
               @nErrNo OUTPUT, @cErrMsg OUTPUT      
      
            IF @nErrNo <> 0       
               GOTO Step_Scan_Fail      
         END      
      END      
    
      -- Capture ASN Info    
      IF @cCaptureInfoSP <> ''    
      BEGIN    
      	SET @nErrNo = 0
         EXEC rdt.rdt_MbolCreation_CaptureInfo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'DISPLAY',     
            @cMBOLKey, @cOrderkey, @cLoadKey, @cRefNo1, @cRefNo2, @cRefNo3,     
            @cData1, @cData2, @cData3, @cData4, @cData5,     
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,       
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,       
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,       
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,       
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,       
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,      
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,      
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,      
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,      
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,      
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,     
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,     
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,     
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,     
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,     
            @tCaptureVar,     
            @nErrNo  OUTPUT,     
            @cErrMsg OUTPUT    

         IF @nErrNo > 0    
            GOTO Quit    
    
         IF @nErrNo = 0
         BEGIN
            -- Go to next screen    
            SET @nScn = @nScn_CaptureData    
            SET @nStep = @nStep_CaptureData    
    
            GOTO Quit
         END
         
         -- IF @nErrNo = -1
         --    no need show capture info screen
      END    
      
      SET @nErrNo = 0
      EXEC rdt.rdt_MbolCreation    
          @nMobile      = @nMobile    
         ,@nFunc        = @nFunc    
         ,@cLangCode    = @cLangCode    
         ,@nStep        = @nStep    
         ,@nInputKey    = @nInputKey    
         ,@cFacility    = @cFacility    
         ,@cStorerKey   = @cStorerKey    
         ,@cOrderKey    = @cOrderKey    
         ,@cLoadKey     = @cLoadKey    
         ,@cRefNo1      = @cRefNo1    
         ,@cRefNo2      = @cRefNo2    
         ,@cRefNo3      = @cRefNo3    
         ,@tMbolCreate  = @tMbolCreate    
         ,@cMBOLKey     = @cMBOLKey    OUTPUT    
         ,@nErrNo       = @nErrNo      OUTPUT    
         ,@cErrMsg      = @cErrMsg     OUTPUT    
    
      IF @nErrNo <> 0    
         GOTO Step_Scan_Fail    
    
      SELECT @nOrderCnt = COUNT( 1)    
      FROM dbo.MBOLDETAIL WITH (NOLOCK)    
      WHERE MbolKey = @cMBOLKey    

      IF @cBlankMBOL ='1' --(yeekung01)
         SET @cMBOLKey=''
    
    
      -- Prepare next screen var      
      SET @cOutField01 = @cFacility       
      SET @cOutField02 = @cMBOLKey    
      SET @cOutField03 = ''       
      SET @cOutField04 = ''    
          
      IF @cMbolCriteria <> ''    
      BEGIN    
         -- Enable / disable field    
         SET @cFieldAttr06 = CASE WHEN @cRefnoLabel1 = '' THEN 'O' ELSE '' END    
         SET @cFieldAttr08 = CASE WHEN @cRefnoLabel2 = '' THEN 'O' ELSE '' END    
         SET @cFieldAttr10 = CASE WHEN @cRefnoLabel3 = '' THEN 'O' ELSE '' END    
    
         -- Clear optional in field    
         SET @cInField06 = ''    
         SET @cInField08 = ''    
         SET @cInField10 = ''    
    
         -- Prepare next screen var    
         SET @cOutField05 = @cRefnoLabel1    
         SET @cOutField06 = ''    
         SET @cOutField07 = @cRefnoLabel2    
         SET @cOutField08 = ''    
         SET @cOutField09 = @cRefnoLabel3    
         SET @cOutField10 = ''    
      END    
      ELSE    
      BEGIN    
         SET @cOutField05 = ''    
         SET @cOutField06 = ''    
         SET @cOutField07 = ''    
         SET @cOutField08 = ''    
         SET @cOutField09 = ''    
         SET @cOutField10 = ''    

         SET @cFieldAttr05 = 'O' 
         SET @cFieldAttr06 = 'O'
         SET @cFieldAttr07 = 'O' 
         SET @cFieldAttr08 = 'O'
         SET @cFieldAttr09 = 'O'
         SET @cFieldAttr10 = 'O'
      END    
          
      SET @cOutField15 = @nOrderCnt      
    
      IF @cOrderKey <> ''    
         EXEC rdt.rdtSetFocusField @nMobile, 3    
    
      IF @cLoadKey <> ''    
         EXEC rdt.rdtSetFocusField @nMobile, 4    
    
      IF @cMbolCriteria <> '' AND @cRefno1 <> ''    
         EXEC rdt.rdtSetFocusField @nMobile, 6    
    
      -- Reset variable    
      SET @cOrderKey = ''      
      SET @cLoadKey = ''    
      SET @cRefNo1 = ''    
      SET @cRefNo2 = ''    
      SET @cRefNo3 = ''    
   END      
      
   IF @nInputKey = 0 -- ESC      
   BEGIN      
      IF @cMBOLKey = ''    
      BEGIN    
         -- Prepare next screen var      
         SET @cOutField01 = @cFacility      
         SET @cFieldAttr01 = CASE WHEN @cLockFacility = '1' THEN 'O' ELSE '' END    
    
         SET @cMBOLKey = ''    
         SET @cOrderKey = ''    
         SET @cLoadKey = ''    
         SET @cRefNo1 = ''    
         SET @cRefNo2 = ''    
         SET @cRefNo3 = ''    
      
         -- Go to next screen      
         SET @nScn = @nScn_Facility      
         SET @nStep = @nStep_Facility      
      END    
      ELSE    
      BEGIN    
         -- Prepare next screen var      
         SET @cOption = ''    
          
         SET @cOutField01 = @cMBOLKey      
         SET @cOutField02 = ''   -- Option    
            
         -- Go to next screen      
         SET @nScn = @nScn_CloseMbol      
         SET @nStep = @nStep_CloseMbol      
      END    
   END      
   GOTO Quit      
    
   Step_Scan_Fail:    
   BEGIN    
      SET @cOutField01 = @cFacility       
      SET @cOutField02 = @cMBOLKey    
      SET @cOutField03 = ''       
      SET @cOutField04 = ''    
          
      IF @cMbolCriteria <> ''    
      BEGIN    
         SET @cOutField05 = @cRefnoLabel1    
         SET @cOutField06 = ''    
         SET @cOutField07 = @cRefnoLabel2    
         SET @cOutField08 = ''    
         SET @cOutField09 = @cRefnoLabel3    
         SET @cOutField10 = ''    
      END    
      ELSE    
      BEGIN    
         SET @cOutField05 = ''    
         SET @cOutField06 = ''    
         SET @cOutField07 = ''    
         SET @cOutField08 = ''    
         SET @cOutField09 = ''    
         SET @cOutField10 = ''    

         SET @cFieldAttr05 = 'O' 
         SET @cFieldAttr06 = 'O'
         SET @cFieldAttr07 = 'O' 
         SET @cFieldAttr08 = 'O'
         SET @cFieldAttr09 = 'O'
         SET @cFieldAttr10 = 'O'
      END    
    
      IF @cOrderKey <> ''    
         EXEC rdt.rdtSetFocusField @nMobile, 3    
    
      IF @cLoadKey <> ''    
         EXEC rdt.rdtSetFocusField @nMobile, 4    
    
      IF @cMbolCriteria <> '' AND @cRefno1 <> ''    
         EXEC rdt.rdtSetFocusField @nMobile, 6    
   END      
END      
GOTO Quit      
      
/********************************************************************************      
Scn = 5931. Loc      
   MBOLKey  (field01)      
   Option   (field02, input)      
********************************************************************************/      
Step_CloseMbol:      
BEGIN      
   IF @nInputKey = 1 -- ENTER      
   BEGIN      
      -- Screen mapping      
      SET @cOption = @cInField02      
      
      -- Validate blank      
      IF ISNULL( @cOption, '') = ''      
      BEGIN      
         SET @nErrNo = 172108      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Option      
         GOTO Step_CloseMbol_Fail      
      END      
      
      -- Validate option      
      IF @cOption NOT IN ( '1', '2')      
      BEGIN      
         SET @nErrNo = 172109      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option      
         GOTO Step_CloseMbol_Fail      
      END      
    
      IF @cOption = '1'    
      BEGIN    
         IF ISNULL( @cMBOLKey, '') = ''    
         BEGIN      
            SET @nErrNo = 172110      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No MBOLKey      
            GOTO Step_CloseMbol_Fail      
         END      
    
         IF @cCloseMbol = '1'    
         BEGIN    
            UPDATE dbo.MBOL SET     
               [STATUS] = '5'    
            WHERE MbolKey = @cMBOLKey    
                
            IF @@ERROR <> 0    
            BEGIN      
               SET @nErrNo = 172111      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close MBOL Fail      
               GOTO Step_CloseMbol_Fail      
            END      
         END    
             
         -- Prepare next screen var      
         SET @cOutField01 = @cFacility    
         SET @cFieldAttr01 = CASE WHEN @cLockFacility = '1' THEN 'O' ELSE '' END    
    
         SET @cMBOLKey = ''    
         SET @cOrderKey = ''    
         SET @cLoadKey = ''    
         SET @cRefNo1 = ''    
         SET @cRefNo2 = ''    
         SET @cRefNo3 = ''    
    
         -- Go to next screen      
         SET @nScn = @nScn_Facility      
         SET @nStep = @nStep_Facility      
      END          
      ELSE    
      BEGIN    
         -- Prepare next screen var      
         SET @cOutField01 = @cFacility      
         SET @cOutField02 = @cMBOLKey       
         SET @cOutField03 = ''    
         SET @cOutField04 = ''    
         SET @cOutField05 = @cRefnoLabel1    
         SET @cOutField06 = ''     
         SET @cOutField07 = @cRefnoLabel2    
         SET @cOutField08 = ''    
         SET @cOutField09 = @cRefnoLabel3    
         SET @cOutField10 = ''    
         SET @cOutField15 = @nOrderCnt      
    
         -- Go to next screen      
         SET @nScn = @nScn_Scan      
         SET @nStep = @nStep_Scan      
      END    

      -- Extended Update      
      IF @cExtendedUpdateSP <> ''      
      BEGIN      
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')      
         BEGIN      
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +      
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +       
               ' @cMBOLKey, @cOrderKey, @cLoadKey, @cRefNo1, @cRefNo2, @cRefNo3, @tExtUpdate, ' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '                
      
            SET @cSQLParam =      
               ' @nMobile        INT,           ' +      
               ' @nFunc          INT,           ' +      
               ' @cLangCode      NVARCHAR( 3),  ' +      
               ' @nStep          INT,           ' +      
               ' @nInputKey      INT,           ' +      
               ' @cFacility      NVARCHAR( 5),  ' +      
               ' @cStorerKey     NVARCHAR( 15), ' +      
               ' @cMBOLKey       NVARCHAR( 10), ' +    
               ' @cOrderKey      NVARCHAR( 10), ' +      
               ' @cLoadKey       NVARCHAR( 10), ' +      
               ' @cRefNo1        NVARCHAR( 20), ' +      
               ' @cRefNo2        NVARCHAR( 20), ' +   
               ' @cRefNo3        NVARCHAR( 20), ' +    
               ' @tExtUpdate     VariableTable READONLY, ' +       
               ' @nErrNo         INT           OUTPUT, ' +      
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '      
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,       
               @cMBOLKey, @cOrderKey, @cLoadKey, @cRefNo1, @cRefNo2, @cRefNo3, @tExtUpdate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT 
      
            IF @nErrNo <> 0       
            BEGIN    
               -- Go to next screen      
               SET @nScn = @nScn_CloseMbol      
               SET @nStep = @nStep_CloseMbol      
    
               GOTO Step_CloseMbol_Fail    
            END      
         END      
      END      
   END      
      
   IF @nInputKey = 0 -- ESC      
   BEGIN      
      -- Prepare next screen var      
      SET @cOutField01 = @cFacility    
      SET @cFieldAttr01 = CASE WHEN @cLockFacility = '1' THEN 'O' ELSE '' END    
    
      SET @cMBOLKey = ''    
      SET @cOrderKey = ''    
      SET @cLoadKey = ''    
      SET @cRefNo1 = ''    
      SET @cRefNo2 = ''    
      SET @cRefNo3 = ''    
    
      -- Go to next screen      
      SET @nScn = @nScn_Facility      
      SET @nStep = @nStep_Facility      
   END      
   GOTO Quit      
      
   Step_CloseMbol_Fail:      
   BEGIN      
      SET @cOption = ''      
      
      SET @cOutField02 = ''      
   END      
END      
GOTO Quit      
    
/***********************************************************************************    
Step 4. Scn = 5933. Capture data screen    
   Data1    (field01)    
   Input1   (field02, input)    
   .    
   .    
   .    
   Data5    (field09)    
   Input5   (field10, input)    
***********************************************************************************/    
Step_CaptureData:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cData1 = CASE WHEN @cFieldAttr02 = '' THEN @cInField02 ELSE @cOutField02 END    
      SET @cData2 = CASE WHEN @cFieldAttr04 = '' THEN @cInField04 ELSE @cOutField04 END    
      SET @cData3 = CASE WHEN @cFieldAttr06 = '' THEN @cInField06 ELSE @cOutField06 END    
      SET @cData4 = CASE WHEN @cFieldAttr08 = '' THEN @cInField08 ELSE @cOutField08 END    
      SET @cData5 = CASE WHEN @cFieldAttr10 = '' THEN @cInField10 ELSE @cOutField10 END    
    
      -- Retain value    
      SET @cOutField02 = @cInField02    
      SET @cOutField04 = @cInField04    
      SET @cOutField06 = @cInField06    
      SET @cOutField08 = @cInField08    
      SET @cOutField10 = @cInField10    
    
      EXEC rdt.rdt_MbolCreation_CaptureInfo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 'UPDATE',     
         @cMBOLKey, @cOrderKey, @cLoadKey, @cRefNo1, @cRefNo2, @cRefNo3, @cData1, @cData2, @cData3, @cData4, @cData5,     
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,       
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,       
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,       
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,       
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,       
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,      
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,      
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,      
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,      
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,      
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,     
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,     
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,     
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,     
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,     
         @tCaptureVar,     
         @nErrNo  OUTPUT,     
         @cErrMsg OUTPUT    
      IF @nErrNo <> 0    
         GOTO Quit    
    
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN MbolCreation_CapData -- For rollback or commit only our own transaction
      
      SET @nErrNo = 0
      EXEC rdt.rdt_MbolCreation    
          @nMobile      = @nMobile    
         ,@nFunc        = @nFunc    
         ,@cLangCode    = @cLangCode    
         ,@nStep        = @nStep    
         ,@nInputKey    = @nInputKey    
         ,@cFacility    = @cFacility    
         ,@cStorerKey   = @cStorerKey    
         ,@cOrderKey    = @cOrderKey    
         ,@cLoadKey     = @cLoadKey    
         ,@cRefNo1      = @cRefNo1    
         ,@cRefNo2      = @cRefNo2    
         ,@cRefNo3      = @cRefNo3    
         ,@tMbolCreate  = @tMbolCreate    
         ,@cMBOLKey     = @cMBOLKey    OUTPUT    
         ,@nErrNo       = @nErrNo      OUTPUT    
         ,@cErrMsg      = @cErrMsg     OUTPUT    
    
      IF @nErrNo <> 0    
         GOTO RollBackTran_CapData    

      -- Extended Update      
      IF @cExtendedUpdateSP <> ''      
      BEGIN      
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')      
         BEGIN      
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +      
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +       
               ' @cMBOLKey, @cOrderKey, @cLoadKey, @cRefNo1, @cRefNo2, @cRefNo3, @tExtUpdate, ' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '                
      
            SET @cSQLParam =      
               ' @nMobile        INT,           ' +      
               ' @nFunc          INT,           ' +      
               ' @cLangCode      NVARCHAR( 3),  ' +      
               ' @nStep          INT,           ' +      
               ' @nInputKey      INT,           ' +      
               ' @cFacility      NVARCHAR( 5),  ' +      
               ' @cStorerKey     NVARCHAR( 15), ' +      
               ' @cMBOLKey       NVARCHAR( 10), ' +    
               ' @cOrderKey      NVARCHAR( 10), ' +      
               ' @cLoadKey       NVARCHAR( 10), ' +      
               ' @cRefNo1        NVARCHAR( 20), ' +      
               ' @cRefNo2        NVARCHAR( 20), ' +   
               ' @cRefNo3        NVARCHAR( 20), ' +    
               ' @tExtUpdate     VariableTable READONLY, ' +       
               ' @nErrNo         INT           OUTPUT, ' +      
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '      
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,      
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,       
               @cMBOLKey, @cOrderKey, @cLoadKey, @cRefNo1, @cRefNo2, @cRefNo3, @tExtUpdate, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT 
      
            IF @nErrNo <> 0       
               GOTO Quit_CapData
         END      
      END      

      COMMIT TRAN MbolCreation_CapData -- Only commit change made here
      GOTO Quit_CapData

      RollBackTran_CapData:
         ROLLBACK TRAN MbolCreation_CapData -- Only rollback change made here

      Quit_CapData:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

      IF @nErrNo <> 0
         GOTO Step_CaptureData_Quit

      -- Enable field    
      SET @cFieldAttr02 = ''    
      SET @cFieldAttr04 = ''    
      SET @cFieldAttr06 = ''    
      SET @cFieldAttr08 = ''    
      SET @cFieldAttr10 = ''    

      SELECT @nOrderCnt = COUNT( 1)    
      FROM dbo.MBOLDETAIL WITH (NOLOCK)    
      WHERE MbolKey = @cMBOLKey    
    
      -- Prepare next screen var  
      SET @cOutField01 = @cFacility  
      SET @cOutField02 = @cMBOLKey   
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField15 = @nOrderCnt  

      IF @cMbolCriteria <> ''
      BEGIN
         -- Enable / disable field    
         SET @cFieldAttr06 = CASE WHEN @cRefnoLabel1 = '' THEN 'O' ELSE '' END    
         SET @cFieldAttr08 = CASE WHEN @cRefnoLabel2 = '' THEN 'O' ELSE '' END    
         SET @cFieldAttr10 = CASE WHEN @cRefnoLabel3 = '' THEN 'O' ELSE '' END    
    
         -- Clear optional in field    
         SET @cInField06 = ''    
         SET @cInField08 = ''    
         SET @cInField10 = ''    
    
         -- Prepare next screen var    
         SET @cOutField05 = @cRefnoLabel1    
         SET @cOutField06 = ''    
         SET @cOutField07 = @cRefnoLabel2    
         SET @cOutField08 = ''    
         SET @cOutField09 = @cRefnoLabel3    
         SET @cOutField10 = ''    
      END
      ELSE
      BEGIN
      	SET @cOutField05 = ''
      	SET @cOutField06 = ''
      	SET @cOutField07 = ''
      	SET @cOutField08 = ''
      	SET @cOutField09 = ''
      	SET @cOutField10 = ''

    	   SET @cFieldAttr05 = 'O' 
    	   SET @cFieldAttr06 = 'O'
    	   SET @cFieldAttr07 = 'O' 
    	   SET @cFieldAttr08 = 'O'
    	   SET @cFieldAttr09 = 'O'
    	   SET @cFieldAttr10 = 'O'
      END
    
      IF @cOrderKey <> ''    
         EXEC rdt.rdtSetFocusField @nMobile, 3    
    
      IF @cLoadKey <> ''    
         EXEC rdt.rdtSetFocusField @nMobile, 4    
    
      IF @cMbolCriteria <> '' AND @cRefno1 <> ''    
         EXEC rdt.rdtSetFocusField @nMobile, 6    
    
      -- Reset variable    
      SET @cOrderKey = ''      
      SET @cLoadKey = ''    
      SET @cRefNo1 = ''    
      SET @cRefNo2 = ''    
      SET @cRefNo3 = ''    
    
      -- Go to next screen    
      SET @nScn = @nScn_Scan    
      SET @nStep = @nStep_Scan    
   END    
    
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Enable field
      SET @cFieldAttr02 = ''
      SET @cFieldAttr04 = ''
      SET @cFieldAttr06 = ''
      SET @cFieldAttr08 = ''
      SET @cFieldAttr10 = ''

      SET @cOrderKey = ''  
      SET @cLoadKey = ''  
      SET @cRefNo1 = ''  
      SET @cRefNo2 = ''
      SET @cRefNo3 = ''
      
      EXEC rdt.rdtSetFocusField @nMobile, 3

      -- Prepare next screen var  
      SET @cOutField01 = @cFacility   
      SET @cOutField02 = @cMBOLKey
      SET @cOutField03 = ''   
      SET @cOutField04 = ''
      
      IF @cMbolCriteria <> ''
      BEGIN
         SET @cOutField05 = @cRefnoLabel1
         SET @cOutField06 = ''
         SET @cOutField07 = @cRefnoLabel2
         SET @cOutField08 = ''
         SET @cOutField09 = @cRefnoLabel3
         SET @cOutField10 = ''
      END
      ELSE
      BEGIN
      	SET @cOutField05 = ''
      	SET @cOutField06 = ''
      	SET @cOutField07 = ''
      	SET @cOutField08 = ''
      	SET @cOutField09 = ''
      	SET @cOutField10 = ''

    	   SET @cFieldAttr05 = 'O' 
    	   SET @cFieldAttr06 = 'O'
    	   SET @cFieldAttr07 = 'O' 
    	   SET @cFieldAttr08 = 'O'
    	   SET @cFieldAttr09 = 'O'
    	   SET @cFieldAttr10 = 'O'
      END

      IF @cOrderKey <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 3

      IF @cLoadKey <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 4

      IF @cMbolCriteria <> '' AND @cRefno1 <> ''
         EXEC rdt.rdtSetFocusField @nMobile, 6

      -- Go to next screen  
      SET @nScn = @nScn_Scan  
      SET @nStep = @nStep_Scan   
   END
    
   Step_CaptureData_Quit:    
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
      
      V_Integer1 = @nOrderCnt,      
    
      V_OrderKey = @cOrderKey,    
      V_LoadKey  = @cLoadKey,              
      V_String1  = @cExtendedUpdateSP,      
      V_String2  = @cExtendedValidateSP,    
      V_String3  = @cExtendedInfoSP,      
      V_String4  = @cMBOLKey,        
      V_String5  = @cCloseMbol,    
      V_String6  = @cRefNo1,        
      V_String7  = @cRefNo2,    
      V_String8  = @cRefNo3,    
      V_String9  = @cLockFacility,    
      V_String10 = @cRefNoLookupColumn,    
      V_String11 = @cCaptureInfoSP,    
      V_String12 = @cMbolCriteria,    
      V_String13 = @cRefnoLabel1,    
      V_String14 = @cRefnoLabel2,    
      V_String15 = @cRefnoLabel3, 
      V_String16 = @cBlankMBOL,
          
      V_String41 = @cData1,    
      V_String42 = @cData2,    
      V_String43 = @cData3,    
      V_String44 = @cData4,    
      V_String45 = @cData5,    
          
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