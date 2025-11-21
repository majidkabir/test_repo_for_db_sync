SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/
/* Store procedure: rdtfnc_VFCDC_ConveyorMove                                */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: Allow User to send messages to WCS to move mutiple carton(s) to a*/
/*          specified destination.                                           */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2013-09-05 1.0  Chee     Created                                          */  
/* 2016-09-30 1.1  Ung      Performance tuning                               */ 
/* 2018-08-03 1.2  ChewKP   WMS-5857 - Add ExtendedUP SP config (ChewKP01)   */  
/* 2019-07-12 1.3  Ung      Fix ExtendedUpdateSP param                       */
/*                          Performance tuning                               */ 
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_VFCDC_ConveyorMove](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS

-- Misc variable
DECLARE
   @bSuccess           INT
        
-- Define a variable
DECLARE  
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),
   @cPrinter            NVARCHAR(10),
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cToLoc              NVARCHAR(20),
   @cLPNNo              NVARCHAR(20), 
   @nCartonCnt          INT, 
   @nCount              INT,
   @cContainerType      NVARCHAR(15),
   @cLPNNo1             NVARCHAR(20), 
   @cLPNNo2             NVARCHAR(20), 
   @cLPNNo3             NVARCHAR(20), 
   @cLPNNo4             NVARCHAR(20), 
   @cLPNNo5             NVARCHAR(20), 
   @cLPNNo6             NVARCHAR(20), 
   @cLPNNo7             NVARCHAR(20), 
   @cOption             NVARCHAR(1), 
   
   @cExtendedUpdateSP   NVARCHAR(20), -- (ChewKP01) 
   @cExtendedValidateSP NVARCHAR(20), -- (ChewKP01) 
   @cSkipConfirmScn     NVARCHAR(1),  -- (ChewKP01) 
   @cSQL                NVARCHAR(MAX),-- (ChewKP01) 
   @cSQLParam           NVARCHAR(MAX),-- (ChewKP01) 

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
   @cLangCode        = Lang_code,
   @nMenu            = Menu,

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
   @cPrinter         = Printer, 
   @cUserName        = UserName,

   @cToLoc           = V_String1,
   @cLPNNo           = V_String2,
   @cLPNNo1          = V_String4,
   @cLPNNo2          = V_String5,
   @cLPNNo3          = V_String6,
   @cLPNNo4          = V_String7,
   @cLPNNo5          = V_String8,
   @cLPNNo6          = V_String9,
   @cLPNNo7          = V_String10,
   @cExtendedUpdateSP = V_String11,   -- (ChewKP01) 
   @cExtendedValidateSP = V_String12, -- (ChewKP01)
   @cSkipConfirmScn     = V_String13, -- (ChewKP01) 

   @nCartonCnt       = V_Integer1,
         
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

FROM   RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 1799
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1799
   IF @nStep = 1 GOTO Step_1   -- Scn = 3620  TOLOC
   IF @nStep = 2 GOTO Step_2   -- Scn = 3621  LPNNO
   IF @nStep = 3 GOTO Step_3   -- Scn = 3622  Create/Cancel Option
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1799)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 3620
   SET @nStep = 1

   -- initialise all variable
   SET @cLPNNo = ''
   SET @cContainerType = ''
   SET @cToLoc = ''
   
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerkey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
      
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerkey)
   IF @cExtendedUpdateSP = '0'
      SET @cExtendedUpdateSP = ''
      
   SET @cSkipConfirmScn = rdt.RDTGetConfig( @nFunc, 'SkipConfirmScn', @cStorerkey)
   IF @cSkipConfirmScn = '0'
      SET @cSkipConfirmScn = ''
      
      

   -- Prep next screen var   
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
   SET @cOutField11 = '' 
END
GOTO Quit

