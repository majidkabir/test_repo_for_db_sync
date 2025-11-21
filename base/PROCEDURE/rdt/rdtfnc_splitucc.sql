SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/     
/* Copyright: IDS                                                             */     
/* Purpose: SOS#306388 A&F Project                                            */     
/*                                                                            */     
/* Modifications log:                                                         */     
/*                                                                            */     
/* Date       Rev  Author     Purposes                                        */     
/* 2014-04-15 1.0  ChewKP     Created                                         */    
/* 2022-12-20 1.1  James      WMS-21186 Misc enhancement (james01)            */
/******************************************************************************/    
    
CREATE   PROC [RDT].[rdtfnc_SplitUCC] (    
   @nMobile    int,    
   @nErrNo     int  OUTPUT,    
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max    
)    
AS    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
-- Misc variable    
DECLARE     
   @nCount      INT,    
   @nRowCount   INT    
    
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
   @cPrinter   NVARCHAR( 20),     
   @cUserName  NVARCHAR( 18),    
       
   @nError        INT,    
   @b_success     INT,    
   @n_err         INT,         
   @c_errmsg      NVARCHAR( 250),     
   @cPUOM         NVARCHAR( 10),        
   @bSuccess      INT,    
       
   @cFromUCC      NVARCHAR(20),    
   @cToUCC        NVARCHAR(20),    
   @cSKU          NVARCHAR(20),    
   @cExtendedUpdateSP    NVARCHAR(20),    
   @cExtendedValidateSP  NVARCHAR(20),    
   @cSuggestedSKU        NVARCHAR(20),     
   @cOptions             NVARCHAR(1),     
   @cQty                 NVARCHAR(5),     
   @nSKUCnt              INT,    
   @cSQL                 NVARCHAR(MAX),     
   @cSQLParam            NVARCHAR(MAX),     
   @cSKUValidated       NVARCHAR( 2),   
   @cDefaultQTY         NVARCHAR( 5),    
   @cDisableQTYField    NVARCHAR( 1),
   @cBarcode            NVARCHAR( 60),
   @cUPC                NVARCHAR( 30),
   @cDecodeSP           NVARCHAR( 20),
   @cToID               NVARCHAR( 18),
   @cToLOC              NVARCHAR( 10),
   @cDESCR              NVARCHAR( 60),
   @cSkipToLoc          NVARCHAR( 1),
   
   @nTranCount          INT,
   @nQTY                INT,
   @nActQTY             INT,
   @tSplitUCC           VARIABLETABLE,
   
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
   @cPrinter   = Printer,     
   @cUserName  = UserName,    
       
   @cPUOM       = V_UOM,    
   @cFromUCC    = V_UCC,    
   @cSKU        = V_SKU,    
   @cToID       = V_ID,
   @cToLOC      = V_Loc,
   
   @nActQTY     = V_Integer1,

   @cToUCC              = V_String1,    
   @cSKUValidated       = V_String2,    
   @cExtendedUpdateSP   = V_String3,    
   @cExtendedValidateSP = V_String4,    
   @cDefaultQTY         = V_String5,    
   @cDisableQTYField    = V_String6,
   @cSkipToLoc          = V_String7,
   
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
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04  = FieldAttr04,    
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,    
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,    
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,    
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,    
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,    
   @cFieldAttr15 =  FieldAttr15    
    
FROM RDTMOBREC (NOLOCK)    
WHERE Mobile = @nMobile    
    
Declare @n_debug INT    
    
SET @n_debug = 0    

-- Screen constant  
DECLARE  
   @nStep_FromUCC    INT,  @nScn_FromUCC     INT,  
   @nStep_ToUCC      INT,  @nScn_ToUCC       INT,  
   @nStep_SKUQTY     INT,  @nScn_SKUQTY      INT,  
   @nStep_ToID       INT,  @nScn_ToID        INT,  
   @nStep_ToLOC      INT,  @nScn_ToLOC       INT,  
   @nStep_Message    INT,  @nScn_Message     INT
  
SELECT  
   @nStep_FromUCC    = 1,  @nScn_FromUCC     = 3820,  
   @nStep_ToUCC      = 2,  @nScn_ToUCC       = 3821,  
   @nStep_SKUQTY     = 3,  @nScn_SKUQTY      = 3822,  
   @nStep_ToID       = 4,  @nScn_ToID        = 3823,  
   @nStep_ToLOC      = 5,  @nScn_ToLOC       = 3824,
   @nStep_Message    = 6,  @nScn_Message     = 3825
  
IF @nFunc = 535  -- Split UCC    
BEGIN    
   -- Redirect to respective screen    
   IF @nStep = 0 GOTO Step_0           -- Split UCC    
   IF @nStep = 1 GOTO Step_FromUCC     -- Scn = 3820. From UCC    
   IF @nStep = 2 GOTO Step_ToUCC       -- Scn = 3821. To UCC , Options    
   IF @nStep = 3 GOTO Step_SKUQTY      -- Scn = 3822. SKU, Qty    
   IF @nStep = 4 GOTO Step_ToID        -- Scn = 3823. TO ID
   IF @nStep = 5 GOTO Step_ToLOC       -- Scn = 3824. TO LOC
   IF @nStep = 6 GOTO Step_Message     -- Scn = 3825. MESSAGE
