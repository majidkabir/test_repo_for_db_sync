SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdtfnc_UCC_SortAndMove                              */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: UCC Sort and Move                                           */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2017-10-10 1.0  ChewKP   WMS-3166 Created                            */
/* 2018-10-26 1.1  Gan      Performance tuning                          */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtfnc_UCC_SortAndMove] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF  

-- Misc variable
DECLARE 
   @cUCC         NVARCHAR( 20), 
   @cChkFacility NVARCHAR( 5), 
   @i            INT

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
   
   @cSKU       NVARCHAR( 20), 
   @cSKUDescr  NVARCHAR( 60), 

   @cUCC1      NVARCHAR( 20), 
   @cUCC2      NVARCHAR( 20), 
   @cUCC3      NVARCHAR( 20), 
   @cUCC4      NVARCHAR( 20), 
   @cUCC5      NVARCHAR( 20), 
   @cUCC6      NVARCHAR( 20), 
   @cUCC7      NVARCHAR( 20), 
   @cUCC8      NVARCHAR( 20), 
   @cUCC9      NVARCHAR( 20), 

   @cToLOC     NVARCHAR( 10), 
   @cToID      NVARCHAR( 18), 
   @cUserName  NVARCHAR(18), 
   @cFromLOC   NVARCHAR( 10), 
   @cExtendedValidateSP NVARCHAR( 20), 
   @cExtendedUpdateSP   NVARCHAR( 20), 
   @cSQL                NVARCHAR(1000), 
   @cSQLParam           NVARCHAR(1000), 
   @cSortCodeText       NVARCHAR(20),
   @cSortCode           NVARCHAR(20),
   @cExtendedInfoSP     NVARCHAR(20),
   @cUCCLOC             NVARCHAR(10),
   @cUCCID              NVARCHAR(18),
   @cDefaultToLoc       NVARCHAR(10),
   
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
   @cUserName  = UserName,

   @cSKU       = V_SKU, 
   @cSKUDescr  = V_SKUDescr, 

   @cUCC          = V_String1,
   @cSortCodeText = V_String2, 
   @cSortCode     = V_String3,
   @cToLOC        = V_String4, 
   @cToID         = V_String5, 
   @cExtendedValidateSP = V_String6, 
   @cExtendedUpdateSP   = V_String7,
   @cExtendedInfoSP     = V_String8,
   @cDefaultToLoc       = V_String9,

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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 624 -- Move (UCC)
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Move (generic)
   IF @nStep = 1 GOTO Step_1   -- Scn = 808. UCC1..9, SKU, Desc1, Desc2
   IF @nStep = 2 GOTO Step_2   -- Scn = 809. ToLOC, ToID
   IF @nStep = 3 GOTO Step_3   -- Scn = 810. Message
   --IF @nStep = 4 GOTO Step_4   -- Scn = 811. FROM LOC -- (james02)
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 514. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   
   SET @nScn = 5030
   SET @nStep = 1
   
   
   
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''
      
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
   IF @cExtendedUpdateSP = '0'  
      SET @cExtendedUpdateSP = ''
      
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'
      SET @cExtendedInfoSP = ''   
      
   SET @cDefaultToLoc = rdt.RDTGetConfig( @nFunc, 'DefaultToLoc', @cStorerKey)
   IF @cDefaultToLoc = '0'
      SET @cDefaultToLoc = ''   
   
   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep

   -- Initiate var
   
   SET @cToLOC = ''
   SET @cToID = ''
   SET @cSKU = ''
   SET @cSKUDescr = ''

   --Prep next screen var
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
   SET @cOutField12 = '' 

END
GOTO Quit


