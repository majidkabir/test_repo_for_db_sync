SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
               
/************************************************************************/                      
/* Store procedure: rdtfnc_GroupJobCapture                              */                      
/* Copyright      : LFLogistics                                         */                      
/*                                                                      */                      
/* Purpose: User Capture start time and end time                        */                      
/*                                                                      */                      
/* Date        Rev  Author     Purposes                                 */                      
/* 20-07-2019  1.0  YeeKung    WMS-8855 Created                         */    
/* 10-10-2019  1.1  YeeKung    WMS-10672 RDT 707 Enhancement            */     
/* 08-06-2022  1.2  YeeKung    WMS-19782 Add New screen Data capture    */
/*                             (yeekung01)                              */
/* 22-12-2022  1.3  YeeKung    WMS-21376 Add extendedvalidatesp         */
/*                             (yeekung02)                              */
/************************************************************************/                      
                      
CREATE   PROC [RDT].[rdtfnc_GroupJobCapture] (                      
   @nMobile    INT,                      
   @nErrNo     INT  OUTPUT,                      
   @cErrMsg    NVARCHAR(1024) OUTPUT                      
)                      
AS                      
SET NOCOUNT ON                      
SET QUOTED_IDENTIFIER OFF                      
SET ANSI_NULLS OFF                      
SET CONCAT_NULL_YIELDS_NULL OFF                      
                      
-- Misc var                      
DECLARE                      
   @nRowRef       INT,                      
   @cSQL          NVARCHAR( MAX),                       
   @cSQLParam     NVARCHAR( MAX),                  
   @i             INT                        
                      
-- RDT.RDTMobRec variable                      
DECLARE                      
   @nFunc               INT,                      
   @nScn                INT,                      
   @nStep               INT,                      
   @cLangCode           NVARCHAR( 3),                      
   @cUserName           NVARCHAR( 10),                      
   @nInputKey           INT,                      
   @nMenu               INT,                  
   @cOption             INT,  
   @cTotalUser          INT,
                                      
   @cStorerKey          NVARCHAR( 15),                      
   @cFacility           NVARCHAR( 5),                      
                                      
   @cUserID             NVARCHAR( 15),                          
   @cStart              NVARCHAR( 10),                      
   @cEnd                NVARCHAR( 10),                      
   @cDuration           NVARCHAR( 5),                      
   @cCaptureUser        NVARCHAR( 60),                  
   @cJobType            NVARCHAR( 60),                   
   @cUserID01           NVARCHAR( 15),                      
   @cUserID02           NVARCHAR( 15),                      
   @cUserID03           NVARCHAR( 15),                        
   @cUserID04           NVARCHAR( 15),                      
   @cUserID05           NVARCHAR( 15),                  
   @cUserID06           NVARCHAR( 15),                      
   @cUserID07           NVARCHAR( 15),                      
   @cUserID08           NVARCHAR( 15),                      
   @cUserID09           NVARCHAR( 15),                   
   @cCheckUserID        NVARCHAR( 15),                  
   @cRef01              NVARCHAR( 60),                      
   @cRef02              NVARCHAR( 60),                      
   @cRef03              NVARCHAR( 60),                        
   @cRef04              NVARCHAR( 60),                      
   @cRef05              NVARCHAR( 60),                  
   @cRef06              NVARCHAR( 60),                      
   @cRef07              NVARCHAR( 60),                      
   @cRef08              NVARCHAR( 60),                      
   @cRef09              NVARCHAR( 60),                
   @cFunc01             NVARCHAR( 10),                      
   @cFunc02             NVARCHAR( 10),       
   @cFunc03             NVARCHAR( 10),                        
   @cFunc04             NVARCHAR( 10),                      
   @cFunc05             NVARCHAR( 10),                 
   @cFunc06             NVARCHAR( 10),                    
   @cFunc07             NVARCHAR( 10),                       
   @cFunc08             NVARCHAR( 10),                 
   @cFunc09             NVARCHAR( 10),                
   @cFuncID             NVARCHAR( 10),                
   @cExtendedValidateSP NVARCHAR( 20),                      
   @tVar                VariableTable,  
   @tUserID             VariableTable,
   @cConfirmEnd         NVARCHAR(  1),   
   @cCaptureProcess     NVARCHAR(  1),

                      
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),    @cFieldAttr01 NVARCHAR( 1),                      
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),    @cFieldAttr02 NVARCHAR( 1),                      
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),    @cFieldAttr03 NVARCHAR( 1),                      
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),    @cFieldAttr04 NVARCHAR( 1),                      
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),    @cFieldAttr05 NVARCHAR( 1),                      
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),    @cFieldAttr06 NVARCHAR( 1),                      
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),    @cFieldAttr07 NVARCHAR( 1),                      
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),    @cFieldAttr08 NVARCHAR( 1),                      
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),    @cFieldAttr09 NVARCHAR( 1),                      
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),    @cFieldAttr10 NVARCHAR( 1),                      
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),    @cFieldAttr11 NVARCHAR( 1),                      
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),    @cFieldAttr12 NVARCHAR( 1),                      
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),    @cFieldAttr13 NVARCHAR( 1),                      
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),    @cFieldAttr14 NVARCHAR( 1),                      
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1)                      
                      