END
RETURN -- Do nothing if incorrect step    
    
/********************************************************************************    
Step 0. func = 815. Menu    
********************************************************************************/    
Step_0:    
BEGIN    
   -- Get prefer UOM    
 SET @cPUOM = ''    
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA    
   FROM RDT.rdtMobRec M WITH (NOLOCK)    
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)    
   WHERE M.Mobile = @nMobile    
       
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)    
   IF @cExtendedValidateSP = '0'    
      SET @cExtendedValidateSP = ''    
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)    
   IF @cExtendedUpdateSP = '0'    
      SET @cExtendedUpdateSP = ''    

   SET @cDisableQTYField = rdt.rdtGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)  

   SET @cDefaultQTY = rdt.rdtGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)  
   
   SET @cSkipToLoc = rdt.rdtGetConfig( @nFunc, 'SkipToLoc', @cStorerKey)
   
   -- Initiate var    
 -- EventLog - Sign In Function    
   EXEC RDT.rdt_STD_EventLog    
     @cActionType = '1', -- Sign in function    
     @cUserID     = @cUserName,    
     @nMobileNo   = @nMobile,    
     @nFunctionID = @nFunc,    
     @cFacility   = @cFacility,    
     @cStorerKey  = @cStorerkey    
         
       
   -- Init screen    
   SET @cOutField01 = ''     
   SET @cOutField02 = ''    
       
   SET @cFromUCC    = ''      
   SET @cToUCC      = ''      
   SET @cSKU        = ''    
     
   -- Set the entry point    
   SET @nScn = @nScn_FromUCC    
   SET @nStep = @nStep_FromUCC    
     
   EXEC rdt.rdtSetFocusField @nMobile, 1    
     
END    
GOTO Quit    
    
/********************************************************************************    
Step 1. Scn = 3820.     
   FromUCC  (Input , Field01)    
********************************************************************************/    
Step_FromUCC:    
BEGIN    
   IF @nInputKey = 1 --ENTER    
   BEGIN    
      SET @cFromUCC  = ISNULL(RTRIM(@cInField01),'')    
      
  
      IF @cFromUCC = ''     
      BEGIN    
         SET @nErrNo = 87251    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromUCC Req    
         GOTO Step_FromUCC_Fail    
      END     
        
      IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cFromUCC AND Status = '1' )     
      BEGIN    
         SET @nErrNo = 87252    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidUCC    
         GOTO Step_FromUCC_Fail    
      END           

      EXEC rdt.rdt_SplitUCC     
         @nMobile          = @nMobile,    
         @nFunc            = @nFunc,    
         @cLangCode        = @cLangCode,    
         @nStep            = @nStep,    
         @nInputKey        = @nInputKey,    
         @cFacility        = @cFacility,    
         @cStorerKey       = @cStorerKey,    
         @cType            = 'DELLOG', 
         @cFromUCC         = @cFromUCC,
         @cToUCC           = @cToUCC,
         @cSKU             = @cSKU,    
         @nQTY             = @nActQTY,
         @cToID            = @cToID,
         @cToLOC           = @cToLOC,
         @tSplitUCC        = @tSplitUCC,  
         @nErrNo           = @nErrNo   OUTPUT,    
         @cErrMsg          = @cErrMsg  OUTPUT    
  
      IF @nErrNo <> 0    
         GOTO Quit    
            
      -- Prepare Next Screen Variable    
      SET @cOutField01 = @cFromUCC     
      SET @cOutField02 = ''  -- To UCC  
      SET @cOutField03 = ''  -- Option  
      
      EXEC rdt.rdtSetFocusField @nMobile, 2
      
      -- GOTO Next Screen    
      SET @nScn = @nScn_ToUCC    
      SET @nStep = @nStep_ToUCC    
         
   END  -- Inputkey = 1    
    
   IF @nInputKey = 0     
   BEGIN    
      EXEC rdt.rdt_SplitUCC     
         @nMobile          = @nMobile,    
         @nFunc            = @nFunc,    
         @cLangCode        = @cLangCode,    
         @nStep            = @nStep,    
         @nInputKey        = @nInputKey,    
         @cFacility        = @cFacility,    
         @cStorerKey       = @cStorerKey,    
         @cType            = 'DELLOG', 
         @cFromUCC         = @cFromUCC,
         @cToUCC           = @cToUCC,
         @cSKU             = @cSKU,    
         @nQTY             = @nActQTY,
         @cToID            = @cToID,
         @cToLOC           = @cToLOC,
         @tSplitUCC        = @tSplitUCC,  
         @nErrNo           = @nErrNo   OUTPUT,    
         @cErrMsg          = @cErrMsg  OUTPUT    
  
      IF @nErrNo <> 0    
         GOTO Quit

      -- EventLog - Sign In Function    
       EXEC RDT.rdt_STD_EventLog    
        @cActionType = '9', -- Sign in function    
        @cUserID     = @cUserName,    
        @nMobileNo   = @nMobile,    
        @nFunctionID = @nFunc,    
        @cFacility   = @cFacility,    
        @cStorerKey  = @cStorerkey    
            
      --go to main menu    
      SET @nFunc = @nMenu    
      SET @nScn  = @nMenu    
      SET @nStep = 0    
      SET @cOutField01 = ''    
            
   END    
   GOTO Quit    
    
   STEP_FromUCC_FAIL:    
   BEGIN    
      SET @cOutField01 = ''    
      SET @cOutField02 = ''    
   END    
