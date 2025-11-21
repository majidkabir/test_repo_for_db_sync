SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtfnc_ActivityTrack                               */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: To Track the time the Driver Check in At Office             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 2022-03-25   1.0  yeekung    WMS-18920 Created                       */
/* 2024-05-27   1.1  Cuize      FCR-242                                 */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_ActivityTrack] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

-- Misc variables
DECLARE
   @b_success      INT,
   @n_err          INT,
   @c_errmsg       NVARCHAR( 250),
   @i              INT,
   @nTask          INT,
   @cParentScn     NVARCHAR( 3),
   @cOption        NVARCHAR( 1),
   @cXML           NVARCHAR( 4000) -- To allow double byte data for e.g. SKU desc

-- RDT.RDTMobRec variables
DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,

   @nPrevScn            INT,
   @nPrevStep           INT,

   @cStorerKey          NVARCHAR( 15),
   @cUserName           NVARCHAR( 18),
   @cFacility           NVARCHAR( 5),

   @cContainerNo        NVARCHAR( 20),
   @cUserID             NVARCHAR( 18),
   @cClickCnt           NVARCHAR(  1),

   @cErrMsg1            NVARCHAR(20),
   @cErrMsg2            NVARCHAR(20),
   @cErrMsg3            NVARCHAR(20),
   @cErrMsg4            NVARCHAR(20),

   @cMenuOption         NVARCHAR(1),

   @cSQL                NVARCHAR(1000), -- (ChewKP01)
   @cSQLParam           NVARCHAR(1000), -- (ChewKP01)
   @cExtendedUpdateSP   NVARCHAR(30),   -- (ChewKP01)
   @cAppointmentNo      NVARCHAR(20),   -- (ChewKP01)
   @cInput01            NVARCHAR(30),   -- (ChewKP01)
   @cInput02            NVARCHAR(30),   -- (ChewKP01)
   @cInput03            NVARCHAR(30),   -- (ChewKP01)
   @cInput04            NVARCHAR(30),   -- (ChewKP01)
   @cActionType         NVARCHAR(10),   -- (ChewKP01)
   @cRefNo1             NVARCHAR(20),   -- (ChewKP01)
   @cDefaultOption      NVARCHAR(1),    -- (ChewKP01)
   @cDefaultCursor      NVARCHAR(1),    -- (ChewKP01)
   @cFocusStep2      NVARCHAR(1),    -- (ChewKP01)
   @cExtendedValidateSP NVARCHAR(30),   -- (cc01)
   @cMBOLKey            NVARCHAR( 10),  -- (cc02)
   @cSP                 NVARCHAR(40),
   @cExtendedinfo       NVARCHAR(20),
   @cActivityStatus     NVARCHAR(20),
   @cGroup              NVARCHAR(20),

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


   @cContainerNo     = V_String1,
   @cAppointmentNo   = V_String2,
   @cExtendedUpdateSP = V_String3,
   @cExtendedValidateSP = V_String4, --(cc01)
   @cMenuOption       = V_String5,

   @cActionType       = V_String8,
   @cRefNo1           = V_String9,
   @cDefaultOption    = V_String10,
   @cDefaultCursor    = V_String11,
   @cSP               = V_String12,  --(cc02)
   @cExtendedinfo     = V_String13,
   @cActivityStatus   = V_String14,
   @cFocusStep2       = V_String15,

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