-- Load RDT.RDTMobRec                      
SELECT                      
   @nFunc               = Func,                      
   @nScn                = Scn,                      
   @nStep               = Step,                      
   @nInputKey           = InputKey,                      
   @nMenu               = Menu,                      
   @cLangCode           = Lang_code,                      
   @cUserName           = UserName,                      
                                      
   @cStorerKey          = StorerKey,                      
   @cFacility           = Facility,                      
                      
   @cUserID             = V_String1,                      
   @cStart              = V_String2,                      
   @cEnd                = V_String3,                      
   @cDuration           = V_String4,                  
   @cCaptureUser        = V_String5,                  
   @cJobType            = V_String6,                        
   @cExtendedValidateSP = V_String10,                           
                    
   @cUserID01           = V_String12,                    
   @cUserID02           = V_String13,                    
   @cUserID03           = V_String14,                    
   @cUserID04           = V_String15,                    
   @cUserID05           = V_String16,                    
   @cUserID06           = V_String17,                    
   @cUserID07           = V_String18,                    
   @cUserID08           = V_String19,                    
   @cUserID09           = V_String20,                  
   @cCheckUserID        = V_String21,                   
   @cRef01              = V_String22,                   
   @cRef02              = V_String23,                   
   @cRef03              = V_String24,                   
   @cRef04              = V_String25,                   
   @cRef05              = V_String26,                   
   @cRef06              = V_String27,                   
   @cRef07              = V_String28,                   
   @cRef08              = V_String29,                   
   @cRef09              = V_String30,                 
   @cFunc01             = V_String31,                   
   @cFunc02             = V_String32,                      
   @cFunc03             = V_String33,                      
   @cFunc04             = V_String34,                 
   @cFunc05             = V_String35,                   
   @cFunc06             = V_String36,                   
   @cFunc07             = V_String37,                     
   @cFunc08             = V_String38,                 
   @cFunc09             = V_String39,     
   @cConfirmEnd         = V_String40, 
   @cCaptureProcess     = V_String41,
                    
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
                         
FROM rdt.RDTMOBREC (NOLOCK)                      
WHERE Mobile = @nMobile                      
                      
IF @nFunc = 707 -- Job capture                      
BEGIN                      
   -- Redirect to respective screen                      
   IF @nStep = 0 GOTO Step_0   -- Func = 707                      
   IF @nStep = 1 GOTO Step_1   -- 5480 UserID                      
   IF @nStep = 2 GOTO Step_2   -- 5481 Capture UserID                      
   IF @nStep = 3 GOTO Step_3   -- 5482 Capture Process     
   IF @nStep = 4 GOTO Step_4   -- 5483 Confirm End 
   IF @nStep = 5 GOTO Step_5   -- 5484 Capture Process 
END                      
                      
RETURN -- Do nothing if incorrect step                      
                      
                      
/********************************************************************************                      
Step 0. func = 707. Menu                      
********************************************************************************/                      
Step_0:                      
BEGIN                      
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)                      
   IF @cExtendedValidateSP = '0'                      
      SET @cExtendedValidateSP = ''                      
                     
   SET @cCaptureUser = rdt.rdtGetConfig( @nFunc, 'CaptureUser', @cStorerKey)                      
   IF @cCaptureUser <> ''                  
   BEGIN                   
      SET @cInField01 = @cUserName                  
   END    
   
   SET @cCaptureProcess = rdt.rdtGetConfig( @nFunc, 'CaptureProcess', @cStorerKey)   
    
   SET @cConfirmEnd = rdt.rdtGetConfig( @nFunc, 'ConfirmEnd', @cStorerKey)                       
                      
   SET @cFieldAttr02 = ''                    
   SET @cFieldAttr04 = ''                    
   SET @cFieldAttr06 = ''                    
   SET @cFieldAttr08 = ''                    
   SET @cFieldAttr10 = ''                    
                    
   SET @cUserID = ''                    
                    
   -- Set the entry point                      
   SET @nScn = 5480                      
   SET @nStep = 1                      
                      
   -- Prepare next screen var                      
   SET @cOutField01 = '' -- User ID                      
                      
   -- EventLog                      
   EXEC RDT.rdt_STD_EventLog                      
      @cActionType = '1', -- Sign-in                      
      @cUserID     = @cUserName,                      
      @nMobileNo   = @nMobile,                      
      @nFunctionID = @nFunc,                      
      @cFacility   = @cFacility,                      
      @cStorerKey  = @cStorerkey                      
