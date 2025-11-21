SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


    
/************************************************************************/    
/* Store procedure: rdtfnc_TM_Assist_Putaway_Demeter                    */    
/* Copyright      : LF Logistics                                        */    
/*                                                                      */    
/* Purpose: Putaway pallet to ASRS                                      */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2015-03-05 1.0  Ung      Created SOS332730                           */    
/* 2019-09-12 1.1  Ung      WMS-10452 Add override LOC                  */    
/* 2019-10-03 1.2  James    WMS-10316 Clear Case ID when esc (james01)  */    
/* 2020-08-17 1.3  YeeKung  WMS-14344 Fixed bugs (yeekung01)            */    
/* 2021-06-30 1.4  James    WMS-17016 Add Sku, Qty screen (james02)     */    
/*                          Add variabletable param                     */    
/* 2021-10-21 1.5  Chermain WMS-17638 Add ExtUpd in st1 (cc01)          */
/************************************************************************/    
    
CREATE     PROC [RDT].[rdtfnc_TM_Assist_Putaway_Demeter] (    
   @nMobile    INT,    
   @nErrNo     INT          OUTPUT,    
   @cErrMsg    NVARCHAR(20) OUTPUT    
) AS    
    
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
    
-- Misc variable    
DECLARE    
   @nTranCount          INT,    
   @bSuccess            INT,    
   @cNextTaskDetailKey  NVARCHAR( 10),    
   @cSQL                NVARCHAR( MAX),    
   @cSQLParam           NVARCHAR( MAX),     
   @cOption             NVARCHAR( 1),     
   @cUPC                NVARCHAR(30),         
   @nPQTY               INT,     
   @nMQTY               INT,     
   @nPQTY_PWY           INT,    
   @nMQTY_PWY           INT    
       
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
    
   @cFromID             NVARCHAR( 20),     
   @cFromLOC            NVARCHAR( 10),     
   @cTaskDetailKey      NVARCHAR( 10),    
   @cSKU                NVARCHAR( 20),    
   @cSKUDescr           NVARCHAR( 60),    
   @cPUOM               NVARCHAR( 10),      
   @nPUOM_Div           INT,    
   @nQTY_PWY            INT,    
   @nQTY                INT,    
    
   @cAreaKey            NVARCHAR( 10),    
   @cTTMStrategykey     NVARCHAR( 10),    
   @cTTMTaskType        NVARCHAR( 10),    
   @cSuggToLOC          NVARCHAR( 10),     
   @cPickAndDropLOC     NVARCHAR( 10),     
   @cPickMethod         NVARCHAR( 10),    
   @cPPK                NVARCHAR( 3),    
   @cMUOM_Desc          NVARCHAR( 5),    
   @cPUOM_Desc          NVARCHAR( 5),    
   @cToLOC              NVARCHAR( 10),    
    
   @cExtendedValidateSP NVARCHAR( 20),    
   @cExtendedUpdateSP   NVARCHAR( 20),    
   @cExtendedInfoSP     NVARCHAR( 20),    
   @cExtendedInfo       NVARCHAR( 20),    
   @cOverwriteToLOC     NVARCHAR( 20),    
   @cDefaultCursor      NVARCHAR( 1),    
   @cFlowThruScreen     NVARCHAR( 1),    
   @cGoToEndTask        NVARCHAR( 1),    
   @cVerifySKU          NVARCHAR( 1),     
   @cDecodeSP           NVARCHAR( 20),    
   @cMultiSKUBarcode    NVARCHAR( 1),    
   @cDefaultQTY         NVARCHAR( 1),     
   @cVerifyToID         NVARCHAR( 1),
   @cSuggestToID        NVARCHAR( 18),
   @cToID               NVARCHAR( 18),
   
   @nPABookingKey       INT,    
   @nQTY_Avail          INT,    
   @nQTY_Alloc          INT,    
   @nQTY_PMoveIn        INT,    
   @nInitSKUInPallet    INT,     
    
   @tExtValidate        VariableTable,
   @tExtInfo            VariableTable,
    
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
    
-- Load RDT.RDTMobRec    
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
    
   @cFromID          = V_ID,    
   @cFromLOC         = V_LOC,    
   @cTaskDetailKey   = V_TaskDetailKey,    
   @cSKU             = V_SKU,    
   @cSKUDescr        = V_SKUDescr,        
   @cPUOM            = V_UOM,    
   @nPUOM_Div        = V_PUOM_Div,      
   @nQTY_PWY         = V_TaskQTY,     
   @nQTY             = V_QTY,    
          
   @cAreakey            = V_String1,    
   @cTTMStrategykey     = V_String2,    
   @cTTMTaskType        = V_String3,    
   @cSuggToLOC          = V_String4,    
   @cPickAndDropLOC     = V_String5,    
   @cPickMethod         = V_String6,    
   @cPPK                = V_String7,    
   @cMUOM_Desc          = V_String8,    
   @cPUOM_Desc          = V_String9,    
   @cToLOC              = V_String10,    
   @cSuggestToID        = V_String11,
   @cToID               = V_String12,
   
   @cExtendedValidateSP = V_String20,    
   @cExtendedUpdateSP   = V_String21,    
   @cExtendedInfoSP     = V_String22,    
   @cExtendedInfo       = V_String23,    
   @cOverwriteToLOC     = V_String24,    
   @cDefaultCursor      = V_String25,    
   @cFlowThruScreen     = V_String26,    
   @cGoToEndTask        = V_String27,    
   @cVerifySKU          = V_String28,     
   @cDecodeSP           = V_String29,     
   @cMultiSKUBarcode    = V_String30,     
   @cDefaultQTY         = V_String31,     
   @cVerifyToID         = V_String32,
   
   @nPABookingKey       = V_Integer1,    
   @nQTY_Avail          = V_Integer2,        
   @nQTY_Alloc          = V_Integer3,        
   @nQTY_PMoveIn        = V_Integer4,     
   @nInitSKUInPallet    = V_Integer5,     
    
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
   @nStep_FP_FinalLOC         INT,  @nScn_FP_FinalLOC       INT,    
   @nStep_FP_LOCNotMatch      INT,  @nScn_FP_LOCNotMatch    INT,    
   @nStep_FP_NextTask         INT,  @nScn_FP_NextTask       INT,    
   @nStep_PP_SKU              INT,  @nScn_PP_SKU            INT,    
   @nStep_PP_QTY              INT,  @nScn_PP_QTY            INT,    
   @nStep_PP_ToID             INT,  @nScn_PP_ToID           INT,
   @nStep_PP_FinalLOC         INT,  @nScn_PP_FinalLOC       INT,    
   @nStep_PP_LOCNotMatch      INT,  @nScn_PP_LOCNotMatch    INT,    
   @nStep_PP_MultiSKU         INT,  @nScn_PP_MultiSKU       INT    
    
SELECT    
   @nStep_FP_FinalLOC         = 1,  @nScn_FP_FinalLOC       = 4070,    
   @nStep_FP_LOCNotMatch      = 2,  @nScn_FP_LOCNotMatch    = 4071,    
   @nStep_FP_NextTask         = 3,  @nScn_FP_NextTask       = 4072,    
   @nStep_PP_SKU              = 4,  @nScn_PP_SKU            = 4073,    
   @nStep_PP_QTY              = 5,  @nScn_PP_QTY            = 4074,    
   @nStep_PP_ToID             = 6,  @nScn_PP_ToID           = 4075,
   @nStep_PP_FinalLOC         = 7,  @nScn_PP_FinalLOC       = 4076,    
   @nStep_PP_LOCNotMatch      = 8,  @nScn_PP_LOCNotMatch    = 4077,    
   @nStep_PP_MultiSKU         = 9,  @nScn_PP_MultiSKU       = 3570    
    
-- Redirect to respective screen    
IF @nFunc = 1815    
BEGIN    
   IF @nStep = 0 GOTO Step_Start          -- Menu. Func = 1815    
    
   -- Full pallet    
   IF @nStep = 1 GOTO Step_FP_FinalLOC    -- Scn = 4070. Final LOC    
   IF @nStep = 2 GOTO Step_FP_LOCNotMatch -- Scn = 4071. LOC not match    
   IF @nStep = 3 GOTO Step_FP_NextTask    -- Scn = 4072. Message. Next task type    
    
   -- Partial pallet    
   IF @nStep = 4 GOTO Step_PP_SKU         -- Scn = 4073. SKU    
   IF @nStep = 5 GOTO Step_PP_QTY         -- Scn = 4074. QTY    
   IF @nStep = 6 GOTO Step_PP_ToID        -- Scn = 4075. Final LOC    
   IF @nStep = 7 GOTO Step_PP_FinalLOC    -- Scn = 4076. Final LOC    
   IF @nStep = 8 GOTO Step_PP_LOCNotMatch -- Scn = 4077. LOC not match    
   IF @nStep = 9 GOTO Step_PP_MultiSKU    -- Scn = 3570. Multi SKU selection    