END     
GOTO QUIT    
    
/********************************************************************************    
Step 2. Scn = 3821.     
   FromUCC       (field01)    
   ToUCC         (field02, input)    
   Options       (field03, input)    
********************************************************************************/    
Step_ToUCC:    
BEGIN    
   IF @nInputKey = 1 --ENTER    
   BEGIN    
      SET @cToUCC = @cInField02    
      SET @cOptions = @cInField03    
      
      IF @cToUCC = ''     
      BEGIN    
      SET @nErrNo = 87253    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToUCC Req    
         SET @cToUCC = ''    
         GOTO Step_ToUCC_Fail    
      END     
        
      IF @cOptions = ''    
      BEGIN    
         SET @nErrNo = 87254    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Option Req'    
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_ToUCC_Fail    
      END    
          
      IF @cOptions NOT IN ('1','9')    
      BEGIN    
         SET @nErrNo = 87255    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOption'    
         GOTO Step_ToUCC_Fail    
      END    
        
      IF @cOptions = '1'    
      BEGIN    
         EXEC rdt.rdt_SplitUCC     
            @nMobile          = @nMobile,    
            @nFunc            = @nFunc,    
            @cLangCode        = @cLangCode,    
            @nStep            = @nStep,    
            @nInputKey        = @nInputKey,    
            @cFacility        = @cFacility,    
            @cStorerKey       = @cStorerKey,    
            @cType            = 'FULL',   
            @cFromUCC         = @cFromUCC,
            @cToUCC           = @cToUCC,
            @cSKU             = @cSKU,    
            @nQTY             = @nActQTY,
            @cToID            = @cToID,
            @cToLOC           = @cToLOC,
            @tSplitUCC        = @tSplitUCC,  
            @nErrNo           = @nErrNo   OUTPUT,    
            @cErrMsg          = @cErrMsg  OUTPUT    
  
         IF @nErrNo <> 0    
            GOTO Quit    
            
         EXEC RDT.rdt_STD_EventLog    
            @cActionType = '3',     
            @cUserID     = @cUserName,    
            @nMobileNo   = @nMobile,    
            @nFunctionID = @nFunc,    
            @cFacility   = @cFacility,    
            @cStorerKey  = @cStorerkey,    
            @cRefNo1     = @cFromUCC,    
            @cRefNo2     = @cToUCC    
             
         -- Prepare Next Screen Variable    
         SET @cOutField01 = ''    
         SET @cOutField02 = ''    
         SET @cOutField03 = ''    
         SET @cOutField04 = ''    
    
         -- GOTO Previous Screen    
         SET @nScn = @nScn_FromUCC    
         SET @nStep = @nStep_FromUCC    
            
         GOTO QUIT    
      END    
      ELSE IF @cOptions = '9'    
      BEGIN    
         SET @cOutField01 = @cToUCC
         SET @cOutField02 = ''   -- SKU
         SET @cOutField03 = ''   -- DESCR1
         SET @cOutField04 = ''   -- DESCR2 
         SET @cOutField05 = CASE WHEN @cDefaultQTY = '0' THEN '' ELSE @cDefaultQTY END -- QTY    
         SET @cOutField06 = ''

         -- Enable field  
         IF @cDisableQTYField = '1'  
            SET @cFieldAttr05 = 'O'  
         ELSE  
            SET @cFieldAttr05 = ''  
  
         SET @nActQTY = 0  
         SET @cSKUValidated = '0'  
         SET @cSKU = ''
         SET @nQTY = 0
         
         EXEC rdt.rdtSetFocusField @nMobile, 2

         -- GOTO Next Screen    
         SET @nScn = @nScn_SKUQTY    
         SET @nStep = @nStep_SKUQTY  
            
         GOTO QUIT    
      END    
         
   END  -- Inputkey = 1    
    
   IF @nInputKey = 0     
   BEGIN    
      SET @cOutField01 = ''    
      SET @cOutField02 = ''      
      SET @cOutField03 = ''    
      SET @cOutField04 = ''    
    
      -- GOTO Previous Screen    
      SET @nScn = @nScn_FromUCC   
      SET @nStep = @nStep_FromUCC    
            
   END    
   GOTO Quit    
    
   STEP_ToUCC_FAIL:    
   BEGIN      
      -- Prepare Next Screen Variable    
      SET @cOutField01 = @cFromUCC     
      SET @cOutField02 = @cToUCC     
      SET @cOutField03 = ''        
   END    