END                      
GOTO Quit                      
                      
                      
/********************************************************************************                      
Step 1. Screen = 5480                      
   User ID  (Field01, input)                      
********************************************************************************/                      
Step_1:                      
BEGIN                      
   IF @nInputKey = 1 -- ENTER                      
   BEGIN                      
      -- Screen mapping                      
      SET @cUserID = @cInField01                      
                      
      -- Check blank                      
      IF @cUserID = ''                      
      BEGIN               
         SET @nErrNo = 139101                       
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need UserID                      
         GOTO Quit                      
      END                      
                    
      SET @cFieldAttr02 = ''                    
      SET @cFieldAttr04 = ''                    
      SET @cFieldAttr06 = ''                    
      SET @cFieldAttr08 = ''                    
      SET @cFieldAttr10 = ''                    
                    
      -- Get user info                      
      DECLARE @cStatus NVARCHAR(10)                      
      SELECT @cStatus = Short                      
      FROM CodeLKUP WITH (NOLOCK)                      
      WHERE ListName = 'JOBCapUser'                      
         AND Code = @cUserID                      
         AND StorerKey = @cStorerKey                      
         AND Code2 = @cFacility                      
                      
      -- Check order valid                      
      IF @@ROWCOUNT = 0                      
      BEGIN                      
         SET @nErrNo = 139102                      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UserID                      
         SET @cOutField01 = ''                      
         GOTO Quit                      
      END                      
                      
      -- Check status                      
      IF @cStatus = '9'                      
      BEGIN                      
         SET @nErrNo = 139103                      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inactive user                      
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Order                      
         SET @cOutField01 = ''                      
         GOTO Quit                      
      END     
      
       -- Extended validate (yeekung02)
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cUserID',      @cUserID),
               ('@cJobType',     @cJobType),
               ('@UserID01',     @cUserID01),
               ('@UserID02',     @cUserID02),
               ('@UserID03',     @cUserID03),
               ('@UserID04',     @cUserID04),
               ('@UserID05',     @cUserID05),
               ('@UserID06',     @cUserID06),
               ('@UserID07',     @cUserID07),
               ('@UserID08',     @cUserID08),
               ('@UserID09',     @cUserID09),
               ('@cJobType',     @cStart),
               ('@cEnd',         @cEnd),
               ('@cDuration',    @cDuration),
               ('@cRef01',       @cRef01),
               ('@cRef02',       @cRef02),
               ('@cRef03',       @cRef03),
               ('@cRef04',       @cRef04),
               ('@cRef05',       @cRef05)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@tVar            VariableTable READONLY, ' +
               '@nErrNo          INT           OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @cOutField02 = ''
               GOTO Quit
            END
         END
      END

                      
      --Get job info                    
      SELECT                       
         @nRowRef = RowRef,                       
         @cJobType = TaskCode,                       
         @cStatus = Status                      
      FROM rdt.rdtWATLog WITH (NOLOCK)                      
      WHERE Module = 'GrpJbCap'                      
         AND UserName = @cUserID                      
         AND StorerKey = @cStorerKey                      
         AND Facility = @cFacility                      
         AND Status = '0'                      
                      
      -- Job start                      
      IF @@ROWCOUNT = 0                      
      BEGIN                      
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
    
         EXEC rdt.rdtSetFocusField @nMobile, 1                         
                      
         SET @nScn = @nScn + 1                      
         SET @nStep = @nStep + 1                      
      END                      
      ELSE                      
      BEGIN    
           
         IF @cConfirmEnd='1'    
         BEGIN     
            -- Prep next screen var        
            SET @cOutField01 = '' -- Option        
            SET @cOutField02 = @cJobType      
        
            SET @nScn = @nScn + 3        
            SET @nStep = @nStep + 3           
         END    
         ELSE    
         BEGIN                         
          -- Confirm                      
          EXEC rdt.rdt_GroupJobCapture_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'END',                       
             @cUserID   = @cUserID,                       
             @cJobType  = @cJobType,                              
             @cStart    = @cStart    OUTPUT,                       
             @cEnd      = @cEnd      OUTPUT,                       
             @cDuration = @cDuration OUTPUT,                      
             @nErrNo    = @nErrNo    OUTPUT,                       
             @cErrMsg   = @cErrMsg   OUTPUT                      
          IF @nErrNo <> 0                      
             GOTO Quit                      
                      
          -- Prep next screen var                      
          SET @cOutField01 = '' --  UserID                      
          SET @cOutField02 = @cStart                      
          SET @cOutField03 = @cEnd                      
          SET @cOutField04 = @cDuration     
     END                  
      END                      
   END                      
                      
   IF @nInputKey = 0 -- ESC                      
   BEGIN         
     -- EventLog                      
     EXEC RDT.rdt_STD_EventLog                      
       @cActionType = '9', -- Sign-out                      
       @cUserID     = @cUserName,                      
       @nMobileNo   = @nMobile,                      
       @nFunctionID = @nFunc,                      
       @cFacility   = @cFacility,                      
       @cStorerKey  = @cStorerkey                      
                      
      -- Back to menu                      
      SET @nFunc = @nMenu                      
      SET @nScn  = @nMenu                      
      SET @nStep = 0                      
      SET @cOutField01 = '' -- Clean up for menu option                      
   END                      
   GOTO Quit                      
END                      
GOTO Quit                      
                      
                      
/********************************************************************************                      
Step 2. Screen = 5481                      
   USER ID 1-9                      
   (Field01, input)                     
   (Field02, input)                    
   (Field03, input)                    
   (Field04, input)                    
   (Field05, input)                    
   (Field06, input)                     
   (Field07, input)                    
   (Field08, input)                    
   (Field09, input)                    
   (Field10, input)                    
********************************************************************************/                      
Step_2:                      
BEGIN                      
   IF @nInputKey = 1 -- ENTER                      
   BEGIN                  
