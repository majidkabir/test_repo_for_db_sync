SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_TM_Assist_ReplenTo                           */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2019-08-13 1.0  Ung      WMS-10166 Created                           */
/* 2020-07-29 1.1  YeeKung  WMS-14059 Add Extendedupdatesp and          */
/*                            validatesp (yeekung01)                    */
/* 2020-01-20 1.2  YeeKung  WMS-16148 Display FinalLoc (yeekung02)      */
/* 2021-02-15 1.3  James    WMS-15659 Add verify case id (james01)      */
/*                          Add verify Sku, Qty                         */
/* 2021-08-24 1.4  James    Add Suggest Qty (james02)                   */
/* 2025-01-25 1.5.0Dennis   FCR-2517 Extend Error message length        */
/* 2024-12-04 1.6.0YYS027   FCR-1489 Fn1836 TM Assist Replen To         */
/************************************************************************/
    
CREATE   PROC [RDT].[rdtfnc_TM_Assist_ReplenTo] (
   @nMobile    INT,    
   @nErrNo     INT  OUTPUT,    
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max    
) AS    
    
SET NOCOUNT ON    
SET ANSI_NULLS OFF    
SET QUOTED_IDENTIFIER OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
    
-- Misc variable    
DECLARE    
   @bSuccess            INT,     
   @cAreaKey            NVARCHAR( 10),    
   @cTTMStrategykey     NVARCHAR( 10),     
   @cSQL                NVARCHAR( MAX),     
   @cSQLParam           NVARCHAR( MAX),    
   @cFinalLOC           NVARCHAR( 10)    
    
-- RDT.RDTMobRec variable    
DECLARE    
   @nFunc               INT,    
   @nScn                INT,    
   @nStep               INT,    
   @cLangCode           NVARCHAR( 3),    
   @nInputKey           INT,    
   @nMenu               INT,    
    
   @cStorerKey          NVARCHAR( 15),    
   @cFacility           NVARCHAR( 5),    
   @cPrinter            NVARCHAR( 10),    
   @cUserName           NVARCHAR( 18),    
    
   @cCaseID             NVARCHAR( 20),     
   @cFromLOC            NVARCHAR( 10),     
   @cTaskDetailKey      NVARCHAR( 10),    
    
   @cTTMTaskType        NVARCHAR( 10),     
   @cSuggToLOC          NVARCHAR( 10),     
   @cExtendedValidateSP NVARCHAR( 20),    
   @cExtendedUpdateSP   NVARCHAR( 20),    
   @cOverwriteToLOC     NVARCHAR( 1),    
   @cExtendedInfoSP     NVARCHAR( 20),    
   @cExtendedInfo       NVARCHAR( 20),    
   @cDefaultToLoc       NVARCHAR( 20),    
   @cDefaultCursor      NVARCHAR( 1),  
   @cFlowThruScreen     NVARCHAR( 1),  
   @cGoToEndTask        NVARCHAR( 1),
   @cSuggFinalLoc       NVARCHAR( 10), 
   @cSwapTaskSP         NVARCHAR( 20),
   @cNewTaskdetailKey   NVARCHAR( 10),
   @cNewCaseID          NVARCHAR( 20), -- (james01)
   @cValidateCaseID     NVARCHAR( 1),  -- (james01)
   @cValidateSKUQty     NVARCHAR( 1),  -- (james01)
   @cSKU                NVARCHAR( 20), -- (james01)
   @cVerifySKU          NVARCHAR( 20), -- (james01)   
   @nQty                INT,           -- (james01)   
   @nVerifyQty          INT,           -- (james01)      
   @cSKUDesc            NVARCHAR( 60), -- (james01)      
   @cCurrentCaseID      NVARCHAR( 20), -- (james01)      
   @cCurrentSuggToLoc   NVARCHAR( 10), -- (james01)      
   @cCurrentTTMTaskType NVARCHAR( 10), -- (james01)         
   @cCurrentTaskDetailKey  NVARCHAR( 10), -- (james01)      
   @nSuggestQty         INT,           -- (james02)
   @cCLRPutawayZone     NVARCHAR( 20), -- (yys027)

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
   @nFunc            = Func,    
   @nScn             = Scn,    
   @nStep            = Step,    
   @nInputKey        = InputKey,    
   @nMenu            = Menu,    
   @cLangCode        = Lang_code,    
    
   @cFacility        = Facility,    
   @cUserName        = UserName,    
   @cPrinter         = Printer,    
    
   @cStorerKey       = V_StorerKey,    
   @cCaseID          = V_CaseID,    
   @cFromLOC         = V_LOC,    
   @cTaskDetailKey   = V_TaskDetailKey,    
   @cSKU             = V_SKU,
   @nQty             = V_QTY,
   @cSKUDesc         = V_SKUDescr,
   
   @cAreakey            = V_String1,    
   @cTTMStrategykey     = V_String2,    
   @cTTMTaskType        = V_String3,    
   @cSuggToLOC          = V_String4,    
   @cExtendedValidateSP = V_String5,    
   @cExtendedUpdateSP   = V_String6,    
   @cOverwriteToLOC     = V_String7,    
   @cExtendedInfoSP     = V_String8,    
   @cExtendedInfo       = V_String9,    
   @cDefaultToLoc       = V_String10,    
   @cDefaultCursor      = V_string11,  
   @cFlowThruScreen     = V_string12,  
   @cGoToEndTask        = V_string13,
   @cSwapTaskSP         = V_string14,
   @cValidateCaseID     = V_string15,
   @cValidateSKUQty     = V_string16,
   @cCurrentTTMTaskType = V_string17,
   @cCurrentTaskDetailKey = V_string18,
   @cFinalLOC           = V_string19,
   @cCLRPutawayZone     = V_string20,     --(yys027) config for skipping the checking the putaway zone LULUCP (step 0)

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
    
FROM RDTMOBREC (NOLOCK)    
WHERE Mobile = @nMobile    
    
-- Redirect to respective screen    
IF @nFunc = 1836    
BEGIN    
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 1836    
   IF @nStep = 1 GOTO Step_1   -- Scn = 5560. Final LOC    
   IF @nStep = 2 GOTO Step_2   -- Scn = 5561. Message. Next task type    
   IF @nStep = 3 GOTO Step_3   -- Scn = 5562. Verify Case ID    
   IF @nStep = 4 GOTO Step_4   -- Scn = 5563. Verify SKU/Qty       