END     
GOTO QUIT    
    
/********************************************************************************    
Step 3. Scn = 3822.     
   TO UCC   (field01)    
   SKU      (field02, Input)    
   Qty      (field05, Input)    
********************************************************************************/    
Step_SKUQTY:    
BEGIN    
   IF @nInputKey = 1    
   BEGIN    
      SET @cBarcode = ''  
      SET @cBarcode = @cInField02 -- SKU    
      SET @cUPC = LEFT( @cInField02, 30)    
      SET @cQTY = CASE WHEN @cFieldAttr05 = 'O' THEN @cOutField05 ELSE @cInField05 END    
      SET @cOptions = @cInField07

      IF ISNULL(@cOptions, '') <> ''  
      BEGIN  
         IF @cOptions <> '1'  
         BEGIN  
            SET @nErrNo = 87263  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv opt  
            SET @cOptions = ''  
            SET @cOutField07 = ''
            EXEC rdt.rdtSetFocusField @nMobile, 7 
            GOTO Quit  
         END  
  
         IF @cOptions = '1'  
         BEGIN  
            EXEC rdt.rdt_SplitUCC     
               @nMobile          = @nMobile,    
               @nFunc            = @nFunc,    
               @cLangCode        = @cLangCode,    
               @nStep            = @nStep,    
               @nInputKey        = @nInputKey,    
               @cFacility        = @cFacility,    
               @cStorerKey       = @cStorerKey,    
               @cType            = 'DELLOG', 
               @cFromUCC         = @cFromUCC,
               @cToUCC           = @cToUCC,
               @cSKU             = @cSKU,    
               @nQTY             = @nActQTY,
               @cToID            = @cToID,
               @cToLOC           = @cToLOC,
               @tSplitUCC        = @tSplitUCC,  
               @nErrNo           = @nErrNo   OUTPUT,    
               @cErrMsg          = @cErrMsg  OUTPUT    
  
            IF @nErrNo <> 0    
               GOTO Quit  

            -- Init screen    
            SET @cOutField01 = ''     
            SET @cOutField02 = ''    
            SET @cOutField03 = ''
            SET @cOutField04 = ''
            SET @cOutField05 = ''
            SET @cOutField06 = ''
            SET @cOutField07 = ''
       
            SET @cFromUCC    = ''      
     
            -- Set the entry point    
            SET @nScn = @nScn_FromUCC    
            SET @nStep = @nStep_FromUCC    
     
            GOTO Quit    
         END  
      END  
      
      -- Check SKU blank    
      IF @cUPC = ''   
      BEGIN    
         IF @cDisableQTYField = '1'  
         BEGIN  
            SET @cSKUValidated = '99'     
            SET @cQTY = '0'  
         END  
         ELSE  
         BEGIN  
            IF @cQTY = '' OR @cQTY = '0'   
            BEGIN  
               SET @cSKUValidated = '99'     
               SET @cQTY = '0'  
            END  
            ELSE  
            BEGIN  
               IF @cSKUValidated = '0' -- False    
               BEGIN  
                  SET @nErrNo = 87256    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU Req    
                  EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU    
                  GOTO Step_SKUQTY_Fail  
               END  
            END    
         END  
      END    
      
      IF @cUPC <> ''
      BEGIN
         -- Decode    
         IF @cDecodeSP <> ''    
         BEGIN    
            -- Standard decode    
            IF @cDecodeSP = '1'    
            BEGIN    
               EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,    
                  @cUPC        = @cUPC           OUTPUT,    
                  @nQTY        = @nQTY           OUTPUT,    
                  @nErrNo      = @nErrNo  OUTPUT,    
                  @cErrMsg     = @cErrMsg OUTPUT,    
                  @cType       = 'UPC'    
            END    
            -- Customize decode    
            ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode, ' +    
                  ' @cTaskDetailKey, @cUPC OUTPUT, @cQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '   
               SET @cSQLParam =    
                  ' @nMobile           INT,           ' +    
                  ' @nFunc             INT,           ' +    
                  ' @cLangCode         NVARCHAR( 3),  ' +    
                  ' @nStep             INT,           ' +    
                  ' @nInputKey         INT,           ' +    
                  ' @cFacility         NVARCHAR( 5),  ' +    
                  ' @cStorerKey        NVARCHAR( 15), ' +    
                  ' @cBarcode          NVARCHAR( 60), ' +    
                  ' @cFromUCC          NVARCHAR( 20), ' +    
                  ' @cToUCC            NVARCHAR( 20), ' +
                  ' @cUPC              NVARCHAR( 30)  OUTPUT, ' +    
                  ' @cQTY              NVARCHAR( 5)   OUTPUT, ' +    
                  ' @nErrNo            INT            OUTPUT, ' +    
                  ' @cErrMsg           NVARCHAR( 20)  OUTPUT'    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode,    
                  @cFromUCC, @cToUCC, @cUPC OUTPUT, @cQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
            END    
    
            IF @nErrNo <> 0    
            BEGIN    
               EXEC rdt.rdtSetFocusField @nMobile, 2
               GOTO Step_SKUQTY_Fail    
            END      
         END    
            
         EXEC rdt.rdt_GETSKUCNT    
             @cStorerkey  = @cStorerKey           
            ,@cSKU        = @cUPC    
            ,@nSKUCnt     = @nSKUCnt       OUTPUT    
            ,@bSuccess    = @b_Success     OUTPUT    
            ,@nErr        = @nErrNo        OUTPUT    
            ,@cErrMsg     = @cErrMsg       OUTPUT    
    
         -- Check SKU/UPC    
         IF @nSKUCnt = 0    
         BEGIN    
            SET @nErrNo = 87257    
            SET @cErrMsg = @cUPC--rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU    
            SET @cSKU = ''    
            GOTO Step_SKUQTY_Fail    
         END    
          
         EXEC rdt.rdt_GetSKU    
             @cStorerKey  = @cStorerKey    
            ,@cSKU        = @cUPC      OUTPUT    
            ,@bSuccess    = @bSuccess  OUTPUT    
            ,@nErr        = @nErrNo    OUTPUT    
            ,@cErrMsg     = @cErrMsg   OUTPUT    
                   
         IF @nErrNo <> 0    
         BEGIN    
            SET @nErrNo = 87258    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'Invalid SKU'    
            SET @cSKU = ''    
            GOTO Step_SKUQTY_Fail    
         END    

         SET @cSKU = @cUPC
         
         IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                         WHERE Storerkey = @cStorerKey
                         AND   UCCNo = @cFromUCC
                         AND   SKU = @cSKU)
         BEGIN    
            SET @nErrNo = 87259    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'Invalid SKU'    
            GOTO Step_SKUQTY_Fail    
         END    
      
         -- Mark SKU as validated    
         SET @cSKUValidated = '1'    
      END
      
      IF @cQTY <> '' AND RDT.rdtIsValidQTY( @cQTY, 0) = 0     
      BEGIN    
         SET @nErrNo = 87260    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'Invalid Qty'    
         GOTO Step_SKUQTY_Fail    
      END    

      -- Top up QTY    
      IF @nQTY > 0    
         SET @nQTY = @nActQTY + @nQTY    
      ELSE    
         IF @cSKU <> '' AND @cDisableQTYField = '1' AND @cDefaultQTY <> '1'    
            SET @nQTY = @nActQTY + 1    
         ELSE    
            SET @nQTY = CAST( @cQTY AS INT)    
            
      IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)     
                  WHERE StorerKey = @cStorerKey
                  AND   UCCNo = @cFromUCC
                  AND   SKU = @cSKU    
                  AND   Qty < @nQTY )    
      BEGIN    
         SET @nErrNo = 87261    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo , @cLangCode, 'DSP') --'Qty Not Enuf'    
         GOTO Step_SKUQTY_Fail    
      END                      
  
      -- Extended validate    
      IF @cExtendedValidateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFromUCC, @cToUCC, @cSKU, @cQty, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile    INT,           ' +    
               '@nFunc      INT,           ' +    
               '@cLangCode  NVARCHAR( 3),  ' +    
               '@nStep      INT,           ' +     
               '@cStorerKey NVARCHAR( 15), ' +     
               '@cFromUCC   NVARCHAR( 20), ' +     
               '@cToUCc     NVARCHAR( 20), ' +    
               '@cSKU       NVARCHAR( 20), ' +    
               '@cQty       NVARCHAR( 5),  ' +    
               '@nErrNo     INT OUTPUT,    ' +    
               '@cErrMsg    NVARCHAR( 20) OUTPUT'    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFromUCC, @cToUCC, @cSKU, @cQty, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
         END    
      END    

      -- Save to ActQTY    
      SET @nActQTY = @nActQTY + @nQTY    
    
      -- SKU scanned, remain in current screen    
      IF @cBarcode <> ''   
      BEGIN    
      	SELECT @cDESCR = DESCR
      	FROM dbo.SKU WITH (NOLOCK)
      	WHERE StorerKey = @cStorerKey
      	AND   Sku = @cSKU
      	
         SET @cOutField02 = '' -- SKU    
         SET @cOutField03 = SUBSTRING( @cDESCR, 1, 20)
         SET @cOutField04 = SUBSTRING( @cDESCR, 21, 20)
         SET @cOutField05 = CASE WHEN @cDefaultQTY = '0' THEN '' ELSE @cDefaultQTY END -- QTY  
         SET @cSKUValidated = '1'  
           
         IF @cDisableQTYField = '1'    
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU    
         ELSE    
         BEGIN    
            IF @cDefaultQTY = '0'
               EXEC rdt.rdtSetFocusField @nMobile, 5 -- QTY    
            ELSE
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU
         END    
         
         IF @nActQTY = 0
            GOTO Quit
      END    

      -- Handling transaction            
      SET @nTranCount = @@TRANCOUNT            
      BEGIN TRAN  -- Begin our own transaction            
      SAVE TRAN Step_SKUAddLog -- For rollback or commit only our own transaction         
      
      EXEC rdt.rdt_SplitUCC     
         @nMobile          = @nMobile,    
         @nFunc            = @nFunc,    
         @cLangCode        = @cLangCode,    
         @nStep            = @nStep,    
         @nInputKey        = @nInputKey,    
         @cFacility        = @cFacility,    
         @cStorerKey       = @cStorerKey,    
         @cType            = 'ADDLOG',   
         @cFromUCC         = @cFromUCC,
         @cToUCC           = @cToUCC,
         @cSKU             = @cSKU,    
         @nQTY             = @nQTY,
         @cToID            = @cToID,
         @cToLOC           = @cToLOC,
         @tSplitUCC        = @tSplitUCC,  
         @nErrNo           = @nErrNo   OUTPUT,    
         @cErrMsg          = @cErrMsg  OUTPUT    
  
      IF @nErrNo <> 0    
      BEGIN
         ROLLBACK TRAN Step_SKUAddLog            
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
            COMMIT TRAN            
         GOTO STEP_SKUQTY_FAIL      
      END
            
      -- Extended update    
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFromUCC, @cToUCC, @cSKU, @cQty, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile    INT,           ' +    
               '@nFunc      INT,           ' +    
               '@cLangCode  NVARCHAR( 3),  ' +    
               '@nStep      INT,           ' +     
               '@cStorerKey NVARCHAR( 15), ' +     
               '@cFromUCC   NVARCHAR( 20), ' +     
               '@cToUCc     NVARCHAR( 20), ' +    
               '@cSKU       NVARCHAR( 20), ' +    
               '@cQty       NVARCHAR( 5),  ' +    
               '@nErrNo     INT OUTPUT,    ' +    
               '@cErrMsg    NVARCHAR( 20) OUTPUT'    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFromUCC, @cToUCC, @cSKU, @cQty, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
            BEGIN
               ROLLBACK TRAN Step_SKUAddLog            
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
                  COMMIT TRAN            
               GOTO STEP_SKUQTY_FAIL      
            END
    
         END    
      END    

      COMMIT TRAN Step_SKUAddLog -- Only commit change made here            
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
         COMMIT TRAN    
         
      SET @cOutField01 = @cToUCC
      SET @cOutField02 = ''   -- SKU
      SET @cOutField05 = CASE WHEN @cDefaultQTY = '0' THEN '' ELSE @cDefaultQTY END -- QTY    
      SET @cOutField06 = @nActQTY
      
      SET @cSKUValidated = '0'  
         
      EXEC rdt.rdtSetFocusField @nMobile, 2

      -- Remain in same screen            
      GOTO QUIT    
   END  -- Inputkey = 1    
       
   IF @nInputKey = 0     
   BEGIN    
   	-- Check if scanned something then can go to next screen
   	IF EXISTS ( SELECT 1 FROM rdt.RDTUCC WITH (NOLOCK)
   	            WHERE StorerKey = @cStorerKey
   	            AND   Qty > 0
   	            AND   AddWho = @cUserName)
      BEGIN
      	SET @cOutField01 = ''
      	
      	SET @nScn = @nScn_ToID
      	SET @nStep = @nStep_ToID
      END
      ELSE
      BEGIN
         -- Prepare Previous Screen Variable    
         SET @cOutField01 = @cFromUCC    
         SET @cOutField02 = ''    
         SET @cOutField03 = ''    
         SET @cOutField04 = ''    
          
          -- GOTO Previous Screen    
         SET @nScn = @nScn_ToUCC    
         SET @nStep = @nStep_ToUCC
      END    
   END    
   GOTO Quit    
     
   STEP_SKUQTY_FAIL:    
   BEGIN    
      IF @cSKUValidated = '1'  
         SET @cOutField02 = @cSKU  
      ELSE  
         SET @cOutField02 = '' -- SKU    
   END    