-- Retain key-in value                    
      SET @cOutField01 = @cInField01                    
      SET @cOutField02 = @cInField02                    
      SET @cOutField03 = @cInField03                    
      SET @cOutField04 = @cInField04                    
      SET @cOutField05 = @cInField05                    
      SET @cOutField06 = @cInField06                    
      SET @cOutField07 = @cInField07                    
      SET @cOutField08 = @cInField08                    
      SET @cOutField09 = @cInField09                   
                  
      -- Validate blank                    
      IF @cInField01 = '' AND                    
         @cInField02 = '' AND                    
         @cInField03 = '' AND                    
         @cInField04 = '' AND                    
         @cInField05 = '' AND                    
         @cInField06 = '' AND                    
         @cInField07 = '' AND                    
         @cInField08 = '' AND                    
         @cInField09 = ''                    
      BEGIN                    
         SET @nErrNo = 139104                    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'User needed'                    
         EXEC rdt.rdtSetFocusField @nMobile, 1                    
         GOTO Quit                  
      END                        
                         
      -- Put all User into temp table                    
      DECLARE @tUser TABLE (Userid NVARCHAR( 20), i INT)                    
      INSERT INTO @tUser (Userid, i) VALUES (@cInField01, 1)                    
      INSERT INTO @tUser (Userid, i) VALUES (@cInField02, 2)                    
      INSERT INTO @tUser (Userid, i) VALUES (@cInField03, 3)                    
      INSERT INTO @tUser (Userid, i) VALUES (@cInField04, 4)                    
      INSERT INTO @tUser (Userid, i) VALUES (@cInField05, 5)                    
      INSERT INTO @tUser (Userid, i) VALUES (@cInField06, 6)                    
      INSERT INTO @tUser (Userid, i) VALUES (@cInField07, 7)                    
      INSERT INTO @tUser (Userid, i) VALUES (@cInField08, 8)                    
      INSERT INTO @tUser (Userid, i) VALUES (@cInField09, 9)                  
                        
      -- Validate User scanned more than once                    
      SELECT @i = MAX( i)                    
      FROM @tUser                    
      WHERE Userid <> '' AND Userid IS NOT NULL                    
      GROUP BY Userid                    
      HAVING COUNT( Userid) > 1                  
                        
                          
      IF @@ROWCOUNT <> 0                    
      BEGIN                    
         SET @nErrNo = 139105                    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'User Double Scan'                    
         EXEC rdt.rdtSetFocusField @nMobile, @i                    
         GOTO quit                  
      END                   
                        
      -- Validate if anything changed                  
      IF @cUserID01 <> @cInField01 OR                  
         @cUserID02 <> @cInField02 OR                  
         @cUserID03 <> @cInField03 OR                  
         @cUserID04 <> @cInField04 OR                  
         @cUserID05 <> @cInField05 OR                  
         @cUserID06 <> @cInField06 OR                  
         @cUserID07 <> @cInField07 OR                  
         @cUserID08 <> @cInField08 OR                  
         @cUserID09 <> @cInField09                     
      BEGIN                  
         DECLARE @cInField NVARCHAR( 20)                  
                  
         -- Check newly scanned UserID. Validated USerID will be saved to respective @cUserID variable                  
         SET @i = 1                  
         WHILE @i < 10            
         BEGIN                  
            IF @i = 1 SELECT @cInField = @cInField01, @cCheckUserID = @cUserID01                  
            IF @i = 2 SELECT @cInField = @cInField02, @cCheckUserID = @cUserID02                  
            IF @i = 3 SELECT @cInField = @cInField03, @cCheckUserID = @cUserID03                  
            IF @i = 4 SELECT @cInField = @cInField04, @cCheckUserID = @cUserID04                  
            IF @i = 5 SELECT @cInField = @cInField05, @cCheckUserID = @cUserID05                  
            IF @i = 6 SELECT @cInField = @cInField06, @cCheckUserID = @cUserID06                  
            IF @i = 7 SELECT @cInField = @cInField07, @cCheckUserID = @cUserID07                  
            IF @i = 8 SELECT @cInField = @cInField08, @cCheckUserID = @cUserID08                  
            IF @i = 9 SELECT @cInField = @cInField09, @cCheckUserID = @cUserID09                  
                  
            -- Value changed                  
            IF @cInField <> @cCheckUserID                  
            BEGIN                  
               -- Consist a new value                  
               IF @cInField <> ''                  
               BEGIN                  
                                    
                  IF (@cInField = @cUserID)                  
                  BEGIN                  
                     SET @nErrNo = 139107                      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Same UserID                    
                  END                  
                  
                  SELECT @cStatus = Short                      
                  FROM CodeLKUP WITH (NOLOCK)                      
                  WHERE ListName = 'JOBCapUser'                      
                     AND Code = @cInField                      
                     AND StorerKey = @cStorerKey                      
                     AND Code2 = @cFacility                      
                      
                  -- Check order valid                      
                  IF @@ROWCOUNT = 0           
                  BEGIN                      
                     SET @nErrNo = 139108                      
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UserID                           
                  END                   
                  
                  IF @nErrNo <> 0                   
                  BEGIN                  
                     -- Error, clear the UCC field                  
                     IF @i = 1 SELECT @cUserID01 = '', @cInField01 = '', @cOutField01 = ''                  
                     IF @i = 2 SELECT @cUserID02 = '', @cInField02 = '', @cOutField02 = ''                  
                     IF @i = 3 SELECT @cUserID03 = '', @cInField03 = '', @cOutField03 = ''                  
                     IF @i = 4 SELECT @cUserID04 = '', @cInField04 = '', @cOutField04 = ''                  
                     IF @i = 5 SELECT @cUserID05 = '', @cInField05 = '', @cOutField05 = ''                  
                     IF @i = 6 SELECT @cUserID06 = '', @cInField06 = '', @cOutField06 = ''                  
                     IF @i = 7 SELECT @cUserID07 = '', @cInField07 = '', @cOutField07 = ''                  
                     IF @i = 8 SELECT @cUserID08 = '', @cInField08 = '', @cOutField08 = ''                  
                     IF @i = 9 SELECT @cUserID09 = '', @cInField09 = '', @cOutField09 = ''                  
                     EXEC rdt.rdtSetFocusField @nMobile, @i                  
                     GOTO Quit                  
                  END                  
               END                  
                  
               -- Save to UserID variable                  
               IF @i = 1 SET @cUserID01 = @cInField01                  
               IF @i = 2 SET @cUserID02 = @cInField02                  
               IF @i = 3 SET @cUserID03 = @cInField03                  
               IF @i = 4 SET @cUserID04 = @cInField04                               
               IF @i = 5 SET @cUserID05 = @cInField05                  
               IF @i = 6 SET @cUserID06 = @cInField06                  
               IF @i = 7 SET @cUserID07 = @cInField07                  
               IF @i = 8 SET @cUserID08 = @cInField08                  
               IF @i = 9 SET @cUserID09 = @cInField09                  
            END                  
                  
            SET @i = @i + 1                  
         END       
             
         -- Set next field focus    
         SET @i = 1 -- start from 1st field    
         IF @cInField01 <> '' SET @i = @i + 1    
         IF @cInField02 <> '' SET @i = @i + 1    
         IF @cInField03 <> '' SET @i = @i + 1    
         IF @cInField04 <> '' SET @i = @i + 1    
         IF @cInField05 <> '' SET @i = @i + 1    
         IF @cInField06 <> '' SET @i = @i + 1    
         IF @cInField07 <> '' SET @i = @i + 1    
         IF @cInField08 <> '' SET @i = @i + 1    
         IF @cInField09 <> '' SET @i = @i + 1    
         IF @i > 9 SET @i = 1    
         EXEC rdt.rdtSetFocusField @nMobile, @i                 
      END     
      ELSE                
      BEGIN            
                  
         SELECT 1 FROM DBO.CODELKUP WITH (NOLOCK)                  
         WHERE STORERKEY= @cStorerKey                  
         AND LISTNAME= 'JOBLMSType'                  
         AND Code2 = @cFacility                  
                   
         IF @@ROWCOUNT = 0                    
         BEGIN                    
            SET @nErrNo = 139106                    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'JobType No Setup'                    
            EXEC rdt.rdtSetFocusField @nMobile, @i                    
            GOTO Quit                  
         END              
               
         SET @cOutField01 =''            
         SET @cOutField02 =''                
         SET @cOutField03 =''             
         SET @cOutField04 =''            
         SET @cOutField05 =''                
         SET @cOutField06 =''             
         SET @cOutField07 =''            
         SET @cOutField08 =''                
         SET @cOutField09 ='' 
         
         If @cCaptureProcess ='1'
         BEGIN                     
            -- Go to next screen    
            SET @cOutField01=@cUserID
            SET @nScn = @nScn + 3                  
            SET @nStep = @nStep + 3 
            GOTO QUIT
         END
                  
         Declare @cCode NVARCHAR(20),@cCount INT = 1 , @cFuncIDs NVARCHAR(10)                
                   
         DECLARE CURS CURSOR FOR                  
         SELECT  Top 9 code,UDF01 FROM DBO.CODELKUP WITH (NOLOCK)                  
         WHERE STORERKEY= @cStorerKey                  
            AND LISTNAME= 'JOBLMSType'                  
            AND Code2 = @cFacility                  
                   
         OPEN CURS                  
         FETCH NEXT FROM CURS into @cCode,@cFuncIDs                  
                   
         while(@@FETCH_STATUS=0)                    
         BEGIN                    
                   
            IF @cCount = 1 BEGIN SET @cOutField01 = Cast(@cCount AS NVARCHAR(02)) + '-' + @cCode  SET @cRef01=@cCode SET @cFunc01 =@cFuncIDs END                  
            IF @cCount = 2 BEGIN SET @cOutField02 = Cast(@cCount AS NVARCHAR(02)) + '-' + @cCode  SET @cRef02=@cCode SET @cFunc02 =@cFuncIDs END                  
            IF @cCount = 3 BEGIN SET @cOutField03 = Cast(@cCount AS NVARCHAR(02)) + '-' + @cCode  SET @cRef03=@cCode SET @cFunc03 =@cFuncIDs END            
            IF @cCount = 4 BEGIN SET @cOutField04 = Cast(@cCount AS NVARCHAR(02)) + '-' + @cCode  SET @cRef04=@cCode SET @cFunc04 =@cFuncIDs END                  
            IF @cCount = 5 BEGIN SET @cOutField05 = Cast(@cCount AS NVARCHAR(02)) + '-' + @cCode  SET @cRef05=@cCode SET @cFunc05 =@cFuncIDs END                  
            IF @cCount = 6 BEGIN SET @cOutField06 = Cast(@cCount AS NVARCHAR(02)) + '-' + @cCode  SET @cRef06=@cCode SET @cFunc06 =@cFuncIDs END                  
            IF @cCount = 7 BEGIN SET @cOutField07 = Cast(@cCount AS NVARCHAR(02)) + '-' + @cCode  SET @cRef07=@cCode SET @cFunc07 =@cFuncIDs END                  
            IF @cCount = 8 BEGIN SET @cOutField08 = Cast(@cCount AS NVARCHAR(02)) + '-' + @cCode  SET @cRef08=@cCode SET @cFunc08 =@cFuncIDs END                  
            IF @cCount = 9 BEGIN SET @cOutField09 = Cast(@cCount AS NVARCHAR(02)) + '-' + @cCode  SET @cRef09=@cCode SET @cFunc09 =@cFuncIDs END                  
                   
            SET @cCount = @cCount + 1                  
                   
            Fetch next from CURS into @cCode,@cFuncIDs                    
         END                    
         Close CURS                     
         DEALLOCATE CURS                  
                         
         -- Go to next screen                  
         SET @nScn = @nScn + 1                  
         SET @nStep = @nStep + 1    
      END  
      
      -- Extended validate (yeekung02)
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            INSERT INTO @tVar (Variable, Value) VALUES
               ('@cUserID',      @cUserID),
               ('@cJobType',     @cJobType),
               ('@cUserID01',    @cUserID01),
               ('@cUserID02',    @cUserID02),
               ('@cUserID03',    @cUserID03),
               ('@cUserID04',    @cUserID04),
               ('@cUserID05',    @cUserID05),
               ('@cUserID06',    @cUserID06),
               ('@cUserID07',    @cUserID07),
               ('@cUserID08',    @cUserID08),
               ('@cUserID09',    @cUserID09),
               ('@cJobType',     @cStart),
               ('@cEnd',         @cEnd),
               ('@cDuration',    @cDuration),
               ('@cRef01',       @cRef01),
               ('@cRef02',       @cRef02),
               ('@cRef03',       @cRef03),
               ('@cRef04',       @cRef04),
               ('@cRef05',       @cRef05)

            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@tVar            VariableTable READONLY, ' +
               '@nErrNo          INT           OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20) OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @tVar, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN              
               IF @cInField01<>''  set @i = 1                
               IF @cInField02<>''  set @i = 2                
               IF @cInField03<>''  set @i = 3                
               IF @cInField04<>''  set @i = 4                
               IF @cInField05<>''  set @i = 5                
               IF @cInField06<>''  set @i = 6                
               IF @cInField07<>''  set @i = 7                
               IF @cInField08<>''  set @i = 8                
               IF @cInField09<>''  set @i = 9                
                                                                              
               -- Error, clear the UCC field                  
               IF @i = 1 SELECT @cUserID01 = '', @cInField01 = '', @cOutField01 = ''                  
               IF @i = 2 SELECT @cUserID02 = '', @cInField02 = '', @cOutField02 = ''                  
               IF @i = 3 SELECT @cUserID03 = '', @cInField03 = '', @cOutField03 = ''                  
               IF @i = 4 SELECT @cUserID04 = '', @cInField04 = '', @cOutField04 = ''                  
               IF @i = 5 SELECT @cUserID05 = '', @cInField05 = '', @cOutField05 = ''                  
               IF @i = 6 SELECT @cUserID06 = '', @cInField06 = '', @cOutField06 = ''                  
               IF @i = 7 SELECT @cUserID07 = '', @cInField07 = '', @cOutField07 = ''                  
               IF @i = 8 SELECT @cUserID08 = '', @cInField08 = '', @cOutField08 = ''                  
               IF @i = 9 SELECT @cUserID09 = '', @cInField09 = '', @cOutField09 = ''                  
               EXEC rdt.rdtSetFocusField @nMobile, @i                  
            END     
         END
      END

   END                  
                      
   IF @nInputKey = 0 -- ESC                      
   BEGIN                  
                     
      SET @cUserID01 = ''                  
      SET @cUserID02 = ''                  
      SET @cUserID03 = ''                        
      SET @cUserID04 = ''                        
      SET @cUserID05 = ''                  
      SET @cUserID06 = ''                        
      SET @cUserID07 = ''                  
      SET @cUserID08 = ''                        
      SET @cUserID09 = ''                        
      SET @cCheckUserID = ''                  
                         
      -- Prepare next screen var                      
      SET @cOutField01 = '' -- UserID                      
      SET @cOutField02 = ''                        
      SET @cOutField03 = '' -- End                      
      SET @cOutField04 = '' -- Duration                      
                      
      SET @nScn = @nScn - 1                                      
      SET @nStep = @nStep - 1                                      
   END                      