END    
RETURN -- Do nothing if incorrect step    
    
    
/********************************************************************************    
Step 0. Initialize    
********************************************************************************/    
Step_0:    
BEGIN    
   -- Get task manager data    
   SET @cTaskDetailKey  = @cOutField06    
   SET @cAreaKey        = @cOutField07    
   SET @cTTMStrategyKey = @cOutField08    
    
   -- Get task info    
   SELECT    
      @cTTMTaskType = TaskType,    
      @cStorerKey   = Storerkey,    
      @cCaseID      = CaseID,    
      @cFromLOC     = FromLOC,    
      @cSuggToLOC   = ToLOC,
      @cSuggFinalLoc  = finalloc,
      @cSKU         = Sku,
      @nQty         = Qty    
   FROM dbo.TaskDetail WITH (NOLOCK)    
   WHERE TaskDetailKey = @cTaskDetailKey    
    
   -- Get storer configure    
   SET @cOverwriteToLOC = rdt.rdtGetConfig( @nFunc, 'OverwriteToLOC', @cStorerKey)    
  
   SET @cDefaultCursor = rdt.rdtGetConfig( @nFunc, 'DefaultCursor', @cStorerKey)  
    
   SET @cDefaultToLoc = rdt.rdtGetConfig( @nFunc, 'DefaultToLoc', @cStorerKey)    
   IF @cDefaultToLoc = '0'    
      SET @cDefaultToLoc = ''    
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)    
   IF @cExtendedValidateSP = '0'    
      SET @cExtendedValidateSP = ''    
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)    
   IF @cExtendedUpdateSP = '0'    
      SET @cExtendedUpdateSP = ''    
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)    
   IF @cExtendedInfoSP = '0'    
      SET @cExtendedInfoSP = ''    

   -- (james01)
   SET @cValidateCaseID = rdt.rdtGetConfig( @nFunc, 'ValidateCaseID', @cStorerKey)    
   SET @cValidateSKUQty = rdt.rdtGetConfig( @nFunc, 'ValidateSKUQty', @cStorerKey)   
  
   -- flow through step 1 (@cflowthruscreen)  
   -- While scan palletid and need go back task assisted manager screen (@cGoToEndTask)  
   SET @cFlowThruScreen = rdt.RDTGetConfig( @nFunc, 'FlowThruScreen', @cStorerKey)   
   SET @cGoToEndTask = rdt.RDTGetConfig( @nFunc, 'GoToEndTask', @cStorerKey)   

   SET @cSwapTaskSP = rdt.rdtGetConfig( @nFunc, 'SwapTaskSP', @cStorerKey)    
   IF @cSwapTaskSP = '0'    
      SET @cSwapTaskSP = ''    

   set @cCLRPutawayZone = rdt.rdtGetConfig( @nFunc, 'CLRPutawayZone', @cStorerKey)
   IF @cCLRPutawayZone = '0'
      SET @cCLRPutawayZone = ''

   
   -- EventLog    
   EXEC RDT.rdt_STD_EventLog    
      @cActionType = '1', -- Sign-in    
      @cUserID     = @cUserName,    
      @nMobileNo   = @nMobile,    
      @nFunctionID = @nFunc,    
      @cFacility   = @cFacility,    
      @cStorerKey  = @cStorerkey,    
      @nStep       = @nStep    

   IF @cValidateCaseID = '1'
   BEGIN
      DECLARE @cListKey    NVARCHAR( 10)
      
      SELECT @cListKey = ListKey
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskDetailKey
      
      IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON (TD.FromLoc = LOC.LOC)
                  WHERE TD.TaskDetailKey = @cListKey
                  AND   TD.TaskType = 'RPF'
                  AND   TD.[Status] = '9'
                  AND   LOC.Facility = @cFacility
                  AND   (@cCLRPutawayZone = '1' OR LOC.PutawayZone = 'LULUCP'   ) )
      BEGIN                  
         -- Prepare next screen var    
         SET @cOutField01 = @cCaseID    
         SET @cOutField02 = ''    
         SET @cOutField03 = @cSuggToLOC    
         SET @cOutField04 = @cSuggFinalLoc  
    
         -- Set the entry point    
         SET @nScn  = 5562    
         SET @nStep = 3    
         
         GOTO Quit
      END
   END  

   -- Extended validate  (yeekung01)  
   IF @cExtendedValidateSP <> ''    
   BEGIN    
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
         SET @cSQLParam =    
            '@nMobile         INT,           ' +    
            '@nFunc           INT,           ' +    
            '@cLangCode       NVARCHAR( 3),  ' +    
            '@nStep           INT,           ' +    
            '@nInputKey       INT,           ' +     
            '@cTaskdetailKey  NVARCHAR( 10), ' +    
            '@cFinalLOC       NVARCHAR( 10), ' +    
            '@nErrNo          INT OUTPUT,    ' +    
            '@cErrMsg         NVARCHAR( 1024) OUTPUT '
       
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
         IF @nErrNo <> 0    
         BEGIN  
            IF @nErrNo='-1'  
            BEGIN  
               SET @cErrMsg=''  
               SET @nErrNo=''  
            END  
            SET @nFunc='1814'  
            GOTO QUIT    
         END  
      END    
   END    
  
   -- Extended validate  (yeekung01)  
   IF @cExtendedUpdateSP <> ''    
   BEGIN    
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
         SET @cSQLParam =    
            '@nMobile         INT,           ' +    
            '@nFunc           INT,           ' +    
            '@cLangCode       NVARCHAR( 3),  ' +    
            '@nStep           INT,           ' +    
            '@nInputKey       INT,           ' +     
            '@cTaskdetailKey  NVARCHAR( 10), ' +    
            '@cFinalLOC       NVARCHAR( 10), ' +    
            '@nErrNo          INT OUTPUT,    ' +    
            '@cErrMsg         NVARCHAR( 20) OUTPUT '    
       
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
         IF @nErrNo <> 0    
         BEGIN  
            SET @nFunc='1814'  
            GOTO QUIT    
         END   
      END    
   END    
   
   -- Prepare next screen var    
   SET @cOutField01 = @cCaseID    
   SET @cOutField02 = @cSuggToLOC    
   SET @cOutField03 = CASE WHEN @cDefaultToLoc = '1' THEN @cSuggToLOC ELSE '' END   -- FinalLOC    
   SET @cOutField04 = @cSuggFinalLoc  
    
   -- Set the entry point    
   SET @nScn  = 5560    
   SET @nStep = 1    
   
   -- Extended info    
   SET @cOutField15 = ''    
   SET @cExtendedInfo = '' -- (james02)    
   IF @cExtendedInfoSP <> ''    
   BEGIN    
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
      BEGIN    
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
         SET @cSQLParam =    
            '@nMobile         INT,           ' +    
            '@nFunc           INT,           ' +    
            '@cLangCode       NVARCHAR( 3),  ' +    
            '@nStep           INT,           ' +    
            '@nAfterStep      INT,           ' +    
            '@nInputKey       INT,           ' +     
            '@cTaskdetailKey  NVARCHAR( 10), ' +    
            '@cFinalLOC       NVARCHAR( 10), ' +    
            '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +    
            '@nErrNo          INT           OUTPUT, ' +    
            '@cErrMsg         NVARCHAR( 20) OUTPUT  '    
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
            @nMobile, @nFunc, @cLangCode, 0, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
         SET @cOutField15 = @cExtendedInfo    
      END    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 1. Screen = 4080    
   CASE ID      (Field01)    
   SUGGEST LOC  (Field02)    
   FINAL LOC    (Field03, input)    