IF @nFunc = 652   -- (james01)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_Start       -- Menu. Func = 857
   IF @nStep = 1  GOTO Step_1           -- Scn = 2134. Container #
   IF @nStep = 2  GOTO Step_2           -- Scn = 2134. Container #
   IF @nStep = 3  GOTO Step_3           -- Scn = 2135. Dynamic Display Field
   IF @nStep = 4  GOTO Step_4           -- Scn = 2136. Dynamic Input Field
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step_Start. Func = 652
********************************************************************************/
Step_Start:
BEGIN

   -- Prepare label screen var
   SET @cOutField01 = ''
   SET @cOutField02 = ''

    -- (ChewKP01)
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'
   BEGIN
      SET @cExtendedUpdateSP = ''
   END

   -- (ChewKP01)
   SET @cDefaultOption = ''
   SET @cDefaultOption = rdt.RDTGetConfig( @nFunc, 'DefaultOption', @cStorerKey)
   IF @cDefaultOption = '0'
   BEGIN
      SET @cDefaultOption = ''
   END

   SET @cDefaultCursor = ''
   SET @cDefaultCursor = rdt.RDTGetConfig( @nFunc, 'DefaultCursor', @cStorerKey)
   IF @cDefaultOption = '0'
   BEGIN
      SET @cDefaultOption = ''
   END

   SET @cFocusStep2= ''
   SET @cFocusStep2 = rdt.RDTGetConfig( @nFunc, 'FocusStep2', @cStorerKey)
   IF @cFocusStep2 = '0'
   BEGIN
      SET @cFocusStep2 = ''
   END
   
   -- (cc01)
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
   BEGIN
      SET @cExtendedValidateSP = ''
   END

   SELECT @cGroup=OpsPosition
   FROM rdt.rdtuser (NOLOCK)
   WHERE USERNAME=@cusername
   
   -- Prepare next screen var        
   SELECT @cOutField01='1-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='1'  AND CHARINDEX(@cGroup,short)<>'0'     
   SELECT @cOutField02='2-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='2'  AND CHARINDEX(@cGroup,short)<>'0'     
   SELECT @cOutField03='3-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='3'  AND CHARINDEX(@cGroup,short)<>'0'     
   SELECT @cOutField04='4-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='4'  AND CHARINDEX(@cGroup,short)<>'0'     
   SELECT @cOutField05='5-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='5'  AND CHARINDEX(@cGroup,short)<>'0'     
   SELECT @cOutField06='6-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='6'  AND CHARINDEX(@cGroup,short)<>'0'     
   SELECT @cOutField07='7-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='7'  AND CHARINDEX(@cGroup,short)<>'0'     
   SELECT @cOutField08='8-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='8'  AND CHARINDEX(@cGroup,short)<>'0'     
   SELECT @cOutField09='9-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='9'  AND CHARINDEX(@cGroup,short)<>'0'      

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
   SET @cFieldAttr11 = ''
   SET @cFieldAttr12 = ''
   SET @cFieldAttr13 = ''
   SET @cFieldAttr14 = ''
   SET @cFieldAttr15 = ''

  EXEC RDT.rdt_STD_EventLog
     @cActionType   = '1', -- Sign In Function
     @cUserID       = @cUserName,
     @nMobileNo     = @nMobile,
     @nFunctionID   = @nFunc,
     @cFacility     = @cFacility,
     @cStorerKey    = @cStorerKey,
     @cRefNo4       = @cMenuOption,
     @nStep         = @nStep

   EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor

   -- Go to Label screen
   SET @nScn = 6050
   SET @nStep = 1
   GOTO Quit

   Step_Start_Fail:
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
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
    
      SET @cOption=@cInField10    
    
      IF ISNULL(@cOption,'')=''    
      BEGIN    
         SET @nErrNo = 185351        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong Option       
         GOTO Step1_Fail        
      END  
      
      IF (@cOption='1' and @cOutField01='') OR
         (@cOption='2' and @cOutField02='') OR
         (@cOption='3' and @cOutField03='') OR
         (@cOption='4' and @cOutField04='') OR
         (@cOption='5' and @cOutField05='') OR
         (@cOption='6' and @cOutField06='') OR
         (@cOption='7' and @cOutField07='') OR
         (@cOption='8' and @cOutField08='') OR
         (@cOption='9' and @cOutField09='') 
      BEGIN    
         SET @nErrNo = 185358        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option       
         GOTO Step1_Fail        
      END  




      -- Get even to capture           
      SELECT                   
         @cSP           = Long       
      FROM dbo.CodeLkup WITH (NOLOCK)         
      WHERE StorerKey = @cStorerKey        
         AND ListName = 'RDTAcTrack'    
         AND code=@cOption    
          
      -- Check SP setup        
      IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSP AND type = 'P')        
      BEGIN        
         SET @nErrNo = 185052        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SP NotSetup        
         GOTO step1_Fail        
      END   
      
      SET @cMenuOption=@cOption  
    
      SET @cOutField01= ''
      SET @cOutField02= ''
      SET @cOutField03= ''
      SET @cOutField04= ''
      SET @cOutField05= ''
      SET @cOutField06= ''
      SET @cOutField07= ''
      SET @cOutField08= ''
      SET @cOutField09= ''
      SET @cOutField10= ''
      
      -- Execute label/report stored procedure        
      IF @cSP <> ''        
      BEGIN        
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption,@cRefNo1,@cInput01,@cInput02,@cInput03,@cInput04,@cActivityStatus,' +        
               ' @nStep OUTPUT,@nScn OUTPUT,@cOutField01 OUTPUT,@cOutField02 OUTPUT,@cOutField03 OUTPUT ' +        
               ' ,@cOutField04 OUTPUT ,@cOutField05 OUTPUT,@cOutField06 OUTPUT,@cOutField07 OUTPUT,@cOutField08 OUTPUT' +        
               ' ,@cOutField09 OUTPUT,@cOutField10 OUTPUT,@cOutField11 OUTPUT,@cExtendedinfo OUTPUT,' +         
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
               ' @nMobile       INT,           ' +        
               ' @nFunc         INT,           ' +        
               ' @cLangCode     NVARCHAR( 3),  ' +        
               ' @nInputKey     INT,           ' +         
               ' @cFacility     NVARCHAR( 5),  ' +        
               ' @cStorerKey    NVARCHAR( 15), ' +         
               ' @cOption       NVARCHAR( 1),  ' +    
               ' @cRefNo1       NVARCHAR( 20), ' +
               ' @cInput01      NVARCHAR( 20), ' +
               ' @cInput02      NVARCHAR( 20), ' +
               ' @cInput03      NVARCHAR( 20), ' +
               ' @cInput04      NVARCHAR( 20), ' +
               ' @cActivityStatus NVARCHAR(20), ' +
               ' @nStep         INT           OUTPUT, ' +      
               ' @nScn          INT           OUTPUT, ' +        
               ' @cOutField01  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField02  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField03  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField04  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField05  NVARCHAR( 20) OUTPUT, ' +       
               ' @cOutField06  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField07  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField08  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField09  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField10  NVARCHAR( 20) OUTPUT, ' +  
               ' @cOutField11  NVARCHAR( 20) OUTPUT, ' +  
               ' @cExtendedinfo NVARCHAR(20)  OUTPUT, ' +        
               ' @nErrNo        INT           OUTPUT, ' +        
               ' @cErrMsg       NVARCHAR( 20) OUTPUT  '        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
                @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption,@cRefNo1,@cInput01,@cInput02,@cInput03,@cInput04,@cActivityStatus    
                ,@nStep OUTPUT,@nScn OUTPUT,@cOutField01 OUTPUT,@cOutField02 OUTPUT,@cOutField03 OUTPUT          
                ,@cOutField04 OUTPUT ,@cOutField05 OUTPUT,@cOutField06 OUTPUT,@cOutField07 OUTPUT,@cOutField08 OUTPUT         
                ,@cOutField09 OUTPUT,@cOutField10 OUTPUT,@cOutField11 OUTPUT,@cExtendedinfo OUTPUT,         
                @nErrNo OUTPUT, @cErrMsg OUTPUT             
         END        
        
         IF @nErrNo <> 0        
            GOTO Quit        
      
         SET @cOption = ''      
      END 
      
      --CYU027
      IF @cFocusStep2 = '' OR @cFocusStep2 = '0'
         SET @cFocusStep2 = 3
      
       EXEC rdt.rdtSetFocusField @nMobile, @cFocusStep2
   
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
step 2
Scn = 6051. 
   Container # screen
   CONTAINER NO       (field01)