/********************************************************************************
Step 1. Scn = 5030. Move From screen
   UCC  (field01)
  
********************************************************************************/
Step_1:      
BEGIN      
   IF @nInputKey = 1 --ENTER      
   BEGIN      
            
      SET @cUCC = ISNULL(RTRIM(@cInField01),'')      
      
          
      IF @cUCC = ''
      BEGIN
         SET @nErrNo = 115851      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCReq    
         GOTO Step_1_Fail  
      END
      
      
      IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)  
                      WHERE StorerKey = @cStorerKey  
                      AND UCCNo = @cUCC 
                      AND Status = '1' )   
      BEGIN  
         SET @nErrNo = 115852      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvUCC
         GOTO Step_1_Fail      
      END    
      
      IF @cExtendedValidateSP <> ''    
      BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +     
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cUCC, @cToID, @cToLoc, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
               SET @cSQLParam =    
                  '@nMobile        INT,            ' +    
                  '@nFunc          INT,            ' +    
                  '@cLangCode      NVARCHAR(3),    ' +    
                  '@nStep          INT,            ' +    
                  '@nInputKey      INT,            ' +   
                  '@cUserName      NVARCHAR( 18),  ' +     
                  '@cFacility      NVARCHAR( 5),   ' +     
                  '@cStorerKey     NVARCHAR( 15),  ' +     
                  '@cUCC           NVARCHAR( 20),  ' +     
                  '@cToID          NVARCHAR( 10),  ' +   
                  '@cToLoc         NVARCHAR( 10),  ' +   
                  '@nErrNo         INT OUTPUT, ' +      
                  '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cUCC, @cToID, @cToLoc, @nErrNo OUTPUT, @cErrMsg OUTPUT
        
               IF @nErrNo <> 0    
                  GOTO Step_1_Fail  
            
         END    
      END  
      
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cUCC, @cSortCodeText OUTPUT, @cSortCode OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile        INT,            ' +    
               '@nFunc          INT,            ' +    
               '@cLangCode      NVARCHAR(3),    ' +    
               '@nStep          INT,            ' +   
               '@nInputKey      INT,            ' +    
               '@cUserName      NVARCHAR( 18),  ' +     
               '@cFacility      NVARCHAR( 5),   ' +     
               '@cStorerKey     NVARCHAR( 15),  ' +     
               '@cUCC           NVARCHAR( 20),  ' +     
               '@cSortCodeText  NVARCHAR( 20) OUTPUT ,  ' +     
               '@cSortCode      NVARCHAR( 20) OUTPUT ,  ' +     
               '@nErrNo         INT OUTPUT, ' +      
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cUCC, @cSortCodeText OUTPUT, @cSortCode OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
        
            IF @nErrNo <> 0    
               GOTO Step_1_Fail  
            
            SET @cOutField01 = @cSortCodeText 
            SET @cOutField02 = @cSortCode
            SET @cOutField03 = ''
            SET @cOutField04 = CASE WHEN ISNULL(@cDefaultToLoc,'' ) = '' THEN '' ELSE @cDefaultToLoc END
         END    
      END  -- IF @cExtendedInfoSP <> ''  
      ELSE
      BEGIN
      
         -- Prepare Next Screen Variable      
         SET @cOutField01 = ''  
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cOutField04 = CASE WHEN ISNULL(@cDefaultToLoc,'' ) = '' THEN '' ELSE @cDefaultToLoc END
      END
      
      -- GOTO Next Screen      
      SET @nScn = @nScn + 1      
      SET @nStep = @nStep + 1     
    
        
            
   END  -- Inputkey = 1      
      
   IF @nInputKey = 0     
   BEGIN      
              
--    -- EventLog - Sign In Function      
      EXEC RDT.rdt_STD_EventLog      
        @cActionType = '9', -- Sign in function      
        @cUserID     = @cUserName,      
        @nMobileNo   = @nMobile,      
        @nFunctionID = @nFunc,      
        @cFacility   = @cFacility,      
        @cStorerKey  = @cStorerkey,
        @nStep       = @nStep
              
      --go to main menu      
      SET @nFunc = @nMenu      
      SET @nScn  = @nMenu      
      SET @nStep = 0      
      SET @cOutField01 = ''      
  
   END      
   GOTO Quit      
      
   STEP_1_FAIL:      
   BEGIN      
      -- Prepare Next Screen Variable      
      SET @cOutField01 = ''
      
     
   END      
END       
GOTO QUIT   