END    
RETURN -- Do nothing if incorrect step    
    
    
/********************************************************************************    
Step 0. Initialize    
********************************************************************************/    
Step_Start:    
BEGIN    
   -- Get task manager data    
   SET @cTaskDetailKey  = @cOutField06    
   SET @cAreaKey        = @cOutField07    
   SET @cTTMStrategyKey = @cOutField08    
    
   SET @nPABookingKey = 0    
   SET @cPickAndDropLOC = ''    
    
   -- Get task info    
   SELECT    
      @cTTMTaskType = TaskType,    
      @cStorerKey   = Storerkey,    
      @cFromID      = FromID,    
      @cFromLOC     = FromLOC,    
      @cSKU         = SKU,     
      @nQTY         = QTY,     
      --@cSuggToLOC   = ToLOC,
	  @cSuggToLOC   = (
						SELECT TOP 1 LOC.Loc
						FROM dbo.TaskDetail WITH (NOLOCK)
						JOIN LOTxLOCxID WITH (NOLOCK)
						ON LOTxLOCxID.Id = TaskDetail.FromID
						AND LOTxLOCxID.StorerKey = TaskDetail.Storerkey
						JOIN LotAttribute WITH (NOLOCK) 
						ON (LOTxLOCxID.Lot = LotAttribute.lot)
						JOIN PutawayZone WITH (NOLOCK)
						ON PutawayZone.Pallet_type = LotAttribute.Lottable01
						JOIN LOC WITH (NOLOCK) 
						ON PutawayZone.PutawayZone = LOC.PutawayZone
						AND PutawayZone.facility = LOC.Facility
						JOIN PALLET WITH (NOLOCK)
						on PALLET.PalletKey = LOTxLOCxID.Id
						JOIN dbo.TaskDetail TaskDetail1 WITH (NOLOCK)
						ON TaskDetail.FromID = LOTxLOCxID.Id
						AND TaskDetail1.TaskDetailKey = @cTaskDetailKey
						AND NOT EXISTS (SELECT 1 FROM LOTxLOCxID (NOLOCK) LOTxLOCxID1
						WHERE LOC.Loc = LOTxLOCxID1.Loc)
					    ORDER BY Loc.WeightCapacity 
					   ),	
      @cPickMethod  = PickMethod    
   FROM dbo.TaskDetail WITH (NOLOCK)    
   WHERE TaskDetailKey = @cTaskDetailKey    
    
   -- Get storer configure    
   SET @cDefaultCursor = rdt.rdtGetConfig( @nFunc, 'DefaultCursor', @cStorerKey)    
   -- flow through step 1 (@cflowthruscreen)    
   -- While scan palletid and need go back task assisted manager screen (@cGoToEndTask)    
   SET @cFlowThruScreen = rdt.RDTGetConfig( @nFunc, 'FlowThruScreen', @cStorerKey)    
   SET @cGoToEndTask = rdt.RDTGetConfig( @nFunc, 'GoToEndTask', @cStorerKey)    
    
   SET @cDecodeSP = rdt.RDTGetConfig( @nFunc, 'DecodeSP', @cStorerKey)    
   IF @cDecodeSP = '0'    
      SET @cDecodeSP = ''    
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)    
   IF @cExtendedValidateSP = '0'    
      SET @cExtendedValidateSP = ''    
   SET @cOverwriteToLOC = rdt.rdtGetConfig( @nFunc, 'OverwriteToLOC', @cStorerKey)    
   IF @cOverwriteToLOC = '0'    
      SET @cOverwriteToLOC = ''    
      
   --(cc01)
   SET @cExtendedUpdateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)      
   IF @cExtendedUpdateSP = '0'      
      SET @cExtendedUpdateSP = ''        

   SET @cVerifySKU = rdt.rdtGetConfig( @nFunc, 'VerifySKU', @cStorerKey)
   
   SET @cVerifyToID = rdt.rdtGetConfig( @nFunc, 'VerifyToID', @cStorerKey)   

   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)    
   IF @cExtendedInfoSP = '0'    
      SET @cExtendedInfoSP = ''    

   SET @cDefaultQTY = rdt.rdtGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)
   
   -- EventLog    
   EXEC RDT.rdt_STD_EventLog    
      @cActionType = '1', -- Sign-in    
      @cUserID     = @cUserName,    
      @nMobileNo   = @nMobile,    
      @nFunctionID = @nFunc,    
      @cFacility   = @cFacility,    
      @cStorerKey  = @cStorerkey    
    
   -- Full pallet putaway    
   IF @cPickMethod = 'FP'    
   BEGIN    
      IF @cVerifySKU = '1'
      BEGIN
         -- Get task    
         SET @cSKU = ''    
         SET @nQTY_PWY = 0    
         SELECT TOP 1    
            @cSKU = SKU,     
            @nQTY_PWY = SUM( QTY - QTYAllocated - QTYPicked)    
         FROM dbo.LOTxLOCxID WITH (NOLOCK)    
         WHERE LOC = @cFromLOC    
            AND ID = @cFromID    
            AND (QTY - QTYAllocated - QTYPicked) > 0    
            AND StorerKey = @cStorerKey    
         GROUP BY SKU    
         HAVING SUM( QTY - QTYAllocated - QTYPicked) > 0    
    
         SET @nInitSKUInPallet = @@ROWCOUNT    
    
         -- Go to SKU screen    
         IF @nInitSKUInPallet > 1 OR @cVerifySKU = '1'    
         BEGIN    
            SET @cOutField01 = @cFromLOC    
            SET @cOutField02 = @cFromID
            SET @cOutField03 = @cSKU    
            SET @cOutField04 = '' -- SKU    

            IF @cExtendedInfoSP <> ''    
            BEGIN    
               IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
               BEGIN    
                  SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
                     ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cSKU, @nQTY, @cToLOC, @tExtInfo, ' +     
                     ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
                  SET @cSQLParam =    
                     '@nMobile         INT,           ' +    
                     '@nFunc           INT,           ' +    
                     '@cLangCode       NVARCHAR( 3),  ' +    
                     '@nStep           INT,           ' +    
                     '@nInputKey     INT,           ' +    
                     '@cTaskdetailKey  NVARCHAR( 10), ' +    
                     '@cSKU            NVARCHAR( 20), ' +    
                     '@nQTY            INT,           ' +    
                     '@cToLOC          NVARCHAR( 10), ' +    
                     '@tExtInfo        VariableTable READONLY, ' +    
                     '@cExtendedInfo   NVARCHAR( 20) OUTPUT,   ' +
                     '@nErrNo          INT OUTPUT,    ' +    
                     '@cErrMsg         NVARCHAR( 20) OUTPUT '    
    
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cSKU, @nQTY, @cToLOC, @tExtInfo,     
                     @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
                  IF @nErrNo <> 0    
                     GOTO Quit    
               END    
            END    
         
            SET @nScn  = @nScn_PP_SKU    
            SET @nStep = @nStep_PP_SKU    
    
            GOTO Quit    
         END    
      END
      
      -- Suggest LOC    
      IF @cSuggToLOC = ''    
      BEGIN    
         -- Get suggest LOC    
         EXEC rdt.rdt_TM_Assist_Putaway_GetSuggestLOC @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility    
            ,@cTaskDetailKey    
            ,@cFromLOC    
            ,@cFromID    
            ,@cSuggToLOC      OUTPUT    
            ,@cPickAndDropLOC OUTPUT    
            ,@nPABookingKey   OUTPUT    
            ,@nErrNo          OUTPUT    
            ,@cErrMsg         OUTPUT    
         IF @nErrNo = -1 -- No suggested LOC    
         SET @nErrNo = 0    
      END    
    
      -- Prepare next screen var    
      SET @cOutField01 = @cFromID    
      SET @cOutField02 = CASE WHEN @cPickAndDropLOC = '' THEN @cSuggToLOC ELSE @cPickAndDropLOC END    
      SET @cOutField03 = '' -- FinalLOC    
    
      -- Set the entry point    
      SET @nScn  = @nScn_FP_FinalLOC    
      SET @nStep = @nStep_FP_FinalLOC    
   END    
    
   -- Partial pallet putaway    
   IF @cPickMethod = 'PP'    
   BEGIN    
      -- Get task    
      SET @cSKU = ''    
      SET @nQTY_PWY = 0    
      SELECT TOP 1    
         @cSKU = SKU,     
         @nQTY_PWY = SUM( QTY - QTYAllocated - QTYPicked)    
      FROM dbo.LOTxLOCxID WITH (NOLOCK)    
      WHERE LOC = @cFromLOC    
         AND ID = @cFromID    
         AND (QTY - QTYAllocated - QTYPicked) > 0    
         AND StorerKey = @cStorerKey    
      GROUP BY SKU    
      HAVING SUM( QTY - QTYAllocated - QTYPicked) > 0    
    
      SET @nInitSKUInPallet = @@ROWCOUNT    
    
      -- Go to SKU screen    
      IF @nInitSKUInPallet > 1 OR @cVerifySKU = '1'    
      BEGIN    
         SET @cOutField01 = @cFromLOC    
         SET @cOutField02 = @cFromID    
         SET @cOutField03 = @cSKU    
         SET @cOutField04 = '' -- SKU         

         IF @cExtendedInfoSP <> ''    
         BEGIN    
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')    
            BEGIN    
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +    
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cSKU, @nQTY, @cToLOC, @tExtInfo, ' +     
                  ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'    
               SET @cSQLParam =    
                  '@nMobile         INT,           ' +    
                  '@nFunc           INT,           ' +    
                  '@cLangCode       NVARCHAR( 3),  ' +    
                  '@nStep           INT,           ' +    
                  '@nInputKey       INT,           ' +    
                  '@cTaskdetailKey  NVARCHAR( 10), ' +    
                  '@cSKU            NVARCHAR( 20), ' +    
                  '@nQTY            INT,         ' +    
                  '@cToLOC          NVARCHAR( 10), ' +    
                  '@tExtInfo        VariableTable READONLY, ' +    
                  '@cExtendedInfo   NVARCHAR( 20) OUTPUT,   ' +
                  '@nErrNo          INT OUTPUT,    ' +    
                  '@cErrMsg         NVARCHAR( 20) OUTPUT '    
    
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cSKU, @nQTY, @cToLOC, @tExtInfo,     
                  @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
               IF @nErrNo <> 0    
                  GOTO Quit    
            END    
         END    
         
         SET @nScn  = @nScn_PP_SKU    
         SET @nStep = @nStep_PP_SKU    
    
         GOTO Quit    
      END    
    
      -- Go to QTY screen    
      BEGIN    
         -- Get SKU info    
         SELECT    
            @cSKUDescr = SKU.DescR,    
            @cPPK =    
               CASE WHEN SKU.PrePackIndicator = '2'    
                  THEN CAST( SKU.PackQtyIndicator AS NVARCHAR( 3))    
                  ELSE ''    
               END,    
            @cMUOM_Desc = Pack.PackUOM3,    
            @cPUOM_Desc =    
               CASE @cPUOM    
                  WHEN '2' THEN Pack.PackUOM1 -- Case    
                  WHEN '3' THEN Pack.PackUOM2 -- Inner pack    
                  WHEN '6' THEN Pack.PackUOM3 -- Master unit    
                  WHEN '1' THEN Pack.PackUOM4 -- Pallet    
                  WHEN '4' THEN Pack.PackUOM8 -- Other unit 1    
                  WHEN '5' THEN Pack.PackUOM9 -- Other unit 2    
               END,    
            @nPUOM_Div = CAST(    
               CASE @cPUOM    
                  WHEN '2' THEN Pack.CaseCNT    
                  WHEN '3' THEN Pack.InnerPack    
                  WHEN '6' THEN Pack.QTY    
                  WHEN '1' THEN Pack.Pallet    
                  WHEN '4' THEN Pack.OtherUnit1    
                  WHEN '5' THEN Pack.OtherUnit2    
               END AS INT)    
         FROM dbo.SKU WITH (NOLOCK)    
            JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)    
         WHERE SKU.StorerKey = @cStorerKey    
            AND SKU.SKU = @cSKU    
                
         -- Default move QTY as available QTY    
         IF @cDefaultQTY = '1'    
            SET @nQTY = @nQTY_PWY    
    
         -- Convert to prefer UOM QTY    
         IF @cPUOM = '6' OR -- When preferred UOM = master unit    
            @nPUOM_Div = 0 -- UOM not setup    
         BEGIN    
            SET @cPUOM_Desc = ''    
            SET @nPQTY_PWY = 0    
            SET @nMQTY_PWY = @nQTY_PWY    
            SET @nPQTY = 0    
            SET @nMQTY = @nQTY    
            SET @cFieldAttr12 = 'O' -- @nPQTY       
         END    
         ELSE    
         BEGIN    
            SET @nPQTY_PWY = @nQTY_PWY / @nPUOM_Div -- Calc QTY in preferred UOM    
            SET @nMQTY_PWY = @nQTY_PWY % @nPUOM_Div -- Calc the remaining in master unit    
            SET @nPQTY = @nQTY / @nPUOM_Div    
            SET @nMQTY = @nQTY % @nPUOM_Div    
            SET @cFieldAttr12 = '' -- @nPQTY     
         END    
    
         -- Prep next screen var    
         SET @cOutField01 = @cPPK    
         SET @cOutField02 = @cSKU    
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1    
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2    
         SET @cOutField05 = '' -- Lottables    
         SET @cOutField06 = '' -- Lottables    
         SET @cOutField07 = '' -- Lottables    
         SET @cOutField08 = '' -- Lottables    
         SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6))    
         IF @cFieldAttr12 = '' -- PQTY enable    
         BEGIN    
            SET @cOutField10 = @cPUOM_Desc    
            SET @cOutField11 = CAST( @nPQTY_PWY AS NVARCHAR( 5))    
            SET @cOutField12 = CAST( @nPQTY AS NVARCHAR( 5))    
         END    
         ELSE    
         BEGIN    
            SET @cOutField10 = '' --@cPUOM_Desc    
            SET @cOutField11 = '' --@nPQTY_PWY    
            SET @cOutField12 = '' --@nPQTY    
         END    
         SET @cOutField13 = @cMUOM_Desc     
         SET @cOutField14 = CAST( @nMQTY_PWY AS NVARCHAR( 5))    
         SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 5))    
    
         SET @nScn  = @nScn_PP_QTY    
         SET @nStep = @nStep_PP_QTY    
      END    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 1. Screen = 4070    
   ID           (Field01)    
   SUGGEST LOC  (Field02)    
   FINAL LOC    (Field03, input)    