END                      
GOTO Quit                      
                      
                      
/********************************************************************************                      
Step 3. Screen = 5482. Capture Process                    
   Process:                     
   (Field01)                     
   (Field02)                    
   (Field03)                    
   (Field04)                    
   (Field05)                      
   (Field06)                     
   (Field07)                    
   (Field08)                    
   (Field09)                     
   Option:    (Field10,input)                    
********************************************************************************/                      
Step_3:                      
BEGIN                      
   IF @nInputKey = 1 -- ENTER                      
   BEGIN                  
                        
      SET @cOption = @cInField10                                
      IF (@cOption < 1 and @cOption > @cCount)                  
      BEGIN                  
         SET @nErrNo = 139109                   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Option'                    
         EXEC rdt.rdtSetFocusField @nMobile, 10                   
         GOTO Quit                   
      END                  
      ELSE                  
      BEGIN                  
         IF @cOption = 1 BEGIN SET @cJobType = @cRef01 SET @cFuncID= @cFunc01 END                
         IF @cOption = 2 BEGIN SET @cJobType = @cRef02 SET @cFuncID= @cFunc02 END                
         IF @cOption = 3 BEGIN SET @cJobType = @cRef03 SET @cFuncID= @cFunc03 END                
         IF @cOption = 4 BEGIN SET @cJobType = @cRef04 SET @cFuncID= @cFunc04 END                
         IF @cOption = 5 BEGIN SET @cJobType = @cRef05 SET @cFuncID= @cFunc05 END                
         IF @cOption = 6 BEGIN SET @cJobType = @cRef06 SET @cFuncID= @cFunc06 END                
         IF @cOption = 7 BEGIN SET @cJobType = @cRef07 SET @cFuncID= @cFunc07 END                
         IF @cOption = 8 BEGIN SET @cJobType = @cRef08 SET @cFuncID= @cFunc08 END                
         IF @cOption = 9 BEGIN SET @cJobType = @cRef09 SET @cFuncID= @cFunc09 END                 
      END         
    
      -- Put all User into temp table                           
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID)                         
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID01)                        
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID02)                           
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID03)            
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID04)            
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID05)            
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID06)            
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID07)            
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID08)            
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID09)            
            
    
      SELECT  @cTotalUser=COUNT(*)      
      FROM @tUserID     
      WHERE isnull(value,'')<>'';            
      
      -- Confirm                          
      EXEC rdt.rdt_GroupJobCapture_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'START',                           
         @cUserID   = @cUserID,                           
         @cJobType  = @cJobType,       
         @cTable    = @tUserID,                          
         @cStart    = @cStart    OUTPUT,                           
         @cEnd      = @cEnd      OUTPUT,                           
         @cDuration = @cDuration OUTPUT,                     
         @nErrNo    = @nErrNo    OUTPUT,                           
         @cErrMsg   = @cErrMsg   OUTPUT,                    
         @cRef01    = @cFuncID,      
         @cRef02    = @cTotalUser                       
      IF @nErrNo <> 0                      
         GOTO Quit                    
                        
      -- Prepare next screen var                      
      SET @cOutField01 = '' -- UserID                      
      SET @cOutField02 = @cStart                      
      SET @cOutField03 = '' -- End                      
      SET @cOutField04 = '' -- Duration                   
                  
      SET @nScn  = @nScn - 2                      
      SET @nStep = @nStep - 2                    
   END                      
                      
   IF @nInputKey = 0 -- ESC                      
   BEGIN                      
      -- Prepare next screen var                      
      SET @cOutField01 = @cUserID01                   
      SET @cOutField02 = @cUserID02                  
      SET @cOutField03 = @cUserID03                   
      SET @cOutField04 = @cUserID04                   
      SET @cOutField05 = @cUserID05                   
      SET @cOutField06 = @cUserID06                   
      SET @cOutField07 = @cUserID07                   
      SET @cOutField08 = @cUserID08                    
      SET @cOutField09 = @cUserID09           
                   
      SET @nScn  = @nScn - 1                      
      SET @nStep = @nStep - 1                      
   END                      