********************************************************************************/    
Step_1:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cFinalLOC = @cInField03    
    
      -- Check blank    
      IF @cFinalLOC = ''    
      BEGIN    
         SET @nErrNo = 142951    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TO LOC needed    
         GOTO Step_1_Fail    
      END    
    
      -- Check if FromLOC match    
      IF @cFinalLOC <> @cSuggToLOC AND @cSuggToLOC <> ''    
      BEGIN    
         IF @cOverwriteToLOC = '0'    
         BEGIN    
            SET @nErrNo = 142952    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different LOC     
            GOTO Step_1_Fail    
         END    
             
         -- Check ToLOC valid    
         IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cFinalLOC)    
         BEGIN    
            SET @nErrNo = 142953    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC    
            GOTO Step_1_Fail    
         END    
      END    
      SET @cOutField03 = @cFinalLOC    
    
      -- Extended validate    
      IF @cExtendedValidateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +     
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cFinalLOC       NVARCHAR( 10), ' +    
               '@nErrNo          INT OUTPUT,    ' +    
               '@cErrMsg         NVARCHAR( 1024) OUTPUT '
       
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
            IF @nErrNo <> 0    
               GOTO Step_1_Fail    
         END    
      END    
      
      IF @cValidateSKUQty = '1'
      BEGIN
         SELECT @cListKey = ListKey
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey
         
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON (TD.FromLoc = LOC.LOC)
                     WHERE TD.TaskDetailKey = @cListKey
                     AND   TD.TaskType = 'RPF'
                     AND   TD.[Status] = '9'
                     AND   LOC.Facility = @cFacility
                     AND  (@cCLRPutawayZone = '1' OR LOC.PutawayZone = 'LULUCP') )
         BEGIN
            -- Get SKU info  
            SELECT @cSKUDesc = ISNULL( DescR, '')  
            FROM dbo.SKU SKU WITH (NOLOCK)  
            JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
            WHERE SKU.StorerKey = @cStorerKey  
            AND   SKU.SKU = @cSKU  

            SELECT @nSuggestQty = ISNULL( SUM( Qty), 0)
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE ListKey = @cListKey
            AND   TaskType = @cTTMTaskType
            AND   Caseid = @cCaseID
            AND   [Status] = '0'
            AND   ToLoc = @cSuggToLOC
            AND   Sku = @cSKU
            
            SET @cOutField01 = @cSKU
            SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1  
            SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20)  -- SKU desc 2  
            SET @cOutField04 = ''      -- SKU
            SET @cOutField05 = @nSuggestQty
            SET @cOutField06 = ''      -- Qty
         
            EXEC rdt.rdtSetFocusField @nMobile, 4
         
            SET @nScn = @nScn + 3
            SET @nStep = @nStep + 3
         
            GOTO Quit
         END
      END

      -- Confirm (move by ID, update task status = 9)    
      EXEC rdt.rdt_TM_Assist_ReplenTo_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey    
         ,@cTaskdetailKey      
         ,@cFinalLOC           
         ,@nErrNo   OUTPUT    
         ,@cErrMsg  OUTPUT    
      IF @nErrNo <> 0    
         GOTO Step_1_Fail    
          
      -- Extended validate    
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +     
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cFinalLOC       NVARCHAR( 10), ' +    
               '@nErrNo          INT OUTPUT,    ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT '    
       
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
            IF @nErrNo <> 0    
               GOTO Step_1_Fail    
         END    
      END
          
      -- Get next task    
      DECLARE @cNextTaskDetailKey NVARCHAR(10)    
      SET @cNextTaskDetailKey = ''    
      SELECT TOP 1     
         @cNextTaskDetailKey = TaskDetailKey,    
         @cTTMTasktype = TaskType    
      FROM dbo.TaskDetail WITH (NOLOCK)    
         JOIN CodeLKUP WITH (NOLOCK) ON (ListName = 'RDTAstTask' AND Code = TaskType AND Code2 = @cFacility)    
      WHERE CaseID = @cCaseID    
         AND Status = '0'    
      ORDER BY TaskDetailKey    
          
      -- No task    
      IF @cNextTaskDetailKey = ''    
      BEGIN    
         -- EventLog    
         EXEC RDT.rdt_STD_EventLog    
            @cActionType = '9', -- Sign-out    
            @cUserID     = @cUserName,    
            @nMobileNo   = @nMobile,    
            @nFunctionID = @nFunc,    
            @cFacility   = @cFacility,    
            @cStorerKey  = @cStorerKey,    
            @nStep       = @nStep    
             
         -- Go back to assist task manager    
         SET @nFunc = 1814    
         SET @nScn = 4060    
         SET @nStep = 1    
    
         SET @cOutField01 = ''  -- From ID    
         SET @cOutField02 = ''  -- Case ID    
             
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Case ID    
    
         GOTO QUIT    
      END    
  
      IF @cFlowThruScreen='1'  
      BEGIN  
         IF @cGoToEndTask='1'  
            SET @nInputKey=0  
  
         GOTO STEP_2  
      END  
          
      -- Have next task    
      IF @cNextTaskDetailKey <> ''    
      BEGIN    
         SET @cTaskDetailKey = @cNextTaskDetailKey    
             
         -- Prepare next screen var    
         SET @cOutField01 = @cTTMTasktype    
    
         -- Go to next task    
         SET @nScn  = @nScn + 1    
         SET @nStep = @nStep + 1    
    
         GOTO Quit    
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
         @cStorerKey  = @cStorerKey,    
         @nStep       = @nStep    
  
      -- Extended validate  (yeekung01)  
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,     ' +     
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cFinalLOC       NVARCHAR( 10), ' +    
               '@nErrNo          INT OUTPUT,    ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT '    
       
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
            IF @nErrNo <> 0    
               GOTO Quit    
         END    
      END    
  
      -- Go back to assist task manager    
      SET @nFunc = 1814    
      SET @nScn = 4060    
      SET @nStep = 1    
    
      SET @cOutField01 = ''  -- Pallet ID    
      SET @cOutField02 = ''  -- Case ID    
  
      IF ISNULL(@cDefaultCursor,'')<>0  --(yeekung01)  
         EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor            
      ELSE    
         EXEC rdt.rdtSetFocusField @nMobile, 2   
    
      GOTO QUIT    
   END    
   GOTO Quit    
    
   Step_1_Fail:    
   BEGIN    
      SET @cFinalLOC = ''    
      SET @cOutField03 = '' -- FinalLOC    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 2. Screen 4081. Next task    
   Next task type (field01)    