********************************************************************************/    
Step_FP_FinalLOC:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cToLOC = @cInField03    
    
      -- Check blank    
      IF @cToLOC = ''    
      BEGIN    
         SET @nErrNo = 51951    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC needed    
         GOTO Quit    
      END    
    
      -- Check LOC valid    
      IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE Facility = @cFacility AND LOC = @cToLOC)    
      BEGIN    
         SET @nErrNo = 51952    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC    
         SET @cOutField03 = '' -- FinalLOC    
         GOTO Quit    
      END    
    
      -- Check if suggested LOC match    
      IF (@cToLOC <> @cSuggToLOC AND @cPickAndDropLOC = '') OR      -- Not match suggested LOC    
         (@cToLOC <> @cPickAndDropLOC AND @cPickAndDropLOC <> '')   -- Not match PND LOC    
      BEGIN    
         IF @cOverwriteToLOC = '1'    
         BEGIN    
            SET @nErrNo = 51953    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC Not Match    
            SET @cOutField03 = '' -- FinalLOC    
            GOTO Quit    
         END    
    
         ELSE IF @cOverwriteToLOC = '2'    
         BEGIN    
            -- Prepare next screen var    
            SET @cOutField01 = '' -- Option    
    
            -- Go to LOC not match screen    
            SET @nScn = @nScn_FP_LOCNotMatch    
            SET @nStep = @nStep_FP_LOCNotMatch    
    
            GOTO Quit    
         END    
      END    
    
      -- Extended validate    
      IF @cExtendedValidateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cSKU, @nQTY, @cToLOC, @tExtValidate, ' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +    
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cSKU            NVARCHAR( 20), ' +    
               '@nQTY            INT,           ' +    
               '@cToLOC          NVARCHAR( 10), ' +    
               '@tExtValidate    VariableTable READONLY, ' +    
               '@nErrNo          INT OUTPUT,    ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cSKU, @nQTY, @cToLOC, @tExtValidate,     
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
         END    
      END    
    
      -- Confirm task    
      EXEC rdt.rdt_TM_Assist_Putaway_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility    
         ,@cTaskDetailKey    
         ,@cFromLOC    
         ,@cFromID    
         ,@cSuggToLOC    
         ,@cPickAndDropLOC    
         ,@cToLOC    
         ,@nErrNo    OUTPUT    
         ,@cErrMsg   OUTPUT    
      IF @nErrNo <> 0    
         GOTO Quit    
    
      -- Get next task    
      SET @cNextTaskDetailKey = ''    
      SELECT TOP 1    
         @cNextTaskDetailKey = TaskDetailKey,    
         @cTTMTasktype = TaskType    
      FROM dbo.TaskDetail WITH (NOLOCK)    
         JOIN CodeLKUP WITH (NOLOCK) ON (ListName = 'RDTAstTask' AND Code = TaskType AND Code2 = @cFacility)    
      WHERE FromID = @cFromID    
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
            @cStorerKey  = @cStorerKey    
    
         -- Go back to assist task manager    
         SET @nFunc = 1814    
         SET @nScn = 4060    
         SET @nStep = 1    
    
         SET @cOutField01 = '' -- From ID    
         SET @cOutField02 = '' -- Case ID    
      END    
    
      -- Have next task    
      IF @cNextTaskDetailKey <> ''    
      BEGIN    
         SET @cTaskDetailKey = @cNextTaskDetailKey    
    
         -- Prepare next screen var    
         SET @cOutField01 = @cTTMTasktype    
    
         IF @cFlowThruScreen='1'  --(yeekung01)    
         BEGIN    
            IF @cGoToEndTask='1'    
               SET @nInputKey=0    
    
            GOTO Step_FP_NextTask    
         END    
    
         -- Go to next task    
         SET @nScn  = @nScn_FP_NextTask    --(yeekung01)    
         SET @nStep = @nStep_FP_NextTask   --(yeekung01)    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Unlock current session suggested LOC    
      IF @nPABookingKey <> 0    
      BEGIN    
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'    
            ,'' --FromLOC    
            ,'' --FromID    
            ,'' --cSuggLOC    
            ,'' --Storer    
            ,@nErrNo  OUTPUT    
            ,@cErrMsg OUTPUT    
            ,@nPABookingKey = @nPABookingKey OUTPUT    
         IF @nErrNo <> 0    
            GOTO Quit    
  
         SET @nPABookingKey = 0    
      END    
      
      -- Extended Update  --(cc01)
      IF @cExtendedUpdateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT'  
            SET @cSQLParam =  
               '@nMobile         INT,           ' +  
               '@nFunc           INT,           ' +  
               '@cLangCode       NVARCHAR( 3),  ' +  
               '@nStep           INT,           ' +  
               '@nInputKey       INT,           ' +   
               '@cTaskdetailKey  NVARCHAR( 10), ' +  
               '@cToLOC          NVARCHAR( 10), ' +  
               '@nErrNo          INT OUTPUT,    ' +  
               '@cErrMsg         NVARCHAR( 20) OUTPUT '  
     
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cToLOC, @nErrNo OUTPUT, @cErrMsg OUTPUT  
     
            IF @nErrNo <> 0  
               GOTO Quit  
         END  
      END  
    
      -- EventLog    
      EXEC RDT.rdt_STD_EventLog    
         @cActionType = '9', -- Sign-out    
         @cUserID     = @cUserName,    
         @nMobileNo   = @nMobile,    
         @nFunctionID = @nFunc,    
         @cFacility   = @cFacility,    
         @cStorerKey  = @cStorerKey    
    
      -- Go back to assist task manager    
      SET @nFunc = 1814    
      SET @nScn = 4060    
      SET @nStep = 1    
    
      IF ISNULL(@cDefaultCursor,'')<>0  --(yeekung01)    
         EXEC rdt.rdtSetFocusField @nMobile, @cDefaultCursor    
      ELSE    
         EXEC rdt.rdtSetFocusField @nMobile, 2    
    
      SET @cOutField01 = ''  -- From ID    
      SET @cOutField02 = ''  -- Case ID    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 2. Scn = 4071.    
   LOC not match. Proceed?    
   1 = YES    
   2 = NO    
   OPTION (Input, Field01)    