END                      
GOTO Quit    
    
/********************************************************************************        
Step 4. Screen = 5483        
   CONFIRM JOB END?        
   OPTION (Field01, input)        
********************************************************************************/        
Step_4:        
BEGIN        
   IF @nInputKey = 1 -- ENTER        
   BEGIN        
        
      -- Screen mapping        
      SET @cOption = @cInField01        
        
      -- Check blank        
      IF @cOption = ''        
      BEGIN        
         SET @nErrNo = 139110        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need option        
         GOTO Quit        
      END        
        
      -- Check option valid        
      IF @cOption NOT IN ('1', '9')        
      BEGIN        
         SET @nErrNo = 139111        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option        
         SET @cOutField01 = ''        
         GOTO Quit        
      END        
        
      IF @cOption = '1' -- YES        
      BEGIN        
         EXEC rdt.rdt_GroupJobCapture_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'END',                       
            @cUserID   = @cUserID,                           
            @cJobType  = @cJobType,                                  
            @cStart    = @cStart    OUTPUT,                           
            @cEnd      = @cEnd      OUTPUT,                           
            @cDuration = @cDuration OUTPUT,                          
            @nErrNo    = @nErrNo    OUTPUT,                           
            @cErrMsg   = @cErrMsg   OUTPUT                          
         IF @nErrNo <> 0                          
            GOTO Quit                          
                          
         -- Prep next screen var                          
         SET @cOutField01 = '' --  UserID                          
         SET @cOutField02 = @cStart                          
         SET @cOutField03 = @cEnd                          
         SET @cOutField04 = @cDuration      
        
         SET @nScn = @nScn - 3        
         SET @nStep = @nStep - 3        
        
         GOTO Quit        
      END       
            
      IF @cOption = '9'      
      BEGIN      
         -- Prepare next screen var        
         SET @cOutField01 = '' -- User ID        
         SET @cOutField02 = @cStart        
         SET @cOutField03 = '' -- End        
         SET @cOutField04 = '' -- Duration        
        
         SET @nScn = @nScn - 3                        
         SET @nStep = @nStep - 3      
         GOTO Quit                
      END       
   END        
        
   -- Prepare next screen var        
   SET @cOutField01 = '' -- User ID        
   SET @cOutField02 = @cStart        
   SET @cOutField03 = '' -- End        
   SET @cOutField04 = '' -- Duration        
        
   SET @nScn = @nScn - 3                        
   SET @nStep = @nStep - 3                        
        