********************************************************************************/    
Step_2:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      IF @cCurrentTTMTaskType <> @cTTMTaskType
      BEGIN
         SET @cCurrentCaseID = @cCaseID
         SET @cCurrentSuggToLoc = @cSuggToLOC
         
         -- Get task info    
         SELECT    
            @cTTMTaskType = TaskType,    
            @cStorerKey   = Storerkey,    
            @cCaseID      = CaseID,    
            @cFromLOC     = FromLOC,    
            @cSuggToLOC   = ToLOC,
            @cSuggFinalLoc  = finalloc,
            @cSKU         = Sku,
            @nQty         = Qty    
         FROM dbo.TaskDetail WITH (NOLOCK)    
         WHERE TaskDetailKey = @cTaskDetailKey  

         -- Same case id, same suggested loc -> remain same screen
         -- Same case id, diff suggested loc -> goto suggested loc
         -- Different case id -> go to verify case id 
         IF @cCurrentCaseID = @cCaseID
         BEGIN
            IF @cCurrentSuggToLoc = @cSuggToLOC
            BEGIN
               SELECT @cListKey = ListKey
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE TaskDetailKey = @cTaskDetailKey
               
               -- Get SKU info  
               SELECT @cSKUDesc = ISNULL( DescR, '')  
               FROM dbo.SKU SKU WITH (NOLOCK)  
               JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
               WHERE SKU.StorerKey = @cStorerKey  
               AND   SKU.SKU = @cSKU  
         
               SELECT @nSuggestQty = ISNULL( SUM( Qty), 0)
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE ListKey = @cListKey
               AND   TaskType = @cTTMTaskType
               AND   Caseid = @cCaseID
               AND   [Status] = '0'
               AND   ToLoc = @cSuggToLOC
               AND   Sku = @cSKU
               
               SET @cOutField01 = @cSKU
               SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1  
               SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20)  -- SKU desc 2  
               SET @cOutField04 = ''      -- SKU
               SET @cOutField05 = @nSuggestQty
               SET @cOutField06 = ''      -- Qty
         
               EXEC rdt.rdtSetFocusField @nMobile, 4
         
               SET @nScn = @nScn + 2
               SET @nStep = @nStep + 2
            END
            ELSE
            BEGIN
               -- Prepare next screen var    
               SET @cOutField01 = @cCaseID    
               SET @cOutField02 = @cSuggToLOC    
               SET @cOutField03 = CASE WHEN @cDefaultToLoc = '1' THEN @cSuggToLOC ELSE '' END   -- FinalLOC    
               SET @cOutField04 = @cSuggFinalLoc  
    
               -- Set the entry point    
               SET @nScn  = @nScn - 1    
               SET @nStep = @nStep - 1    
            END
         END
         ELSE
         BEGIN
            IF @cValidateCaseID = '1'
            BEGIN
               -- Prepare next screen var    
               SET @cOutField01 = @cCaseID    
               SET @cOutField02 = ''    
               SET @cOutField03 = @cSuggToLOC    
               SET @cOutField04 = @cSuggFinalLoc  
    
               -- Set the entry point    
               SET @nScn  = @nScn + 1    
               SET @nStep = @nStep + 1    
            END  
            ELSE
            BEGIN
               -- Extended validate  (yeekung01)  
               IF @cExtendedValidateSP <> ''    
               BEGIN    
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
                  BEGIN    
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
                     SET @cSQLParam =    
                        '@nMobile         INT,           ' +    
                        '@nFunc           INT,           ' +    
                        '@cLangCode       NVARCHAR( 3),  ' +    
                        '@nStep           INT,           ' +    
                        '@nInputKey       INT,           ' +     
                        '@cTaskdetailKey  NVARCHAR( 10), ' +    
                        '@cFinalLOC       NVARCHAR( 10), ' +    
                        '@nErrNo          INT OUTPUT,    ' +    
                        '@cErrMsg         NVARCHAR( 1024) OUTPUT '
       
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
                     IF @nErrNo <> 0    
                     BEGIN  
                        IF @nErrNo='-1'  
                        BEGIN  
                           SET @cErrMsg=''  
                           SET @nErrNo=''  
                        END  
                        SET @nFunc='1814'  
                        GOTO QUIT    
                     END  
                  END    
               END    
  
               -- Extended validate  (yeekung01)  
               IF @cExtendedUpdateSP <> ''    
               BEGIN    
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
                  BEGIN    
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
                     SET @cSQLParam =    
                        '@nMobile         INT,           ' +    
                        '@nFunc           INT,           ' +    
                        '@cLangCode       NVARCHAR( 3),  ' +    
                        '@nStep           INT,           ' +    
                        '@nInputKey       INT,           ' +     
                        '@cTaskdetailKey  NVARCHAR( 10), ' +    
                        '@cFinalLOC       NVARCHAR( 10), ' +    
                        '@nErrNo          INT OUTPUT,    ' +    
                        '@cErrMsg         NVARCHAR( 20) OUTPUT '    
       
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
                     IF @nErrNo <> 0    
                     BEGIN  
                        SET @nFunc='1814'  
                        GOTO QUIT    
                     END   
                  END    
               END    
   
               -- Prepare next screen var    
               SET @cOutField01 = @cCaseID    
               SET @cOutField02 = @cSuggToLOC    
               SET @cOutField03 = CASE WHEN @cDefaultToLoc = '1' THEN @cSuggToLOC ELSE '' END   -- FinalLOC    
               SET @cOutField04 = @cSuggFinalLoc  
    
               -- Set the entry point    
               SET @nScn  = @nScn - 1    
               SET @nStep = @nStep - 1    
            END
         END

         -- Extended info    
         SET @cOutField15 = ''    
         SET @cExtendedInfo = '' 
         IF @cExtendedInfoSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
               SET @cSQLParam =    
                  '@nMobile         INT,           ' +    
                  '@nFunc           INT,           ' +    
                  '@cLangCode       NVARCHAR( 3),  ' +    
                  '@nStep           INT,           ' +    
                  '@nAfterStep      INT,           ' +    
                  '@nInputKey       INT,           ' +     
                  '@cTaskdetailKey  NVARCHAR( 10), ' +    
                  '@cFinalLOC       NVARCHAR( 10), ' +    
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +    
                  '@nErrNo          INT           OUTPUT, ' +    
                  '@cErrMsg         NVARCHAR( 20) OUTPUT  '    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, 0, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
               SET @cOutField15 = @cExtendedInfo    
            END    
         END    
      END
      ELSE
      BEGIN
         DECLARE @nToFunc INT    
         DECLARE @nToScn  INT    
         DECLARE @nToStep INT    
         SET @nToFunc = 0    
         SET @nToScn  = 0    
         SET @nToStep = 0    
    
         -- Check if function setup    
         SELECT     
            @nToFunc = Function_ID,     
            @nToStep = Step    
         FROM rdt.rdtTaskManagerConfig WITH (NOLOCK)     
         WHERE TaskType = @cTTMTaskType    
         IF @nToFunc = 0    
         BEGIN    
            SET @nErrNo = 142954    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr    
            GOTO Quit    
         END    
    
         -- Check if screen setup    
         SELECT TOP 1 @nToScn = Scn FROM RDT.RDTScn WITH (NOLOCK) WHERE Func = @nToFunc ORDER BY Scn    
         IF @nToScn = 0    
         BEGIN    
            SET @nErrNo = 142955    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr    
            GOTO Quit    
         END    
    
         -- Logging    
         EXEC RDT.rdt_STD_EventLog    
            @cActionType = '9', -- Sign Out function    
            @cUserID     = @cUserName,    
            @nMobileNo   = @nMobile,    
            @nFunctionID = @nFunc,    
            @cFacility   = @cFacility,    
            @cStorerKey  = @cStorerKey,    
            @nStep       = @nStep    
          
         SET @cOutField06 = @cTaskDetailKey    
         SET @cOutField07 = @cAreaKey    
         SET @cOutField08 = @cTTMStrategykey    
    
         SET @nFunc = @nToFunc    
         SET @nScn  = @nToScn    
         SET @nStep = @nToStep    
    
         IF @cTTMTaskType IN ('ASTNMV')    
            GOTO Step_0             
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
         @cStorerKey  = @cStorerKey,    
         @nStep       = @nStep    
    
      -- Go back to assist task manager    
      SET @nFunc = 1814    
      SET @nScn = 4060    
      SET @nStep = 1    
    
      SET @cOutField01 = ''  -- From ID    
      SET @cOutField02 = ''  -- Case ID    
          
      IF ISNULL(@cDefaultCursor,'')<>0  --(yeekung01)  
         EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor            
      ELSE    
         EXEC rdt.rdtSetFocusField @nMobile, 2   
   END    