/********************************************************************************
Step 1. screen = 3621
   TOLOC: 
   (Field01, input01)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cToLoc = SUBSTRING(@cInField01, 1, 15)

      IF ISNULL(@cToLoc, '') = ''         
      BEGIN                
         SET @nErrNo = 82451                
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TOLOC REQ                
         EXEC rdt.rdtSetFocusField @nMobile, 1                
         GOTO Step_1_Fail                
      END
      
      -- (ChewKP01) 
      IF @cExtendedValidateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cToLoc,  @cLPNNo,' +
            ' @cLPNNo1, @cLPNNo2, @cLPNNo3, @cLPNNo4, @cLPNNo5, @cLPNNo6, @cLPNNo7, @nCartonCnt, @cOption,' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cToLoc       NVARCHAR( 10), ' +
            '@cLPNNo       NVARCHAR( 20), ' +
            '@cLPNNo1      NVARCHAR( 20), ' +
            '@cLPNNo2      NVARCHAR( 20), ' +
            '@cLPNNo3      NVARCHAR( 20), ' +
            '@cLPNNo4      NVARCHAR( 20), ' +
            '@cLPNNo5      NVARCHAR( 20), ' +
            '@cLPNNo6      NVARCHAR( 20), ' +
            '@cLPNNo7      NVARCHAR( 20), ' +
            '@nCartonCnt   INT, ' +
            '@cOption      NVARCHAR( 1), ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cToLoc,  @cLPNNo,
            @cLPNNo1, @cLPNNo2, @cLPNNo3, @cLPNNo4, @cLPNNo5, @cLPNNo6, @cLPNNo7, @nCartonCnt, @cOption,
            @nErrNo OUTPUT, @cErrMsg OUTPUT 

         IF @nErrNo <> 0 OR ISNULL( @cErrMsg, '') <> ''
            GOTO Step_1_Fail
      END
      ELSE
      BEGIN
         IF NOT EXISTS(SELECT 1 FROM CODELKUP c WITH (NOLOCK) WHERE c.LISTNAME = 'WCSSTATION' AND C.Code = @cToLoc)
         BEGIN
            SET @nErrNo = 82452
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV TOLOC
            GOTO Step_1_Fail  
         END  
      END    
                                
      -- Prev next screen
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
      SET @cOutField11 = '' 

      SET @cLPNNo = ''
      SET @cLPNNo1 = ''
      SET @cLPNNo2 = ''
      SET @cLPNNo3 = ''
      SET @cLPNNo4 = ''
      SET @cLPNNo5 = ''
      SET @cLPNNo6 = ''
      SET @cLPNNo7 = ''
      SET @nCartonCnt = 0

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0

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
      SET @cOutField11 = '' 

      SET @cToLoc = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cToLoc = ''
   END

END
GOTO Quit

/********************************************************************************
Step 2. screen = 2531
   LPNNO:
   (Field01, input01)

   LPNNO:
   (Field02, display02)
   (Field03, display03)
   (Field04, display04)
   (Field05, display05)
   (Field06, display06)
   (Field07, display07)
   (Field07, display08)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      SET @cLPNNo = @cInField01

      IF ISNULL(RTRIM(@cLPNNo), '') = ''
      BEGIN
         SET @nErrNo = 82453
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LPNNO REQ
         GOTO Step_2_Fail  
      END
      
      -- (ChewKP01) 
      IF @cSkipConfirmScn = '1'
      BEGIN
         
         IF @cExtendedValidateSP <> ''
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cToLoc,  @cLPNNo,' +
               ' @cLPNNo1, @cLPNNo2, @cLPNNo3, @cLPNNo4, @cLPNNo5, @cLPNNo6, @cLPNNo7, @nCartonCnt, @cOption,' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@cStorerkey   NVARCHAR( 15), ' +
               '@cToLoc       NVARCHAR( 10), ' +
               '@cLPNNo       NVARCHAR( 20), ' +
               '@cLPNNo1      NVARCHAR( 20), ' +
               '@cLPNNo2      NVARCHAR( 20), ' +
               '@cLPNNo3      NVARCHAR( 20), ' +
               '@cLPNNo4      NVARCHAR( 20), ' +
               '@cLPNNo5      NVARCHAR( 20), ' +
               '@cLPNNo6      NVARCHAR( 20), ' +
               '@cLPNNo7      NVARCHAR( 20), ' +
               '@nCartonCnt   INT, ' +
               '@cOption      NVARCHAR( 1), ' +
               '@nErrNo       INT           OUTPUT, ' +
               '@cErrMsg      NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cToLoc,  @cLPNNo,
               @cLPNNo1, @cLPNNo2, @cLPNNo3, @cLPNNo4, @cLPNNo5, @cLPNNo6, @cLPNNo7, @nCartonCnt, @cOption,
               @nErrNo OUTPUT, @cErrMsg OUTPUT 

            IF @nErrNo <> 0 OR ISNULL( @cErrMsg, '') <> ''
               GOTO Step_2_Fail
         END
                  
         IF @cExtendedUpdateSP <> ''
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cToLoc,  @cLPNNo,' +
               ' @cLPNNo1, @cLPNNo2, @cLPNNo3, @cLPNNo4, @cLPNNo5, @cLPNNo6, @cLPNNo7, @nCartonCnt, @cOption, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@cStorerkey   NVARCHAR( 15), ' +
               '@cToLoc       NVARCHAR( 10), ' +
               '@cLPNNo       NVARCHAR( 20), ' +
               '@cLPNNo1      NVARCHAR( 20), ' +
               '@cLPNNo2      NVARCHAR( 20), ' +
               '@cLPNNo3      NVARCHAR( 20), ' +
               '@cLPNNo4      NVARCHAR( 20), ' +
               '@cLPNNo5      NVARCHAR( 20), ' +
               '@cLPNNo6      NVARCHAR( 20), ' +
               '@cLPNNo7      NVARCHAR( 20), ' +
               '@nCartonCnt   INT, ' +
               '@cOption      NVARCHAR( 1), ' +
               '@nErrNo       INT           OUTPUT, ' +
               '@cErrMsg      NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cToLoc,  @cLPNNo,
               @cLPNNo1, @cLPNNo2, @cLPNNo3, @cLPNNo4, @cLPNNo5, @cLPNNo6, @cLPNNo7, @nCartonCnt, @cOption,
               @nErrNo OUTPUT, @cErrMsg OUTPUT 

            IF @nErrNo <> 0 OR ISNULL( @cErrMsg, '') <> ''
               GOTO Step_2_Fail
         END
         
         SET @cOutField01  =  ''
         
         SET @nScn = @nScn - 1 
         SET @nStep = @nStep - 1 
         
         GOTO QUIT
      END

      IF @cLPNNo = @cLPNNo1 OR @cLPNNo = @cLPNNo2 OR @cLPNNo = @cLPNNo3 OR @cLPNNo = @cLPNNo4 OR 
         @cLPNNo = @cLPNNo5 OR @cLPNNo = @cLPNNo6 OR @cLPNNo = @cLPNNo7 
      BEGIN
         SET @nErrNo = 82458
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LPNNO REPEAT
         GOTO Step_2_Fail  
      END

      IF @nCartonCnt >= 7
      BEGIN
         SET @nErrNo = 82454
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MAX 7 CARTON
         GOTO Step_2_Fail  
      END
      
      -- (ChewKP01) 
      IF @cExtendedValidateSP <> ''
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
            ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cToLoc,  @cLPNNo,' +
            ' @cLPNNo1, @cLPNNo2, @cLPNNo3, @cLPNNo4, @cLPNNo5, @cLPNNo6, @cLPNNo7, @nCartonCnt, @cOption,' +
            ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

         SET @cSQLParam =
            '@nMobile      INT,           ' +
            '@nFunc        INT,           ' +
            '@nStep        INT,           ' +
            '@nInputKey    INT,           ' +
            '@cLangCode    NVARCHAR( 3),  ' +
            '@cStorerkey   NVARCHAR( 15), ' +
            '@cToLoc       NVARCHAR( 10), ' +
            '@cLPNNo       NVARCHAR( 20), ' +
            '@cLPNNo1      NVARCHAR( 20), ' +
            '@cLPNNo2      NVARCHAR( 20), ' +
            '@cLPNNo3      NVARCHAR( 20), ' +
            '@cLPNNo4      NVARCHAR( 20), ' +
            '@cLPNNo5      NVARCHAR( 20), ' +
            '@cLPNNo6      NVARCHAR( 20), ' +
            '@cLPNNo7      NVARCHAR( 20), ' +
            '@nCartonCnt   INT, ' +
            '@cOption      NVARCHAR( 1), ' +
            '@nErrNo       INT           OUTPUT, ' +
            '@cErrMsg      NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cToLoc,  @cLPNNo,
            @cLPNNo1, @cLPNNo2, @cLPNNo3, @cLPNNo4, @cLPNNo5, @cLPNNo6, @cLPNNo7, @nCartonCnt, @cOption,
            @nErrNo OUTPUT, @cErrMsg OUTPUT 

         IF @nErrNo <> 0 OR ISNULL( @cErrMsg, '') <> ''
            GOTO Step_2_Fail
      END

      SET @nCartonCnt = @nCartonCnt + 1

      IF @nCartonCnt = 1
      BEGIN
         SET @cLPNNo1 = @cLPNNo
         SET @cOutField02 = @cLPNNo
      END
      ELSE
      IF @nCartonCnt = 2
      BEGIN
         SET @cLPNNo2 = @cLPNNo
         SET @cOutField03 = @cLPNNo
      END
      ELSE
      IF @nCartonCnt = 3
      BEGIN
         SET @cLPNNo3 = @cLPNNo
         SET @cOutField04 = @cLPNNo
      END
      ELSE
      IF @nCartonCnt = 4
      BEGIN
         SET @cLPNNo4 = @cLPNNo
         SET @cOutField05 = @cLPNNo
      END
      ELSE
      IF @nCartonCnt = 5
      BEGIN
         SET @cLPNNo5 = @cLPNNo
         SET @cOutField06 = @cLPNNo
      END
      ELSE
      IF @nCartonCnt = 6
      BEGIN
         SET @cLPNNo6 = @cLPNNo
         SET @cOutField07 = @cLPNNo
      END
      ELSE
      IF @nCartonCnt = 7
      BEGIN
         SET @cLPNNo7 = @cLPNNo
         SET @cOutField08 = @cLPNNo
      END
      
      
      SET @cOutField01  =  ''
      
      SET @nScn = @nScn 
      SET @nStep = @nStep 
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cLPNNo = ''
      SET @cOption = ''

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END  
   GOTO Quit
   
   Step_2_Fail:
   BEGIN
      SET @cLPNNo = ''
   END
   GOTO Quit
   
END
GOTO Quit

/********************************************************************************
Step 3. screen = 2532
   Option: (field01, input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1  -- ENTER
   BEGIN
      SET @cOption = @cInField01

      -- Check if option is blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 82455
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --Opt required 
         GOTO Step_3_Fail      
      END      

      -- Check if option is valid
      IF @cOption NOT IN ('1', '9')
      BEGIN
         SET @nErrNo = 82456
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP') --Inv Option 
         GOTO Step_3_Fail      
      END      

      IF @cOption = '1'
      BEGIN
         
         -- (ChewKP01) 
         IF @cExtendedUpdateSP <> ''
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cToLoc,  @cLPNNo,' +
               ' @cLPNNo1, @cLPNNo2, @cLPNNo3, @cLPNNo4, @cLPNNo5, @cLPNNo6, @cLPNNo7, @nCartonCnt, @cOption, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@cStorerkey   NVARCHAR( 15), ' +
               '@cToLoc       NVARCHAR( 10), ' +
               '@cLPNNo       NVARCHAR( 20), ' +
               '@cLPNNo1      NVARCHAR( 20), ' +
               '@cLPNNo2      NVARCHAR( 20), ' +
               '@cLPNNo3      NVARCHAR( 20), ' +
               '@cLPNNo4      NVARCHAR( 20), ' +
               '@cLPNNo5      NVARCHAR( 20), ' +
               '@cLPNNo6      NVARCHAR( 20), ' +
               '@cLPNNo7      NVARCHAR( 20), ' +
               '@nCartonCnt   INT, ' +
               '@cOption      NVARCHAR( 1), ' +
               '@nErrNo       INT           OUTPUT, ' +
               '@cErrMsg      NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cToLoc,  @cLPNNo,
               @cLPNNo1, @cLPNNo2, @cLPNNo3, @cLPNNo4, @cLPNNo5, @cLPNNo6, @cLPNNo7, @nCartonCnt, @cOption,
               @nErrNo OUTPUT, @cErrMsg OUTPUT 

            IF @nErrNo <> 0 OR ISNULL( @cErrMsg, '') <> ''
               GOTO Step_3_Fail
         END
         ELSE
         BEGIN
            BEGIN TRAN

            SET @nCount = 1
            WHILE @nCartonCnt > 0
            BEGIN
               SET @cLPNNo = ''
               SELECT @cLPNNo = CASE @nCount
                                  WHEN 1 THEN @cLPNNo1 
                                  WHEN 2 THEN @cLPNNo2 
                                  WHEN 3 THEN @cLPNNo3 
                                  WHEN 4 THEN @cLPNNo4 
                                  WHEN 5 THEN @cLPNNo5 
                                  WHEN 6 THEN @cLPNNo6 
                                  WHEN 7 THEN @cLPNNo7 
                               END

               -- OLD LPN
               IF EXISTS(SELECT 1 FROM dbo.WCSRouting WITH (NOLOCK) 
                         WHERE StorerKey = @cStorerKey AND ToteNo = @cLPNNo)
               BEGIN
                  SET @cContainerType = ''

                  EXECUTE dbo.isp_WS_WCS_VF_ContainerCommand  
                      @cLPNNo
                     ,@cContainerType 
                     ,@cToLoc
                     ,@bSuccess  OUTPUT   
                     ,@nErrNo    OUTPUT  
                     ,@cErrMsg   OUTPUT  
                     ,1
                     ,@nFunc

                  IF @nErrNo <> 0   
                  BEGIN
                     SET @nErrNo = 82457
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CrtRouteFailed
                     GOTO Step_3_Fail  
                  END
               END
               -- NEW LPN
               ELSE BEGIN
                  SELECT @cContainerType = Long
                  FROM CODELKUP c WITH (NOLOCK)
                  WHERE c.LISTNAME = 'WCSSTATION' AND C.Code = @cToLoc

                  EXECUTE dbo.isp_WS_WCS_VF_ContainerCommand  
                      @cLPNNo
                     ,@cContainerType 
                     ,@cToLoc
                     ,@bSuccess  OUTPUT   
                     ,@nErrNo    OUTPUT  
                     ,@cErrMsg   OUTPUT
                     ,1
                     ,@nFunc

                  IF @nErrNo <> 0   
                  BEGIN
                     SET @nErrNo = 82457
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CrtRouteFailed
                     GOTO Step_3_Fail  
                  END
               END

               SET @nCount = @nCount + 1
               SET @nCartonCnt = @nCartonCnt - 1
            END

            COMMIT TRAN
         END
         
         -- initialise all variable
         SET @cToLoc = ''
         SET @cLPNNo = ''
         SET @cLPNNo1 = ''
         SET @cLPNNo2 = ''
         SET @cLPNNo3 = ''
         SET @cLPNNo4 = ''
         SET @cLPNNo5 = ''
         SET @cLPNNo6 = ''
         SET @cLPNNo7 = ''
         SET @nCartonCnt = 0

         -- Prep next screen var   
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
         SET @cOutField11 = '' 

         EXEC rdt.rdtSetFocusField @nMobile, 1                

         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      END

      IF @cOption = '9'
      BEGIN
         
         -- (ChewKP01) 
         IF @cExtendedUpdateSP <> ''
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cToLoc,  @cLPNNo,' +
               ' @cLPNNo1, @cLPNNo2, @cLPNNo3, @cLPNNo4, @cLPNNo5, @cLPNNo6, @cLPNNo7, @nCartonCnt, @cOption, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               '@nMobile      INT,           ' +
               '@nFunc        INT,           ' +
               '@nStep        INT,           ' +
               '@nInputKey    INT,           ' +
               '@cLangCode    NVARCHAR( 3),  ' +
               '@cStorerkey   NVARCHAR( 15), ' +
               '@cToLoc       NVARCHAR( 10), ' +
               '@cLPNNo       NVARCHAR( 20), ' +
               '@cLPNNo1      NVARCHAR( 20), ' +
               '@cLPNNo2      NVARCHAR( 20), ' +
               '@cLPNNo3      NVARCHAR( 20), ' +
               '@cLPNNo4      NVARCHAR( 20), ' +
               '@cLPNNo5      NVARCHAR( 20), ' +
               '@cLPNNo6      NVARCHAR( 20), ' +
               '@cLPNNo7      NVARCHAR( 20), ' +
               '@nCartonCnt   INT,           ' +
               '@cOption      NVARCHAR( 1),  ' +
               '@nErrNo       INT           OUTPUT, ' +
               '@cErrMsg      NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @nStep, @nInputKey, @cLangCode, @cStorerkey, @cToLoc,  @cLPNNo,
               @cLPNNo1, @cLPNNo2, @cLPNNo3, @cLPNNo4, @cLPNNo5, @cLPNNo6, @cLPNNo7, @nCartonCnt, @cOption,
               @nErrNo OUTPUT, @cErrMsg OUTPUT 

            IF @nErrNo <> 0 OR ISNULL( @cErrMsg, '') <> ''
               GOTO Step_3_Fail
         END
         
         -- initialise all variable
         SET @cToLoc = ''
         SET @cLPNNo = ''
         SET @cLPNNo1 = ''
         SET @cLPNNo2 = ''
         SET @cLPNNo3 = ''
         SET @cLPNNo4 = ''
         SET @cLPNNo5 = ''
         SET @cLPNNo6 = ''
         SET @cLPNNo7 = ''
         SET @nCartonCnt = 0

         -- Prep next screen var   
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
         SET @cOutField11 = '' 

         EXEC rdt.rdtSetFocusField @nMobile, 1                

         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cLPNNo = ''

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOption = ''
      ROLLBACK TRAN 
   END
   GOTO Quit
END
/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      EditDate      = GETDATE(), 
      ErrMsg        = @cErrMsg, 
      Func          = @nFunc,
      Step          = @nStep,            
      Scn           = @nScn,

      StorerKey     = @cStorerKey,
      Facility      = @cFacility, 
      Printer       = @cPrinter,    
      -- UserName      = @cUserName,
     
      V_String1     = @cToLoc,  
      V_String2     = @cLPNNo,   
      V_String4     = @cLPNNo1,
      V_String5     = @cLPNNo2,
      V_String6     = @cLPNNo3,
      V_String7     = @cLPNNo4,
      V_String8     = @cLPNNo5,
      V_String9     = @cLPNNo6,
      V_String10    = @cLPNNo7,
      V_String11    = @cExtendedUpdateSP,
      V_String12    = @cExtendedValidateSP,
      V_String13    = @cSkipConfirmScn,

      V_Integer1    = @nCartonCnt,

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