END        
GOTO Quit        

                      
/********************************************************************************                      
Step 3. Screen = 5482. Capture Process                    
   Process:                     
   (Field01)                     
   (Field02)                    
   (Field03)                    
   (Field04)                    
   (Field05)                      
   (Field06)                     
   (Field07)                    
   (Field08)                    
   (Field09)                     
   Option:    (Field10,input)                    
********************************************************************************/                      
Step_5:                      
BEGIN                      
   IF @nInputKey = 1 -- ENTER                      
   BEGIN                  
                        
      SET @cJobType = @cInField02     
      
      IF NOT EXISTS ( SELECT 1 FROM DBO.CODELKUP WITH (NOLOCK)                  
                     WHERE STORERKEY= @cStorerKey                  
                        AND LISTNAME= 'JOBLMSType'                  
                        AND Code2 = @cFacility   
                        AND Code = @cJobType )
      BEGIN        
         SET @nErrNo = 139112        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid option        
         SET @cOutField02 = ''        
         GOTO Quit        
      END        


      -- Put all User into temp table                        
            
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID)                         
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID01)                        
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID02)                           
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID03)            
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID04)            
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID05)            
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID06)            
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID07)            
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID08)            
      INSERT INTO @tUserID (variable, value) VALUES ('Users',@cUserID09)            
        
      SELECT  @cTotalUser=COUNT(*)      
      FROM @tUserID     
      WHERE isnull(value,'')<>'';            
      
      -- Confirm                          
      EXEC rdt.rdt_GroupJobCapture_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, 'START',                           
         @cUserID   = @cUserID,                           
         @cJobType  = @cJobType,       
         @cTable    = @tUserID,                          
         @cStart    = @cStart    OUTPUT,                           
         @cEnd      = @cEnd      OUTPUT,                           
         @cDuration = @cDuration OUTPUT,                     
         @nErrNo    = @nErrNo    OUTPUT,                           
         @cErrMsg   = @cErrMsg   OUTPUT,                    
         @cRef01    = @cFuncID,      
         @cRef02    = @cTotalUser                       
      IF @nErrNo <> 0                      
         GOTO Quit                    
                        
      -- Prepare next screen var                      
      SET @cOutField01 = '' -- UserID                      
      SET @cOutField02 = @cStart                      
      SET @cOutField03 = '' -- End                      
      SET @cOutField04 = '' -- Duration                   
                  
      SET @nScn  = @nScn - 4                      
      SET @nStep = @nStep - 4                    
   END                      
                      
   IF @nInputKey = 0 -- ESC                      
   BEGIN                      
      -- Prepare next screen var                      
      SET @cOutField01 = @cUserID01                   
      SET @cOutField02 = @cUserID02                  
      SET @cOutField03 = @cUserID03                   
      SET @cOutField04 = @cUserID04                   
      SET @cOutField05 = @cUserID05                   
      SET @cOutField06 = @cUserID06                   
      SET @cOutField07 = @cUserID07                   
      SET @cOutField08 = @cUserID08                    
      SET @cOutField09 = @cUserID09           
                   
      SET @nScn  = @nScn - 3                      
      SET @nStep = @nStep - 3                      
   END                      