END    
GOTO Quit    
    
/********************************************************************************    
Step 3. Screen = 5562    
   CASE ID      (Field01)    
   CASE ID      (Field02, input)    
********************************************************************************/    
Step_3:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cNewCaseID = @cInField02    
    
      -- Check blank    
      IF @cNewCaseID = ''    
      BEGIN    
         SET @nErrNo = 142956    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Case Id needed    
         GOTO Step_3_Fail    
      END    
      
      -- Check if valid case id
      IF NOT EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)
                      WHERE Storerkey = @cStorerKey
                      AND   Caseid = @cNewCaseID
                      AND   TaskType = 'ASTRPT'
                      AND   [Status] IN ('H', '0'))
      BEGIN    
         SET @nErrNo = 142957    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Case Id     
         GOTO Step_3_Fail    
      END 
      
      -- Check if case id match    
      IF @cCaseID <> @cNewCaseID     
      BEGIN    
         -- Check if swap task setup
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cSwapTaskSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cSwapTaskSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cNewCaseID, @cTaskdetailKey, ' + 
               ' @cNewTaskdetailKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile            INT,           ' +    
               '@nFunc              INT,           ' +    
               '@cLangCode          NVARCHAR( 3),  ' +    
               '@nStep              INT,           ' +    
               '@nInputKey          INT,           ' +     
               '@cNewCaseID         NVARCHAR( 20), ' +
               '@cTaskdetailKey     NVARCHAR( 10), ' +    
               '@cNewTaskdetailKey  NVARCHAR( 10)  OUTPUT,' +
               '@nErrNo             INT            OUTPUT,    ' +    
               '@cErrMsg            NVARCHAR( 20)  OUTPUT '    
       
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cNewCaseID, @cTaskdetailKey, @cNewTaskdetailKey OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    

            IF @nErrNo <> 0    
               GOTO Step_1_Fail    
            ELSE
            BEGIN
               SET @cTaskDetailKey = @cNewTaskdetailKey

               -- Reload again taskdetail
               SELECT    
                  @cCaseID      = CaseID,    
                  @cFromLOC     = FromLOC,    
                  @cSuggToLOC   = ToLOC,
                  @cSuggFinalLoc  = FinalLoc,
                  @cSKU         = Sku,
                  @nQty         = Qty    
               FROM dbo.TaskDetail WITH (NOLOCK)    
               WHERE TaskDetailKey = @cTaskDetailKey
            END    
         END
         ELSE
         BEGIN    
            SET @nErrNo = 142958    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different Case     
            GOTO Step_3_Fail    
         END    
      END    
      
      -- Extended validate  
      IF @cExtendedValidateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +     
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cFinalLOC       NVARCHAR( 10), ' +    
               '@nErrNo          INT OUTPUT,    ' +    
               '@cErrMsg         NVARCHAR( 1024) OUTPUT '
       
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
            IF @nErrNo <> 0    
            BEGIN  
               IF @nErrNo='-1'  
               BEGIN  
                  SET @cErrMsg=''  
                  SET @nErrNo=''  
               END  
               GOTO Step_3_Fail    
            END  
         END    
      END    
  
      -- Extended update    
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +     
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cFinalLOC       NVARCHAR( 10), ' +    
               '@nErrNo          INT OUTPUT,    ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT '    
       
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
            IF @nErrNo <> 0    
               GOTO Step_3_Fail    
         END    
      END    
   
      -- Prepare next screen var    
      SET @cOutField01 = @cCaseID    
      SET @cOutField02 = @cSuggToLOC    
      SET @cOutField03 = CASE WHEN @cDefaultToLoc = '1' THEN @cSuggToLOC ELSE '' END   -- FinalLOC    
      SET @cOutField04 = @cSuggFinalLoc  
    
      -- Set the entry point    
      SET @nScn  = 5560    
      SET @nStep = 1    
   
      -- Extended info    
      SET @cOutField15 = ''    
      SET @cExtendedInfo = '' 
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nAfterStep      INT,           ' +    
               '@nInputKey       INT,           ' +     
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cFinalLOC       NVARCHAR( 10), ' +    
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +    
               '@nErrNo          INT           OUTPUT, ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, 0, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            SET @cOutField15 = @cExtendedInfo    
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
         @cStorerKey  = @cStorerKey,    
         @nStep       = @nStep    
  
      -- Extended validate  (yeekung01)  
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,     ' +     
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cFinalLOC       NVARCHAR( 10), ' +    
               '@nErrNo          INT OUTPUT,    ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT '    
       
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
            IF @nErrNo <> 0    
               GOTO Quit    
         END    
      END    
  
      -- Go back to assist task manager    
      SET @nFunc = 1814    
      SET @nScn = 4060    
      SET @nStep = 1    
    
      SET @cOutField01 = ''  -- Pallet ID    
      SET @cOutField02 = ''  -- Case ID    
  
      IF ISNULL(@cDefaultCursor,'')<>0  --(yeekung01)  
         EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor            
      ELSE    
         EXEC rdt.rdtSetFocusField @nMobile, 2   
    
      GOTO QUIT    
   END    
   GOTO Quit    
    
   Step_3_Fail:    
   BEGIN    
      SET @cNewCaseID = ''    
      SET @cOutField02 = '' -- Case Id    
   END    