********************************************************************************/    
Step_FP_LOCNotMatch:    
BEGIN    
   IF @nInputKey = 1    
   BEGIN    
      SET @cOption = @cInField01    
    
      -- Check blank    
      IF @cOption = ''    
      BEGIN    
         SET @nErrNo = 51954    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req    
         GOTO Quit    
      END    
    
      -- Check optin valid    
      IF @cOption NOT IN ('1', '2')    
      BEGIN    
         SET @nErrNo = 51955    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option    
         SET @cOutField01 = ''    
         GOTO Quit    
      END    
    
      IF @cOption = '1' -- YES    
      BEGIN    
         -- Confirm task    
         EXEC rdt.rdt_TM_Assist_Putaway_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility    
            ,@cTaskDetailKey    
            ,@cFromLOC    
            ,@cFromID    
            ,@cSuggToLOC    
            ,@cPickAndDropLOC    
            ,@cToLOC    
            ,@nErrNo    OUTPUT    
            ,@cErrMsg   OUTPUT    
         IF @nErrNo <> 0    
            GOTO Quit    
    
         -- Get next task    
         SET @cNextTaskDetailKey = ''    
         SELECT TOP 1    
            @cNextTaskDetailKey = TaskDetailKey,    
            @cTTMTasktype = TaskType    
         FROM dbo.TaskDetail WITH (NOLOCK)    
            JOIN CodeLKUP WITH (NOLOCK) ON (ListName = 'RDTAstTask' AND Code = TaskType AND Code2 = @cFacility)    
         WHERE FromID = @cFromID    
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
               @cStorerKey  = @cStorerKey    
    
            -- Go back to assist task manager    
            SET @nFunc = 1814    
            SET @nScn = 4060    
            SET @nStep = 1    
    
            SET @cOutField01 = '' -- From ID    
            SET @cOutField02 = '' -- Case ID    
         END    
    
         -- Have next task    
         IF @cNextTaskDetailKey <> ''    
         BEGIN    
            SET @cTaskDetailKey = @cNextTaskDetailKey    
    
            -- Prepare next screen var    
            SET @cOutField01 = @cTTMTasktype    
    
            -- Go to next task    
 SET @nScn  = @nScn_FP_NextTask    
            SET @nStep = @nStep_FP_NextTask    
         END    
      END    
    
      IF @cOption = '2' -- No    
      BEGIN    
         -- Prepare next screen var    
         SET @cOutField01 = @cFromID    
         SET @cOutField02 = CASE WHEN @cPickAndDropLOC = '' THEN @cSuggToLOC ELSE @cPickAndDropLOC END    
         SET @cOutField03 = ''    
    
         -- Go to Suggest LOC screen    
         SET @nScn  = @nScn_FP_FinalLOC    
         SET @nStep = @nStep_FP_FinalLOC    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Prepare next screen var    
      SET @cOutField01 = @cFromID    
      SET @cOutField02 = CASE WHEN @cPickAndDropLOC = '' THEN @cSuggToLOC ELSE @cPickAndDropLOC END    
      SET @cOutField03 = ''    
    
      -- Go to Suggest LOC screen    
      SET @nScn  = @nScn_FP_FinalLOC    
      SET @nStep = @nStep_FP_FinalLOC    
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 3. Screen 4072. Next task    
   Next task type (field01)    
********************************************************************************/    
Step_FP_NextTask:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
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
         SET @nErrNo = 51956    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskFncErr    
         GOTO Quit    
      END    
    
      -- Check if screen setup    
      SELECT TOP 1 @nToScn = Scn FROM RDT.RDTScn WITH (NOLOCK) WHERE Func = @nToFunc ORDER BY Scn    
      IF @nToScn = 0    
      BEGIN    
         SET @nErrNo = 51957    
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
         @cStorerKey  = @cStorerKey    
    
      SET @cOutField06 = @cTaskDetailKey    
      SET @cOutField07 = @cAreaKey    
      SET @cOutField08 = @cTTMStrategykey    
    
      SET @nFunc = @nToFunc    
      SET @nScn  = @nToScn    
      SET @nStep = @nToStep    
    
      IF @cTTMTaskType IN ('ASTPA')    
         GOTO Step_Start    
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
         @cStorerKey  = @cStorerKey    
    
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
Step 4. scn = 4073. SKU screen    
   FromLOC (field01)    
   FromID  (field02)    
   SKU     (field03, input)    