***********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cContainerNo   = RTRIM(@cInField02)
      SET @cAppointmentNo = RTRIM(@cInField03)
      SET @cOption        = RTRIM(@cInField06)

      IF ISNULL(RTRIM(@cContainerNo), '') = '' AND ISNULL(RTRIM(@cAppointmentNo), '') = ''
      BEGIN
         SET @nErrNo = 185353
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Atleast1InputReq
         GOTO Step_2_Fail
      END

      IF @cContainerNo <> ''
      BEGIN
         SET @cRefNo1  = ISNULL(RTRIM(@cContainerNo), '' )
      END
      ELSE
      BEGIN
         SET @cRefNo1  = ISNULL(RTRIM(@cAppointmentNo), '' )
      END

      IF ISNULL(RTRIM(@cOption), '') = ''
      BEGIN
         SET @nErrNo = 185354
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- OptionReq
         GOTO Step_2_Fail
      END

      IF ISNULL(RTRIM(@cOption), '') NOT IN ( '1' , '9' )
      BEGIN
         SET @nErrNo = 185355
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidOption
         GOTO Step_2_Fail
      END

      SET @cActivityStatus=@cOption

      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
                        ' @cContainerNo, @cAppointmentNo, @cMenuOption, @cActionType, @cRefNo1, @cDefaultOption, @cDefaultCursor, @cActivityStatus, ' +
                        ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
                    '@nMobile             INT,                    ' +
                    '@nFunc               INT,                    ' +
                    '@cLangCode           NVARCHAR( 3),           ' +
                    '@nStep               INT,                    ' +
                    '@nInputKey           INT,                    ' +
                    '@cStorerKey          NVARCHAR( 15),          ' +
                    '@cFacility           NVARCHAR( 5),           ' +
                    '@cContainerNo        NVARCHAR( 20),          ' +
                    '@cAppointmentNo      NVARCHAR( 20),          ' +
                    '@cMenuOption         NVARCHAR( 10),          ' +
                    '@cActionType         NVARCHAR( 10),          ' +
                    '@cRefNo1             NVARCHAR( 10),          ' +
                    '@cDefaultOption      NVARCHAR( 10),          ' +
                    '@cDefaultCursor      NVARCHAR( 10),          ' +
                    '@cActivityStatus     NVARCHAR( 20),          ' +
                    '@nErrNo              INT           OUTPUT,   ' +
                    '@cErrMsg             NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
                 @cContainerNo, @cAppointmentNo, @cMenuOption, @cActionType, @cRefNo1, @cDefaultOption, @cDefaultCursor, @cActivityStatus,
                 @nErrNo OUTPUT, @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO QUIT
         END
      END

      -- Execute label/report stored procedure        
      IF @cSP <> ''        
      BEGIN        
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption,@cRefNo1,@cInput01,@cInput02,@cInput03,@cInput04,@cActivityStatus,' +        
               ' @nStep OUTPUT,@nScn OUTPUT,@cOutField01 OUTPUT,@cOutField02 OUTPUT,@cOutField03 OUTPUT ' +        
               ' ,@cOutField04 OUTPUT ,@cOutField05 OUTPUT,@cOutField06 OUTPUT,@cOutField07 OUTPUT,@cOutField08 OUTPUT' +        
               ' ,@cOutField09 OUTPUT,@cOutField10 OUTPUT,@cOutField11 OUTPUT,@cExtendedinfo OUTPUT,' +         
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
               ' @nMobile       INT,           ' +        
               ' @nFunc         INT,           ' +        
               ' @cLangCode     NVARCHAR( 3),  ' +        
               ' @nInputKey     INT,           ' +         
               ' @cFacility     NVARCHAR( 5),  ' +        
               ' @cStorerKey    NVARCHAR( 15), ' +         
               ' @cOption       NVARCHAR( 1),  ' +    
               ' @cRefNo1       NVARCHAR( 20), ' +
               ' @cInput01      NVARCHAR( 20), ' +
               ' @cInput02      NVARCHAR( 20), ' +
               ' @cInput03      NVARCHAR( 20), ' +
               ' @cInput04      NVARCHAR( 20), ' +
               ' @cActivityStatus NVARCHAR(20), ' +
               ' @nStep         INT           OUTPUT, ' +      
               ' @nScn          INT           OUTPUT, ' +        
               ' @cOutField01  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField02  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField03  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField04  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField05  NVARCHAR( 20) OUTPUT, ' +       
               ' @cOutField06  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField07  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField08  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField09  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField10  NVARCHAR( 20) OUTPUT, ' +  
               ' @cOutField11  NVARCHAR( 20) OUTPUT, ' +  
               ' @cExtendedinfo NVARCHAR(20)  OUTPUT, ' +        
               ' @nErrNo        INT           OUTPUT, ' +        
               ' @cErrMsg       NVARCHAR( 20) OUTPUT  '        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
                @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption,@cRefNo1,@cInput01,@cInput02,@cInput03,@cInput04,@cActivityStatus    
                ,@nStep OUTPUT,@nScn OUTPUT,@cOutField01 OUTPUT,@cOutField02 OUTPUT,@cOutField03 OUTPUT          
                ,@cOutField04 OUTPUT ,@cOutField05 OUTPUT,@cOutField06 OUTPUT,@cOutField07 OUTPUT,@cOutField08 OUTPUT         
                ,@cOutField09 OUTPUT,@cOutField10 OUTPUT,@cOutField11 OUTPUT,@cExtendedinfo OUTPUT,         
                @nErrNo OUTPUT, @cErrMsg OUTPUT             
         END        
        
         IF @nErrNo <> 0        
            GOTO Quit        
      
         SET @cOption = ''      
      END

      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedUpdateSP) +
                              ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +
                              ' @cContainerNo, @cAppointmentNo, @cMenuOption, @cActionType, @cRefNo1, @cDefaultOption, @cDefaultCursor, @cActivityStatus, ' +
                              ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
                          '@nMobile             INT,           ' +
                          '@nFunc               INT,           ' +
                          '@cLangCode           NVARCHAR( 3),  ' +
                          '@nStep               INT,           ' +
                          '@nInputKey           INT,           ' +
                          '@cStorerKey          NVARCHAR( 15), ' +
                          '@cFacility           NVARCHAR( 5),  ' +
                          '@cContainerNo        NVARCHAR( 20), ' +
                          '@cAppointmentNo      NVARCHAR( 20), ' +
                          '@cMenuOption         NVARCHAR( 10), ' +
                          '@cActionType         NVARCHAR( 10), ' +
                          '@cRefNo1             NVARCHAR( 10), ' +
                          '@cDefaultOption      NVARCHAR( 10), ' +
                          '@cDefaultCursor      NVARCHAR( 10), ' +
                          '@cActivityStatus     NVARCHAR( 20), ' +
                          '@nErrNo              INT           OUTPUT, ' +
                          '@cErrMsg             NVARCHAR( 20) OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                       @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,
                       @cContainerNo, @cAppointmentNo, @cMenuOption, @cActionType, @cRefNo1, @cDefaultOption, @cDefaultCursor, @cActivityStatus,
                       @nErrNo OUTPUT, @cErrMsg OUTPUT
            IF @nErrNo <> 0
               GOTO QUIT
         END
      END

   END

   IF @nInputKey = 0 -- ESC
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

      SELECT @cGroup=OpsPosition
      FROM rdt.rdtuser (NOLOCK)
      WHERE USERNAME=@cusername
   
      -- Prepare next screen var        
      SELECT @cOutField01='1-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='1'  AND CHARINDEX(@cGroup,short)<>'0'     
      SELECT @cOutField02='2-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='2'  AND CHARINDEX(@cGroup,short)<>'0'     
      SELECT @cOutField03='3-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='3'  AND CHARINDEX(@cGroup,short)<>'0'     
      SELECT @cOutField04='4-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='4'  AND CHARINDEX(@cGroup,short)<>'0'     
      SELECT @cOutField05='5-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='5'  AND CHARINDEX(@cGroup,short)<>'0'     
      SELECT @cOutField06='6-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='6'  AND CHARINDEX(@cGroup,short)<>'0'     
      SELECT @cOutField07='7-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='7'  AND CHARINDEX(@cGroup,short)<>'0'     
      SELECT @cOutField08='8-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='8'  AND CHARINDEX(@cGroup,short)<>'0'     
      SELECT @cOutField09='9-'+Description FROM dbo.CodeLkup WITH (NOLOCK) WHERE StorerKey = @cStorerKey  AND ListName = 'RDTAcTrack' AND code='9'  AND CHARINDEX(@cGroup,short)<>'0'      
           
      -- Back to menu
      SET @nScn  = @nScn -1
      SET @nStep = @nStep - 1

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
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      IF @cOption =''
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 6
         SET @cOutField03=@cInField03
      END
      ELSE
      BEGIN
         SET @cOutField02  = ''
         SET @cOutField03  = ''
         SET @cOutField06  = ''
         SET @cContainerNo = ''

         EXEC rdt.rdtSetFocusField @nMobile, 3
      END
   END
 END