/********************************************************************************
Step 2. scn = 5031. Move to screen
   SortCodeText (field03)
   SortCode     (field03)
   ToID         (field03)
   ToLOC        (field04)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Screen mapping
      SET @cToID  = ISNULL(@cInField03,'') 
      SET @cToLOC = ISNULL(@cInField04,'') 

      --SET @cToID = 'GIT001'
      --SET @cToLoc = 'TRISTAGE'

      -- Validate blank
      IF @cToLOC = '' 
      BEGIN
         SET @nErrNo = 115853
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToLOCReq'
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_2_Fail
      END
      
      -- Get LOC
      
   
      -- Validate LOC
      IF NOT EXISTS ( SELECT 1
                      FROM dbo.LOC (NOLOCK)
                      WHERE Facility = @cFacility
                      AND LOC = @cToLOC ) 
      BEGIN
         SET @nErrNo = 115854
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidToLOC'
         SET @cToLOC = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Step_2_Fail
      END

      SELECT @cChkFacility = Facility
      FROM dbo.LOC (NOLOCK)
      WHERE Facility = @cFacility
      AND LOC = @cToLOC
      
      -- Validate ToLOC's facility
      IF NOT (rdt.rdtGetConfig( 0, 'MoveToLOCNotCheckFacility', @cStorerKey) = '1')
         IF @cChkFacility <> @cFacility
         BEGIN
            SET @nErrNo = 115855
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DiffFacility'
            SET @cToLOC = ''
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Step_2_Fail
         END

      IF @cExtendedValidateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey,@cUserName, @cFacility, @cStorerKey, @cUCC, @cToID, @cToLoc, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile        INT,            ' +    
               '@nFunc          INT,            ' +    
               '@cLangCode      NVARCHAR(3),    ' +    
               '@nStep          INT,            ' +   
               '@nInputKey      INT,            ' +     
               '@cUserName      NVARCHAR( 18),  ' +     
               '@cFacility      NVARCHAR( 5),   ' +     
               '@cStorerKey     NVARCHAR( 15),  ' +     
               '@cUCC           NVARCHAR( 20),  ' +     
               '@cToID          NVARCHAR( 10),  ' +   
               '@cToLoc         NVARCHAR( 10),  ' +   
               '@nErrNo         INT OUTPUT, ' +      
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey,@cUserName, @cFacility, @cStorerKey, @cUCC, @cToID, @cToLoc, @nErrNo OUTPUT, @cErrMsg OUTPUT
        
            IF @nErrNo <> 0    
               GOTO Step_2_Fail  
            
         END    
      END  
      
      -- Extended update
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cUCC, @cToID, @cToLoc, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile        INT,            ' +    
               '@nFunc          INT,            ' +    
               '@cLangCode      NVARCHAR(3),    ' +    
               '@nStep          INT,            ' + 
               '@nInputKey      INT,            ' +       
               '@cUserName      NVARCHAR( 18),  ' +     
               '@cFacility      NVARCHAR( 5),   ' +     
               '@cStorerKey     NVARCHAR( 15),  ' +     
               '@cUCC           NVARCHAR( 20),  ' +     
               '@cToID          NVARCHAR( 10),  ' +   
               '@cToLoc         NVARCHAR( 10),  ' +   
               '@nErrNo         INT OUTPUT, ' +      
               '@cErrMsg        NVARCHAR( 20) OUTPUT'    
                
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cUserName, @cFacility, @cStorerKey, @cUCC, @cToID, @cToLoc, @nErrNo OUTPUT, @cErrMsg OUTPUT
        
            IF @nErrNo <> 0    
               GOTO Step_2_Fail  
         END
      END
      ELSE
      BEGIN
            -- Get FromLOC, FromID
            SELECT 
               @cUCCLOC = LOC, 
               @cUCCID = ID
            FROM dbo.UCC (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND UCCNo = @cUCC
               AND Status = '1' -- Received

            SET @cSKU = ''
            EXEC RDT.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode, 
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
               @cSourceType = 'rdtfnc_UCC_SortAndMove', 
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility, 
               @cFromLOC    = @cUCCLOC, 
               @cToLOC      = @cToLOC, 
               @cFromID     = @cUCCID,
               @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
               @cSKU        = NULL, 
               @cUCC        = @cUCC,
               @nFunc       = @nFunc  
         
            IF @nErrNo <> 0
            BEGIN
               
               GOTO Step_2_Fail
            END
            
            
      END
      
      -- Log event
      EXEC RDT.rdt_STD_EventLog
      @cActionType   = '4', -- Move
      @cUserID       = @cUserName,
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerkey,
      @cLocation     = @cUCCLOC,
      @cToLocation   = @cToLOC,
      @cID           = @cUCCID, 
      @cToID         = @cToID, 
      @cUCC          = @cUCC,
      --@cRefNo1       = @cUCC,
      @nStep         = @nStep
                  
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
      SET @cOutfield01 = ''
      
      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   
   Step_2_Fail:
   BEGIN
      
      SET @cOutField03 = @cToID
      SET @cOutField04 = @cToLoc 
   END
   
   
END
GOTO Quit


/********************************************************************************
Step 3. scn = 5032. Message screen
   Msg
********************************************************************************/
Step_3:
BEGIN
   -- Go back to SKU screen  
   
   SET @nScn  = @nScn - 2 
   SET @nStep = @nStep - 2   
   

   -- Init next screen var
   SET @cUCC1 = ''
   SET @cUCC2 = ''
   SET @cUCC3 = ''
   SET @cUCC4 = ''
   SET @cUCC5 = ''
   SET @cUCC6 = ''
   SET @cUCC7 = ''
   SET @cUCC8 = ''
   SET @cUCC9 = ''
   SET @cSKU = ''
   SET @cSKUDescr = ''
   SET @cToID = ''
   SET @cToLOC = ''
   SET @cFromLOC = ''
   
   
   SET @cOutField01 = '' 
   
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

      StorerKey  = @cStorerKey,
      Facility   = @cFacility, 
      

      V_SKU      = @cSKU, 
      V_SKUDescr = @cSKUDescr, 
   
      V_String1 = @cUCC           ,
      V_String2 = @cSortCodeText  , 
      V_String3 = @cSortCode      ,
      V_String4 = @cToLOC         , 
      V_String5 = @cToID          , 
      V_String6 = @cExtendedValidateSP, 
      V_String7 = @cExtendedUpdateSP  ,  
      V_String8 = @cExtendedInfoSP    ,
      V_String9 = @cDefaultToLoc,

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