********************************************************************************/    
Step_PP_SKU:    
BEGIN    
   IF @nInputKey = 1 -- ENTER        
   BEGIN        
      DECLARE @cBarcode NVARCHAR(60)        
        
      -- Screen mapping        
      SET @cBarcode = @cInField04        
      SET @cUPC = LEFT( @cInField04, 30)        
        
      -- Skip task        
      IF @cBarcode = '' OR @cBarcode IS NULL        
      BEGIN        
         SET @nErrNo = 51958    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Needed SKU/UPC    
         GOTO Step_PP_SKU_Fail        
      END        
    
      -- Decode          
      IF @cDecodeSP <> ''    
      BEGIN    
         DECLARE @cDecodeSKU  NVARCHAR( 20)    
         DECLARE @nDecodeQTY  INT    
    
         SET @cDecodeSKU = @cSKU    
         SET @nDecodeQTY = @nQTY    
    
         -- Standard decode    
         IF @cDecodeSP = '1'    
         BEGIN    
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,    
               @cUPC    = @cUPC     OUTPUT,    
               @nQTY    = @nQTY     OUTPUT,    
               @nErrNo  = @nErrNo   OUTPUT,    
               @cErrMsg = @cErrMsg  OUTPUT,    
               @cType   = 'UPC'    
         END    
    
         -- Customize decode    
         ELSE IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDecodeSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, ' +    
               ' @cTaskdetailKey, @cBarcode, @cUPC OUTPUT, @nQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    
            SET @cSQLParam =    
               ' @nMobile        INT,           ' +    
               ' @nFunc          INT,           ' +    
               ' @cLangCode      NVARCHAR( 3),  ' +    
               ' @nStep          INT,           ' +    
               ' @nInputKey      INT,           ' +    
               ' @cStorerKey     NVARCHAR( 15), ' +    
               ' @cFacility      NVARCHAR( 5),  ' +    
               ' @cTaskdetailKey NVARCHAR( 10),  ' +    
               ' @cBarcode       NVARCHAR( 60),  ' +    
               ' @cUPC           NVARCHAR( 30)  OUTPUT, ' +    
               ' @nQTY           INT            OUTPUT, ' +    
               ' @nErrNo         INT            OUTPUT, ' +    
               ' @cErrMsg        NVARCHAR( 20)  OUTPUT'    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility,     
               @cTaskdetailKey, @cBarcode,    
               @cUPC OUTPUT, @nQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Step_PP_SKU_Fail    
         END    
      END    
        
      -- Get SKU count    
      DECLARE @nSKUCnt INT        
      EXEC RDT.rdt_GetSKUCNT        
          @cStorerKey  = @cStorerKey        
         ,@cSKU        = @cUPC        
         ,@nSKUCnt     = @nSKUCnt   OUTPUT        
         ,@bSuccess    = @bSuccess  OUTPUT        
         ,@nErr        = @nErrNo    OUTPUT        
         ,@cErrMsg     = @cErrMsg   OUTPUT        
        
      -- Check SKU valid        
      IF @nSKUCnt = 0        
      BEGIN        
         SET @nErrNo = 51959        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU        
         GOTO Step_PP_SKU_Fail        
      END        
        
      -- Validate barcode return multiple SKU    
      IF @nSKUCnt > 1    
      BEGIN    
         IF @cMultiSKUBarcode IN ('1', '2')    
         BEGIN    
            EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,    
               @cInField01 OUTPUT,  @cOutField01 OUTPUT,    
               @cInField02 OUTPUT,  @cOutField02 OUTPUT,    
               @cInField03 OUTPUT,  @cOutField03 OUTPUT,    
               @cInField04 OUTPUT,  @cOutField04 OUTPUT,    
               @cInField05 OUTPUT,  @cOutField05 OUTPUT,    
               @cInField06 OUTPUT,  @cOutField06 OUTPUT,    
               @cInField07 OUTPUT,  @cOutField07 OUTPUT,    
               @cInField08 OUTPUT,  @cOutField08 OUTPUT,    
               @cInField09 OUTPUT,  @cOutField09 OUTPUT,    
               @cInField10 OUTPUT,  @cOutField10 OUTPUT,    
               @cInField11 OUTPUT,  @cOutField11 OUTPUT,    
               @cInField12 OUTPUT,  @cOutField12 OUTPUT,    
               @cInField13 OUTPUT,  @cOutField13 OUTPUT,    
               @cInField14 OUTPUT,  @cOutField14 OUTPUT,    
               @cInField15 OUTPUT,  @cOutField15 OUTPUT,    
               'POPULATE',    
               @cMultiSKUBarcode,    
               @cStorerKey,    
               @cSKU         OUTPUT,    
               @nErrNo       OUTPUT,    
               @cErrMsg      OUTPUT,    
               'LOTXLOCXID.ID',    -- DocType    
               @cFromID    
    
            IF @nErrNo = 0 -- Populate multi SKU screen    
            BEGIN    
               -- Go to Multi SKU screen    
               SET @nScn = @nScn_PP_MultiSKU    
               SET @nStep = @nStep_PP_MultiSKU    
               GOTO Quit    
            END    
            IF @nErrNo = -1 -- Found in Doc, skip multi SKU screen    
               SET @nErrNo = 0    
         END    
         ELSE    
         BEGIN    
            SET @nErrNo = 51960    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SameBarCodeSKU    
            GOTO Step_PP_SKU_Fail    
         END    
      END    
              
      -- Get SKU        
      EXEC rdt.rdt_GetSKU        
          @cStorerKey  = @cStorerKey        
         ,@cSKU        = @cUPC      OUTPUT        
         ,@bSuccess    = @bSuccess  OUTPUT        
         ,@nErr        = @nErrNo    OUTPUT        
         ,@cErrMsg     = @cErrMsg   OUTPUT        
          
      SET @cSKU = @cUPC    

      -- Validate SKU  
      IF @cSKU <> @cOutField03  
      BEGIN  
         SET @nErrNo = 51961  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong SKU  
         GOTO Step_PP_SKU_Fail  
      END  
            
      -- Get QTY    
      SELECT @nQTY_PWY = SUM( QTY - QTYAllocated - QTYPicked)    
      FROM dbo.LOTxLOCxID WITH (NOLOCK)    
      WHERE LOC = @cFromLOC    
         AND ID = @cFromID    
         AND (QTY - QTYAllocated - QTYPicked) > 0    
         AND StorerKey = @cStorerKey    
         AND SKU = @cSKU    
    
      -- Check SKU in pallet    
      IF @nQTY_PWY = 0    
      BEGIN    
         SET @nErrNo = 51962        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No QTY to move    
         GOTO Step_PP_SKU_Fail        
      END          
    
      -- Default QTY as available QTY    
      IF @cDefaultQTY = '1'    
         SET @nQTY = @nQTY_PWY    
      ELSE    
         SET @nQTY = 0    
    
      -- Convert to prefer UOM QTY    
      IF @cPUOM = '6' OR -- When preferred UOM = master unit    
         @nPUOM_Div = 0 -- UOM not setup    
      BEGIN    
         SET @cPUOM_Desc = ''    
         SET @nPQTY_PWY = 0    
         SET @nMQTY_PWY = @nQTY_PWY    
         SET @nPQTY = 0    
         SET @nMQTY = @nQTY    
         SET @cFieldAttr12 = 'O' -- @nPQTY       
      END    
      ELSE    
      BEGIN    
         SET @nPQTY_PWY = @nQTY_PWY / @nPUOM_Div -- Calc QTY in preferred UOM    
         SET @nMQTY_PWY = @nQTY_PWY % @nPUOM_Div -- Calc the remaining in master unit    
         SET @nPQTY = @nQTY / @nPUOM_Div    
         SET @nMQTY = @nQTY % @nPUOM_Div    
         SET @cFieldAttr12 = '' -- @nPQTY     
      END    
    
      -- Prep next screen var    
      SET @cOutField01 = @cPPK    
      SET @cOutField02 = @cSKU    
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1    
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2    
      SET @cOutField05 = '' -- Lottables    
      SET @cOutField06 = '' -- Lottables    
      SET @cOutField07 = '' -- Lottables    
      SET @cOutField08 = '' -- Lottables    
      SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6))    
      IF @cFieldAttr12 = '' -- PQTY enable    
      BEGIN    
         SET @cOutField10 = @cPUOM_Desc    
         SET @cOutField11 = CAST( @nPQTY_PWY AS NVARCHAR( 5))    
         SET @cOutField12 = CAST( @nPQTY AS NVARCHAR( 5))    
      END    
      ELSE    
      BEGIN    
         SET @cOutField10 = '' --@cPUOM_Desc    
         SET @cOutField11 = '' --@nPQTY_PWY    
         SET @cOutField12 = '' --@nPQTY    
      END    
      SET @cOutField13 = @cMUOM_Desc     
      SET @cOutField14 = CAST( @nMQTY_PWY AS NVARCHAR( 5))    
      SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 5))    
    
      SET @nScn  = @nScn_PP_QTY    
      SET @nStep = @nStep_PP_QTY     
   END        
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Go back to assist task manager    
      SET @nFunc = 1814    
      SET @nScn = 4060    
      SET @nStep = 1    
    
      IF @cFromID <> ''    
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- From ID    
      ELSE    
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Case ID    
    
      SET @cOutField01 = ''  -- From ID    
      SET @cOutField02 = ''  -- Case ID    
   END    
   GOTO Quit    
    
   Step_PP_SKU_Fail:        
   BEGIN        
      SET @cOutField04 = '' -- SKU        
   END     
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 5. Scn = 4074. QTY screen    
   PPK       (field01)    
   SKU       (field02)    
   Desc1     (field03)    
   Desc2     (field04)    
   Lottable  (field05)    
   Lottable  (field06)    
   Lottable  (field07)    
   Lottable  (field08)    
   UOM ratio (field09)    
   UOM desc  (field10, field11)    
   QTY AVL   (field11, field14)    
   QTY MV    (field12, field15, input)    
********************************************************************************/    
Step_PP_QTY:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      DECLARE @cPQTY NVARCHAR( 5)    
      DECLARE @cMQTY NVARCHAR( 5)    
    
      -- Screen mapping        
      SET @cPQTY = CASE WHEN @cFieldAttr12 = 'O' THEN @cOutField12 ELSE @cInField12 END        
      SET @cMQTY = @cInField15        
        
      -- Retain QTY keyed-in        
      SET @cOutField12 = CASE WHEN @cFieldAttr12 = 'O' THEN @cOutField12 ELSE @cInField12 END -- PQTY        
      SET @cOutField15 = @cInField15       
    
      -- Validate PQTY    
      IF ISNULL(@cPQTY, '') = '' SET @cPQTY = '0' -- Blank taken as zero    
      IF RDT.rdtIsValidQTY( @cPQTY, 0) = 0    
      BEGIN    
         SET @nErrNo = 51963    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY    
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- PQTY    
         GOTO Quit    
      END    
    
      -- Validate MQTY    
      IF ISNULL(@cMQTY, '')  = '' SET @cMQTY  = '0' -- Blank taken as zero    
      IF RDT.rdtIsValidQTY( @cMQTY, 0) = 0    
      BEGIN    
         SET @nErrNo = 51964    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY    
         EXEC rdt.rdtSetFocusField @nMobile, 15 -- MQTY    
         GOTO Quit    
      END    
    
      -- Calc total QTY in master UOM    
      SET @nPQTY = CAST( @cPQTY AS INT)    
      SET @nMQTY = CAST( @cMQTY AS INT)    
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM    
    
      SET @nQTY = @nQTY + @nMQTY    
    
      -- Validate QTY    
      IF @nQTY = 0    
      BEGIN    
         SET @nErrNo = 51965    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY needed    
         GOTO Quit    
      END    
    
      -- Validate QTY to move more than QTY avail    
      IF @nQTY > @nQTY_PWY    
      BEGIN    
         SET @nErrNo = 51966    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYAVL NotEnuf    
         GOTO Quit    
      END    
    
      -- Suggest LOC    
      IF @cSuggToLOC = ''    
      BEGIN    
         -- Get suggest LOC    
         EXEC rdt.rdt_TM_Assist_Putaway_PP_GetSuggestLOC @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility    
            ,@cTaskDetailKey    
            ,@cFromLOC    
            ,@cFromID    
            ,@cSKU    
            ,@nQTY    
            ,@cSuggToLOC      OUTPUT    
            ,@nPABookingKey   OUTPUT    
            ,@nErrNo          OUTPUT    
            ,@cErrMsg         OUTPUT    
         IF @nErrNo = -1 -- No suggested LOC    
            SET @nErrNo = 0    
      END    
    
      -- Suggested LOC info      
      IF @cSuggToLOC <> ''    
      BEGIN    
         SELECT      
            @nQTY_Avail = ISNULL( SUM( LLI.QTY - LLI.QtyPicked), 0),      
            @nQTY_Alloc = ISNULL( SUM( LLI.QTYAllocated), 0),      
            @nQTY_PMoveIn = ISNULL( SUM( LLI.PendingMoveIn), 0)      
            FROM dbo.LotxLocxID LLI WITH (NOLOCK)      
            JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)      
         WHERE LOC.Facility = @cFacility      
            AND LLI.StorerKey = @cStorerKey    
            -- AND LLI.SKU = @cSKU    
            AND LLI.LOC = @cSuggToLOC      
      END    
      ELSE    
      BEGIN    
         SET @nQTY_Avail = 0    
         SET @nQTY_Alloc = 0    
         SET @nQTY_PMoveIn = 0             
      END    
      
      IF @cVerifyToID = '1'
      BEGIN
         SELECT TOP 1 @cSuggestToID = Id
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)      
         WHERE LOC.Facility = @cFacility      
         AND LLI.StorerKey = @cStorerKey    
         AND LLI.LOC = @cSuggToLOC      
         ORDER BY 1
             
         -- Prepare next screen var    
         SET @cOutField01 = @cSuggToLOC    
         SET @cOutField02 = @cSuggestToID
         SET @cOutField03 = ''
         
         SET @nScn = @nScn_PP_ToID
         SET @nStep = @nStep_PP_ToID
      END
      ELSE
      BEGIN
         -- Prepare next screen var    
         SET @cOutField01 = @cSuggToLOC    
         SET @cOutField02 = CAST( @nQTY_Avail AS NVARCHAR(5))    
         SET @cOutField03 = CAST( @nQTY_Alloc AS NVARCHAR(5))    
         SET @cOutField04 = CAST( @nQTY_PMoveIn AS NVARCHAR(5))    
         SET @cOutField05 = '' -- FinalLOC    
    
         SET @nScn = @nScn_PP_FinalLOC    
         SET @nStep = @nStep_PP_FinalLOC
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      SET @cOutField01 = @cFromLOC    
      SET @cOutField02 = @cFromID
      SET @cOutField03 = @cSKU    
      SET @cOutField04 = '' -- SKU    
    
      SET @cFieldAttr12 = '' -- PQTY    
    
      -- Set the entry point    
      SET @nScn = @nScn_PP_SKU    
      SET @nStep = @nStep_PP_SKU    
   END    