GOTO Quit

/********************************************************************************
Step 3. Scn = 6052.

********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = '1' --ENTER
   BEGIN
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
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''

      -- Execute label/report stored procedure        
      IF @cSP <> ''        
      BEGIN        
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption,@cRefNo1,@cInput01,@cInput02,@cInput03,@cInput04,@cActivityStatus,' +        
               ' @nStep OUTPUT,@nScn OUTPUT,@cOutField01 OUTPUT,@cOutField02 OUTPUT,@cOutField03 OUTPUT ' +        
               ' ,@cOutField04 OUTPUT ,@cOutField05 OUTPUT,@cOutField06 OUTPUT,@cOutField07 OUTPUT,@cOutField08 OUTPUT' +        
               ' ,@cOutField09 OUTPUT,@cOutField10 OUTPUT,@cOutField11 OUTPUT,@cExtendedinfo OUTPUT,' +         
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
               ' @nMobile       INT,           ' +        
               ' @nFunc         INT,           ' +        
               ' @cLangCode     NVARCHAR( 3),  ' +        
               ' @nInputKey     INT,           ' +         
               ' @cFacility     NVARCHAR( 5),  ' +        
               ' @cStorerKey    NVARCHAR( 15), ' +         
               ' @cOption       NVARCHAR( 1),  ' +    
               ' @cRefNo1       NVARCHAR( 20), ' +
               ' @cInput01      NVARCHAR( 20), ' +
               ' @cInput02      NVARCHAR( 20), ' +
               ' @cInput03      NVARCHAR( 20), ' +
               ' @cInput04      NVARCHAR( 20), ' +
               ' @cActivityStatus NVARCHAR(20), ' +
               ' @nStep         INT           OUTPUT, ' +      
               ' @nScn          INT           OUTPUT, ' +        
               ' @cOutField01  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField02  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField03  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField04  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField05  NVARCHAR( 20) OUTPUT, ' +       
               ' @cOutField06  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField07  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField08  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField09  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField10  NVARCHAR( 20) OUTPUT, ' +  
               ' @cOutField11  NVARCHAR( 20) OUTPUT, ' +  
               ' @cExtendedinfo NVARCHAR(20)  OUTPUT, ' +        
               ' @nErrNo        INT           OUTPUT, ' +        
               ' @cErrMsg       NVARCHAR( 20) OUTPUT  '        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
                @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption,@cRefNo1,@cInput01,@cInput02,@cInput03,@cInput04,@cActivityStatus    
                ,@nStep OUTPUT,@nScn OUTPUT,@cOutField01 OUTPUT,@cOutField02 OUTPUT,@cOutField03 OUTPUT          
                ,@cOutField04 OUTPUT ,@cOutField05 OUTPUT,@cOutField06 OUTPUT,@cOutField07 OUTPUT,@cOutField08 OUTPUT         
                ,@cOutField09 OUTPUT,@cOutField10 OUTPUT,@cOutField11 OUTPUT,@cExtendedinfo OUTPUT,         
                @nErrNo OUTPUT, @cErrMsg OUTPUT             
         END        
        
         IF @nErrNo <> 0        
            GOTO Quit        
      
         SET @cOption = ''      
      END   

      --SET @cOutField01 = ''
      --SET @cOutField02 = ''
   END

   IF @nInputKey = 0   --ESC
   BEGIN
      -- Execute label/report stored procedure        
      IF @cSP <> ''        
      BEGIN        
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption,@cRefNo1,@cInput01,@cInput02,@cInput03,@cInput04,@cActivityStatus,' +        
               ' @nStep OUTPUT,@nScn OUTPUT,@cOutField01 OUTPUT,@cOutField02 OUTPUT,@cOutField03 OUTPUT ' +        
               ' ,@cOutField04 OUTPUT ,@cOutField05 OUTPUT,@cOutField06 OUTPUT,@cOutField07 OUTPUT,@cOutField08 OUTPUT' +        
               ' ,@cOutField09 OUTPUT,@cOutField10 OUTPUT,@cOutField11 OUTPUT,@cExtendedinfo OUTPUT,' +         
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
               ' @nMobile       INT,           ' +        
               ' @nFunc         INT,           ' +        
               ' @cLangCode     NVARCHAR( 3),  ' +        
               ' @nInputKey     INT,           ' +         
               ' @cFacility     NVARCHAR( 5),  ' +        
               ' @cStorerKey    NVARCHAR( 15), ' +         
               ' @cOption       NVARCHAR( 1),  ' +    
               ' @cRefNo1       NVARCHAR( 20), ' +
               ' @cInput01      NVARCHAR( 20), ' +
               ' @cInput02      NVARCHAR( 20), ' +
               ' @cInput03      NVARCHAR( 20), ' +
               ' @cInput04      NVARCHAR( 20), ' +
               ' @cActivityStatus NVARCHAR(20), ' +
               ' @nStep         INT           OUTPUT, ' +      
               ' @nScn          INT           OUTPUT, ' +        
               ' @cOutField01  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField02  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField03  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField04  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField05  NVARCHAR( 20) OUTPUT, ' +       
               ' @cOutField06  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField07  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField08  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField09  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField10  NVARCHAR( 20) OUTPUT, ' +  
               ' @cOutField11  NVARCHAR( 20) OUTPUT, ' +  
               ' @cExtendedinfo NVARCHAR(20)  OUTPUT, ' +        
               ' @nErrNo        INT           OUTPUT, ' +        
               ' @cErrMsg       NVARCHAR( 20) OUTPUT  '        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
                @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption,@cRefNo1,@cInput01,@cInput02,@cInput03,@cInput04,@cActivityStatus    
                ,@nStep OUTPUT,@nScn OUTPUT,@cOutField01 OUTPUT,@cOutField02 OUTPUT,@cOutField03 OUTPUT          
                ,@cOutField04 OUTPUT ,@cOutField05 OUTPUT,@cOutField06 OUTPUT,@cOutField07 OUTPUT,@cOutField08 OUTPUT         
                ,@cOutField09 OUTPUT,@cOutField10 OUTPUT,@cOutField11 OUTPUT,@cExtendedinfo OUTPUT,         
                @nErrNo OUTPUT, @cErrMsg OUTPUT             
         END        
        
         IF @nErrNo <> 0        
            GOTO Quit        
      
         SET @cOption = ''      
      END   

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END -- Inputkey = 1
END
GOTO QUIT

/********************************************************************************
Step 3. Scn = 6053.

********************************************************************************/
Step_4:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      SET @cInput01        = ISNULL(RTRIM(@cInField04),'')
      SET @cInput02        = ISNULL(RTRIM(@cInField06),'')
      SET @cInput03        = ISNULL(RTRIM(@cInField08),'')
      SET @cInput04        = ISNULL(RTRIM(@cInField10),'')
      SET @cOption         = ISNULL(RTRIM(@cInField12),'')

      IF ISNULL(RTRIM(@cOption), '') = ''
      BEGIN
         SET @nErrNo = 185356
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- OptionReq
         GOTO Step_4_Fail
      END

      IF ISNULL(RTRIM(@cOption), '') NOT IN ( '1' , '9' )
      BEGIN
         SET @nErrNo = 185357
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidOption
         GOTO Step_4_Fail
      END

      -- Execute label/report stored procedure        
      IF @cSP <> ''        
      BEGIN        
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption,@cRefNo1,@cInput01,@cInput02,@cInput03,@cInput04,@cActivityStatus,' +        
               ' @nStep OUTPUT,@nScn OUTPUT,@cOutField01 OUTPUT,@cOutField02 OUTPUT,@cOutField03 OUTPUT ' +        
               ' ,@cOutField04 OUTPUT ,@cOutField05 OUTPUT,@cOutField06 OUTPUT,@cOutField07 OUTPUT,@cOutField08 OUTPUT' +        
               ' ,@cOutField09 OUTPUT,@cOutField10 OUTPUT,@cOutField11 OUTPUT,@cExtendedinfo OUTPUT,' +         
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
               ' @nMobile       INT,           ' +        
               ' @nFunc         INT,           ' +        
               ' @cLangCode     NVARCHAR( 3),  ' +        
               ' @nInputKey     INT,           ' +         
               ' @cFacility     NVARCHAR( 5),  ' +        
               ' @cStorerKey    NVARCHAR( 15), ' +         
               ' @cOption       NVARCHAR( 1),  ' +    
               ' @cRefNo1       NVARCHAR( 20), ' +
               ' @cInput01      NVARCHAR( 20), ' +
               ' @cInput02      NVARCHAR( 20), ' +
               ' @cInput03      NVARCHAR( 20), ' +
               ' @cInput04      NVARCHAR( 20), ' +
               ' @cActivityStatus NVARCHAR(20), ' +
               ' @nStep         INT           OUTPUT, ' +      
               ' @nScn          INT           OUTPUT, ' +        
               ' @cOutField01  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField02  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField03  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField04  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField05  NVARCHAR( 20) OUTPUT, ' +       
               ' @cOutField06  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField07  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField08  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField09  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField10  NVARCHAR( 20) OUTPUT, ' +  
               ' @cOutField11  NVARCHAR( 20) OUTPUT, ' +  
               ' @cExtendedinfo NVARCHAR(20)  OUTPUT, ' +        
               ' @nErrNo        INT           OUTPUT, ' +        
               ' @cErrMsg       NVARCHAR( 20) OUTPUT  '        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
                @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption,@cRefNo1,@cInput01,@cInput02,@cInput03,@cInput04,@cActivityStatus    
                ,@nStep OUTPUT,@nScn OUTPUT,@cOutField01 OUTPUT,@cOutField02 OUTPUT,@cOutField03 OUTPUT          
                ,@cOutField04 OUTPUT ,@cOutField05 OUTPUT,@cOutField06 OUTPUT,@cOutField07 OUTPUT,@cOutField08 OUTPUT         
                ,@cOutField09 OUTPUT,@cOutField10 OUTPUT,@cOutField11 OUTPUT,@cExtendedinfo OUTPUT,         
                @nErrNo OUTPUT, @cErrMsg OUTPUT             
         END        
        
         IF @nErrNo <> 0        
            GOTO Quit        
      END       
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
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''

      SET @cOutField10 = @cDefaultOption

      EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor
   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN
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
      SET @cFieldAttr11 = ''
      SET @cFieldAttr12 = ''
      SET @cFieldAttr13 = ''
      SET @cFieldAttr14 = ''
      SET @cFieldAttr15 = ''

      -- Execute label/report stored procedure        
      IF @cSP <> ''        
      BEGIN        
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cSP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption,@cRefNo1,@cInput01,@cInput02,@cInput03,@cInput04,@cActivityStatus,' +        
               ' @nStep OUTPUT,@nScn OUTPUT,@cOutField01 OUTPUT,@cOutField02 OUTPUT,@cOutField03 OUTPUT ' +        
               ' ,@cOutField04 OUTPUT ,@cOutField05 OUTPUT,@cOutField06 OUTPUT,@cOutField07 OUTPUT,@cOutField08 OUTPUT' +        
               ' ,@cOutField09 OUTPUT,@cOutField10 OUTPUT,@cOutField11 OUTPUT,@cExtendedinfo OUTPUT,' +         
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '        
            SET @cSQLParam =        
               ' @nMobile       INT,           ' +        
               ' @nFunc         INT,           ' +        
               ' @cLangCode     NVARCHAR( 3),  ' +        
               ' @nInputKey     INT,           ' +         
               ' @cFacility     NVARCHAR( 5),  ' +        
               ' @cStorerKey    NVARCHAR( 15), ' +         
               ' @cOption       NVARCHAR( 1),  ' +    
               ' @cRefNo1       NVARCHAR( 20), ' +
               ' @cInput01      NVARCHAR( 20), ' +
               ' @cInput02      NVARCHAR( 20), ' +
               ' @cInput03      NVARCHAR( 20), ' +
               ' @cInput04      NVARCHAR( 20), ' +
               ' @cActivityStatus NVARCHAR(20), ' +
               ' @nStep         INT           OUTPUT, ' +      
               ' @nScn          INT           OUTPUT, ' +        
               ' @cOutField01  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField02  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField03  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField04  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField05  NVARCHAR( 20) OUTPUT, ' +       
               ' @cOutField06  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField07  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField08  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField09  NVARCHAR( 20) OUTPUT, ' +         
               ' @cOutField10  NVARCHAR( 20) OUTPUT, ' +  
               ' @cOutField11  NVARCHAR( 20) OUTPUT, ' +  
               ' @cExtendedinfo NVARCHAR(20)  OUTPUT, ' +        
               ' @nErrNo        INT           OUTPUT, ' +        
               ' @cErrMsg       NVARCHAR( 20) OUTPUT  '        
        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
                @nMobile, @nFunc, @cLangCode, @nInputKey, @cFacility, @cStorerKey, @cOption,@cRefNo1,@cInput01,@cInput02,@cInput03,@cInput04,@cActivityStatus    
                ,@nStep OUTPUT,@nScn OUTPUT,@cOutField01 OUTPUT,@cOutField02 OUTPUT,@cOutField03 OUTPUT          
                ,@cOutField04 OUTPUT ,@cOutField05 OUTPUT,@cOutField06 OUTPUT,@cOutField07 OUTPUT,@cOutField08 OUTPUT         
                ,@cOutField09 OUTPUT,@cOutField10 OUTPUT,@cOutField11 OUTPUT,@cExtendedinfo OUTPUT,         
                @nErrNo OUTPUT, @cErrMsg OUTPUT             
         END        
        
         IF @nErrNo <> 0        
            GOTO Quit        
      
         SET @cOption = ''      
      END         

      -- Screen mapping
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_4_FAIL:
   BEGIN
      EXEC rdt.rdtSetFocusField @nMobile, 12
      SET @cOutField04=@cInput01
      SET @cOutField06=@cInput02
   END
END
GOTO QUIT

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
      EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      -- UserName       = @cUserName,

      V_String1      = @cContainerNo,
      V_String2      = @cAppointmentNo,
      V_String3      = @cExtendedUpdateSP,
      V_String4      = @cExtendedValidateSP,  --(cc01)
      V_String5      = @cMenuOption,

      V_String8      = @cActionType,
      V_String9      = @cRefNo1,
      V_String10     = @cDefaultOption,
      V_String11     = @cDefaultCursor,
      V_String12     = @cSP,  --(cc02)
      V_String13     = @cExtendedinfo,
      V_String14     = @cActivityStatus,
      V_String15     = @cFocusStep2,

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