END                      
GOTO Quit    
                                            
/********************************************************************************                      
Quit. Update back to I/O table, ready to be pick up by JBOSS                      
********************************************************************************/                      
Quit:                      
BEGIN                      
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET                          
      EditDate       = GETDATE(),                          
      ErrMsg         = @cErrMsg,                          
     Func           = @nFunc,                          
      Step           = @nStep,                          
      Scn            = @nScn,                          
                          
      StorerKey      = @cStorerKey,                          
      Facility       = @cFacility,                          
                          
      V_String1    = @cUserID,                             
      V_String2      = @cStart,                          
      V_String3      = @cEnd,                          
      V_String4      = @cDuration,                      
      V_String5      = @cCaptureUser,      
      V_String6      = @cJobType,                           
      V_String10     = @cExtendedValidateSP,                           
                         
      V_String12     = @cUserID01,                        
      V_String13     = @cUserID02,                        
      V_String14     = @cUserID03,                        
      V_String15     = @cUserID04,                        
      V_String16     = @cUserID05,                      
      V_String17     = @cUserID06,                        
      V_String18     = @cUserID07,                        
      V_String19     = @cUserID08,                        
      V_String20     = @cUserID09,                          
      V_String21     = @cCheckUserID,                      
      V_String22     = @cRef01,                                     
      V_String23     = @cRef02,                               
      V_String24     = @cRef03,                               
      V_String25     = @cRef04,                               
      V_String26     = @cRef05,                               
      V_String27     = @cRef06,                            
      V_String28     = @cRef07,                            
      V_String29     = @cRef08,                               
      V_String30     = @cRef09,                    
      V_String31     = @cFunc01,                                     
      V_String32     = @cFunc02,                               
      V_String33     = @cFunc03,                               
      V_String34     = @cFunc04,                               
      V_String35     = @cFunc05,                               
      V_String36     = @cFunc06,                            
      V_String37     = @cFunc07,                            
      V_String38     = @cFunc08,                               
      V_String39     = @cFunc09,    
      V_String40     = @cConfirmEnd,     
      V_String41     = @cCaptureProcess,
                                          
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