END     
GOTO QUIT    
    
/********************************************************************************    
Step 4. Scn = 3823.     
   TO ID      (field01, Input)    
********************************************************************************/    
Step_ToID:    
BEGIN    
   IF @nInputKey = 1    
   BEGIN    
   	SET @cToID = @cInField01
   	
      IF @cToID = ''    
      BEGIN    
         SET @nErrNo = 87262    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToID Req'    
         SET @cToID = ''    
         GOTO Step_ToID_Fail    
      END    

      IF @cSkipToLoc = '1'
      BEGIN
         -- Handling transaction            
         SET @nTranCount = @@TRANCOUNT            
         BEGIN TRAN  -- Begin our own transaction            
         SAVE TRAN Step_SKUAddUccID -- For rollback or commit only our own transaction         

         EXEC rdt.rdt_SplitUCC     
            @nMobile          = @nMobile,    
            @nFunc            = @nFunc,    
            @cLangCode        = @cLangCode,    
            @nStep            = @nStep,    
            @nInputKey        = @nInputKey,    
            @cFacility        = @cFacility,    
            @cStorerKey       = @cStorerKey,    
            @cType            = 'PARTIAL',   -- FULL/PARTIAL    
            @cFromUCC         = @cFromUCC,
            @cToUCC           = @cToUCC,
            @cSKU             = @cSKU,    
            @nQTY             = @nActQTY,
            @cToID            = @cToID,
            @cToLOC           = @cToLOC,
            @tSplitUCC        = @tSplitUCC,  
            @nErrNo           = @nErrNo   OUTPUT,    
            @cErrMsg          = @cErrMsg  OUTPUT    
  
         IF @nErrNo <> 0    
         BEGIN
            ROLLBACK TRAN Step_SKUAddUccID            
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
               COMMIT TRAN            
            GOTO STEP_ToID_FAIL      
         END
            
         -- Extended update    
         IF @cExtendedUpdateSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFromUCC, @cToUCC, @cSKU, @cQty, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
               SET @cSQLParam =    
                  '@nMobile    INT,           ' +    
                  '@nFunc      INT,           ' +    
                  '@cLangCode  NVARCHAR( 3),  ' +    
                  '@nStep      INT,           ' +     
                  '@cStorerKey NVARCHAR( 15), ' +     
                  '@cFromUCC   NVARCHAR( 20), ' +     
                  '@cToUCc     NVARCHAR( 20), ' +    
                  '@cSKU       NVARCHAR( 20), ' +    
                  '@cQty       NVARCHAR( 5),  ' +    
                  '@nErrNo     INT OUTPUT,    ' +    
                  '@cErrMsg    NVARCHAR( 20) OUTPUT'    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFromUCC, @cToUCC, @cSKU, @cQty, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
               IF @nErrNo <> 0    
               BEGIN
                  ROLLBACK TRAN Step_SKUAddUccID            
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
                     COMMIT TRAN            
                  GOTO STEP_ToID_FAIL      
               END
    
            END    
         END    

         COMMIT TRAN Step_SKUAddUccID -- Only commit change made here            
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
            COMMIT TRAN    

         EXEC RDT.rdt_STD_EventLog    
            @cActionType = '3',     
            @cUserID     = @cUserName,    
            @nMobileNo   = @nMobile,    
            @nFunctionID = @nFunc,    
            @cFacility   = @cFacility,    
            @cStorerKey  = @cStorerkey,
            @cSKU        = @cSKU,
            @nQTY        = @nActQTY,
            @cRefNo1     = @cFromUCC,    
            @cRefNo2     = @cToUCC,        
            @cToID       = @cToID    
             
         -- Set the entry point    
         SET @nScn = @nScn_Message    
         SET @nStep = @nStep_Message
      END     
      ELSE
      BEGIN
         SET @cOutField01 = ''
      
          -- GOTO Next Screen    
         SET @nScn = @nScn_ToLOC    
         SET @nStep = @nStep_ToLOC    
      END
   END
   
   IF @nInputKey = 0
   BEGIN
      SET @cOutField01 = @cToUCC
      SET @cOutField02 = ''   -- SKU
      SET @cOutField03 = ''   -- DESCR1
      SET @cOutField04 = ''   -- DESCR2 
      SET @cOutField05 = CASE WHEN @cDefaultQTY = '0' THEN '' ELSE @cDefaultQTY END -- QTY    

      -- Enable field  
      IF @cDisableQTYField = '1'  
         SET @cFieldAttr05 = 'O'  
      ELSE  
         SET @cFieldAttr05 = ''  
  
      SET @nActQTY = 0  
      SET @cSKUValidated = '0'  

      EXEC rdt.rdtSetFocusField @nMobile, 2

      -- GOTO Next Screen    
      SET @nScn = @nScn_SKUQTY    
      SET @nStep = @nStep_SKUQTY   
   END
   GOTO Quit

   STEP_ToID_FAIL:    
   BEGIN    
      SET @cOutField01 = ''  
   END    