END    
GOTO Quit    

/********************************************************************************    
Step 4. Screen = 5563    
   SKU          (Field01, input)
   REPLEN QTY   (Field02)
   QTY          (Field03, input)    
********************************************************************************/    
Step_4:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cVerifySKU = @cInField04    
      SET @nSuggestQty = CAST( @cOutField05 AS INT)
      SET @nVerifyQty = @cInField06
      
      -- Validate blank  
      IF @cVerifySKU = ''  
      BEGIN  
         SET @nErrNo = 142959  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU needed  
         GOTO Step_SKUQTY_Fail_SKU  
      END  

      -- Get SKU/UPC  
      DECLARE @nSKUCnt INT  
      DECLARE @b_Success INT
      SET @nSKUCnt = 0  
  
      EXEC RDT.rdt_GETSKUCNT  
          @cStorerKey  = @cStorerKey  
         ,@cSKU        = @cVerifySKU  
         ,@nSKUCnt     = @nSKUCnt       OUTPUT  
         ,@bSuccess    = @b_Success     OUTPUT  
         ,@nErr        = @nErrNo        OUTPUT  
         ,@cErrMsg     = @cErrMsg       OUTPUT  
  
      -- Validate SKU/UPC  
      IF @nSKUCnt = 0  
      BEGIN  
         SET @nErrNo = 142960  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU  
         GOTO Step_SKUQTY_Fail_SKU  
      END  
  
      IF @nSKUCnt = 1  
         EXEC [RDT].[rdt_GETSKU]  
             @cStorerKey  = @cStorerKey  
            ,@cSKU        = @cVerifySKU    OUTPUT  
            ,@bSuccess    = @b_Success     OUTPUT  
            ,@nErr        = @nErrNo        OUTPUT  
            ,@cErrMsg     = @cErrMsg       OUTPUT  
  
      -- Validate barcode return multiple SKU  
      IF @nSKUCnt > 1  
      BEGIN  
         SET @nErrNo = 142961  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod  
         GOTO Step_SKUQTY_Fail_SKU  
      END  

      IF @cVerifySKU <> @cSKU
      BEGIN
         SET @nErrNo = 142962  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Sku Not Match 
         GOTO Step_SKUQTY_Fail_SKU  
      END
      
      -- Retain value  
      SET @cOutField01 = @cSKU  
      SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1  
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2  
      SET @cOutField04 = @cSKU

      -- Check QTY blank  
      IF @nVerifyQty = ''  
      BEGIN  
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY  
         GOTO Quit
         --GOTO Step_SKUQTY_Fail_QTY  
      END  
  
      -- Check QTY valid  
      IF rdt.rdtIsValidQty( @nVerifyQty, 1) = 0  
      BEGIN  
         SET @nErrNo = 142963  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY  
         GOTO Step_SKUQTY_Fail_QTY  
      END  

      IF @nVerifyQty <> @nSuggestQty
      BEGIN
         SET @nErrNo = 142964  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Qty Not Match 
         GOTO Step_SKUQTY_Fail_QTY  
      END

      -- Retain QTY field  
      SET @cOutField06 = @nSuggestQty  

      -- Confirm (move by ID, update task status = 9)    
      EXEC rdt.rdt_TM_Assist_ReplenTo_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey    
         ,@cTaskdetailKey      
         ,@cFinalLOC           
         ,@nErrNo   OUTPUT    
         ,@cErrMsg  OUTPUT    
      IF @nErrNo <> 0    
         GOTO Quit    
          
      -- Extended validate    
      IF @cExtendedUpdateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +     
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cFinalLOC       NVARCHAR( 10), ' +    
               '@nErrNo          INT OUTPUT,    ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT '    
       
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
            IF @nErrNo <> 0    
               GOTO Quit    
         END    
      END    

      -- Retain current value
      SET @cCurrentTTMTaskType = @cTTMTaskType
      SET @cCurrentTaskDetailKey = @cTaskDetailKey

      -- Get next task    
      SET @cNextTaskDetailKey = ''    
      SELECT TOP 1     
         @cNextTaskDetailKey = TaskDetailKey,    
         @cTTMTasktype = TaskType    
      FROM dbo.TaskDetail WITH (NOLOCK)    
         JOIN CodeLKUP WITH (NOLOCK) ON (ListName = 'RDTAstTask' AND Code = TaskType AND Code2 = @cFacility)    
      WHERE CaseID = @cCaseID    
         AND Status = '0'    
      ORDER BY TaskDetailKey    
          
      -- No task    
      IF @cNextTaskDetailKey = ''    
      BEGIN    
         -- EventLog    
         EXEC RDT.rdt_STD_EventLog    
            @cActionType = '9', -- Sign-out    
            @cUserID     = @cUserName,    
            @nMobileNo   = @nMobile,    
            @nFunctionID = @nFunc,    
            @cFacility   = @cFacility,    
            @cStorerKey  = @cStorerKey,    
            @nStep       = @nStep    
             
         -- Go back to assist task manager    
         SET @nFunc = 1814    
         SET @nScn = 4060    
         SET @nStep = 1    
    
         SET @cOutField01 = ''  -- From ID    
         SET @cOutField02 = ''  -- Case ID    
             
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Case ID    
    
         GOTO QUIT    
      END    
  
      IF @cFlowThruScreen='1'  
      BEGIN  
         IF @cGoToEndTask='1'  
            SET @nInputKey=0  
  
         GOTO STEP_2  
      END  
          
      -- Have next task    
      IF @cNextTaskDetailKey <> ''    
      BEGIN    
         SET @cTaskDetailKey = @cNextTaskDetailKey    

         SET @cCurrentCaseID = @cCaseID
         SET @cCurrentSuggToLoc = @cSuggToLOC
         
         -- Get task info    
         SELECT    
            @cTTMTaskType = TaskType,    
            @cStorerKey   = Storerkey,    
            @cCaseID      = CaseID,    
            @cFromLOC     = FromLOC,    
            @cSuggToLOC   = ToLOC,
            @cSuggFinalLoc  = finalloc,
            @cSKU         = Sku,
            @nQty         = Qty    
         FROM dbo.TaskDetail WITH (NOLOCK)    
         WHERE TaskDetailKey = @cTaskDetailKey  

         -- Same case id, same suggested loc -> remain same screen
         -- Same case id, diff suggested loc -> goto suggested loc
         -- Different case id -> go to verify case id 
         IF @cCurrentCaseID = @cCaseID
         BEGIN
            IF @cCurrentSuggToLoc = @cSuggToLOC
            BEGIN
               SELECT @cListKey = ListKey
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE TaskDetailKey = @cTaskDetailKey
               
               -- Get SKU info  
               SELECT @cSKUDesc = ISNULL( DescR, '')  
               FROM dbo.SKU SKU WITH (NOLOCK)  
               JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)  
               WHERE SKU.StorerKey = @cStorerKey  
               AND   SKU.SKU = @cSKU  
         
               SELECT @nSuggestQty = ISNULL( SUM( Qty), 0)
               FROM dbo.TaskDetail WITH (NOLOCK)
               WHERE ListKey = @cListKey
               AND   TaskType = @cTTMTaskType
               AND   Caseid = @cCaseID
               AND   [Status] = '0'
               AND   ToLoc = @cSuggToLOC
               AND   Sku = @cSKU
               
               SET @cOutField01 = @cSKU
               SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1  
               SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20)  -- SKU desc 2  
               SET @cOutField04 = ''      -- SKU
               SET @cOutField05 = @nSuggestQty
               SET @cOutField06 = ''      -- Qty
         
               EXEC rdt.rdtSetFocusField @nMobile, 4
         
               GOTO Quit
            END
            ELSE
            BEGIN
               -- Prepare next screen var    
               SET @cOutField01 = @cCaseID    
               SET @cOutField02 = @cSuggToLOC    
               SET @cOutField03 = CASE WHEN @cDefaultToLoc = '1' THEN @cSuggToLOC ELSE '' END   -- FinalLOC    
               SET @cOutField04 = @cSuggFinalLoc  
    
               -- Set the entry point    
               SET @nScn  = 5560    
               SET @nStep = 1    
   
               -- Extended info    
               SET @cOutField15 = ''    
               SET @cExtendedInfo = '' 
               IF @cExtendedInfoSP <> ''    
               BEGIN    
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
                  BEGIN    
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
                     SET @cSQLParam =    
                        '@nMobile         INT,           ' +    
                        '@nFunc           INT,           ' +    
                        '@cLangCode       NVARCHAR( 3),  ' +    
                        '@nStep           INT,           ' +    
                        '@nAfterStep      INT,           ' +    
                        '@nInputKey       INT,           ' +     
                        '@cTaskdetailKey  NVARCHAR( 10), ' +    
                        '@cFinalLOC       NVARCHAR( 10), ' +    
                        '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +    
                        '@nErrNo          INT           OUTPUT, ' +    
                        '@cErrMsg         NVARCHAR( 20) OUTPUT  '    
    
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                        @nMobile, @nFunc, @cLangCode, 0, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
                     SET @cOutField15 = @cExtendedInfo    
                  END    
               END    
            END
         END
         ELSE
         BEGIN
            IF @cValidateCaseID = '1'
            BEGIN
               -- Prepare next screen var    
               SET @cOutField01 = @cCaseID    
               SET @cOutField02 = ''    
               SET @cOutField03 = @cSuggToLOC    
               SET @cOutField04 = @cSuggFinalLoc  
    
               -- Set the entry point    
               SET @nScn  = 5562    
               SET @nStep = 3    
            END  
            ELSE
            BEGIN
               -- Extended validate  (yeekung01)  
               IF @cExtendedValidateSP <> ''    
               BEGIN    
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
                  BEGIN    
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
                     SET @cSQLParam =    
                        '@nMobile         INT,           ' +    
                        '@nFunc           INT,           ' +    
                        '@cLangCode       NVARCHAR( 3),  ' +    
                        '@nStep           INT,           ' +    
                        '@nInputKey       INT,           ' +     
                        '@cTaskdetailKey  NVARCHAR( 10), ' +    
                        '@cFinalLOC       NVARCHAR( 10), ' +    
                        '@nErrNo          INT OUTPUT,    ' +    
                        '@cErrMsg         NVARCHAR( 1024) OUTPUT '
       
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
                     IF @nErrNo <> 0    
                     BEGIN  
                        IF @nErrNo='-1'  
                        BEGIN  
                           SET @cErrMsg=''  
                           SET @nErrNo=''  
                        END  
                        SET @nFunc='1814'  
                        GOTO QUIT    
                     END  
                  END    
               END    
  
               -- Extended validate  (yeekung01)  
               IF @cExtendedUpdateSP <> ''    
               BEGIN    
                  IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')    
                  BEGIN    
                     SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +    
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
                     SET @cSQLParam =    
                        '@nMobile         INT,           ' +    
                        '@nFunc           INT,           ' +    
                        '@cLangCode       NVARCHAR( 3),  ' +    
                        '@nStep           INT,           ' +    
                        '@nInputKey       INT,           ' +     
                        '@cTaskdetailKey  NVARCHAR( 10), ' +    
                        '@cFinalLOC       NVARCHAR( 10), ' +    
                        '@nErrNo          INT OUTPUT,    ' +    
                        '@cErrMsg         NVARCHAR( 20) OUTPUT '    
       
                     EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                        @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT    
       
                     IF @nErrNo <> 0    
                     BEGIN  
                        SET @nFunc='1814'  
                        GOTO QUIT    
                     END   
                  END    
               END    
   
               -- Prepare next screen var    
               SET @cOutField01 = @cCaseID    
               SET @cOutField02 = @cSuggToLOC    
               SET @cOutField03 = CASE WHEN @cDefaultToLoc = '1' THEN @cSuggToLOC ELSE '' END   -- FinalLOC    
               SET @cOutField04 = @cSuggFinalLoc  
    
               -- Set the entry point    
               SET @nScn  = 5560    
               SET @nStep = 1    
            END
         END
         
         -- Prepare next screen var    
         SET @cOutField01 = @cTTMTasktype    
    
         -- Go to next task    
         SET @nScn  = @nScn + 1    
         SET @nStep = @nStep + 1    
    
         GOTO Quit    
      END    
   END

   IF @nInputKey = 0 -- ESC    
   BEGIN
      -- Prepare next screen var    
      SET @cOutField01 = @cCaseID    
      SET @cOutField02 = @cSuggToLOC    
      SET @cOutField03 = CASE WHEN @cDefaultToLoc = '1' THEN @cSuggToLOC ELSE '' END   -- FinalLOC    
      SET @cOutField04 = @cSuggFinalLoc  
    
      -- Set the entry point    
      SET @nScn  = @nScn - 3    
      SET @nStep = @nStep - 3    
   
      -- Extended info    
      SET @cOutField15 = ''    
      SET @cExtendedInfo = '' -- (james02)    
      IF @cExtendedInfoSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nAfterStep      INT,           ' +    
               '@nInputKey       INT,           ' +     
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cFinalLOC       NVARCHAR( 10), ' +    
               '@cExtendedInfo   NVARCHAR( 20) OUTPUT, ' +    
               '@nErrNo          INT           OUTPUT, ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT  '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, 0, @nStep, @nInputKey, @cTaskdetailKey, @cFinalLOC, @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            SET @cOutField15 = @cExtendedInfo    
         END    
      END        
   END
   GOTO Quit

   Step_SKUQTY_Fail_SKU:  
   BEGIN  
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nErrNo, @cErrMsg  
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU  
      SET @cOutField04 = ''  
      SET @cVerifySKU = ''  
      GOTO Quit  
   END  
  
   Step_SKUQTY_Fail_QTY:  
   BEGIN  
      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @nErrNo, @cErrMsg  
      EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY  
      SET @cOutField06 = ''  
      GOTO Quit  
   END  
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
    
      Facility  = @cFacility,    
      -- UserName  = @cUserName,    
    
      V_StorerKey = @cStorerKey,    
      V_CaseID        = @cCaseID,    
      V_LOC       = @cFromLOC,    
      V_TaskDetailKey = @cTaskDetailKey,    
      V_SKU       = @cSKU,
      V_QTY       = @nQty,
      V_SKUDescr  = @cSKUDesc,

      V_String1  = @cAreakey,    
      V_String2  = @cTTMStrategykey,    
      V_String3  = @cTTMTaskType,          
      V_String4  = @cSuggToLOC,    
      V_String5  = @cExtendedValidateSP,    
      V_String6  = @cExtendedUpdateSP,    
      V_String7  = @cOverwriteToLOC,    
      V_String8  = @cExtendedInfoSP,    
      V_String9  = @cExtendedInfo,    
      V_String10 = @cDefaultToLoc,    
      V_String11 = @cDefaultCursor,  
      V_string12 = @cFlowThruScreen,  
      V_string13 = @cGoToEndTask,  
      V_string14 = @cSwapTaskSP,
      V_string15 = @cValidateCaseID,
      V_string16 = @cValidateSKUQty,
      V_string17 = @cCurrentTTMTaskType,
      V_string18 = @cCurrentTaskDetailKey,
      V_string19 = @cFinalLOC,
      V_string20 = @cCLRPutawayZone,       --(yys027)

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
    
   -- Execute TM module initialization (ung01)    
   IF (@nFunc <> 1836 AND @nStep = 0) AND -- Other module that begin with step 0    
      (@nFunc <> @nMenu)                  -- Not ESC from screen to menu    
   BEGIN    
      -- Get the stor proc to execute    
      DECLARE @cStoredProcName NVARCHAR( 1024)    
      SELECT @cStoredProcName = StoredProcName    
      FROM RDT.RDTMsg WITH (NOLOCK)    
      WHERE Message_ID = @nFunc    
    
      -- Execute the stor proc    
      SELECT @cStoredProcName = N'EXEC RDT.' + RTRIM(@cStoredProcName)    
      SELECT @cStoredProcName = RTRIM(@cStoredProcName) + ' @InMobile, @nErrNo OUTPUT,  @cErrMsg OUTPUT'    
      EXEC sp_executesql @cStoredProcName , N'@InMobile int, @nErrNo int OUTPUT,  @cErrMsg NVARCHAR(125) OUTPUT',    
         @nMobile,    
         @nErrNo OUTPUT,    
         @cErrMsg OUTPUT    
   END    
END 

GO