END    
GOTO Quit    

/********************************************************************************    
Step 1. Screen = 4075    
   SUGGEST LOC (Field01)    
   SUGGEST ID  (Field02)    
   TO ID       (Field03, input)       
********************************************************************************/    
Step_PP_ToID:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cToID = @cInField03    
    
      -- Check blank    
      IF @cToID = ''    
      BEGIN    
         SET @nErrNo = 51967    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToId needed    
         GOTO Quit    
      END    

      IF ISNULL( @cSuggestToID, '') <> '' AND @cSuggestToID <> @cToID
      BEGIN    
         SET @nErrNo = 51968    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ToID    
         SET @cOutField03 = ''
         GOTO Quit    
      END    

      -- Prepare next screen var    
      SET @cOutField01 = @cSuggToLOC    
      SET @cOutField02 = CAST( @nQTY_Avail AS NVARCHAR(5))    
      SET @cOutField03 = CAST( @nQTY_Alloc AS NVARCHAR(5))    
      SET @cOutField04 = CAST( @nQTY_PMoveIn AS NVARCHAR(5))    
      SET @cOutField05 = '' -- FinalLOC    
    
      SET @nScn = @nScn_PP_FinalLOC    
      SET @nStep = @nStep_PP_FinalLOC
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Unlock current session suggested LOC    
      IF @nPABookingKey <> 0    
      BEGIN    
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'    
            ,'' --FromLOC    
            ,'' --FromID    
            ,'' --cSuggLOC    
            ,'' --Storer    
            ,@nErrNo  OUTPUT    
            ,@cErrMsg OUTPUT    
            ,@nPABookingKey = @nPABookingKey OUTPUT    
         IF @nErrNo <> 0    
            GOTO Quit    
    
         SET @nPABookingKey = 0    
         SET @cSuggToLOC = ''    
      END    
    
      -- Convert to prefer UOM QTY    
      IF @cPUOM = '6' OR -- When preferred UOM = master unit    
         @nPUOM_Div = 0 -- UOM not setup    
      BEGIN    
         SET @cPUOM_Desc = ''    
         SET @nPQTY_PWY = 0    
         SET @nMQTY_PWY = @nQTY_PWY    
         SET @nPQTY = 0    
         SET @nMQTY = @nQTY    
         SET @cFieldAttr12 = 'O' -- @nPQTY       
      END    
      ELSE    
      BEGIN    
         SET @nPQTY_PWY = @nQTY_PWY / @nPUOM_Div -- Calc QTY in preferred UOM    
         SET @nMQTY_PWY = @nQTY_PWY % @nPUOM_Div -- Calc the remaining in master unit    
         SET @nPQTY = @nQTY / @nPUOM_Div    
         SET @nMQTY = @nQTY % @nPUOM_Div    
         SET @cFieldAttr12 = '' -- @nPQTY     
      END    
    
      -- Prep next screen var    
      SET @cOutField01 = @cPPK    
      SET @cOutField02 = @cSKU    
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1    
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2    
      SET @cOutField05 = '' -- Lottables    
      SET @cOutField06 = '' -- Lottables    
      SET @cOutField07 = '' -- Lottables    
      SET @cOutField08 = '' -- Lottables    
      SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6))    
      IF @cFieldAttr12 = '' -- PQTY enable    
      BEGIN    
         SET @cOutField10 = @cPUOM_Desc    
         SET @cOutField11 = CAST( @nPQTY_PWY AS NVARCHAR( 5))    
         SET @cOutField12 = CAST( @nPQTY AS NVARCHAR( 5))    
      END    
      ELSE    
      BEGIN    
         SET @cOutField10 = '' --@cPUOM_Desc    
         SET @cOutField11 = '' --@nPQTY_PWY    
         SET @cOutField12 = '' --@nPQTY    
      END    
      SET @cOutField13 = @cMUOM_Desc     
      SET @cOutField14 = CAST( @nMQTY_PWY AS NVARCHAR( 5))    
      SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 5))    
    
      SET @nScn  = @nScn_PP_QTY    
      SET @nStep = @nStep_PP_QTY     
   END    
END    
GOTO Quit    