END
GOTO Quit

/********************************************************************************    
Step 5. Scn = 3824.     
   TO Loc      (field01, Input)    
********************************************************************************/    
Step_ToLOC:    
BEGIN    
   IF @nInputKey = 1    
   BEGIN    
   	SET @cToLOC = @cInField01
   	
      IF @cToLOC = ''    
      BEGIN    
         SET @nErrNo = 87262    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToID Req'    
         SET @cToID = ''    
         GOTO Step_ToLOC_Fail    
      END    

      -- Handling transaction            
      SET @nTranCount = @@TRANCOUNT            
      BEGIN TRAN  -- Begin our own transaction            
      SAVE TRAN Step_SKUAddUccLoc -- For rollback or commit only our own transaction         

      EXEC rdt.rdt_SplitUCC     
         @nMobile          = @nMobile,    
         @nFunc            = @nFunc,    
         @cLangCode        = @cLangCode,    
         @nStep            = @nStep,    
         @nInputKey        = @nInputKey,    
         @cFacility        = @cFacility,    
         @cStorerKey       = @cStorerKey,    
         @cType            = 'PARTIAL',   -- FULL/PARTIAL    
         @cFromUCC         = @cFromUCC,
         @cToUCC           = @cToUCC,
         @cSKU             = @cSKU,    
         @nQTY             = @nActQTY,
         @cToID            = @cToID,
         @cToLOC           = @cToLOC,
         @tSplitUCC        = @tSplitUCC,  
         @nErrNo           = @nErrNo   OUTPUT,    
         @cErrMsg          = @cErrMsg  OUTPUT    
  
      IF @nErrNo <> 0    
      BEGIN
         ROLLBACK TRAN Step_SKUAddUccLoc            
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
            COMMIT TRAN            
         GOTO STEP_ToLoc_FAIL      
      END
            
      -- Extended update    
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFromUCC, @cToUCC, @cSKU, @cQty, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile    INT,           ' +    
               '@nFunc      INT,           ' +    
               '@cLangCode  NVARCHAR( 3),  ' +    
               '@nStep      INT,           ' +     
               '@cStorerKey NVARCHAR( 15), ' +     
               '@cFromUCC   NVARCHAR( 20), ' +     
               '@cToUCc     NVARCHAR( 20), ' +    
               '@cSKU       NVARCHAR( 20), ' +    
               '@cQty       NVARCHAR( 5),  ' +    
               '@nErrNo     INT OUTPUT,    ' +    
               '@cErrMsg    NVARCHAR( 20) OUTPUT'    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @cStorerKey, @cFromUCC, @cToUCC, @cSKU, @cQty, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
            BEGIN
               ROLLBACK TRAN Step_SKUAddUccLoc            
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
                  COMMIT TRAN            
               GOTO STEP_ToLoc_FAIL      
            END
    
         END    
      END    

      COMMIT TRAN Step_SKUAddUccLoc -- Only commit change made here            
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
         COMMIT TRAN    
                     
      EXEC RDT.rdt_STD_EventLog    
         @cActionType = '3',     
         @cUserID     = @cUserName,    
         @nMobileNo   = @nMobile,    
         @nFunctionID = @nFunc,    
         @cFacility   = @cFacility,    
         @cStorerKey  = @cStorerkey,
         @cSKU        = @cSKU,
         @nQTY        = @nActQTY,
         @cRefNo1     = @cFromUCC,    
         @cRefNo2     = @cToUCC,        
         @cToID       = @cToID,
         @cToLocation = @cToLOC    

      -- Set the entry point    
      SET @nScn = @nScn_Message    
      SET @nStep = @nStep_Message
   END
   
   IF @nInputKey = 0
   BEGIN
      SET @cOutField01 = ''

      -- GOTO Next Screen    
      SET @nScn = @nScn_ToID    
      SET @nStep = @nStep_ToID    
   END
   GOTO Quit

   STEP_ToLOC_FAIL:    
   BEGIN    
      SET @cOutField01 = ''  
   END    
