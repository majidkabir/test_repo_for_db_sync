SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
         
/************************************************************************/
/* Store procedure: rdtfnc_SKU_Replenishment                            */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Replenishment by SKU                                        */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-06-12 1.0  YeeKung    WMS-13629 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_SKU_Replenishment] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF


DECLARE
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT,
   @nMenu               INT,
   @b_Success           INT,
   @cSQL                NVARCHAR( MAX),  
   @cSQLParam           NVARCHAR( MAX),  

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),
   @cUserName           NVARCHAR(18),
   @cPrinter            NVARCHAR(10),
   @cSKU                NVARCHAR(20),
   @cFromLOC            NVARCHAR(10),
   @cSuggToLoc          NVARCHAR(10),
   @cToLoc              NVARCHAR(10),
   @cExtendedUpdateSP   NVARCHAR(20),
   @cExtendedValidateSP NVARCHAR(20),
   @cRepleshGetLocSP    NVARCHAR(20),
   @cSuggID             NVARCHAR(20),
   @cFromID             NVARCHAR(20),
   @cFromLOT            NVARCHAR(20),

   @nQTY                INT,
   @nQTYAlloc           INT,
   @nQTYPick            INT,

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
   @nFunc         = Func,
   @nScn          = Scn,
   @nStep         = Step,
   @nInputKey     = InputKey,
   @nMenu         = Menu,
   @cLangCode     = Lang_code,

   @cStorerKey    = StorerKey,
   @cFacility     = Facility,
   @cPrinter      = Printer,
   @cUserName     = UserName,

   @cSKU                = V_String1,
   @cFromLOC            = V_String2,
   @cSuggToLoc          = V_String3,
   @cExtendedUpdateSP   = V_String4,
   @cExtendedValidateSP = V_String5,
   @cRepleshGetLocSP    = V_String6,
   @cToLoc              = V_String7,
   @cFromID             = V_String8,
   @cFromLOT            = V_String9,
   @cSuggID             = V_String10,

   @nQTY                = V_Integer1,
   @nQTYAlloc           = V_Integer2,
   @nQTYPick            = V_Integer3,

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

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 1842 -- Handover data capture
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Data capture
   IF @nStep = 1 GOTO Step_1   -- Scn = 5760 SKU
   IF @nStep = 2 GOTO Step_2   -- Scn = 5761 FROMID
   IF @nStep = 3 GOTO Step_3   -- Scn = 5762 TOLOC
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 1842. Menu
********************************************************************************/
Step_0:
BEGIN

   -- Set the entry point
   SET @nScn = 5760
   SET @nStep = 1

   SET @cRepleshGetLocSP = rdt.RDTGetConfig( @nFunc, 'RepleshGetLocSP', @cStorerKey)                
   IF @cRepleshGetLocSP = '0'                  
   BEGIN                
      SET @cRepleshGetLocSP = ''                
   END

   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)                
   IF @cExtendedUpdateSP = '0'                  
   BEGIN                
      SET @cExtendedUpdateSP = ''                
   END
   
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)  
   IF @cExtendedValidateSP = '0'  
      SET @cExtendedValidateSP = ''    


   -- Prepare next screen var
   SET @cOutField01 = '' -- Wavekey

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
Step 1. Screen = 5610
   SKU  (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      
      SET @cSKU=@cInField01
 
      IF @cSKU = '' OR @cSKU IS NULL  
      BEGIN  
         SET @nErrNo = 153951  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU is require  
         GOTO Step_1_Fail  
      END 

      -- Get SKU barcode count  
      DECLARE @nSKUCnt INT  
      EXEC rdt.rdt_GETSKUCNT  
          @cStorerkey  = @cStorerKey  
         ,@cSKU        = @cSKU  
         ,@nSKUCnt     = @nSKUCnt       OUTPUT  
         ,@bSuccess    = @b_Success     OUTPUT  
         ,@nErr        = @nErrNo        OUTPUT  
         ,@cErrMsg     = @cErrMsg       OUTPUT  
  
      -- Check SKU/UPC  
      IF @nSKUCnt = 0  
      BEGIN  
         SET @nErrNo = 153952  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU  
         GOTO Step_1_Fail  
      END

      -- Check multi SKU barcode  
      IF @nSKUCnt > 1  
      BEGIN  
         SET @nErrNo = 153953  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod  
         GOTO Step_1_Fail  
      END

      -- Get SKU
      EXEC rdt.rdt_GetSKU
         @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU      OUTPUT
         ,@bSuccess    = @b_Success OUTPUT
         ,@nErr        = @nErrNo    OUTPUT
         ,@cErrMsg     = @cErrMsg   OUTPUT
      IF @nErrNo <> 0
         GOTO Step_1_Fail

       -- Extended validate  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +  
               ' @cFromLOC, @cSKU,@cSuggToLoc,@cFromID,@cSuggID, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
            SET @cSQLParam =  
               '@nMobile         INT,           ' +  
               '@nFunc           INT,           ' +  
               '@cLangCode       NVARCHAR( 3),  ' +  
               '@nStep           INT,           ' +  
               '@nInputKey       INT,           ' +  
               '@cStorerKey      NVARCHAR( 15), ' +  
               '@cFacility       NVARCHAR( 5),  ' +  
               '@cFromLOC        NVARCHAR( 10), ' +  
               '@cSKU            NVARCHAR( 20), ' +  
               '@cSuggToLoc      NVARCHAR( 10), ' +  
               '@cFromID         NVARCHAR( 20), ' +  
               '@cSuggID         NVARCHAR( 20), ' +  
               '@nErrNo          INT           OUTPUT, ' +  
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,  
               @cFromLOC, @cSKU,@cSuggToLoc,@cFromID,@cSuggID, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0  
               GOTO Step_1_Fail  
         END  
      END  

      IF @cRepleshGetLocSP <>''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRepleshGetLocSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cRepleshGetLocSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +  
               ' @cSKU,@cFromLOC OUTPUT,@cSuggToLoc OUTPUT,@cSuggID OUTPUT,@cFromLOT OUTPUT,@nQTY OUTPUT,@nQTYAlloc OUTPUT,@nQTYPick OUTPUT,'+ 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '  
            SET @cSQLParam =  
               '@nMobile         INT,           ' +  
               '@nFunc           INT,           ' +  
               '@cLangCode       NVARCHAR( 3),  ' +  
               '@nStep           INT,           ' +  
               '@nInputKey       INT,           ' +  
               '@cStorerKey      NVARCHAR( 15), ' +  
               '@cFacility       NVARCHAR( 5),  ' +  
               '@cSKU            NVARCHAR( 20), ' +  
               '@cFromLOC        NVARCHAR( 10) OUTPUT, ' +  
               '@cSuggToLoc      NVARCHAR( 10) OUTPUT, ' + 
               '@cSuggID         NVARCHAR( 20) OUTPUT, ' + 
               '@cFromLOT        NVARCHAR( 20) OUTPUT, ' + 
               '@nQTY            INT           OUTPUT, ' +
               '@nQTYAlloc       INT           OUTPUT, ' +
               '@nQTYPick        INT           OUTPUT, ' +
               '@nErrNo          INT           OUTPUT, ' +  
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,  
               @cSKU,@cFromLOC OUTPUT,@cSuggToLoc OUTPUT,@cSuggID OUTPUT,@cFromLOT OUTPUT,@nQTY OUTPUT,@nQTYAlloc OUTPUT,@nQTYPick OUTPUT
               , @nErrNo OUTPUT, @cErrMsg OUTPUT 
  
            IF @nErrNo <> 0  
               GOTO Step_1_Fail  
         END  
      END

      SET @nScn  = @nScn+1
      SET @nStep = @nStep+1
      SET @cOutField01=@cSKU
      SET @cOutField02=@cFromLOC
      SET @cOutField03=@cSuggID

      GOTO QUIT

   END

   IF @nInputkey = 0
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign-out
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey

      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''

      GOTO Quit
   END

   Step_1_Fail:
   BEGIN
      SET @cSKU=''
      SET @cOutField01=''
      GOTO Quit
   END
END
GOTO Quit

/********************************************************************************
Step 2. Screen = 5761
  SKU
  (field 1)
  FROMID
  (field 2)
  (field 3)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      
      SET @cFromID=@cInField04
 
      IF @cFromID = '' OR @cFromID IS NULL  
      BEGIN  
         SET @nErrNo = 153956  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID is require  
         GOTO Step_2_Fail  
      END 

      IF @cFromID<>@cSuggID
      BEGIN  
         SET @nErrNo = 153957
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID is require  
         GOTO Step_2_Fail  
      END 

       -- Extended validate  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +  
               ' @cFromLOC, @cSKU,@cSuggToLoc,@cFromID,@cSuggID, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
            SET @cSQLParam =  
               '@nMobile         INT,           ' +  
               '@nFunc           INT,           ' +  
               '@cLangCode       NVARCHAR( 3),  ' +  
               '@nStep           INT,           ' +  
               '@nInputKey       INT,           ' +  
               '@cStorerKey      NVARCHAR( 15), ' +  
               '@cFacility       NVARCHAR( 5),  ' +  
               '@cFromLOC        NVARCHAR( 10), ' +  
               '@cSKU            NVARCHAR( 20), ' +  
               '@cSuggToLoc      NVARCHAR( 10), ' +  
               '@cFromID         NVARCHAR( 20), ' +  
               '@cSuggID         NVARCHAR( 20), ' +  
               '@nErrNo          INT           OUTPUT, ' +  
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '  
  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,  
               @cFromLOC, @cSKU,@cSuggToLoc,@cFromID,@cSuggID, @nErrNo OUTPUT, @cErrMsg OUTPUT 
  
            IF @nErrNo <> 0  
               GOTO Step_2_Fail  
         END  
      END  

      SET @nScn  = @nScn+1
      SET @nStep = @nStep+1
      SET @cOutField01=@cSKU
      SET @cOutField02=@cFromLOC
      SET @cOutField04=@cFromID
      SET @cOutField05=@cSuggToLoc

      GOTO QUIT

   END

   IF @nInputkey = 0
   BEGIN
     
      SET @cOutField01 = ''
      SET @cSKU = ''
      SET @cSuggToLoc=''
      SET @cFromLOC=''
      SET @cSuggID = ''
      SET @cFromID = ''
      SET @nStep=@nStep-1
      SET @nScn=@nScn-1

      GOTO Quit
   END

   Step_2_Fail:
   BEGIN
      SET @cFromID=''
      SET @cInField04=''
      GOTO Quit
   END
END
GOTO Quit



/********************************************************************************
Step 3. Screen = 5611
   WAVEKEY
   (field01)
   USERID
   (field02)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      
      SET @cToLoc=@cInField06

      IF ISNULL(@cToLoc,'')=''
      BEGIN
         SET @nErrNo = 153954 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NeedToLoc  
         GOTO Step_3_Fail  
      END
      
      IF ISNULL(@cSuggToLoc,'')<>'' AND (@cToLoc<>@cSuggToLoc)
      BEGIN
         SET @nErrNo = 153955 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- LOCNOTSAME  
         GOTO Step_3_Fail  
      END

      EXEC [RDT].[rdt_Move]
         @nMobile    = @nMobile,    
         @cLangCode  = @cLangCode,   
         @nErrNo     = @nErrNo OUTPUT,    
         @cErrMsg    = @cErrMsg OUTPUT,   
         @cSourceType= 'rdtfnc_SKU_Replenishment', 
         @cStorerKey = @cStorerKey,  
         @cFacility  = @cFacility, 
         @cFromLOC   = @cFromLOC, 
         @cToLOC     = @cToLoc,
         @cFromID    = @cFromID,
         @nQTY       = @nQTY,
         @nQTYAlloc  = @nQTYAlloc,    
         @nQTYPick   = @nQTYPick, 
         @cFromLOT   = @cFromLOT,
         @nFunc      = @nFunc,
         @cSKU       = @cSKU

      IF @nErrNo<>''
      BEGIN
         GOTO Step_3_Fail  
      END

      SET @cSKU=''
      SET @cFromLOC=''
      SET @cSuggID=''
      SET @cFromID=''
      SET @cSuggToLoc=''
      SET @cOutField01=''

      SET @nScn  = @nScn-2
      SET @nStep = @nStep-2

      GOTO Quit

   END

   IF @nInputkey = 0
   BEGIN

      SET @nScn  = @nScn-1
      SET @nStep = @nStep-1
      SET @cFromID = ''
      SET @cOutField04=''
      SET @cInField04=''
      GOTO Quit
   END

   STEP_3_Fail:
   BEGIN
     SET @cToLoc=''
     SET @cInField06=''
   END

END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
      ErrMsg         = @cErrMsg,
      Func           = @nFunc,
      Step           = @nStep,
      Scn            = @nScn,

      StorerKey      = @cStorerKey,
      Facility       = @cFacility,
      Printer        = @cPrinter,
      UserName       = @cUserName,

      V_String1      =  @cSKU                 ,
      V_String2      =  @cFromLOC             ,
      V_String3      =  @cSuggToLoc           ,
      V_String4      =  @cExtendedUpdateSP    ,
      V_String5      =  @cExtendedValidateSP  ,
      V_String6      =  @cRepleshGetLocSP     ,
      V_String7      =  @cToLoc               ,
      V_String8      =  @cFromID              ,
      V_String9      =  @cFromLOT             ,
      V_String10     =  @cSuggID              ,

      V_Integer1     =  @nQTY                 ,
      V_Integer2     =  @nQTYAlloc            ,
      V_Integer3     =  @nQTYPick             , 

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