/********************************************************************************    
Step 1. Screen = 4075    
   SUGGEST LOC (Field01)    
   QTY AVAIL   (Field02)    
   QTY ALLOC   (Field03)    
   QTY MOVIN   (Field04)    
   FINAL LOC   (Field05, input)       
********************************************************************************/    
Step_PP_FinalLOC:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      SET @cToLOC = @cInField05    
    
      -- Check blank    
      IF @cToLOC = ''    
      BEGIN    
         SET @nErrNo = 51969    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC needed    
         GOTO Quit    
      END    
    
      -- Check LOC valid    
      IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE Facility = @cFacility AND LOC = @cToLOC)    
      BEGIN    
         SET @nErrNo = 51970    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC    
         SET @cOutField05 = '' -- FinalLOC    
         GOTO Quit    
      END    
    
      -- Check if suggested LOC match    
      IF @cSuggToLOC <> '' AND @cToLOC <> @cSuggToLOC     
      BEGIN    
         IF @cOverwriteToLOC = '1'    
         BEGIN    
            SET @nErrNo = 51971    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC Not Match    
            SET @cOutField05 = '' -- FinalLOC    
            GOTO Quit    
         END    
    
         ELSE IF @cOverwriteToLOC = '2'    
         BEGIN    
            -- Prepare next screen var    
            SET @cOutField01 = '' -- Option    
    
            -- Go to LOC not match screen    
            SET @nScn = @nScn_PP_LOCNotMatch    
            SET @nStep = @nStep_PP_LOCNotMatch    
    
            GOTO Quit    
         END    
      END    
    
      -- Extended validate    
      IF @cExtendedValidateSP <> ''    
      BEGIN    
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')    
         BEGIN    
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +    
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cSKU, @nQTY, @cToLOC, @tExtValidate, ' +     
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'    
            SET @cSQLParam =    
               '@nMobile         INT,           ' +    
               '@nFunc           INT,           ' +    
               '@cLangCode       NVARCHAR( 3),  ' +    
               '@nStep           INT,           ' +    
               '@nInputKey       INT,           ' +    
               '@cTaskdetailKey  NVARCHAR( 10), ' +    
               '@cSKU            NVARCHAR( 20), ' +    
               '@nQTY            INT,           ' +    
               '@cToLOC          NVARCHAR( 10), ' +    
               '@tExtValidate    VariableTable READONLY, ' +    
               '@nErrNo          INT OUTPUT,    ' +    
               '@cErrMsg         NVARCHAR( 20) OUTPUT '    
    
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,    
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, @cSKU, @nQTY, @cToLOC, @tExtValidate,     
               @nErrNo OUTPUT, @cErrMsg OUTPUT    
    
            IF @nErrNo <> 0    
               GOTO Quit    
         END    
      END    
    
      -- Confirm task    
      EXEC rdt.rdt_TM_Assist_Putaway_PP_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility    
         ,@cTaskDetailKey    
         ,@cFromLOC    
         ,@cFromID    
         ,@cSKU    
         ,@nQTY    
         ,@cSuggToLOC    
         ,@cToLOC    
         ,@nPABookingKey OUTPUT    
         ,@nErrNo        OUTPUT    
         ,@cErrMsg       OUTPUT    
      IF @nErrNo <> 0    
         GOTO Quit    
    
      -- Get task    
      SET @cSKU = ''    
      SET @nQTY_PWY = 0    
      SET @cSuggToLOC = ''    
      SELECT     
         @cSKU = SKU,     
         @nQTY_PWY = SUM( QTY - QTYAllocated - QTYPicked)    
      FROM dbo.LOTxLOCxID WITH (NOLOCK)    
      WHERE LOC = @cFromLOC    
         AND ID = @cFromID    
         AND (QTY - QTYAllocated - QTYPicked) > 0    
         AND StorerKey = @cStorerKey    
      GROUP BY SKU    
      HAVING SUM( QTY - QTYAllocated - QTYPicked) > 0    
    
      -- No task    
      IF @@ROWCOUNT = 0    
      BEGIN    
         -- Update task    
         IF EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey AND Status < '9')    
         BEGIN    
            UPDATE dbo.TaskDetail SET    
               Status = '9',    
               ToLOC = @cToLOC,    
               UserKey = SUSER_SNAME(),    
               EditWho = SUSER_SNAME(),    
               EditDate = GETDATE(),     
               Trafficcop = NULL    
            WHERE TaskDetailKey = @cTaskDetailKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 51972    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail    
               GOTO Quit    
            END    
         END    
    
         -- EventLog    
         EXEC RDT.rdt_STD_EventLog    
            @cActionType = '9', -- Sign-out    
            @cUserID     = @cUserName,    
            @nMobileNo   = @nMobile,    
            @nFunctionID = @nFunc,    
            @cFacility   = @cFacility,    
            @cStorerKey  = @cStorerKey    
    
         -- Go back to assist task manager    
         SET @nFunc = 1814    
         SET @nScn = 4060    
         SET @nStep = 1    
    
         IF @cFromID <> ''    
            EXEC rdt.rdtSetFocusField @nMobile, 1 -- From ID    
         ELSE    
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Case ID    
    
         SET @cOutField01 = '' -- From ID    
         SET @cOutField02 = '' -- Case ID    
             
         GOTO Quit    
      END    
    
      -- Go to SKU screen    
      IF @nInitSKUInPallet > 1 OR @cVerifySKU = '1'    
      BEGIN    
         SET @cOutField01 = @cFromLOC    
         SET @cOutField02 = @cFromID
         SET @cOutField03 = @cSKU    
         SET @cOutField04 = '' -- SKU    
    
         SET @nScn  = @nScn_PP_SKU    
         SET @nStep = @nStep_PP_SKU    
    
         GOTO Quit    
      END    
    
      -- Go to QTY screen    
      BEGIN                
         -- Default move QTY as available QTY    
         IF @cDefaultQTY = '1'    
            SET @nQTY = @nQTY_PWY    
         ELSE    
            SET @nQTY = 0    
    
         -- Convert to prefer UOM QTY    
         IF @cPUOM = '6' OR -- When preferred UOM = master unit    
            @nPUOM_Div = 0 -- UOM not setup    
         BEGIN    
            SET @cPUOM_Desc = ''    
            SET @nPQTY_PWY = 0    
            SET @nMQTY_PWY = @nQTY_PWY    
            SET @nPQTY = 0    
            SET @nMQTY = @nQTY    
            SET @cFieldAttr12 = 'O' -- @nPQTY       
         END    
         ELSE    
         BEGIN    
            SET @nPQTY_PWY = @nQTY_PWY / @nPUOM_Div -- Calc QTY in preferred UOM    
            SET @nMQTY_PWY = @nQTY_PWY % @nPUOM_Div -- Calc the remaining in master unit    
            SET @nPQTY = @nQTY / @nPUOM_Div    
            SET @nMQTY = @nQTY % @nPUOM_Div    
            SET @cFieldAttr12 = '' -- @nPQTY     
         END    
    
         -- Prep next screen var    
         SET @cOutField01 = @cPPK    
         SET @cOutField02 = @cSKU    
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1    
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2    
         SET @cOutField05 = '' -- Lottables    
         SET @cOutField06 = '' -- Lottables    
         SET @cOutField07 = '' -- Lottables    
         SET @cOutField08 = '' -- Lottables    
         SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6))    
         IF @cFieldAttr12 = '' -- PQTY enable    
         BEGIN    
            SET @cOutField10 = @cPUOM_Desc    
            SET @cOutField11 = CAST( @nPQTY_PWY AS NVARCHAR( 5))    
            SET @cOutField12 = CAST( @nPQTY AS NVARCHAR( 5))    
         END    
         ELSE    
         BEGIN    
            SET @cOutField10 = '' --@cPUOM_Desc    
            SET @cOutField11 = '' --@nPQTY_PWY    
            SET @cOutField12 = '' --@nPQTY    
         END    
         SET @cOutField13 = @cMUOM_Desc     
         SET @cOutField14 = CAST( @nMQTY_PWY AS NVARCHAR( 5))    
         SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 5))    
    
         SET @nScn  = @nScn_PP_QTY    
         SET @nStep = @nStep_PP_QTY    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Unlock current session suggested LOC    
      IF @nPABookingKey <> 0    
      BEGIN    
         EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'    
            ,'' --FromLOC    
            ,'' --FromID    
            ,'' --cSuggLOC    
            ,'' --Storer    
            ,@nErrNo  OUTPUT    
            ,@cErrMsg OUTPUT    
            ,@nPABookingKey = @nPABookingKey OUTPUT    
         IF @nErrNo <> 0    
            GOTO Quit    
    
         SET @nPABookingKey = 0    
         SET @cSuggToLOC = ''    
      END    
    
      -- Convert to prefer UOM QTY    
      IF @cPUOM = '6' OR -- When preferred UOM = master unit    
         @nPUOM_Div = 0 -- UOM not setup    
      BEGIN    
         SET @cPUOM_Desc = ''    
         SET @nPQTY_PWY = 0    
         SET @nMQTY_PWY = @nQTY_PWY    
         SET @nPQTY = 0    
         SET @nMQTY = @nQTY    
         SET @cFieldAttr12 = 'O' -- @nPQTY       
      END    
      ELSE    
      BEGIN    
         SET @nPQTY_PWY = @nQTY_PWY / @nPUOM_Div -- Calc QTY in preferred UOM    
         SET @nMQTY_PWY = @nQTY_PWY % @nPUOM_Div -- Calc the remaining in master unit    
         SET @nPQTY = @nQTY / @nPUOM_Div    
         SET @nMQTY = @nQTY % @nPUOM_Div    
         SET @cFieldAttr12 = '' -- @nPQTY     
      END    
    
      -- Prep next screen var    
      SET @cOutField01 = @cPPK    
      SET @cOutField02 = @cSKU    
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1    
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2    
      SET @cOutField05 = '' -- Lottables    
      SET @cOutField06 = '' -- Lottables    
      SET @cOutField07 = '' -- Lottables    
      SET @cOutField08 = '' -- Lottables    
      SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6))    
      IF @cFieldAttr12 = '' -- PQTY enable    
      BEGIN    
         SET @cOutField10 = @cPUOM_Desc    
         SET @cOutField11 = CAST( @nPQTY_PWY AS NVARCHAR( 5))    
         SET @cOutField12 = CAST( @nPQTY AS NVARCHAR( 5))    
      END    
      ELSE    
      BEGIN    
         SET @cOutField10 = '' --@cPUOM_Desc    
         SET @cOutField11 = '' --@nPQTY_PWY    
         SET @cOutField12 = '' --@nPQTY    
      END    
      SET @cOutField13 = @cMUOM_Desc     
      SET @cOutField14 = CAST( @nMQTY_PWY AS NVARCHAR( 5))    
      SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 5))    
    
      SET @nScn  = @nScn_PP_QTY    
      SET @nStep = @nStep_PP_QTY     
   END    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 2. Scn = 4071.    
   LOC not match. Proceed?    
   1 = YES    
   2 = NO    
   OPTION (Input, Field01)    