END
GOTO Quit

/********************************************************************************    
Step 6. Scn = 3825.     
   MESSAGE    
********************************************************************************/    
Step_Message:    
BEGIN    
   IF @nInputKey = 1    
   BEGIN    
      -- Init screen    
      SET @cOutField01 = ''     
       
      SET @cFromUCC    = ''      
      SET @cToUCC      = ''      
      SET @cSKU        = ''    
      SET @nActQTY     = 0
           
      -- Set the entry point    
      SET @nScn = @nScn_FromUCC
      SET @nStep = @nStep_FromUCC
   END
END
GOTO Quit

/********************************************************************************    
Quit. Update back to I/O table, ready to be pick up by JBOSS    
********************************************************************************/    
Quit:    
    
BEGIN    
 UPDATE RDTMOBREC WITH (ROWLOCK) SET     
      ErrMsg = @cErrMsg,     
      Func   = @nFunc,    
      Step   = @nStep,    
      Scn    = @nScn,    
    
      StorerKey = @cStorerKey,    
      Facility  = @cFacility,     
      Printer   = @cPrinter,     
      UserName  = @cUserName,    
      InputKey  = @nInputKey,    
      
    
      V_UOM = @cPUOM,    
      V_UCC = @cFromUCC,    
      V_SKU = @cSKU,    
      V_ID  = @cToID,
      V_Loc  = @cToLOC,
      
      V_Integer1 = @nActQTY,
      
      V_String1 = @cToUCC,    
      V_String2 = @cSKUValidated,             
          
      V_String3 = @cExtendedUpdateSP,      
      V_String4 = @cExtendedValidateSP,    
      V_String5 = @cDefaultQTY,
      V_String6 = @cDisableQTYField,
      V_String7 = @cSkipToLoc,
      
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