********************************************************************************/    
Step_PP_LOCNotMatch:    
BEGIN    
   IF @nInputKey = 1    
   BEGIN    
      SET @cOption = @cInField01    
    
      -- Check blank    
      IF @cOption = ''    
      BEGIN    
         SET @nErrNo = 51973    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option req    
         GOTO Quit    
      END    
    
      -- Check optin valid    
      IF @cOption NOT IN ('1', '2')    
      BEGIN    
         SET @nErrNo = 51974    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option    
         SET @cOutField01 = ''    
         GOTO Quit    
      END    
    
      IF @cOption = '1' -- YES    
      BEGIN    
         -- Confirm task    
         EXEC rdt.rdt_TM_Assist_Putaway_PP_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility    
            ,@cTaskDetailKey    
            ,@cFromLOC    
            ,@cFromID    
            ,@cSKU    
            ,@nQTY    
            ,@cSuggToLOC    
            ,@cToLOC    
            ,@nPABookingKey OUTPUT    
            ,@nErrNo        OUTPUT    
            ,@cErrMsg       OUTPUT    
         IF @nErrNo <> 0    
            GOTO Quit    
    
         -- Get task    
         SET @cSKU = ''    
         SET @nQTY_PWY = 0    
         SET @cSuggToLOC = ''    
         SELECT     
            @cSKU = SKU,     
            @nQTY_PWY = SUM( QTY - QTYAllocated - QTYPicked)    
         FROM dbo.LOTxLOCxID WITH (NOLOCK)    
         WHERE LOC = @cFromLOC    
            AND ID = @cFromID    
            AND (QTY - QTYAllocated - QTYPicked) > 0    
            AND StorerKey = @cStorerKey    
         GROUP BY SKU    
         HAVING SUM( QTY - QTYAllocated - QTYPicked) > 0    
    
         -- No task    
         IF @@ROWCOUNT = 0    
         BEGIN    
            -- Update task    
            IF EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey AND Status < '9')    
            BEGIN    
               UPDATE dbo.TaskDetail SET    
                  Status = '9',    
                  ToLOC = @cToLOC,    
                  UserKey = SUSER_SNAME(),    
                  EditWho = SUSER_SNAME(),    
                  EditDate = GETDATE(),     
                  Trafficcop = NULL    
               WHERE TaskDetailKey = @cTaskDetailKey    
               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 51975    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Task Fail    
                  GOTO Quit    
               END    
            END    
                
            -- EventLog    
            EXEC RDT.rdt_STD_EventLog    
               @cActionType = '9', -- Sign-out    
               @cUserID     = @cUserName,    
               @nMobileNo   = @nMobile,    
               @nFunctionID = @nFunc,    
               @cFacility   = @cFacility,    
               @cStorerKey  = @cStorerKey    
    
            -- Go back to assist task manager    
            SET @nFunc = 1814    
            SET @nScn = 4060    
            SET @nStep = 1    
    
            IF @cFromID <> ''    
               EXEC rdt.rdtSetFocusField @nMobile, 1 -- From ID    
            ELSE    
               EXEC rdt.rdtSetFocusField @nMobile, 2 -- Case ID    
    
            SET @cOutField01 = '' -- From ID    
            SET @cOutField02 = '' -- Case ID    
                
            GOTO Quit    
         END    
    
         -- Go to SKU screen    
         IF @nInitSKUInPallet > 1 OR @cVerifySKU = '1'    
         BEGIN    
            SET @cOutField01 = @cFromLOC    
            SET @cOutField02 = @cFromID
            SET @cOutField03 = @cSKU    
            SET @cOutField04 = '' -- SKU    
    
            SET @nScn  = @nScn_PP_SKU    
            SET @nStep = @nStep_PP_SKU    
    
            GOTO Quit    
         END    
    
         -- Go to QTY screen    
         BEGIN                
            -- Default move QTY as available QTY    
            IF @cDefaultQTY = '1'    
               SET @nQTY = @nQTY_PWY    
            ELSE    
               SET @nQTY = 0    
    
            -- Convert to prefer UOM QTY    
            IF @cPUOM = '6' OR -- When preferred UOM = master unit    
               @nPUOM_Div = 0 -- UOM not setup    
            BEGIN    
               SET @cPUOM_Desc = ''    
               SET @nPQTY_PWY = 0    
               SET @nMQTY_PWY = @nQTY_PWY    
               SET @nPQTY = 0    
               SET @nMQTY = @nQTY    
               SET @cFieldAttr12 = 'O' -- @nPQTY       
            END    
            ELSE    
            BEGIN    
               SET @nPQTY_PWY = @nQTY_PWY / @nPUOM_Div -- Calc QTY in preferred UOM    
               SET @nMQTY_PWY = @nQTY_PWY % @nPUOM_Div -- Calc the remaining in master unit    
               SET @nPQTY = @nQTY / @nPUOM_Div    
               SET @nMQTY = @nQTY % @nPUOM_Div    
               SET @cFieldAttr12 = '' -- @nPQTY     
            END    
    
            -- Prep next screen var    
            SET @cOutField01 = @cPPK    
            SET @cOutField02 = @cSKU    
            SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)   -- SKU desc 1    
            SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  -- SKU desc 2    
            SET @cOutField05 = '' -- Lottables    
            SET @cOutField06 = '' -- Lottables    
            SET @cOutField07 = '' -- Lottables    
            SET @cOutField08 = '' -- Lottables    
            SET @cOutField09 = '1:' + CAST( @nPUOM_Div AS NCHAR( 6))    
            IF @cFieldAttr12 = '' -- PQTY enable    
            BEGIN    
               SET @cOutField10 = @cPUOM_Desc    
               SET @cOutField11 = CAST( @nPQTY_PWY AS NVARCHAR( 5))    
               SET @cOutField12 = CAST( @nPQTY AS NVARCHAR( 5))    
            END    
            ELSE    
            BEGIN    
               SET @cOutField10 = '' --@cPUOM_Desc    
               SET @cOutField11 = '' --@nPQTY_PWY    
               SET @cOutField12 = '' --@nPQTY    
            END    
            SET @cOutField13 = @cMUOM_Desc     
            SET @cOutField14 = CAST( @nMQTY_PWY AS NVARCHAR( 5))    
            SET @cOutField15 = CAST( @nMQTY AS NVARCHAR( 5))    
    
            SET @nScn  = @nScn_PP_QTY    
            SET @nStep = @nStep_PP_QTY    
         END    
      END    
   END    
    
   -- Prepare next screen var    
   SET @cOutField01 = @cSuggToLOC    
   SET @cOutField02 = CAST( @nQTY_Avail AS NVARCHAR(5))    
   SET @cOutField03 = CAST( @nQTY_Alloc AS NVARCHAR(5))    
   SET @cOutField04 = CAST( @nQTY_PMoveIn AS NVARCHAR(5))    
   SET @cOutField05 = '' -- FinalLOC    
    
   -- Go to Suggest LOC screen    
   SET @nScn  = @nScn_PP_FinalLOC    
   SET @nStep = @nStep_PP_FinalLOC    
END    
GOTO Quit    
    
    
/********************************************************************************    
Step 6. Screen = 3570. Multi SKU    
   SKU         (Field01)    
   SKUDesc1    (Field02)    
   SKUDesc2    (Field03)    
   SKU         (Field04)    
   SKUDesc1    (Field05)    
   SKUDesc2    (Field06)    
   SKU         (Field07)    
   SKUDesc1    (Field08)    
   SKUDesc2    (Field09)    
   Option      (Field10, input)    
********************************************************************************/    
Step_PP_MultiSKU:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,    
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,    
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,    
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,    
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,    
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,    
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,    
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,    
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,    
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,    
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,    
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,    
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,    
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,    
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,    
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,    
         'CHECK',    
         @cMultiSKUBarcode,    
         @cStorerKey,    
         @cUPC     OUTPUT,    
         @nErrNo   OUTPUT,    
         @cErrMsg  OUTPUT    
    
      IF @nErrNo <> 0    
      BEGIN    
         IF @nErrNo = -1    
            SET @nErrNo = 0    
         GOTO Quit    
      END    
    
      SET @cSKU = @cUPC    
   END    
    
   -- Go to SKU screen    
   SET @cOutField01 = @cFromLOC    
   SET @cOutField02 = @cFromID    
   SET @cOutField03 = @cUPC    
       
   SET @nScn = @nScn_PP_SKU    
   SET @nStep = @nStep_PP_SKU    
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
      UserName  = @cUserName,    
    
      V_ID       = @cFromID,    
      V_LOC      = @cFromLOC,    
      V_TaskDetailKey = @cTaskDetailKey,    
      V_SKU      = @cSKU,    
      V_SKUDescr = @cSKUDescr,        
      V_UOM      = @cPUOM,    
      V_PUOM_Div = @nPUOM_Div ,      
      V_TaskQTY  = @nQTY_PWY,     
      V_QTY      = @nQTY,    
    
      V_String1  = @cAreakey,    
      V_String2  = @cTTMStrategykey,    
      V_String3  = @cTTMTaskType,    
      V_String4  = @cSuggToLOC,    
      V_String5  = @cPickAndDropLOC,    
      V_String6  = @cPickMethod,    
      V_String7  = @cPPK,     
      V_String8  = @cMUOM_Desc,      
      V_String9  = @cPUOM_Desc,     
      V_String10 = @cToLOC,    
      V_String11 = @cSuggestToID,
      V_String12 = @cToID,
      
      V_String20 = @cExtendedValidateSP,    
      V_String21 = @cExtendedUpdateSP,    
      V_String22 = @cExtendedInfoSP,    
      V_String23 = @cExtendedInfo,    
      V_String24 = @cOverwriteToLOC,    
      V_String25 = @cDefaultCursor,    
      V_String26 = @cFlowThruScreen,    
      V_String27 = @cGoToEndTask,    
      V_String28 = @cVerifySKU,     
      V_String29 = @cDecodeSP,     
      V_String30 = @cMultiSKUBarcode,     
      V_String31 = @cDefaultQTY,     
      V_String32 = @cVerifyToID,

      V_Integer1 = @nPABookingKey,     
      V_Integer2 = @nQTY_Avail,      
      V_Integer3 = @nQTY_Alloc,      
      V_Integer4 = @nQTY_PMoveIn,      
      V_Integer5 = @nInitSKUInPallet,     
          
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
    
   -- Execute TM module initialization (ung01)    
   IF (@nFunc <> 1815 AND @nStep = 0) AND -- Other module that begin with step 0    
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