SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/*********************************************************************************/
/* Store procedure: rdtfnc_TM_Assist_ClusterPick                                 */
/* Copyright      : LF Logistics                                                 */
/*                                                                               */
/* Purpose: TM Assisted Cluster Pick                                             */
/*                                                                               */
/* Modifications log:                                                            */
/*                                                                               */
/* Date         Rev     Author   Purposes                                        */
/* 2021-05-26   1.0     James    WMS-17335 Created                               */
/* 2022-02-10   1.1     Ung      WMS-18884 Add ExtendedInfoSP for SKU QTY screen */
/* 2022-02-28   1.2     James    Enhance assign tote logic (james01)             */
/* 2022-03-28   1.3     James    WMS-19202 Allow cart with assigned task continue*/
/*                               to pick (james02)                               */
/* 2023-05-03   1.4     James    WMS-22330 Add config to control whether allow   */
/*                               pick with mix wavekey (james03)                 */
/* 2024-07-31   1.5     Jackc    FCR-652 Add ext scn entry                       */
/* 2024-09-13   1.6     Jackc    FCR-652 Fix bug when continue task              */
/* 2024-09-14   1.7     Jackc    FCR-856 Lock Tasks on carton level              */
/* 2024-12-16   1.8     NLT013   FCR-1755 Add Extended validation                */
/* 2024-12-26   1.8.1   JCH507   FCR-1755 Go to wrong label when extvail fail    */
/* 2024-12-18   1.9     Jackc    UWP-28528 ActQty is reset to 0 when partial short*/
/*********************************************************************************/
        
CREATE   PROC [RDT].[rdtfnc_TM_Assist_ClusterPick](        
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
   @bSuccess       INT,        
   @nTranCount     INT,        
           
   @cStorerKey     NVARCHAR( 15),        
   @cUserName      NVARCHAR( 18),        
   @cFacility      NVARCHAR( 5),        
   @cLabelPrinter  NVARCHAR( 10),        
   @cPaperPrinter  NVARCHAR( 10),        
   @cReasonCode    NVARCHAR( 10),          
   @cPickZone      NVARCHAR( 10),      
   @cMethod        NVARCHAR( 1),      
   @cPassOnCart    NVARCHAR( 1),      
   @cPTLPKZoneReq  NVARCHAR( 1),      
   @c_outstring         NVARCHAR(255),          
   @cNextTaskDetailKey  NVARCHAR(10),          
   @cSKU                NVARCHAR( 20),        
   @cUPC                NVARCHAR( 30),        
   @cSKUDescr           NVARCHAR( 60),        
   @nQty                INT,        
   @cQTY                NVARCHAR( 5),        
   @cFromLoc            NVARCHAR( 10),        
   @cToLoc              NVARCHAR( 10),        
   @cDecodeSP           NVARCHAR( 20),         
   @cExtendedInfo       NVARCHAR( 20),        
   @cExtendedInfoSP     NVARCHAR( 20),        
   @cExtendedUpdateSP   NVARCHAR( 20),        
   @cExtendedValidateSP NVARCHAR( 20),        
   @cBarcode            NVARCHAR( Max),         
   @cOption             NVARCHAR( 1),         
   @cPickConfirmStatus  NVARCHAR( 1),        
   @cDefaultWeight      NVARCHAR( 1),         
   @cSKUValidated       NVARCHAR( 2),         
   @cDefaultQTY         NVARCHAR( 2),          
   @cDefaultQTYSP       NVARCHAR( 20),        
   @tExtValidate        VariableTable,         
   @tExtUpdate          VariableTable,         
   @tExtInfo            VariableTable,         
   @tClosePallet        VariableTable,         
   @tGetTask            VariableTable,         
   @tConfirm            VariableTable,        
   @tVarDisableQTYField VariableTable,        
   @tVarDefaultQTYField VariableTable,        
   @cPalletID           NVARCHAR( 20),        
   @nNoOfCheck          INT,        
   @cLoadKey            NVARCHAR( 10),        
   @cOrderKey           NVARCHAR( 10),        
   @cOverwriteToLOC     NVARCHAR(1),           
   @cPickDetailCartonID NVARCHAR( 20),        
   @cGetNextTaskSP      NVARCHAR( 20),          
   @cDisableQTYFieldSP  NVARCHAR( 20),          
   @cDisableQTYField    NVARCHAR( 1),        
   @cTaskDetailKey      NVARCHAR( 10),        
   @cAreaKey            NVARCHAR( 10),        
   @cTTMStrategyKey     NVARCHAR( 10),        
   @cGroupKey           NVARCHAR( 10),        
   @cTTMTaskType        NVARCHAR( 10),          
   @cRefKey01           NVARCHAR( 20),          
   @cRefKey02           NVARCHAR( 20),          
   @cRefKey03           NVARCHAR( 20),          
   @cRefKey04           NVARCHAR( 20),          
   @cRefKey05           NVARCHAR( 20),          
   @cSuggFromLOC        NVARCHAR( 10),        
   @cSuggToLOC          NVARCHAR( 10),        
   @cSuggCartId         NVARCHAR( 10),        
   @cSuggCartonID       NVARCHAR( 20),        
   @cCartonID           NVARCHAR( 20),              
   @cSuggSKU            NVARCHAR( 20),        
   @nSuggQty            INT,        
   @nPickedQty          INT,        
   @cCartID             NVARCHAR( 10),        
   @cResult01           NVARCHAR( 20),            
   @cResult02           NVARCHAR( 20),            
   @cResult03           NVARCHAR( 20),            
   @cResult04           NVARCHAR( 20),            
   @cResult05           NVARCHAR( 20),            
   @nNextPage           INT,        
   @nActQTY             INT,        
   @nCartonScanned      INT,      
   @cPickMethod         NVARCHAR( 10),      
   @cCartPickMethod     NVARCHAR( 40),      
   @cPosition           NVARCHAR( 20),      
   @cLockTaskKey        NVARCHAR( 10),      
   @cUnAssignTaskKey    NVARCHAR( 10),      
   @cCartonId2Confirm   NVARCHAR( 20),      
   @cSuggToteId         NVARCHAR( 20),      
   @cCartonType         NVARCHAR( 10),      
   @cConfirmToLoc       NVARCHAR( 1),      
   @cLockCaseID         NVARCHAR( 20),      
   @nCartLimit          INT,      
   @cWaveKey            NVARCHAR( 10),      
   @cUDF01              NVARCHAR( 30),      
   @cLong               NVARCHAR( 30),      
   @cCartType           NVARCHAR( 10) = '',      
   @nCartonCnt          INT = 0,      
   @cContinuePickOnAssignedCart  NVARCHAR( 1),      
   @cPickNoMixWave      NVARCHAR( 1),
   @cPickWaveKey        NVARCHAR( 10),

   --extScn Jackc
   @tExtScnData         VariableTable,
   @cExtendedScnSP      NVARCHAR( 20),
   @nAction             INT,
   @cPickSlipNo         NVARCHAR( 18), --V1.6 JACKC
   
   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),  @cFieldAttr01 NVARCHAR( 1),  @cLottable01  NVARCHAR( 18),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),  @cFieldAttr02 NVARCHAR( 1),  @cLottable02  NVARCHAR( 18),     
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),  @cFieldAttr03 NVARCHAR( 1),  @cLottable03  NVARCHAR( 18),     
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),  @cFieldAttr04 NVARCHAR( 1),  @dLottable04  DATETIME,     
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),  @cFieldAttr05 NVARCHAR( 1),  @dLottable05  DATETIME,     
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),  @cFieldAttr06 NVARCHAR( 1),  @cLottable06  NVARCHAR( 30),     
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),  @cFieldAttr07 NVARCHAR( 1),  @cLottable07  NVARCHAR( 30),     
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),  @cFieldAttr08 NVARCHAR( 1),  @cLottable08  NVARCHAR( 30),      
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),  @cFieldAttr09 NVARCHAR( 1),  @cLottable09  NVARCHAR( 30),     
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),  @cFieldAttr10 NVARCHAR( 1),  @cLottable10  NVARCHAR( 30),     
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),  @cFieldAttr11 NVARCHAR( 1),  @cLottable11  NVARCHAR( 30),     
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),  @cFieldAttr12 NVARCHAR( 1),  @cLottable12  NVARCHAR( 30),     
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),  @cFieldAttr13 NVARCHAR( 1),  @dLottable13  DATETIME,     
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),  @cFieldAttr14 NVARCHAR( 1),  @dLottable14  DATETIME,     
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),  @cFieldAttr15 NVARCHAR( 1),  @dLottable15  DATETIME,  

   @cExtScnUDF01  NVARCHAR( 250), @cExtScnUDF02 NVARCHAR( 250), @cExtScnUDF03 NVARCHAR( 250),
   @cExtScnUDF04  NVARCHAR( 250), @cExtScnUDF05 NVARCHAR( 250), @cExtScnUDF06 NVARCHAR( 250),
   @cExtScnUDF07  NVARCHAR( 250), @cExtScnUDF08 NVARCHAR( 250), @cExtScnUDF09 NVARCHAR( 250),
   @cExtScnUDF10  NVARCHAR( 250), @cExtScnUDF11 NVARCHAR( 250), @cExtScnUDF12 NVARCHAR( 250),
   @cExtScnUDF13  NVARCHAR( 250), @cExtScnUDF14 NVARCHAR( 250), @cExtScnUDF15 NVARCHAR( 250),
   @cExtScnUDF16  NVARCHAR( 250), @cExtScnUDF17 NVARCHAR( 250), @cExtScnUDF18 NVARCHAR( 250),
   @cExtScnUDF19  NVARCHAR( 250), @cExtScnUDF20 NVARCHAR( 250), @cExtScnUDF21 NVARCHAR( 250),
   @cExtScnUDF22  NVARCHAR( 250), @cExtScnUDF23 NVARCHAR( 250), @cExtScnUDF24 NVARCHAR( 250),
   @cExtScnUDF25  NVARCHAR( 250), @cExtScnUDF26 NVARCHAR( 250), @cExtScnUDF27 NVARCHAR( 250),
   @cExtScnUDF28  NVARCHAR( 250), @cExtScnUDF29 NVARCHAR( 250), @cExtScnUDF30 NVARCHAR( 250)

   --extScn Jackc end  
        
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
   @cLabelPrinter    = Printer,        
   @cPaperPrinter    = Printer_Paper,         
   @cFromLoc         = V_LOC,        
   @cCartonID        = V_CaseID,        
   @cSKU             = V_SKU,        
   @cSKUDescr        = V_SKUDescr,        
   @cTaskDetailKey   = V_TaskDetailKey,        
   @cWaveKey         = V_WaveKey,
   @cPickSlipNo      = V_PickSlipNo,      
         
   @nSuggQty       = V_Integer1,        
   @nPickedQty     = V_Integer2,        
   @nActQTY        = V_Integer3,        
              
   @cExtendedUpdateSP   = V_String1,        
   @cExtendedValidateSP = V_String2,        
   @cExtendedInfoSP     = V_String3,        
   @cGetNextTaskSP     = V_String4,          
   @cDisableQTYFieldSP  = V_String5,          
   @cDisableQTYField    = V_String6,        
   @cSuggCartId         = V_String7,        
   @cCartID             = V_String8,        
   @cSuggFromLOC        = V_String9,        
   @cSuggCartonID       = V_String10,        
   @cSuggSKU            = V_String11,        
   @cGroupKey           = V_String12,        
   @cSuggToLOC          = V_String13,        
   @cDefaultQTY         = V_String14,          
   @cOverwriteToLOC     = V_String15,          
   @cDefaultQTY         = V_String16,        
   @cPickConfirmStatus  = V_String17,        
   @cSKUValidated       = V_String18,        
   @cDefaultQTYSP       = V_String19,        
   @cPosition           = V_String22,      
   @cConfirmToLoc       = V_String23,      
   @cPickZone           = V_String24,      
   @cMethod             = V_String25,      
   @cResult01           = V_String26,      
   @cResult02           = V_String27,      
   @cResult03           = V_String28,      
   @cResult04           = V_String29,      
   @cResult05           = V_String30,      
   @cSuggToteId         = V_String31,      
   @cAreakey            = V_String32,          
   @cTTMStrategykey     = V_String33,          
   @cTTMTaskType        = V_String34,          
   @cRefKey01           = V_String35,          
   @cRefKey02           = V_String36,          
   @cRefKey03           = V_String37,          
   @cRefKey04           = V_String38,          
   @cRefKey05           = V_String39,          
      
   @cCartPickMethod     = V_String41,      
   @cContinuePickOnAssignedCart = V_String42,      
   @cPickNoMixWave      = V_String43,
   @cExtendedScnSP      = V_String44, -- ExtScn Jackc
   
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
   @nStep_CartID           INT,  @nScn_CartID            INT,        
   @nStep_CartMatrix       INT,  @nScn_CartMatrix        INT,        
   @nStep_Loc              INT,  @nScn_Loc               INT,        
   @nStep_SKUQTY           INT,  @nScn_SKUQTY            INT,        
   @nStep_Option           INT,  @nScn_Option            INT,        
   @nStep_ConfirmTote      INT,  @nScn_ConfirmTote       INT,        
   @nStep_ToLoc            INT,  @nScn_ToLoc             INT,        
   @nStep_UnAssign         INT,  @nScn_UnAssign          INT,      
   @nStep_NextTask         INT,  @nScn_NextTask          INT,      
   @nStep_ContTask         INT,  @nScn_ContTask          INT      
        
SELECT        
   @nStep_CartID           = 1,  @nScn_CartID            = 5920,        
   @nStep_CartMatrix       = 2,  @nScn_CartMatrix        = 5921,        
   @nStep_Loc              = 3,  @nScn_Loc               = 5922,        
   @nStep_SKUQTY           = 4,  @nScn_SKUQTY            = 5923,        
   @nStep_ConfirmTote      = 5,  @nScn_ConfirmTote       = 5924,      
   @nStep_Option           = 6,  @nScn_Option            = 5925,        
   @nStep_ToLoc            = 7,  @nScn_ToLoc             = 5926,        
   @nStep_UnAssign         = 8,  @nScn_UnAssign          = 5927,      
   @nStep_NextTask         = 9,  @nScn_NextTask          = 5928,      
   @nStep_ContTask         = 10, @nScn_ContTask          = 5929      
        
        
IF @nFunc = 1855        
BEGIN        
   -- Redirect to respective screen        
   IF @nStep = 0  GOTO Step_Start            -- Menu. Func = 1855        
   IF @nStep = 1  GOTO Step_CartID           -- Scn = 5920. Scan Car ID        
   IF @nStep = 2  GOTO Step_CartMatrix       -- Scn = 5921. Cart Matrix        
   IF @nStep = 3  GOTO Step_Loc              -- Scn = 5922. Loc        
   IF @nStep = 4  GOTO Step_SKUQTY           -- Scn = 5923. SKU, Qty        
   IF @nStep = 5  GOTO Step_ConfirmTote      -- Scn = 5924. Confirm Carton        
   IF @nStep = 6  GOTO Step_Option           -- Scn = 5925. Option        
   IF @nStep = 7  GOTO Step_ToLoc            -- Scn = 5926. To Loc        
   IF @nStep = 8  GOTO Step_UnAssign         -- Scn = 5927. Unassign Cart        
   IF @nStep = 9  GOTO Step_NextTask         -- Scn = 5928. End Task/Exit TM        
   IF @nStep = 10 GOTO Step_ContTask         -- Scn = 5929. Task exists, continue
   IF @nStep = 99 GOTO Step_99               -- Ext Scn Jackc
         
END        
        
RETURN -- Do nothing if incorrect step        
        
/********************************************************************************        
Step_Start. Func = 1855        
********************************************************************************/        
Step_Start:        
BEGIN        
   -- Get task manager data          
   SET @cTaskDetailKey  = @cOutField06          
   SET @cAreaKey        = @cOutField07          
   SET @cTTMStrategyKey = @cOutField08          
          
   -- Get task info          
   SELECT          
      @cTTMTaskType = TaskType,          
      @cStorerKey   = Storerkey,          
      @cSuggCartId  = DeviceID,        
      @cSuggFromLOC = FromLOC,        
      @cSuggToLOC = ToLoc,        
      @cGroupKey    = GroupKey,       
      @cPickMethod = PickMethod,       
      @cWaveKey = WaveKey        
   FROM dbo.TaskDetail WITH (NOLOCK)          
   WHERE TaskDetailKey = @cTaskDetailKey         
  
  insert into traceinfo (tracename,timein,step1,step2) values ('rmt1',getdate(),@cTaskDetailKey,'' )    
        
   -- Get storer config        
   SET @cOverwriteToLOC = rdt.rdtGetConfig( @nFunc, 'OverwriteToLOC', @cStorerKey)          
        
   SET @cExtendedValidateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)        
   IF @cExtendedValidateSP = '0'          
      SET @cExtendedValidateSP = ''        
        
   SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)        
   IF @cExtendedUpdateSP = '0'          
      SET @cExtendedUpdateSP = ''        
        
   SET @cExtendedInfoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)        
   IF @cExtendedInfoSP = '0'        
      SET @cExtendedInfoSP = ''        
        
   SET @cPickDetailCartonID = rdt.RDTGetConfig( @nFunc, 'PickDetailCartonID', @cStorerKey)        
   IF @cPickDetailCartonID NOT IN ('DropID', 'CaseID')        
      SET @cPickDetailCartonID = 'DropID'        
        
   SET @cDisableQTYField = ''        
   SET @cDisableQTYField = rdt.rdtGetConfig( @nFunc, 'DisableQTYField', @cStorerKey)        
        
   SET @cDisableQTYFieldSP = rdt.RDTGetConfig( @nFunc, 'DisableQTYFieldSP', @cStorerKey)        
   IF @cDisableQTYFieldSP = '0'        
      SET @cDisableQTYFieldSP = ''        
        
   SET @cDefaultQTY = rdt.rdtGetConfig( @nFunc, 'DefaultQTY', @cStorerKey)        
        
   SET @cDefaultQTYSP = rdt.RDTGetConfig( @nFunc, 'DefaultQTYSP', @cStorerKey)        
   IF @cDefaultQTYSP = '0'        
      SET @cDefaultQTYSP = ''        
        
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)          
   IF @cPickConfirmStatus = '0'          
      SET @cPickConfirmStatus = '5'          
      
   SET @cConfirmToLoc = rdt.RDTGetConfig( @nFunc, 'ConfirmToLoc', @cStorerKey)          
         
   SET @cContinuePickOnAssignedCart = rdt.RDTGetConfig( @nFunc, 'ContinuePickOnAssignedCart', @cStorerKey)      

   SET @cPickNoMixWave = rdt.RDTGetConfig( @nFunc, 'PickNoMixWave', @cStorerKey)

   SET @cExtendedScnSP = rdt.RDTGetConfig( @nFunc, 'ExtScnSP', @cStorerKey)
   IF @cExtendedScnSP = '0'
      SET @cExtendedScnSP = ''
   
   -- Prepare next screen var        
   SET @cOutField01 = ''        
   SET @cOutField02 = ''         
   SET @cOutField03 = ''      
      
   EXEC rdt.rdtSetFocusField @nMobile, 1          
           
   -- Logging        
   EXEC RDT.rdt_STD_EventLog        
      @cActionType     = '1', -- Sign-in        
      @cUserID         = @cUserName,        
      @nMobileNo       = @nMobile,        
      @nFunctionID     = @nFunc,        
      @cFacility       = @cFacility,        
      @cStorerKey      = @cStorerKey,        
      @nStep           = @nStep        
        
   -- Go to next screen        
   SET @nScn = @nScn_CartID        
   SET @nStep = @nStep_CartID

   IF @cExtendedScnSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScnSP AND type = 'P')
      BEGIN
         SET @nAction = 0

         EXECUTE [RDT].[rdt_ExtScnEntry] 
         @cExtendedScnSP, 
         @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @tExtScnData ,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,  
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,  
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,  
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,  
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,  
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT, 
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT, 
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT, 
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT, 
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT, 
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
         @nAction, 
         @nScn OUTPUT,  @nStep OUTPUT,
         @nErrNo   OUTPUT, 
         @cErrMsg  OUTPUT,
         @cExtScnUDF01   OUTPUT, @cExtScnUDF02 OUTPUT, @cExtScnUDF03 OUTPUT,
         @cExtScnUDF04   OUTPUT, @cExtScnUDF05 OUTPUT, @cExtScnUDF06 OUTPUT,
         @cExtScnUDF07   OUTPUT, @cExtScnUDF08 OUTPUT, @cExtScnUDF09 OUTPUT,
         @cExtScnUDF10   OUTPUT, @cExtScnUDF11 OUTPUT, @cExtScnUDF12 OUTPUT,
         @cExtScnUDF13   OUTPUT, @cExtScnUDF14 OUTPUT, @cExtScnUDF15 OUTPUT,
         @cExtScnUDF16   OUTPUT, @cExtScnUDF17 OUTPUT, @cExtScnUDF18 OUTPUT,
         @cExtScnUDF19   OUTPUT, @cExtScnUDF20 OUTPUT, @cExtScnUDF21 OUTPUT,
         @cExtScnUDF22   OUTPUT, @cExtScnUDF23 OUTPUT, @cExtScnUDF24 OUTPUT,
         @cExtScnUDF25   OUTPUT, @cExtScnUDF26 OUTPUT, @cExtScnUDF27 OUTPUT,
         @cExtScnUDF28   OUTPUT, @cExtScnUDF29 OUTPUT, @cExtScnUDF30 OUTPUT
         
         IF @nErrNo <> 0
         BEGIN
            GOTO  Quit
         END

         GOTO Quit
      END
   END -- ExtendedScreenSP <> ''       
END        
GOTO Quit        
        
/************************************************************************************        
Scn = 5920. Scan Cart Id        
   PickZone    (field01, input)        
   Cart ID     (field02, input)        
   Method      (field03, input)      
            
************************************************************************************/        
Step_CartID:        
BEGIN        
   IF @nInputKey = 1 -- ENTER        
   BEGIN        
      -- Screen mapping          
      SET @cPickZone = @cInField01      
      SET @cCartID = @cInField02          
      SET @cMethod = @cInField03          
          
      -- Retain value          
      SET @cOutField01 = @cInField01          
      SET @cOutField02 = @cInField02          
      SET @cOutField03 = @cInField03          
      
      IF @cContinuePickOnAssignedCart = '1' AND @cCartID <> ''      
      BEGIN      
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)      
                     WHERE Storerkey = @cStorerKey      
                     AND   TaskType = 'ASTCPK'      
                     AND   [Status] = '3'      
                     AND   Groupkey <> ''      
                     AND   UserKey = @cUserName      
                     AND   DeviceID = @cCartID)      
         BEGIN      
            SET @cOutField01 = ''      
                
            SET @nScn = @nScn_ContTask      
            SET @nStep = @nStep_ContTask      
                
            GOTO Quit      
         END      
      END      
            
      -- Check blank          
      IF @cPickZone = ''          
      BEGIN          
         SET @nErrNo = 171801          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PickZone          
         EXEC rdt.rdtSetFocusField @nMobile, 1          
         GOTO Quit          
      END          
         
      -- Check pickzone valid          
      IF NOT EXISTS( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)       
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)       
                     WHERE TD.Storerkey = @cStorerKey      
          AND   TD.TaskType = 'ASTCPK'      
                     AND   TD.[Status] = '0'      
                     AND   TD.Groupkey = ''      
                     AND   TD.UserKey = ''      
                     AND   TD.DeviceID = ''      
                     AND   LOC.Facility = @cFacility       
                     AND   LOC.PickZone = @cPickZone)          
      BEGIN          
         SET @nErrNo = 171802          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKZone NoTask         
         EXEC rdt.rdtSetFocusField @nMobile, 1          
         SET @cOutField01 = ''          
         GOTO Quit          
      END          
      SET @cOutField01 = @cPickZone          
                
      -- Check blank          
      IF @cCartID = ''          
      BEGIN          
         SET @nErrNo = 171803          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartID          
         EXEC rdt.rdtSetFocusField @nMobile, 2          
         GOTO Quit          
      END          
          
      -- Check cart valid          
      IF NOT EXISTS( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)       
                     WHERE DeviceType = 'CART'       
                     AND   DeviceID = @cCartID)          
      BEGIN          
         SET @nErrNo = 171804          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid CartID          
         EXEC rdt.rdtSetFocusField @nMobile, 2          
         SET @cOutField02 = ''          
         GOTO Quit          
      END          
          
      -- Check cart use by other          
      IF EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)       
                  WHERE Storerkey = @cStorerKey      
                  AND   TaskType = 'ASTCPK'      
                  AND   [STATUS] = '3'      
                  AND   DeviceID = @cCartonID      
                  AND   UserKey <> @cUserName)          
      BEGIN          
         SET @nErrNo = 171805          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cart in use          
         EXEC rdt.rdtSetFocusField @nMobile, 2          
         SET @cOutField02 = ''          
         GOTO Quit          
      END          
      SET @cOutField02 = @cCartID          
          
      -- Check blank          
      IF @cMethod = ''          
      BEGIN          
         SET @nErrNo = 171806          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Method          
         EXEC rdt.rdtSetFocusField @nMobile, 3          
         GOTO Quit          
      END          
          
      -- Check Method valid          
      SELECT @cCartPickMethod = Long      
      FROM dbo.CODELKUP WITH (NOLOCK)      
      WHERE LISTNAME = 'TMPickMtd'      
      AND   Code = @cMethod      
      AND   Storerkey = @cStorerKey      
            
      IF ISNULL( @cCartPickMethod, '') = ''      
      BEGIN          
         SET @nErrNo = 171807          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Method          
         EXEC rdt.rdtSetFocusField @nMobile, 3          
         SET @cOutField03 = ''          
         GOTO Quit          
      END          
      
      DECLARE @n INT      
      SELECT @n = CHARINDEX(',', @cCartPickMethod)      
      IF @n > 0      
      BEGIN      
         DECLARE @tPickMethod TABLE ( Method    NVARCHAR( 20) )      
         INSERT INTO @tPickMethod (Method) VALUES (LEFT( @cCartPickMethod, @n-1))      
         INSERT INTO @tPickMethod (Method) VALUES (LTRIM(SUBSTRING( @cCartPickMethod, @n+1, 20)))      
      END      
      ELSE      
         INSERT INTO @tPickMethod (Method) VALUES (@cCartPickMethod)      
               
      -- Check pickzone + method valid          
      IF NOT EXISTS( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)       
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)       
                     WHERE TD.Storerkey = @cStorerKey      
                     AND   TD.TaskType = 'ASTCPK'      
                     AND   TD.[Status] = '0'      
                     AND   TD.Groupkey = ''      
                     AND   TD.UserKey = ''      
                     AND   TD.DeviceID = ''      
                     --AND   TD.PickMethod = @cCartPickMethod      
                     AND   LOC.Facility = @cFacility       
                     AND   LOC.PickZone = @cPickZone      
                     AND   EXISTS ( SELECT 1 FROM @tPickMethod PM WHERE TD.PickMethod = PM.Method))      
      BEGIN          
         SET @nErrNo = 171808          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Method          
         EXEC rdt.rdtSetFocusField @nMobile, 3          
         SET @cOutField03 = ''          
         GOTO Quit          
      END          
      SET @cOutField03 = @cMethod          
      
          
      -- Extended validate        
      IF @cExtendedValidateSP <> ''        
      BEGIN        
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +         
               ' @cGroupKey, @cTaskDetailKey, @cPickZone, @cCartId, @cMethod, @cFromLoc, @cCartonId, ' +        
               ' @cSKU, @nQty, @cOption, @cToLOC, @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
        
            SET @cSQLParam =        
               ' @nMobile        INT,           ' +        
               ' @nFunc          INT,           ' +        
               ' @cLangCode      NVARCHAR( 3),  ' +        
               ' @nStep          INT,           ' +        
               ' @nInputKey      INT,           ' +        
               ' @cFacility      NVARCHAR( 5),  ' +        
               ' @cStorerKey     NVARCHAR( 15), ' +      
               ' @cGroupKey      NVARCHAR( 10), ' +        
               ' @cTaskDetailKey NVARCHAR( 10), ' +      
               ' @cPickZone      NVARCHAR( 10), ' +        
               ' @cCartId        NVARCHAR( 10), ' +      
               ' @cMethod        NVARCHAR( 1),  ' +        
               ' @cFromLoc       NVARCHAR( 10), ' +        
               ' @cCartonId      NVARCHAR( 20), ' +        
               ' @cSKU           NVARCHAR( 20), ' +        
               ' @nQty           INT,           ' +        
               ' @cOption        NVARCHAR( 1), ' +        
               ' @cToLOC         NVARCHAR( 10), ' +      
               ' @tExtValidate   VariableTable READONLY, ' +         
               ' @nErrNo         INT           OUTPUT, ' +        
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,         
               @cGroupKey, @cTaskDetailKey, @cPickZone, @cCartId, @cMethod, @cFromLoc, @cCartonId,       
               @cSKU, @nQty, @cOption, @cToLoc, @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT        
        
            IF @nErrNo <> 0         
               GOTO Quit        
         END        
      END        
      
      DECLARE @cCurCaseID  NVARCHAR( 20)      
      DECLARE @cNewCaseID  NVARCHAR( 20)      
      DECLARE @nCtnCount   INT      
      SET @cCurCaseID = ''      
      SET @cNewCaseID = ''      
      SET @nCtnCount = 0      
            
      SELECT @nCartLimit = Short      
      FROM dbo.CODELKUP WITH (NOLOCK)      
      WHERE LISTNAME = 'TMPICKMTD'      
      AND   Code = @cMethod      
      AND   Storerkey = @cStorerKey      
      
      -- (james03)
      IF @cPickNoMixWave = '1'
      BEGIN
         SELECT TOP 1 @cPickWaveKey = TD.WaveKey      
         FROM dbo.TaskDetail TD WITH (NOLOCK)      
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.LOC)      
         WHERE TD.Storerkey = @cStorerKey      
         AND   TD.TaskType = 'ASTCPK'      
         AND   TD.[Status] = '0'      
         AND   TD.Groupkey = ''      
         AND   TD.UserKey = ''      
         AND   TD.DeviceID = ''      
         AND   ((TD.UserKeyOverRide = '') OR (TD.UserKeyOverRide = @cUserName))      
         AND   LOC.Facility = @cFacility       
         AND   LOC.PickZone = @cPickZone        
         AND   EXISTS ( SELECT 1 FROM @tPickMethod PM WHERE TD.PickMethod = PM.Method)      
         ORDER BY CASE WHEN TD.UserKeyOverRide = @cUserName THEN '0' ELSE '1' END, TD.WaveKey      
      END

      SET @nTranCount = @@TRANCOUNT      
      BEGIN TRAN      
      SAVE TRAN LockTask      

      SET @cWaveKey = ''
      SET @cGroupKey = ''      
      SET @nErrNo = 0      
      
      DECLARE @curLockTask CURSOR      
      SET @curLockTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR      
      SELECT TD.TaskDetailKey, TD.Caseid, TD.WaveKey      
      FROM dbo.TaskDetail TD WITH (NOLOCK)      
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.LOC)      
      WHERE TD.Storerkey = @cStorerKey      
      AND   TD.TaskType = 'ASTCPK'      
      AND   TD.[Status] = '0'      
      AND   TD.Groupkey = ''      
      AND   TD.UserKey = ''      
      AND   TD.DeviceID = ''      
      AND   ((TD.UserKeyOverRide = '') OR (TD.UserKeyOverRide = @cUserName))      
      AND   (( @cPickNoMixWave = '0' AND TD.WaveKey = TD.WaveKey) OR ( @cPickNoMixWave = '1' AND TD.WaveKey = @cPickWaveKey))
      AND   LOC.Facility = @cFacility       
      AND   LOC.PickZone = @cPickZone        
      AND   EXISTS ( SELECT 1 FROM @tPickMethod PM WHERE TD.PickMethod = PM.Method)      
      ORDER BY CASE WHEN TD.UserKeyOverRide = @cUserName THEN '0' ELSE '1' END, TD.WaveKey, TD.Caseid      
      OPEN @curLockTask      
      FETCH NEXT FROM @curLockTask INTO @cLockTaskKey, @cNewCaseID, @cPickWaveKey      
      WHILE @@FETCH_STATUS = 0      
      BEGIN      
         IF @cCurCaseID <> @cNewCaseID      
         BEGIN      
            SET @cCurCaseID = @cNewCaseID      
            SET @nCtnCount = @nCtnCount + 1      
      
            IF @nCtnCount > @nCartLimit      
               BREAK      
         END      
               
         IF @cGroupKey = ''      
            SET @cGroupKey = @cLockTaskKey      
      
         UPDATE dbo.TaskDetail SET       
            STATUS = '3',      
            UserKey = @cUserName,      
            Groupkey = @cGroupKey,       
            DeviceID = @cCartID,      
            EditWho = @cUserName,       
            EditDate = GETDATE(),       
            StartTime = GETDATE()      
         WHERE TaskDetailKey = @cLockTaskKey      
               
         IF @@ERROR <> 0      
         BEGIN      
            SET @nErrNo = 171809          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lock Task Fail          
            GOTO LockTask_RollBackTran          
         END      
      	
         FETCH NEXT FROM @curLockTask INTO @cLockTaskKey, @cNewCaseID, @cPickWaveKey      
      END      
        
      SELECT TOP 1 @cWaveKey = WaveKey  
      FROM dbo.TaskDetail WITH (NOLOCK)  
      WHERE Storerkey = @cStorerKey  
      AND   TaskType = 'ASTCPK'  
      AND   STATUS = '3'  
      AND   Groupkey = @cGroupKey  
      AND   UserKey = @cUserName  
      AND   DeviceID = @cCartID  
      ORDER BY 1  
        
      -- Temp check for mismatch case qty between taskdetail and pickdetail       
      DECLARE @tTask TABLE      
      (      
         CaseID    NVARCHAR( 20) NOT NULL,      
         Qty       INT      
      )      
      
      DECLARE @tPick TABLE      
      (      
         CaseID    NVARCHAR( 20) NOT NULL,      
         Qty       INT      
      )      
      
      INSERT INTO @tTask( CaseID, Qty)      
      SELECT CaseId, SUM( Qty) FROM dbo.TaskDetail WITH (NOLOCK)       
      WHERE UserKey = @cUserName AND Groupkey = @cGroupKey AND STATUS = '3'       
      GROUP BY CaseID      
         
      INSERT INTO @tPick( CaseID, Qty)      
      SELECT CaseId, SUM( Qty) FROM dbo.PICKDETAIL WITH (NOLOCK) WHERE TaskDetailKey IN (      
      SELECT TaskDetailKey FROM dbo.TaskDetail WITH (NOLOCK) WHERE UserKey = @cUserName AND Groupkey = @cGroupKey AND STATUS = '3')       
      GROUP BY CaseId      
      
      IF EXISTS ( SELECT 1 FROM @tTask t JOIN @tPick p ON ( t.CaseID = p.CaseID)       
                  GROUP BY t.CaseID HAVING SUM( T.Qty) <> SUM( P.Qty))      
      BEGIN      
       DECLARE @curPatchTD CURSOR, @curPatchPD CURSOR  
       DECLARE @cPatchTDKey NVARCHAR( 10), @cPatchCaseId NVARCHAR( 20), @cPatchLot NVARCHAR(10), @cPatchLoc NVARCHAR( 10), @cPatchId NVARCHAR( 18), @cPatchSKU NVARCHAR( 20), @nPatchQty INT  
       DECLARE @cPatchPDKey NVARCHAR( 10), @nPatchPD_Qty INT, @cOriPatchTDKey NVARCHAR( 10)  
       SET @curPatchTD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
       SELECT TD.TaskDetailKey, TD.Caseid, TD.Lot, TD.FromLoc, TD.FromID, TD.Sku, TD.Qty  
       FROM dbo.TaskDetail TD WITH (NOLOCK)  
       WHERE TD.Storerkey = @cStorerKey  
       AND   TD.TaskType = 'ASTCPK'  
       AND   TD.WaveKey = @cWaveKey  
       AND   TD.[Status] = '3'  
       AND   TD.UserKey = @cUserName   
       AND   TD.Groupkey = @cGroupKey  
       AND   NOT EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)  
                          WHERE TD.TaskDetailKey = PD.TaskDetailKey  
                          AND   TD.Storerkey = PD.Storerkey  
                          --AND   TD.Lot = PD.Lot          
                          AND   TD.FromLoc = PD.Loc  
                          AND   TD.FromID = PD.ID  
                          AND   TD.Sku = PD.Sku  
                          AND   PD.[Status] IN ('0', '3'))  
         OPEN @curPatchTD  
         FETCH NEXT FROM @curPatchTD INTO @cPatchTDKey, @cPatchCaseId, @cPatchLot, @cPatchLoc, @cPatchId, @cPatchSKU, @nPatchQty  
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
            SET @curPatchPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
            SELECT PickDetailKey, Qty, TaskDetailKey  
            FROM dbo.PICKDETAIL WITH (NOLOCK)  
            WHERE Storerkey = @cStorerKey  
            AND   [Status] IN ('0', '3')  
            --AND   Lot = @cPatchLot  
            AND   Loc = @cPatchLoc  
            AND   ID = @cPatchId  
            AND   SKU = @cPatchSKU  
            AND   ISNULL( TaskDetailKey, '') = ''  
            OPEN @curPatchPD  
            FETCH NEXT FROM @curPatchPD INTO @cPatchPDKey, @nPatchPD_Qty, @cOriPatchTDKey  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
             IF @nPatchQty >= @nPatchPD_Qty  
             BEGIN  
                UPDATE dbo.PickDeTail SET   
                   TaskDetailKey = @cPatchTDKey,  
                   EditWho = SUSER_SNAME(),  
                   EditDate = GETDATE()  
                WHERE PickDetailKey = @cPatchPDKey  
                  
                  IF @@ERROR <> 0  
                     GOTO Quit_Patch  
                  INSERT INTO traceinfo(TraceName, TimeIn, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5) VALUES   
                  ('1855_patchlog', GETDATE(), @cPatchTDKey, @cPatchCaseId, @cPatchLot, @cPatchLoc, @cPatchId, @cPatchSKU, @nPatchQty, @cPatchPDKey, @nPatchPD_Qty, @cOriPatchTDKey)  
             END  
               
             SET @nPatchQty = @nPatchQty - @nPatchPD_Qty  
               
             IF @nPatchQty <= 0  
                BREAK  
             FETCH NEXT FROM @curPatchPD INTO @cPatchPDKey, @nPatchPD_Qty, @cOriPatchTDKey  
            END  
            FETCH NEXT FROM @curPatchTD INTO @cPatchTDKey, @cPatchCaseId, @cPatchLot, @cPatchLoc, @cPatchId, @cPatchSKU, @nPatchQty   
         END  
  
         DELETE FROM @tTask  
         DELETE FROM @tPick  
           
         INSERT INTO @tTask( CaseID, Qty)      
         SELECT CaseId, SUM( Qty) FROM dbo.TaskDetail WITH (NOLOCK)       
         WHERE UserKey = @cUserName AND Groupkey = @cGroupKey AND STATUS = '3'       
         GROUP BY CaseID      
         
         INSERT INTO @tPick( CaseID, Qty)      
         SELECT CaseId, SUM( Qty) FROM dbo.PICKDETAIL WITH (NOLOCK) WHERE TaskDetailKey IN (      
         SELECT TaskDetailKey FROM dbo.TaskDetail WITH (NOLOCK) WHERE UserKey = @cUserName AND Groupkey = @cGroupKey AND STATUS = '3')       
         GROUP BY CaseId      
  
         IF EXISTS ( SELECT 1 FROM @tTask t JOIN @tPick p ON ( t.CaseID = p.CaseID)       
                     GROUP BY t.CaseID HAVING SUM( T.Qty) <> SUM( P.Qty))      
         BEGIN      
            Quit_Patch:  
            SET @nErrNo = 171831          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TaskQtyXTally          
            GOTO LockTask_RollBackTran  
         END          
      END      
      
      DECLARE @tTaskLoc TABLE      
      (      
         TaskDetailKey NVARCHAR( 10) NOT NULL,      
         Loc NVARCHAR( 10)      
      )      
      
      DECLARE @tPickLoc TABLE      
      (      
         TaskDetailKey NVARCHAR( 10) NOT NULL,      
         Loc NVARCHAR( 10)      
      )      
      
      INSERT INTO @tTaskLoc( TaskDetailKey, Loc)      
      SELECT TaskDetailKey, FromLoc FROM dbo.TaskDetail WITH (NOLOCK)      
      WHERE UserKey = @cUserName AND Groupkey = @cGroupKey AND STATUS = '3'      
      
      INSERT INTO @tPickLoc( TaskDetailKey, Loc)      
      SELECT TaskDetailKey, Loc FROM dbo.PICKDETAIL WITH (NOLOCK) WHERE TaskDetailKey IN (      
      SELECT TaskDetailKey FROM dbo.TaskDetail WITH (NOLOCK) WHERE UserKey = @cUserName AND Groupkey = @cGroupKey AND STATUS = '3')   
      
      IF EXISTS ( SELECT 1      
                  FROM @tTaskLoc t JOIN @tPickLoc p ON ( t.TaskDetailKey = p.TaskDetailKey)      
                  GROUP BY t.Loc, p.Loc       
                  HAVING t.Loc <> p.Loc)      
      BEGIN      
         SET @nErrNo = 171834          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TaskLocXTally          
         GOTO LockTask_RollBackTran          
      END      
      
      --IF EXISTS ( SELECT 1       
      --   FROM taskdetail TD (NOLOCK)      
      --   LEFT JOIN PICKDETAIL PD (NOLOCK) ON TD.WaveKey = PD.WaveKey AND TD.SKU = PD.SKU   
      --      AND TD.CASEID = PD.CaseID AND TD.TaskType = 'ASTCPK' --AND TD.Lot = PD.LoT  
      --      AND TD.FromLoc = PD.Loc AND TD.FromID = PD.ID      
      --   WHERE TD.WaveKey = @cWaveKey      
      --   AND TD.TaskDetailKey <> PD.TaskDetailKey)      
      IF EXISTS ( SELECT 1  
                   FROM dbo.TaskDetail TD WITH (NOLOCK)  
                   WHERE TD.WaveKey = @cWaveKey  
                   AND   TD.TaskType IN ('CPK', 'ASTCPK')  
                   AND   TD.[Status] = '0'  
                   AND   NOT EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)  
                                      JOIN dbo.WAVEDETAIL WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)  
                                      WHERE TD.TaskDetailKey = PD.TaskDetailKey  
                                      AND   PD.Status IN ('0', '3')  
                                      AND   WD.WaveKey = @cWaveKey))  
      BEGIN      
         SET @nErrNo = 171835          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Task Mismatch      
         GOTO LockTask_RollBackTran          
      END      
        
        
        
      GOTO LockTask_Commit      
      
      LockTask_RollBackTran:        
            ROLLBACK TRAN LockTask        
      LockTask_Commit:        
         WHILE @@TRANCOUNT > @nTranCount        
            COMMIT TRAN        
      
      IF @nErrNo <> 0      
         GOTO Quit      
      
      SET @cResult01 = ''      
      SET @cResult02 = ''      
      SET @cResult03 = ''      
      SET @cResult04 = ''      
      SET @cResult05 = ''      
      
      -- Draw matrix           
      SET @nNextPage = 0            
      EXEC rdt.rdt_TM_Assist_ClusterPick_Matrix         
         @nMobile          = @nMobile,         
         @nFunc            = @nFunc,         
         @cLangCode        = @cLangCode,         
         @nStep            = @nStep,         
         @nInputKey        = @nInputKey,         
         @cFacility        = @cFacility,         
         @cStorerKey       = @cStorerKey,         
         @cPickZone        = @cPickZone,         
         @cCartID          = @cCartID,        
         @cMethod          = @cMethod,      
         @cResult01        = @cResult01   OUTPUT,          
         @cResult02        = @cResult02   OUTPUT,          
         @cResult03        = @cResult03   OUTPUT,          
         @cResult04        = @cResult04   OUTPUT,             
         @cResult05        = @cResult05   OUTPUT,          
         @nNextPage        = @nNextPage   OUTPUT,          
         @nErrNo           = @nErrNo      OUTPUT,          
         @cErrMsg          = @cErrMsg     OUTPUT        
            
      IF @nErrNo <> 0            
         GOTO Quit            
              
      -- Prepare next screen var        
      SET @cOutField01 = @cCartPickMethod        
      SET @cOutField02 = @cCartID        
     SET @cOutField03 = @cResult01        
      SET @cOutField04 = @cResult02        
      SET @cOutField05 = @cResult03        
      SET @cOutField06 = @cResult04        
      SET @cOutField07 = @cResult05        
      SET @cOutField08 = ''        
      SET @cOutField09 = 0        
            
      SET @cFromLoc = ''        
      SET @cCartonID = ''        
    SET @cSKU = ''        
      SET @nQTY = 0        
              
      -- Go to next screen        
      SET @nScn = @nScn_CartMatrix        
      SET @nStep = @nStep_CartMatrix         
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
END        
GOTO Quit        
        
/***********************************************************************************        
Scn = 5921. Cart ID/Matrix screen        
   Cart ID   (field01)        
   Result01  (field01)            
   Result02  (field02)            
   Result03  (field03)            
   Result04  (field04)            
   Result05  (field05)            
   Result06  (field06)            
   Result07  (field07)            
   Result08  (field08)            
***********************************************************************************/        
Step_CartMatrix:        
BEGIN        
   IF @nInputKey = 1 -- ENTER        
   BEGIN        
      -- Screen mapping        
      SET @cCartonId = @cInField08        
      
      -- Validate blank        
      IF ISNULL( @cCartonId, '') = ''        
      BEGIN        
         SELECT @nCartonScanned = COUNT( DISTINCT DropID)      
         FROM dbo.TaskDetail WITH (NOLOCK)      
         WHERE Storerkey = @cStorerKey      
         AND   TaskType = 'ASTCPK'      
         AND   [Status] = '3'      
         AND   Groupkey = @cGroupKey      
         AND   UserKey = @cUserName      
         AND   DeviceID = @cCartID      
         AND   DropID <> ''      
      
         IF @nCartonScanned = 0      
         BEGIN      
            SET @nErrNo = 171810     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Tote Id        
            GOTO Step_Matrix_Fail      
         END      
      
         SELECT @nCartLimit = Short      
         FROM dbo.CODELKUP WITH (NOLOCK)      
         WHERE LISTNAME = 'TMPICKMTD'      
         AND   Code = @cMethod      
         AND   Storerkey = @cStorerKey      
               
         SELECT @nCartonCnt = COUNT( DISTINCT DropID)      
         FROM dbo.TaskDetail WITH (NOLOCK)      
       WHERE Storerkey = @cStorerKey      
         AND   TaskType = 'ASTCPK'      
         AND   [Status] IN ( '3', '5')      
         AND   Groupkey = @cGroupkey      
         AND   UserKey = @cUserName      
         AND   DeviceID = @cCartID      
         AND   DropID <> ''      
      
         IF @nCartonCnt < @nCartLimit AND                   
          EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)      
                     WHERE Storerkey = @cStorerKey      
                     AND   TaskType = 'ASTCPK'      
                     AND   [Status] IN ( '3', '5')      
                     AND   Groupkey = @cGroupkey      
                     AND   UserKey = @cUserName      
                     AND   DeviceID = @cCartID      
                     AND   DropID = '')      
         BEGIN      
            SET @nErrNo = 171837                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MoreCtnToScan                  
            GOTO Step_Matrix_Fail      
         END                  
         ELSE  --Something scanned      
         BEGIN      
            --Get task for next loc        
            SET @nErrNo = 0        
            SET @cSuggFromLOC = ''        
            EXEC [RDT].[rdt_TM_Assist_ClusterPick_GetTask]         
               @nMobile          = @nMobile,        
               @nFunc            = @nFunc,        
 @cLangCode        = @cLangCode,        
               @nStep            = @nStep,        
               @nInputKey        = @nInputKey,        
               @cFacility        = @cFacility,        
               @cStorerKey       = @cStorerKey,        
               @cGroupKey        = @cGroupKey,        
               @cCartId          = @cCartId,        
               @cType            = 'NEXTLOC',        
               @cTaskDetailKey   = @cTaskDetailKey OUTPUT,        
               @cFromLoc         = @cSuggFromLOC   OUTPUT,        
               @cCartonId        = @cSuggCartonID  OUTPUT,        
               @cToteId          = @cSuggToteId    OUTPUT,      
               @cSKU             = @cSuggSKU       OUTPUT,        
               @nQty             = @nSuggQty       OUTPUT,        
               @tGetTask         = @tGetTask,         
               @nErrNo           = @nErrNo         OUTPUT,        
               @cErrMsg          = @cErrMsg        OUTPUT        
        
            IF @nErrNo <> 0        
               GOTO Quit        
        
            -- Prepare next screen var        
            SET @cOutField01 = @cCartPickMethod      
            SET @cOutField02 = @cSuggFromLOC         
            SET @cOutField03 = ''      
      
            -- Go to next screen        
            SET @nScn = @nScn_Loc        
            SET @nStep = @nStep_Loc        
                  
            GOTO Quit      
         END      
      END        
      
      IF EXISTS ( SELECT 1       
                  FROM dbo.TaskDetail WITH (NOLOCK)      
                  WHERE Storerkey = @cStorerKey      
                  AND   TaskType = 'ASTCPK'      
                  AND   [Status] = '3'      
                  AND   Groupkey = @cGroupKey      
                  AND   UserKey = @cUserName      
                  AND   DeviceID = @cCartID      
                  AND   DropID = @cCartonId)      
      BEGIN        
         SET @nErrNo = 171811        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned        
         GOTO Step_Matrix_Fail        
      END        
      
      -- Check if all carton assigned      
      IF NOT EXISTS ( SELECT 1      
                      FROM dbo.TaskDetail WITH (NOLOCK)      
                      WHERE Storerkey = @cStorerKey      
                      AND   TaskType = 'ASTCPK'      
                      AND   [Status] = '3'      
                      AND   Groupkey = @cGroupKey      
                      AND   UserKey = @cUserName      
                      AND   DeviceID = @cCartID      
                      AND   DropID = '')      
      BEGIN      
         SET @nErrNo = 171812        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --All Assigned        
         GOTO Step_Matrix_Fail      
      END      
            
      IF EXISTS ( SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK)      
                  WHERE Storerkey = @cStorerKey      
                  AND   DropID = @cCartonID      
                  AND  ([Status] = '4' OR       
                        [Status] < @cPickConfirmStatus OR       
                        ([Status] = '3' AND CaseID <> 'SORTED') OR      
                        ([Status] = '3' AND CaseID <> '')))       
      BEGIN      
         SET @nErrNo = 171832        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote In Use        
         GOTO Step_Matrix_Fail      
      END      
            
      IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)      
                  WHERE Storerkey = @cStorerKey      
                  AND   TaskType = 'ASTCPK'      
                  AND   [Status] < '9'      
                  AND   DropID = @cCartonID)      
      BEGIN      
         SET @nErrNo = 171833        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote In Use        
         GOTO Step_Matrix_Fail      
      END      
      
      -- Extended validate        
      IF @cExtendedValidateSP <> ''        
      BEGIN        
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +         
               ' @cGroupKey, @cTaskDetailKey, @cPickZone, @cCartId, @cMethod, @cFromLoc, @cCartonId, ' +        
               ' @cSKU, @nQty, @cOption, @cToLOC, @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
        
            SET @cSQLParam =        
               ' @nMobile        INT,           ' +        
               ' @nFunc          INT,           ' +        
               ' @cLangCode      NVARCHAR( 3),  ' +        
               ' @nStep          INT,           ' +        
               ' @nInputKey      INT,           ' +        
               ' @cFacility      NVARCHAR( 5),  ' +        
               ' @cStorerKey     NVARCHAR( 15), ' +      
               ' @cGroupKey      NVARCHAR( 10), ' +        
               ' @cTaskDetailKey NVARCHAR( 10), ' +      
               ' @cPickZone      NVARCHAR( 10), ' +        
               ' @cCartId        NVARCHAR( 10), ' +      
               ' @cMethod        NVARCHAR( 1),  ' +        
               ' @cFromLoc       NVARCHAR( 10), ' +        
               ' @cCartonId      NVARCHAR( 20), ' +        
               ' @cSKU           NVARCHAR( 20), ' +        
               ' @nQty           INT,           ' +        
               ' @cOption        NVARCHAR( 1), ' +        
               ' @cToLOC         NVARCHAR( 10), ' +      
               ' @tExtValidate   VariableTable READONLY, ' +         
               ' @nErrNo         INT           OUTPUT, ' +        
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,         
               @cGroupKey, @cTaskDetailKey, @cPickZone, @cCartId, @cMethod, @cFromLoc, @cCartonId,       
               @cSKU, @nQty, @cOption, @cToLoc, @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT        
        
            IF @nErrNo <> 0         
               GOTO Step_Matrix_Fail        
         END        
      END        
      
      SELECT @nCartonScanned = COUNT( DISTINCT DropID)      
      FROM dbo.TaskDetail WITH (NOLOCK)      
      WHERE Storerkey = @cStorerKey      
      AND   TaskType = 'ASTCPK'      
      AND   [Status] = '3'      
      AND   Groupkey = @cGroupKey      
      AND   UserKey = @cUserName      
      AND   DeviceID = @cCartID      
      AND   DropID <> ''      
      
      SELECT @cCartonType = UDF01      
      FROM dbo.CODELKUP WITH (NOLOCK)      
      WHERE LISTNAME = 'TMPICKMTD'      
      AND   Code = @cMethod      
      AND   Storerkey = @cStorerKey      
         
      SET @cPickMethod = ''      
      SELECT @cPickMethod = Long       
      FROM dbo.CODELKUP WITH (NOLOCK)      
      WHERE LISTNAME = 'TMPICKMTD'      
      AND   Storerkey = @cStorerKey      
      AND   UDF01 = SUBSTRING( @cCartonId, 1, 1)      
         
      SELECT TOP 1 @cLockCaseID = Caseid--@cLockTaskKey = TaskDetailKey      
      FROM dbo.TaskDetail WITH (NOLOCK)      
      WHERE Storerkey = @cStorerKey      
      AND   TaskType = 'ASTCPK'      
      AND   [Status] = '3'      
      AND   Groupkey = @cGroupKey      
      AND   UserKey = @cUserName      
      AND   DeviceID = @cCartID      
      AND   DropID = ''      
      AND   PickMethod = @cPickMethod      
      ORDER BY 1      
            
      DECLARE @curLockCase CURSOR      
      SET @curLockCase = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR      
      SELECT TaskDetailKey      
      FROM dbo.TaskDetail WITH (NOLOCK)      
      WHERE Storerkey = @cStorerKey      
      AND   TaskType = 'ASTCPK'      
      AND   [Status] = '3'      
      AND   Groupkey = @cGroupKey      
      AND   UserKey = @cUserName      
      AND   DeviceID = @cCartID      
      AND   Caseid = @cLockCaseID      
      AND   DropID = ''      
      ORDER BY 1      
      OPEN @curLockCase      
      FETCH NEXT FROM @curLockCase INTO @cLockTaskKey      
      WHILE @@FETCH_STATUS = 0      
      BEGIN      
         UPDATE dbo.TaskDetail SET       
            DropID = @cCartonID,       
            StatusMsg =  CAST( @nCartonScanned + 1 AS NVARCHAR( 1)) + '-' + @cCartonType,      
            EditWho = @cUserName,       
            EditDate = GETDATE()      
         WHERE TaskDetailKey = @cLockTaskKey      
            
         IF @@ERROR <> 0      
         BEGIN      
            SET @nErrNo = 171812        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Assign Fail        
           GOTO Step_Matrix_Fail      
         END      
            
         FETCH NEXT FROM @curLockCase INTO @cLockTaskKey      
      END      
            
      -- Prepare next screen var        
      SET @cOutField01 = @cCartPickMethod        
      SET @cOutField02 = @cCartID        
      SET @cOutField03 = @cResult01        
      SET @cOutField04 = @cResult02        
      SET @cOutField05 = @cResult03        
      SET @cOutField06 = @cResult04        
      SET @cOutField07 = @cResult05        
      SET @cOutField08 = ''        
      SET @cOutField09 = @nCartonScanned + 1      
      
      EXEC rdt.rdtSetFocusField @nMobile, 8      
   END        
        
   IF @nInputKey = 0 -- ESC        
   BEGIN        
      -- Prepare next screen var        
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
      SET @cOutField13 = ''        
            
      EXEC rdt.rdtSetFocusField @nMobile, 1      
            
      -- Go to next screen        
      SET @nScn = @nScn_UnAssign        
      SET @nStep = @nStep_UnAssign        
   END        
   GOTO Quit        
      
   Step_Matrix_Fail:                  
   BEGIN                  
      -- Reset this screen var                  
      SET @cCartonID = ''      
      
      SET @cOutField08 = ''                  
   END                  
END        
GOTO Quit        
        
/********************************************************************************        
Scn = 5921. Loc        
   Loc (field01)        
   Loc (field01, input)        
********************************************************************************/        
Step_Loc:        
BEGIN        
   IF @nInputKey = 1 -- ENTER        
   BEGIN        
      -- Screen mapping        
      SET @cFromLoc = @cInField03        
        
      -- Validate blank        
      IF ISNULL( @cFromLoc, '') = ''        
      BEGIN        
         SET @nErrNo = 171814        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Loc        
         GOTO Step_Loc_Fail        
      END        
     
      -- Validate option        
      IF @cFromLoc <> @cSuggFromLOC        
      BEGIN        
         SET @nErrNo = 171814        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Loc Not Match        
         GOTO Step_Loc_Fail        
      END        
               
      -- Disable QTY field        
      IF @cDisableQTYFieldSP <> ''        
      BEGIN        
         IF @cDisableQTYFieldSP = '1'        
            SET @cDisableQTYField = @cDisableQTYFieldSP        
         ELSE        
         BEGIN        
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDisableQTYFieldSP AND type = 'P')        
            BEGIN        
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDisableQTYFieldSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, ' +         
               ' @tVarDisableQTYField, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
               SET @cSQLParam =        
                  '@nMobile            INT,           ' +        
                  '@nFunc              INT,           ' +        
                  '@cLangCode          NVARCHAR( 3),  ' +        
                  '@nStep              INT,           ' +        
                  '@nInputKey          INT,           ' +        
                  '@cTaskdetailKey     NVARCHAR( 10), ' +        
                  '@tVarDisableQTYField VariableTable READONLY,' +        
                  '@cDisableQTYField   NVARCHAR( 1)   OUTPUT, ' +        
                  '@nErrNo             INT            OUTPUT, ' +        
                  '@cErrMsg            NVARCHAR( 20)  OUTPUT'        
        
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskDetailKey,          
                  @tVarDisableQTYField, @cDisableQTYField OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT         
        
               IF @nErrNo <> 0        
                  GOTO Quit        
            END        
         END        
      END        
        
      -- Disable QTY field        
      IF @cDefaultQTYSP <> ''        
      BEGIN        
         IF @cDefaultQTYSP = '1'        
            SET @cDefaultQTY = @cDefaultQTYSP        
         ELSE        
         BEGIN        
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDefaultQTYSP AND type = 'P')        
            BEGIN        
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cDefaultQTYSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskdetailKey, ' +         
               ' @tVarDefaultQTYField, @cDefaultQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
               SET @cSQLParam =        
               '@nMobile            INT,           ' +        
               '@nFunc              INT,           ' +        
               '@cLangCode          NVARCHAR( 3),  ' +        
               '@nStep              INT,           ' +        
               '@nInputKey          INT,           ' +        
               '@cTaskdetailKey     NVARCHAR( 10), ' +        
               '@tVarDefaultQTYField VariableTable READONLY,' +        
               '@cDefaultQTY        NVARCHAR( 2)   OUTPUT, ' +        
               '@nErrNo             INT            OUTPUT, ' +        
               '@cErrMsg            NVARCHAR( 20)  OUTPUT'        
        
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cTaskDetailKey,          
                  @tVarDefaultQTYField, @cDefaultQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT         
        
               IF @nErrNo <> 0        
          GOTO Quit        
            END        
         END        
      END        
      
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
            
      SELECT @cSKUDescr = DESCR        
      FROM dbo.SKU WITH (NOLOCK)        
      WHERE StorerKey = @cStorerKey        
      AND   SKU = @cSuggSKU        
              
      SELECT @nSuggQty = ISNULL( SUM( Qty), 0)        
      FROM dbo.PICKDETAIL WITH (NOLOCK)        
      WHERE StorerKey = @cStorerKey        
      AND   Loc = @cFromLoc        
      AND   Sku = @cSuggSKU        
      AND   CaseID = @cSuggCartonID        
      AND   [Status] < @cPickConfirmStatus        
        
      SELECT @nPickedQty = ISNULL( SUM( Qty), 0)        
      FROM dbo.PICKDETAIL WITH (NOLOCK)        
      WHERE StorerKey = @cStorerKey        
      AND   Loc = @cFromLoc        
      AND   Sku = @cSuggSKU        
      AND   CaseID = @cSuggCartonID        
      AND   [Status] = @cPickConfirmStatus        
              
      -- Prepare next screen var        
      SET @cOutField01 = @cCartPickMethod      
      SET @cOutField02 = @cFromLoc      
      SET @cOutField03 = @cSuggSKU        
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)        
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)        
      SET @cOutField06 = ''   -- SKU/UPC        
      SET @cOutField07 = CASE WHEN @cDefaultQTY = '0' THEN '' ELSE @cDefaultQTY END -- QTY        
      SET @cOutField08 = @nPickedQty        
      SET @cOutField09 = @nSuggQty        
      SET @cOutField15 = '' -- ExtendedInfo      
            
      -- Enable field        
      IF @cDisableQTYField = '1'        
         SET @cFieldAttr07 = 'O'        
      ELSE        
         SET @cFieldAttr07 = ''        
        
      EXEC rdt.rdtSetFocusField @nMobile, 6        
        
      SET @nActQTY = 0        
      SET @cSKUValidated = '0'        
        
      -- Go to next screen        
      SET @nScn = @nScn_SKUQTY        
      SET @nStep = @nStep_SKUQTY        
   END        
        
   IF @nInputKey = 0 -- ESC        
   BEGIN        
      SELECT @nCartonScanned = COUNT( DISTINCT DropID)      
      FROM dbo.TaskDetail WITH (NOLOCK)      
      WHERE Storerkey = @cStorerKey      
      AND   TaskType = 'ASTCPK'      
      AND   [Status] = '3'      
      AND   Groupkey = @cGroupKey      
      AND   UserKey = @cUserName      
      AND   DeviceID = @cCartID
      AND   DropID <> '' -- FCR-652 Fix issue by jack      
               
      -- Prepare next screen var        
      SET @cOutField01 = @cCartPickMethod        
      SET @cOutField02 = @cCartID        
      SET @cOutField03 = @cResult01        
      SET @cOutField04 = @cResult02        
      SET @cOutField05 = @cResult03        
      SET @cOutField06 = @cResult04        
      SET @cOutField07 = @cResult05        
      SET @cOutField08 = ''        
      SET @cOutField09 = @nCartonScanned        
      
      EXEC rdt.rdtSetFocusField @nMobile, 8      
      
      -- Go to next screen        
      SET @nScn = @nScn_CartMatrix        
      SET @nStep = @nStep_CartMatrix

      -- Ext Scn SP
      IF @cExtendedScnSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScnSP AND type = 'P')
         BEGIN
            SET @nAction = 0

            EXECUTE [RDT].[rdt_ExtScnEntry] 
            @cExtendedScnSP, 
            @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @tExtScnData ,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,  
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,  
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,  
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,  
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,  
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT, 
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT, 
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT, 
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT, 
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT, 
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
            @nAction, 
            @nScn OUTPUT,  @nStep OUTPUT,
            @nErrNo   OUTPUT, 
            @cErrMsg  OUTPUT,
            @cExtScnUDF01   OUTPUT, @cExtScnUDF02 OUTPUT, @cExtScnUDF03 OUTPUT,
            @cExtScnUDF04   OUTPUT, @cExtScnUDF05 OUTPUT, @cExtScnUDF06 OUTPUT,
            @cExtScnUDF07   OUTPUT, @cExtScnUDF08 OUTPUT, @cExtScnUDF09 OUTPUT,
            @cExtScnUDF10   OUTPUT, @cExtScnUDF11 OUTPUT, @cExtScnUDF12 OUTPUT,
            @cExtScnUDF13   OUTPUT, @cExtScnUDF14 OUTPUT, @cExtScnUDF15 OUTPUT,
            @cExtScnUDF16   OUTPUT, @cExtScnUDF17 OUTPUT, @cExtScnUDF18 OUTPUT,
            @cExtScnUDF19   OUTPUT, @cExtScnUDF20 OUTPUT, @cExtScnUDF21 OUTPUT,
            @cExtScnUDF22   OUTPUT, @cExtScnUDF23 OUTPUT, @cExtScnUDF24 OUTPUT,
            @cExtScnUDF25   OUTPUT, @cExtScnUDF26 OUTPUT, @cExtScnUDF27 OUTPUT,
            @cExtScnUDF28   OUTPUT, @cExtScnUDF29 OUTPUT, @cExtScnUDF30 OUTPUT
            
            IF @nErrNo <> 0
            BEGIN
               GOTO  Quit
            END

            GOTO Quit
         END
      END -- ExtendedScreenSP <> ''

   END        
      
   -- Extended info        
   IF @cExtendedInfoSP <> ''        
   BEGIN        
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')        
      BEGIN      
         SET @cExtendedInfo = ''      
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +        
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +         
            ' @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption, ' +        
            ' @tExtInfo, @cExtendedInfo OUTPUT '        
         SET @cSQLParam =        
            ' @nMobile        INT,           ' +        
            ' @nFunc          INT,           ' +        
            ' @cLangCode      NVARCHAR( 3),  ' +        
            ' @nStep          INT,           ' +        
            ' @nAfterStep     INT,           ' +        
            ' @nInputKey      INT,           ' +        
            ' @cFacility      NVARCHAR( 5),  ' +        
            ' @cStorerKey     NVARCHAR( 15), ' +        
            ' @cGroupKey      NVARCHAR( 10), ' +        
            ' @cTaskDetailKey NVARCHAR( 10), ' +        
            ' @cCartId        NVARCHAR( 10), ' +        
            ' @cFromLoc       NVARCHAR( 10), ' +        
            ' @cCartonId      NVARCHAR( 20), ' +        
            ' @cSKU           NVARCHAR( 20), ' +        
            ' @nQty           INT,           ' +        
            ' @cOption        NVARCHAR( 1), ' +        
            ' @tExtInfo       VariableTable READONLY, ' +         
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT  '         
                    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
            @nMobile, @nFunc, @cLangCode, @nStep_Loc, @nStep, @nInputKey, @cFacility, @cStorerKey,         
            @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption,         
            @tExtInfo, @cExtendedInfo OUTPUT        
      
         IF @nErrNo <> 0         
            GOTO Quit      
                  
         IF @nStep = @nStep_SKUQTY      
            SET @cOutField15 = @cExtendedInfo      
      END        
   END        
   GOTO Quit         
         
   Step_Loc_Fail:        
   BEGIN        
      SET @cFromLOC = ''        
        
      SET @cOutField03 = ''        
   END        
END        
GOTO Quit        
        
/********************************************************************************          
Scn = 5923. SKU QTY screen          
   Carton ID   (field01)          
   SKU         (field02)          
   DESCR1      (field03)          
   DESCR1      (field04)          
   SKU/UPC     (field05, input)          
   PK QTY      (field06)          
   ACT QTY     (field07)          
********************************************************************************/          
Step_SKUQTY:          
BEGIN          
   IF @nInputKey = 1 -- Yes or Send          
   BEGIN         
      -- Screen mapping          
      SET @cBarcode = ''        
      SET @cBarcode = @cInField06 -- SKU          
      SET @cUPC = LEFT( @cInField06, 30)          
      SET @cQTY = CASE WHEN @cFieldAttr07 = 'O' THEN @cOutField07 ELSE @cInField07 END          
          
      -- Retain value          
      SET @cOutField07 = CASE WHEN @cFieldAttr07 = 'O' THEN @cOutField07 ELSE @cInField07 END -- MQTY          
        
      SET @cSKU = ''          
      SET @nQTY = 0          
              
      -- Check SKU blank          
      IF @cBarcode = ''         
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
                  SET @nErrNo = 171816          
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need SKU          
                  EXEC rdt.rdtSetFocusField @nMobile, 6 -- SKU          
                  GOTO Step_SKUQTY_Fail        
               END        
            END          
         END        
      END          
        
      -- Validate SKU          
      IF @cBarcode <> ''          
      BEGIN          
         IF @cBarcode = '99' -- Fully short          
         BEGIN          
            SET @cSKUValidated = '99'          
            SET @cQTY = '0'          
            SET @cOutField07 = '0'          
         END          
         ELSE          
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
                     ' @cTaskDetailKey    NVARCHAR( 10), ' +          
                     ' @cUPC              NVARCHAR( 30)  OUTPUT, ' +          
                     ' @cQTY              NVARCHAR( 5)   OUTPUT, ' +          
                     ' @nErrNo            INT            OUTPUT, ' +          
                     ' @cErrMsg           NVARCHAR( 20)  OUTPUT'          
          
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,          
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cBarcode,          
                     @cTaskDetailKey, @cUPC OUTPUT, @cQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT          
               END          
          
               IF @nErrNo <> 0          
               BEGIN          
                  EXEC rdt.rdtSetFocusField @nMobile, 6      
                  GOTO Step_SKUQTY_Fail          
               END            
            END          
          
            -- Get SKU count          
            DECLARE @nSKUCnt INT          
            SET @nSKUCnt = 0          
            EXEC RDT.rdt_GetSKUCNT          
                @cStorerKey  = @cStorerKey          
               ,@cSKU        = @cUPC          
               ,@nSKUCnt     = @nSKUCnt   OUTPUT          
               ,@bSuccess    = @bSuccess  OUTPUT          
               ,@nErr        = @nErrNo    OUTPUT          
               ,@cErrMsg     = @cErrMsg   OUTPUT          
          
            -- Check SKU          
            IF @nSKUCnt = 0          
            BEGIN          
               SET @nErrNo = 171817          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU          
               EXEC rdt.rdtSetFocusField @nMobile, 6      
               GOTO Step_SKUQTY_Fail          
            END          
          
            -- Check barcode return multi SKU          
            IF @nSKUCnt > 1          
            BEGIN          
               SET @nErrNo = 171818          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod          
               EXEC rdt.rdtSetFocusField @nMobile, 6      
               GOTO Step_SKUQTY_Fail          
            END          
          
            -- Get SKU          
            EXEC rdt.rdt_GetSKU          
                @cStorerKey  = @cStorerKey   
               ,@cSKU        = @cUPC      OUTPUT          
               ,@bSuccess    = @bSuccess  OUTPUT          
               ,@nErr        = @nErrNo    OUTPUT          
               ,@cErrMsg     = @cErrMsg   OUTPUT          
            IF @nErrNo <> 0          
               GOTO Step_SKUQTY_Fail          
          
            SET @cSKU = @cUPC          
          
            -- Validate SKU          
            IF @cSKU <> @cSuggSKU          
            BEGIN          
               SET @nErrNo = 171819          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong SKU          
               EXEC rdt.rdtSetFocusField @nMobile, 6  -- SKU          
               GOTO Step_SKUQTY_Fail          
            END          
          
            -- Mark SKU as validated          
            SET @cSKUValidated = '1'          
         END          
      END          
          
      -- Validate QTY          
      IF @cQTY <> '' AND RDT.rdtIsValidQTY( @cQTY, 0) = 0          
      BEGIN          
         SET @nErrNo = 171820          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY          
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- QTY          
         GOTO Step_SKUQTY_Fail          
      END          
          
      -- Check full short with QTY          
      IF @cSKUValidated = '99' AND @cQTY <> '0' AND @cQTY <> ''          
      BEGIN          
         SET @nErrNo = 171821          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AllShortWithQTY          
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- QTY          
         GOTO Step_SKUQTY_Fail          
      END          
          
      -- Top up QTY          
      IF @cSKUValidated = '99' -- Fully short          
         SET @nQTY = 0          
      ELSE IF @nQTY > 0          
         SET @nQTY = @nActQTY + @nQTY          
      ELSE          
         IF @cSKU <> '' AND @cDisableQTYField = '1' AND @cDefaultQTY <> '1'          
            SET @nQTY = @nActQTY + 1          
         ELSE          
            SET @nQTY = CAST( @cQTY AS INT)          
          
      -- Check over pick          
      IF ( @nActQTY + @nQTY) > @nSuggQTY          
      BEGIN          
         SET @nErrNo = 171822          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Over pick          
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- PQTY          
         GOTO Step_SKUQTY_Fail          
      END         
                
      -- Extended validate        
      IF @cExtendedValidateSP <> ''        
      BEGIN        
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +         
               ' @cGroupKey, @cTaskDetailKey, @cPickZone, @cCartId, @cMethod, @cFromLoc, @cCartonId, ' +        
               ' @cSKU, @nQty, @cOption, @cToLOC, @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
        
            SET @cSQLParam =        
               ' @nMobile        INT,           ' +        
               ' @nFunc          INT,           ' +        
               ' @cLangCode      NVARCHAR( 3),  ' +        
               ' @nStep          INT,           ' +        
               ' @nInputKey      INT,           ' +        
               ' @cFacility      NVARCHAR( 5),  ' +        
               ' @cStorerKey     NVARCHAR( 15), ' +      
               ' @cGroupKey      NVARCHAR( 10), ' +        
              ' @cTaskDetailKey NVARCHAR( 10), ' +      
               ' @cPickZone      NVARCHAR( 10), ' +        
               ' @cCartId        NVARCHAR( 10), ' +      
               ' @cMethod        NVARCHAR( 1),  ' +        
               ' @cFromLoc       NVARCHAR( 10), ' +        
               ' @cCartonId      NVARCHAR( 20), ' +       
               ' @cSKU           NVARCHAR( 20), ' +        
               ' @nQty           INT,           ' +        
               ' @cOption        NVARCHAR( 1), ' +        
               ' @cToLOC         NVARCHAR( 10), ' +      
               ' @tExtValidate   VariableTable READONLY, ' +         
               ' @nErrNo         INT           OUTPUT, ' +        
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,         
               @cGroupKey, @cTaskDetailKey, @cPickZone, @cCartId, @cMethod, @cFromLoc, @cCartonId,       
               @cSKU, @nQty, @cOption, @cToLoc, @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT        
        
            IF @nErrNo <> 0         
               GOTO Step_SKUQTY_Fail --v1.8.1
         END        
      END        
        
      -- Save to ActQTY          
      SET @nActQTY = @nActQTY + @nQTY          
          
      -- SKU scanned, remain in current screen          
      IF (@cBarcode <> ''  AND @cBarcode <> '99') OR (@cSKUValidated = '1' AND @nQTY > 0)  --v1.8
      BEGIN          
         SET @cOutField06 = '' -- SKU          
         SET @cOutField07 = CASE WHEN @cDefaultQTY = '0' THEN '' ELSE @cDefaultQTY END -- QTY        
         SET @cOutField08 = @nActQTY        
         SET @cSKUValidated = '1'        
                 
         IF @cDisableQTYField = '1'          
         BEGIN          
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- SKU          
                  
            IF @nActQTY <> @nSuggQTY          
               GOTO Quit_StepSKUQTY                 
         END          
         ELSE          
         BEGIN          
            IF @cDefaultQTY = '0'      
               EXEC rdt.rdtSetFocusField @nMobile, 7 -- MQTY          
            ELSE      
               EXEC rdt.rdtSetFocusField @nMobile, 6 -- SKU      
                     
            IF @nActQTY <> @nSuggQTY          
               GOTO Quit_StepSKUQTY                 
         END          
      END          
          
      -- QTY short          
      IF @nActQTY < @nSuggQTY          
      BEGIN          
         --SET @nActQTY = @nActQTY - @nQTY --v1.8
        
         -- Prepare next screen var          
         SET @cOption = ''          
         SET @cOutField01 = @cCartPickMethod      
         SET @cOutField02 = '' -- Option          
      
         -- Enable field          
         SET @cFieldAttr07 = '' -- QTY          
          
         SET @nScn = @nScn_Option          
         SET @nStep = @nStep_Option          
      END          
          
      -- QTY fulfill          
      IF @nActQTY = @nSuggQTY          
      BEGIN          
         -- Confirm          
         EXEC rdt.rdt_TM_Assist_ClusterPick_ConfirmPick           
            @nMobile          = @nMobile,          
            @nFunc            = @nFunc,          
            @cLangCode        = @cLangCode,          
            @nStep            = @nStep,          
            @nInputKey        = @nInputKey,          
            @cFacility        = @cFacility,          
            @cStorerKey       = @cStorerKey,          
            @cType            = 'CONFIRM',   -- CONFIRM/SHORT/CLOSE          
            @cCartID          = @cCartID,      
            @cGroupKey        = @cGroupKey,      
            @cTaskDetailKey   = @cTaskDetailKey,          
            @nQTY             = @nActQTY,          
            @tConfirm         = @tConfirm,        
            @nErrNo           = @nErrNo   OUTPUT,          
            @cErrMsg          = @cErrMsg  OUTPUT          
        
         IF @nErrNo <> 0          
            GOTO Quit          
          
         -- Extended update        
         IF @cExtendedUpdateSP <> ''        
         BEGIN        
            IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')        
            BEGIN        
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +        
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +         
                  ' @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption, ' +        
                  ' @tExtUpdate, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
        
               SET @cSQLParam =        
                  ' @nMobile        INT,           ' +        
                  ' @nFunc          INT,           ' +        
                  ' @cLangCode      NVARCHAR( 3),  ' +        
                  ' @nStep          INT,           ' +        
                  ' @nInputKey      INT,           ' +                        ' @cFacility      NVARCHAR( 5),  ' +        
                  ' @cStorerKey     NVARCHAR( 15), ' +        
                  ' @cGroupKey      NVARCHAR( 10), ' +        
                  ' @cTaskDetailKey NVARCHAR( 10), ' +        
                  ' @cCartId        NVARCHAR( 10), ' +        
                  ' @cFromLoc       NVARCHAR( 10), ' +        
                  ' @cCartonId      NVARCHAR( 20), ' +        
                  ' @cSKU           NVARCHAR( 20), ' +        
                  ' @nQty           INT,           ' +        
                  ' @cOption        NVARCHAR( 1), ' +        
                  ' @tExtUpdate     VariableTable READONLY, ' +         
                  ' @nErrNo         INT           OUTPUT, ' +        
                  ' @cErrMsg        NVARCHAR( 20) OUTPUT  '        
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,         
                  @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption,         
                  @tExtUpdate, @nErrNo OUTPUT, @cErrMsg OUTPUT        
        
               IF @nErrNo <> 0         
                  GOTO Step_SKUQTY_Fail        
            END        
         END                
               
         SELECT       
            @cPosition = StatusMsg,       
            @cSuggToteId = DropID      
         FROM dbo.TaskDetail WITH (NOLOCK)      
         WHERE TaskDetailKey = @cTaskDetailKey      
      
         -- Prepare next screen var      
         SET @cOutField01 = @cCartPickMethod      
         SET @cOutField02 = @cSuggFromLOC      
         SET @cOutField03 = @cSuggToteId      
         SET @cOutField04 = ''      
         SET @cOutField05 = @cPosition      
               
         SET @nScn = @nScn_ConfirmTote      
         SET @nStep = @nStep_ConfirmTote      
               
         GOTO Quit      
      END      
      
      Quit_StepSKUQTY:          
      -- Extended info        
      IF @cExtendedInfoSP <> ''        
      BEGIN        
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')        
         BEGIN      
            SET @cExtendedInfo = ''      
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +         
               ' @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption, ' +        
               ' @tExtInfo, @cExtendedInfo OUTPUT '        
        
            SET @cSQLParam =        
               ' @nMobile        INT,           ' +        
               ' @nFunc          INT,           ' +        
               ' @cLangCode      NVARCHAR( 3),  ' +        
               ' @nStep          INT,           ' +        
               ' @nAfterStep     INT,           ' +        
               ' @nInputKey      INT,           ' +        
               ' @cFacility      NVARCHAR( 5),  ' +        
               ' @cStorerKey     NVARCHAR( 15), ' +        
               ' @cGroupKey      NVARCHAR( 10), ' +        
               ' @cTaskDetailKey NVARCHAR( 10), ' +        
               ' @cCartId        NVARCHAR( 10), ' +        
               ' @cFromLoc       NVARCHAR( 10), ' +        
               ' @cCartonId      NVARCHAR( 20), ' +        
               ' @cSKU           NVARCHAR( 20), ' +        
               ' @nQty           INT,           ' +        
               ' @cOption        NVARCHAR( 1), ' +        
               ' @tExtInfo       VariableTable READONLY, ' +         
               ' @cExtendedInfo  NVARCHAR( 20) OUTPUT  '         
                       
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep_SKUQTY, @nStep, @nInputKey, @cFacility, @cStorerKey,         
               @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption,         
               @tExtInfo, @cExtendedInfo OUTPUT        
        
            IF @nErrNo <> 0         
               GOTO Quit      
                     
            IF @nStep = @nStep_SKUQTY      
               SET @cOutField15 = @cExtendedInfo      
         END        
      END                
   END          
          
   IF @nInputKey = 0 -- ESC          
   BEGIN          
      -- Prepare next screen var        
      SET @cOutField01 = @cCartPickMethod      
      SET @cOutField02 = @cSuggFromLOC         
      SET @cOutField03 = ''         
      
      -- Go to next screen        
      SET @nScn = @nScn_Loc        
      SET @nStep = @nStep_Loc        
   END          
   GOTO Quit          
          
   Step_SKUQTY_Fail:          
   BEGIN          
      IF @cSKUValidated = '1'        
         SET @cOutField06 = @cSKU        
      ELSE        
         SET @cOutField06 = '' -- SKU          
   END          
END          
GOTO Quit          
        
/********************************************************************************          
Scn = 5686. Confirm Tote Id              
   LOC         (field01)          
   TOTE ID     (field02, input)      
   POSITION    (field03)        
********************************************************************************/          
Step_ConfirmTote:                  
BEGIN                  
   IF @nInputKey = 1 -- ENTER                  
   BEGIN                  
      -- Screen mapping                  
      SET @cCartonID = @cOutField03      
      SET @cCartonId2Confirm = @cInField04                  
                  
      -- Validate blank                  
      IF @cCartonId2Confirm = ''                  
      BEGIN                  
         SET @nErrNo = 171823                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Tote Id                  
         GOTO Step_ConfirmTote_Fail                  
      END                  
                  
      -- Validate option                  
      IF @cCartonID <> @cCartonId2Confirm        
      BEGIN                  
         SET @nErrNo = 171824                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Not Match                  
         GOTO Step_ConfirmTote_Fail                  
      END                  
      
      -- Get task in same LOC          
      SET @cSKUValidated = '0'          
      SET @nActQTY = 0          
                 
      SET @nErrNo = 0        
      EXEC [RDT].[rdt_TM_Assist_ClusterPick_GetTask]         
         @nMobile          = @nMobile,        
         @nFunc            = @nFunc,        
         @cLangCode        = @cLangCode,        
         @nStep            = @nStep,        
         @nInputKey        = @nInputKey,        
         @cFacility        = @cFacility,        
         @cStorerKey       = @cStorerKey,        
         @cGroupKey        = @cGroupKey,        
         @cCartId          = @cCartId,        
         @cType            = 'NEXTSKU',        
         @cTaskDetailKey   = @cTaskDetailKey OUTPUT,        
         @cFromLoc         = @cSuggFromLOC   OUTPUT,        
         @cCartonId        = @cSuggCartonID  OUTPUT,        
         @cToteId          = @cSuggToteId    OUTPUT,      
         @cSKU             = @cSuggSKU       OUTPUT,        
         @nQty             = @nSuggQty       OUTPUT,        
         @tGetTask         = @tGetTask,         
         @nErrNo           = @nErrNo         OUTPUT,        
         @cErrMsg          = @cErrMsg        OUTPUT        
        
      IF @nErrNo = 0          
      BEGIN          
         SELECT @cSKUDescr = DESCR        
         FROM dbo.SKU WITH (NOLOCK)        
         WHERE StorerKey = @cStorerKey        
         AND   SKU = @cSuggSKU        
        
         SELECT @nSuggQty = ISNULL( SUM( Qty), 0)        
         FROM dbo.PICKDETAIL WITH (NOLOCK)        
         WHERE StorerKey = @cStorerKey        
         AND   Loc = @cFromLoc        
         AND   Sku = @cSuggSKU        
         AND   CaseID = @cSuggCartonID        
         AND   [Status] < @cPickConfirmStatus      
        
         SELECT @nPickedQty = ISNULL( SUM( Qty), 0)        
         FROM dbo.PICKDETAIL WITH (NOLOCK)        
         WHERE StorerKey = @cStorerKey        
         AND   Loc = @cFromLoc        
         AND   Sku = @cSuggSKU        
         AND   CaseID = @cSuggCartonID        
         AND   [Status] = @cPickConfirmStatus        
              
         -- Prepare SKU QTY screen var        
         SET @cOutField01 = @cCartPickMethod      
         SET @cOutField02 = @cSuggFromLOC        
         SET @cOutField03 = @cSuggSKU        
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)        
         SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)        
         SET @cOutField06 = ''   -- SKU/UPC        
         SET @cOutField07 = CASE WHEN @cDefaultQTY = '0' THEN '' ELSE @cDefaultQTY END -- QTY        
         SET @cOutField08 = @nPickedQty        
         SET @cOutField09 = @nSuggQty        
         SET @cOutField15 = '' -- ExtendedInfo      
               
         EXEC rdt.rdtSetFocusField @nMobile, 6      
      
         -- Go to next screen        
         SET @nScn = @nScn_SKUQTY      
         SET @nStep = @nStep_SKUQTY        
      END          
      ELSE          
      BEGIN          
         -- Clear 'No Task' error from previous get task          
         SET @nErrNo = 0          
         SET @cErrMsg = ''          
        
         -- Get task in next LOC          
         SET @cSKUValidated = '0'          
         SET @nActQTY = 0          
         SET @cSuggSKU = ''        
        
         SET @nErrNo = 0        
         EXEC [RDT].[rdt_TM_Assist_ClusterPick_GetTask]         
            @nMobile          = @nMobile,        
            @nFunc            = @nFunc,        
            @cLangCode        = @cLangCode,        
            @nStep            = @nStep,        
            @nInputKey        = @nInputKey,        
            @cFacility        = @cFacility,        
            @cStorerKey       = @cStorerKey,        
            @cGroupKey        = @cGroupKey,        
            @cCartId          = @cCartId,        
            @cType            = 'NEXTCARTON',        
            @cTaskDetailKey   = @cTaskDetailKey OUTPUT,        
            @cFromLoc         = @cSuggFromLOC   OUTPUT,        
            @cCartonId        = @cSuggCartonID  OUTPUT,        
            @cToteId          = @cSuggToteId    OUTPUT,      
            @cSKU             = @cSuggSKU       OUTPUT,        
            @nQty             = @nSuggQty       OUTPUT,        
            @tGetTask         = @tGetTask,         
            @nErrNo           = @nErrNo         OUTPUT,        
            @cErrMsg          = @cErrMsg        OUTPUT        
                  
         IF @nErrNo = 0        
         BEGIN        
            SELECT @cSKUDescr = DESCR        
            FROM dbo.SKU WITH (NOLOCK)        
            WHERE StorerKey = @cStorerKey        
            AND   SKU = @cSuggSKU        
        
            SELECT @nSuggQty = ISNULL( SUM( Qty), 0)        
            FROM dbo.PICKDETAIL WITH (NOLOCK)        
            WHERE StorerKey = @cStorerKey        
            AND   Loc = @cFromLoc        
            AND   Sku = @cSuggSKU        
            AND   CaseID = @cSuggCartonID      
            AND   [Status] < @cPickConfirmStatus      
        
            SELECT @nPickedQty = ISNULL( SUM( Qty), 0)        
            FROM dbo.PICKDETAIL WITH (NOLOCK)        
            WHERE StorerKey = @cStorerKey        
            AND   Loc = @cFromLoc        
            AND   Sku = @cSuggSKU        
            AND   CaseID = @cSuggCartonID        
            AND   [Status] = @cPickConfirmStatus        
              
            -- Prepare SKU QTY screen var        
            SET @cOutField01 = @cCartPickMethod      
            SET @cOutField02 = @cSuggFromLOC        
            SET @cOutField03 = @cSuggSKU        
            SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)        
            SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)        
            SET @cOutField06 = ''   -- SKU/UPC        
            SET @cOutField07 = CASE WHEN @cDefaultQTY = '0' THEN '' ELSE @cDefaultQTY END -- QTY        
            SET @cOutField08 = @nPickedQty        
            SET @cOutField09 = @nSuggQty        
            SET @cOutField15 = '' -- ExtendedInfo      
      
            EXEC rdt.rdtSetFocusField @nMobile, 6      
      
            -- Go to next screen        
            SET @nScn = @nScn_SKUQTY      
           SET @nStep = @nStep_SKUQTY        
         END        
         ELSE        
         BEGIN           
            -- Clear 'No Task' error from previous get task          
            SET @nErrNo = 0          
            SET @cErrMsg = ''          
        
            -- Get task in next LOC          
            SET @cSKUValidated = '0'          
            SET @nActQTY = 0          
            SET @cSuggSKU = ''        
        
            SET @nErrNo = 0        
            EXEC [RDT].[rdt_TM_ClusterPick_GetTask]         
               @nMobile          = @nMobile,        
               @nFunc            = @nFunc,        
               @cLangCode        = @cLangCode,        
               @nStep            = @nStep,        
               @nInputKey        = @nInputKey,        
               @cFacility        = @cFacility,        
               @cStorerKey       = @cStorerKey,        
               @cGroupKey        = @cGroupKey,        
               @cCartId          = @cCartId,        
               @cType            = 'NEXTLOC',        
               @cTaskDetailKey   = @cTaskDetailKey OUTPUT,        
               @cFromLoc         = @cSuggFromLOC   OUTPUT,        
               @cCartonId        = @cSuggCartonID  OUTPUT,        
               @cSKU             = @cSuggSKU       OUTPUT,        
               @nQty             = @nSuggQty       OUTPUT,        
               @tGetTask         = @tGetTask,         
               @nErrNo           = @nErrNo         OUTPUT,        
               @cErrMsg          = @cErrMsg        OUTPUT        
                    
            IF @nErrNo = 0          
            BEGIN          
               SELECT TOP 1         
                  @cTaskDetailKey = TaskDetailKey,        
                  @cSuggFromLOC = FromLoc        
               FROM dbo.TaskDetail WITH (NOLOCK)        
               WHERE Storerkey = @cStorerKey        
               AND   TaskType = 'CPK'        
               AND   [Status] = '3'        
               AND   Groupkey = @cGroupKey        
               AND   DeviceID = @cCartID        
               AND   FromLoc = @cSuggFromLOC        
               AND   Sku = @cSuggSKU        
               AND   Caseid = @cSuggCartonID        
               ORDER BY 1        
        
               -- Prepare next screen var        
               SET @cOutField01 = @cCartPickMethod      
               SET @cOutField02 = @cSuggFromLOC         
               SET @cOutField03 = ''        
                        
               -- Go to next screen        
               SET @nScn = @nScn_Loc        
               SET @nStep = @nStep_Loc        
            END          
            ELSE        
            BEGIN        
               -- Scan out          
               SET @nErrNo = 0
               EXEC rdt.rdt_TM_Assist_ClusterPick_ScanOut @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey          
                  ,@cTaskDetailKey          
                  ,@nErrNo       OUTPUT          
                  ,@cErrMsg      OUTPUT          
               IF @nErrNo <> 0          
                  GOTO Quit          
          
               -- Clear 'No Task' error from previous get task          
               SET @nErrNo = 0          
               SET @cErrMsg = ''          
      
               SELECT @cSuggToLOC = ToLoc      
               FROM dbo.TaskDetail WITH (NOLOCK)      
               WHERE TaskDetailKey = @cTaskDetailKey      
      
               IF @cConfirmToLoc = '1'      
               BEGIN      
                  -- Prepare next screen var          
                  SET @cOutField01 = @cCartPickMethod      
                  SET @cOutField02 = @cSuggToLOC -- To LOC          
                  SET @cOutField03 = ''        
                        
                  -- Go to To LOC screen          
                  SET @nScn = @nScn_ToLoc          
                  SET @nStep = @nStep_ToLoc          
               END      
               ELSE      
               BEGIN      
                  SET @cOutField01 = @cCartPickMethod      
                  SET @cOutField02 = @cSuggToLOC -- To LOC          
                  SET @cInField03 = @cSuggToLOC
                        
                  -- Go to To LOC screen          
                  SET @nScn = @nScn_ToLoc          
                  SET @nStep = @nStep_ToLoc          
       
                  GOTO Step_ToLoc      
                  /*      
                  -- Prepare next screen var          
                  SET @cOutField01 = @cCartPickMethod          
                  SET @cOutField02 = @cCartID      
                
                  SET @nScn = @nScn_NextTask        
                  SET @nStep = @nStep_NextTask                        
                  */      
               END      
            END        
         END      
      END          
   END                  
                  
   IF @nInputKey = 0        
   BEGIN        
      -- User must confirm tote as this point because the sku already picked      
      -- User might not know where to put back sku      
      SET @nErrNo = 171836                  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Confirm Tote                  
      GOTO Step_ConfirmTote_Fail                  
      
      /*      
      SELECT @cSKUDescr = DESCR        
      FROM dbo.SKU WITH (NOLOCK)        
      WHERE StorerKey = @cStorerKey        
      AND   SKU = @cSuggSKU        
        
      SELECT @nSuggQty = ISNULL( SUM( Qty), 0)        
      FROM dbo.PICKDETAIL WITH (NOLOCK)        
      WHERE StorerKey = @cStorerKey        
      AND   Loc = @cFromLoc        
      AND   Sku = @cSuggSKU        
      AND   CaseID = @cSuggCartonID        
      AND   [Status] < @cPickConfirmStatus      
        
      SELECT @nPickedQty = ISNULL( SUM( Qty), 0)        
      FROM dbo.PICKDETAIL WITH (NOLOCK)        
      WHERE StorerKey = @cStorerKey        
      AND   Loc = @cFromLoc        
      AND   Sku = @cSuggSKU        
      AND   CaseID = @cSuggCartonID        
      AND   [Status] = @cPickConfirmStatus        
              
      -- Prepare SKU QTY screen var        
      SET @cOutField01 = @cCartPickMethod      
      SET @cOutField02 = @cSuggFromLOC        
      SET @cOutField03 = @cSuggSKU        
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)        
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)        
      SET @cOutField06 = ''   -- SKU/UPC        
      SET @cOutField07 = CASE WHEN @cDefaultQTY = '0' THEN '' ELSE @cDefaultQTY END -- QTY        
      SET @cOutField08 = @nPickedQty        
      SET @cOutField09 = @nSuggQty        
      
      EXEC rdt.rdtSetFocusField @nMobile, 6      
      
      -- Enable field        
      IF @cDisableQTYField = '1'        
      BEGIN        
         SET @cFieldAttr07 = 'O'        
         SET @cOutField07 = CASE WHEN @cDefaultQTY = '0' THEN '1' ELSE @cDefaultQTY END        
      END        
      ELSE        
         SET @cFieldAttr07 = ''        
        
      SET @cSKUValidated = '0'        
        
      -- Go to next screen        
      SET @nScn = @nScn_SKUQTY        
      SET @nStep = @nStep_SKUQTY  */      
   END             
      
   -- Extended info        
   IF @cExtendedInfoSP <> ''        
   BEGIN        
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')        
      BEGIN      
         SET @cExtendedInfo = ''      
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +        
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +         
            ' @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption, ' +        
            ' @tExtInfo, @cExtendedInfo OUTPUT '        
         SET @cSQLParam =        
            ' @nMobile        INT,           ' +        
            ' @nFunc          INT,           ' +        
            ' @cLangCode      NVARCHAR( 3),  ' +        
            ' @nStep          INT,           ' +        
            ' @nAfterStep     INT,           ' +        
            ' @nInputKey      INT,           ' +        
            ' @cFacility      NVARCHAR( 5),  ' +        
            ' @cStorerKey     NVARCHAR( 15), ' +        
            ' @cGroupKey      NVARCHAR( 10), ' +        
            ' @cTaskDetailKey NVARCHAR( 10), ' +        
            ' @cCartId        NVARCHAR( 10), ' +        
            ' @cFromLoc       NVARCHAR( 10), ' +        
            ' @cCartonId      NVARCHAR( 20), ' +        
            ' @cSKU           NVARCHAR( 20), ' +        
            ' @nQty           INT,           ' +        
            ' @cOption        NVARCHAR( 1), ' +        
            ' @tExtInfo       VariableTable READONLY, ' +         
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT  '         
                    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
            @nMobile, @nFunc, @cLangCode, @nStep_ConfirmTote, @nStep, @nInputKey, @cFacility, @cStorerKey,         
            @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption,         
            @tExtInfo, @cExtendedInfo OUTPUT        
      
         IF @nErrNo <> 0         
            GOTO Quit      
                  
         IF @nStep = @nStep_SKUQTY      
            SET @cOutField15 = @cExtendedInfo      
      END        
   END        
   GOTO Quit                  
                  
   Step_ConfirmTote_Fail:                  
   BEGIN                  
      -- Reset this screen var                  
      SET @cCartonId2Confirm = ''      
      
      SET @cOutField04 = ''                  
   END                  
END                  
GOTO Quit            
      
/********************************************************************************          
Scn = 5924. Confirm Short Pick?              
   Option   (field01, input)          
********************************************************************************/          
Step_Option:                  
BEGIN                  
   IF @nInputKey = 1 -- ENTER                  
   BEGIN                  
      -- Screen mapping                  
      SET @cOption = @cInField02                  
                  
      -- Validate blank                  
      IF @cOption = ''                  
      BEGIN                  
         SET @nErrNo = 171825                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option required                  
         GOTO Step_Option_Fail                  
      END                  
                  
      -- Validate option                  
      IF @cOption NOT IN ( '1', '2')      
      BEGIN                  
         SET @nErrNo = 171826                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option                  
         GOTO Step_Option_Fail                  
      END                  
      
      -- Handling transaction                  
      SET @nTranCount = @@TRANCOUNT                  
      BEGIN TRAN  -- Begin our own transaction                  
      SAVE TRAN Step_Option -- For rollback or commit only our own transaction                  
                  
      -- Confirm                  
      IF @cOption = '1'                  
      BEGIN                  
         -- Confirm          
         EXEC rdt.rdt_TM_Assist_ClusterPick_ConfirmPick           
            @nMobile          = @nMobile,          
            @nFunc            = @nFunc,          
            @cLangCode        = @cLangCode,          
            @nStep            = @nStep,          
            @nInputKey        = @nInputKey,          
            @cFacility        = @cFacility,          
            @cStorerKey       = @cStorerKey,          
            @cType            = 'SHORT',        
            @cCartID          = @cCartID,      
            @cGroupKey        = @cGroupKey,       
            @cTaskDetailKey   = @cTaskDetailKey,          
            @nQTY             = @nActQTY,          
            @tConfirm         = @tConfirm,        
            @nErrNo           = @nErrNo   OUTPUT,          
            @cErrMsg          = @cErrMsg  OUTPUT          
        
         IF @nErrNo <> 0                  
         BEGIN                  
            ROLLBACK TRAN Step_Option                  
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started                  
               COMMIT TRAN                  
            GOTO Step_Option_Fail                  
         END                  
      END            
        
      -- Extended update        
      IF @cExtendedUpdateSP <> ''        
      BEGIN        
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +         
               ' @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption, ' +        
               ' @tExtUpdate, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
       
            SET @cSQLParam =        
               ' @nMobile        INT,           ' +        
               ' @nFunc          INT,           ' +        
               ' @cLangCode      NVARCHAR( 3),  ' +        
               ' @nStep          INT,           ' +        
               ' @nInputKey      INT,           ' +        
               ' @cFacility      NVARCHAR( 5),  ' +        
               ' @cStorerKey     NVARCHAR( 15), ' +        
               ' @cGroupKey      NVARCHAR( 10), ' +        
               ' @cTaskDetailKey NVARCHAR( 10), ' +        
               ' @cCartId        NVARCHAR( 10), ' +        
               ' @cFromLoc       NVARCHAR( 10), ' +        
               ' @cCartonId      NVARCHAR( 20), ' +        
               ' @cSKU           NVARCHAR( 20), ' +        
               ' @nQty           INT,           ' +        
               ' @cOption        NVARCHAR( 1), ' +        
               ' @tExtUpdate     VariableTable READONLY, ' +         
               ' @nErrNo         INT           OUTPUT, ' +        
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,         
               @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption,         
               @tExtUpdate, @nErrNo OUTPUT, @cErrMsg OUTPUT        
        
            IF @nErrNo <> 0                  
            BEGIN                  
               ROLLBACK TRAN Step_Option                  
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN                  
               GOTO Step_Option_Fail                  
            END          
         END        
      END                
              
      COMMIT TRAN Step_Option -- Only commit change made here                  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started                  
         COMMIT TRAN                 
                
      IF @cOption = '1'  -- Short                  
      BEGIN                  
         SELECT       
            @cPosition = StatusMsg,       
            @cSuggToteId = DropID      
         FROM dbo.TaskDetail WITH (NOLOCK)      
         WHERE TaskDetailKey = @cTaskDetailKey      
      
         -- Prepare next screen var      
         SET @cOutField01 = @cCartPickMethod      
         SET @cOutField02 = @cSuggFromLOC      
         SET @cOutField03 = @cSuggToteId      
         SET @cOutField04 = ''      
         SET @cOutField05 = @cPosition      
               
         SET @nScn = @nScn_ConfirmTote      
         SET @nStep = @nStep_ConfirmTote      
      END                  
      
      IF @cOption = '2'        
      BEGIN        
         SELECT @nPickedQty = ISNULL( SUM( Qty), 0)        
         FROM dbo.PICKDETAIL WITH (NOLOCK)        
         WHERE StorerKey = @cStorerKey        
         AND   Loc = @cFromLoc        
         AND   Sku = @cSuggSKU        
         AND   CaseID = @cSuggCartonID        
         AND   [Status] = @cPickConfirmStatus        
              
         -- Prepare next screen var        
         SET @cOutField01 = @cCartPickMethod      
         SET @cOutField02 = @cSuggFromLOC        
         SET @cOutField03 = @cSuggSKU        
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)        
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)        
         SET @cOutField06 = ''   -- SKU/UPC        
    SET @cOutField07 = CASE WHEN @cDefaultQTY = '0' THEN '' ELSE @cDefaultQTY END -- QTY        
         SET @cOutField08 = @nActQTY--@nPickedQty        
         SET @cOutField09 = @nSuggQty        
         SET @cOutField15 = '' -- ExtendedInfo      
            
         -- Enable field        
         IF @cDisableQTYField = '1'        
            SET @cFieldAttr07 = 'O'        
         ELSE        
            SET @cFieldAttr07 = ''        
        
         EXEC rdt.rdtSetFocusField @nMobile, 6  --SKU        
        
         SET @cSKUValidated = '0'           
        
         -- Go to next screen        
         SET @nScn = @nScn_SKUQTY        
         SET @nStep = @nStep_SKUQTY        
      END             
      END                  
                  
   IF @nInputKey = 0        
   BEGIN        
      SELECT @nPickedQty = ISNULL( SUM( Qty), 0)        
      FROM dbo.PICKDETAIL WITH (NOLOCK)        
      WHERE StorerKey = @cStorerKey        
      AND   Loc = @cFromLoc        
      AND   Sku = @cSuggSKU        
      AND   CaseID = @cSuggCartonID        
      AND   [Status] = @cPickConfirmStatus        
              
      -- Prepare next screen var        
      SET @cOutField01 = @cCartPickMethod      
      SET @cOutField02 = @cSuggFromLOC        
      SET @cOutField03 = @cSuggSKU        
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)        
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)        
      SET @cOutField06 = ''   -- SKU/UPC        
      SET @cOutField07 = CASE WHEN @cDefaultQTY = '0' THEN '' ELSE @cDefaultQTY END -- QTY        
      SET @cOutField08 = @nActQTY--@nPickedQty        
      SET @cOutField09 = @nSuggQty        
      SET @cOutField15 = '' -- ExtendedInfo      
            
      -- Enable field        
      IF @cDisableQTYField = '1'        
         SET @cFieldAttr07 = 'O'        
      ELSE        
         SET @cFieldAttr07 = ''        
        
      EXEC rdt.rdtSetFocusField @nMobile, 6  --SKU        
        
      SET @cSKUValidated = '0'           
        
      -- Go to next screen     
      SET @nScn = @nScn_SKUQTY        
      SET @nStep = @nStep_SKUQTY        
   END             
      
   -- Extended info        
   IF @cExtendedInfoSP <> ''        
   BEGIN        
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')        
      BEGIN      
         SET @cExtendedInfo = ''      
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedInfoSP) +        
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, ' +         
            ' @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption, ' +        
            ' @tExtInfo, @cExtendedInfo OUTPUT '        
         SET @cSQLParam =        
            ' @nMobile        INT,           ' +        
            ' @nFunc          INT,           ' +        
            ' @cLangCode      NVARCHAR( 3),  ' +        
            ' @nStep          INT,           ' +        
            ' @nAfterStep     INT,           ' +        
            ' @nInputKey      INT,           ' +        
            ' @cFacility      NVARCHAR( 5),  ' +        
            ' @cStorerKey     NVARCHAR( 15), ' +        
            ' @cGroupKey      NVARCHAR( 10), ' +        
            ' @cTaskDetailKey NVARCHAR( 10), ' +        
            ' @cCartId        NVARCHAR( 10), ' +        
            ' @cFromLoc       NVARCHAR( 10), ' +        
            ' @cCartonId      NVARCHAR( 20), ' +        
            ' @cSKU           NVARCHAR( 20), ' +        
            ' @nQty           INT,           ' +        
            ' @cOption        NVARCHAR( 1), ' +        
            ' @tExtInfo       VariableTable READONLY, ' +         
            ' @cExtendedInfo  NVARCHAR( 20) OUTPUT  '         
                    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
            @nMobile, @nFunc, @cLangCode, @nStep_Option, @nStep, @nInputKey, @cFacility, @cStorerKey,         
            @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption,         
            @tExtInfo, @cExtendedInfo OUTPUT        
      
         IF @nErrNo <> 0         
            GOTO Quit
                  
         IF @nStep = @nStep_SKUQTY      
            SET @cOutField15 = @cExtendedInfo      
      END        
   END        
   GOTO Quit                  
                  
   Step_Option_Fail:                  
   BEGIN                  
      -- Reset this screen var                  
      SET @cOutField01 = '' --Option                  
   END                  
END                  
GOTO Quit            
      
/********************************************************************************          
Scn = 5687. To Loc             
   Sugg To Loc (field01)          
   To Loc      (field01, input)        
********************************************************************************/          
Step_ToLoc:        
BEGIN        
   IF @nInputKey = 1 -- ENTER          
   BEGIN          
      -- Screen mapping          
      SET @cSuggToLOC = @cOutField02        
      SET @cToLOC = @cInField03          
          
      -- Check blank FromLOC          
      IF @cToLOC = ''          
      BEGIN          
         SET @nErrNo = 171827          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC needed          
         GOTO Step_ToLoc_Fail          
      END          
          
      -- Check if FromLOC match          
      IF @cToLOC <> @cSuggToLOC  AND ISNULL( @cSuggToLOC, '') <> ''        
      BEGIN          
         IF @cOverwriteToLOC = '0'          
         BEGIN          
            SET @nErrNo = 171828          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC Diff          
            GOTO Step_ToLoc_Fail          
         END          
                   
         -- Check ToLOC valid          
         IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC)          
         BEGIN          
            SET @nErrNo = 171829          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC          
            GOTO Step_ToLoc_Fail          
         END          
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cGroupKey, @cTaskDetailKey, @cPickZone, @cCartId, @cMethod, @cFromLoc, @cCartonId, ' +
               ' @cSKU, @nQty, @cOption, @cToLOC, @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               ' @nMobile        INT,           ' +
               ' @nFunc          INT,           ' +
               ' @cLangCode      NVARCHAR( 3),  ' +
               ' @nStep          INT,           ' +
               ' @nInputKey      INT,           ' +
               ' @cFacility      NVARCHAR( 5),  ' +
               ' @cStorerKey     NVARCHAR( 15), ' +
               ' @cGroupKey      NVARCHAR( 10), ' +
               ' @cTaskDetailKey NVARCHAR( 10), ' +
               ' @cPickZone      NVARCHAR( 10), ' +
               ' @cCartId        NVARCHAR( 10), ' +
               ' @cMethod        NVARCHAR( 1),  ' +
               ' @cFromLoc       NVARCHAR( 10), ' +
               ' @cCartonId      NVARCHAR( 20), ' +
               ' @cSKU           NVARCHAR( 20), ' +
               ' @nQty           INT,           ' +
               ' @cOption        NVARCHAR( 1), ' +
               ' @cToLOC         NVARCHAR( 10), ' +
               ' @tExtValidate   VariableTable READONLY, ' +
               ' @nErrNo         INT           OUTPUT, ' +
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
               @cGroupKey, @cTaskDetailKey, @cPickZone, @cCartId, @cMethod, @cFromLoc, @cCartonId,
               @cSKU, @nQty, @cOption, @cToLoc, @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Step_ToLoc_Fail --V1.8.1
         END
      END
      
      -- Handling transaction                  
      SET @nTranCount = @@TRANCOUNT                  
      BEGIN TRAN  -- Begin our own transaction                  
      SAVE TRAN Step_ConfirmToLoc -- For rollback or commit only our own transaction         
            
      SET @nErrNo = 0        
      EXEC rdt.rdt_TM_Assist_ClusterPick_ConfirmToLoc         
          @nMobile         = @nMobile,          
          @nFunc           = @nFunc,          
          @cLangCode       = @cLangCode,          
          @nStep           = @nStep,          
          @nInputKey       = @nInputKey,          
          @cFacility       = @cFacility,          
          @cStorerKey      = @cStorerKey,          
          @cTaskDetailKey  = @cTaskDetailKey,          
          @cToLOC          = @cToLOC,          
          @tConfirm        = @tConfirm,        
          @nErrNo          = @nErrNo     OUTPUT,          
          @cErrMsg         = @cErrMsg    OUTPUT          
        
      IF @nErrNo <> 0        
      BEGIN      
         ROLLBACK TRAN Step_ConfirmToLoc                  
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started                  
            COMMIT TRAN                  
         GOTO Step_ToLoc_Fail                  
      END      
      
      -- Extended update        
      IF @cExtendedUpdateSP <> ''        
      BEGIN        
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')        
         BEGIN        
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +        
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +         
               ' @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption, ' +        
               ' @tExtUpdate, @nErrNo OUTPUT, @cErrMsg OUTPUT '        
        
            SET @cSQLParam =        
               ' @nMobile        INT,           ' +        
               ' @nFunc          INT,           ' +        
               ' @cLangCode      NVARCHAR( 3),  ' +        
               ' @nStep          INT,           ' +        
               ' @nInputKey      INT,           ' +        
               ' @cFacility      NVARCHAR( 5),  ' +        
               ' @cStorerKey     NVARCHAR( 15), ' +        
               ' @cGroupKey      NVARCHAR( 10), ' +        
               ' @cTaskDetailKey NVARCHAR( 10), ' +        
               ' @cCartId        NVARCHAR( 10), ' +        
               ' @cFromLoc       NVARCHAR( 10), ' +        
               ' @cCartonId      NVARCHAR( 20), ' +        
               ' @cSKU           NVARCHAR( 20), ' +        
               ' @nQty           INT,           ' +        
               ' @cOption        NVARCHAR( 1), ' +        
               ' @tExtUpdate     VariableTable READONLY, ' +         
               ' @nErrNo         INT           OUTPUT, ' +        
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '        
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,        
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,         
               @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption,         
               @tExtUpdate, @nErrNo OUTPUT, @cErrMsg OUTPUT        
        
            IF @nErrNo > 0 --OR @nErrNo <> -1        
            BEGIN      
               ROLLBACK TRAN Step_ConfirmToLoc                  
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started                  
                  COMMIT TRAN                  
               GOTO Step_ToLoc_Fail                  
            END      
         END        
      END                
               
      COMMIT TRAN Step_ConfirmToLoc -- Only commit change made here                        
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started                  
         COMMIT TRAN               
      
      -- Prepare next screen var          
      SET @cOutField01 = @cCartPickMethod          
      SET @cOutField02 = @cCartID      
                
      SET @nScn = @nScn_NextTask        
      SET @nStep = @nStep_NextTask         
   END          
           
   Step_ToLoc_Fail:          
   BEGIN          
      SET @cToLOC = ''          
      SET @cOutField03 = '' -- To LOC          
   END          
END        
GOTO Quit        
      
/********************************************************************************          
Scn = 5927. UnAssign Cart?              
   Option   (field01, input)          
********************************************************************************/          
Step_UnAssign:                  
BEGIN                  
   IF @nInputKey = 1 -- ENTER                  
   BEGIN                  
      -- Screen mapping                  
      SET @cOption = @cInField02                  
                  
      -- Validate blank                  
      IF @cOption = ''                  
      BEGIN                  
         SET @nErrNo = 148914                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option required                  
         GOTO Step_UnAssign_Fail                  
      END                  
                  
      -- Validate option                  
      IF @cOption NOT IN ('1', '2')       
      BEGIN                  
         SET @nErrNo = 148915                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option                  
         GOTO Step_UnAssign_Fail                  
      END                  
            
      IF @cOption = '1'      
      BEGIN      
         SET @nTranCount = @@TRANCOUNT      
         BEGIN TRAN      
         SAVE TRAN UnAssign      
            
         -- 1. unassign those locked but not picked task      
         SET @nErrNo = 0      
         DECLARE @curUnAssign CURSOR      
         SET @curUnAssign = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR      
         SELECT TaskDetailKey      
         FROM dbo.TaskDetail WITH (NOLOCK)      
         WHERE Storerkey = @cStorerKey      
         AND   TaskType = 'ASTCPK'      
         AND   [Status] = '3'      
         AND   Groupkey = @cGroupKey      
         AND   UserKey = @cUserName      
         AND   DeviceID = @cCartID      
         OPEN @curUnAssign      
         FETCH NEXT FROM @curUnAssign INTO @cUnAssignTaskKey      
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            UPDATE dbo.TaskDetail SET       
               STATUS = '0',      
               UserKey = '',      
               Groupkey = '',       
               DeviceID = '',      
               DropID = '',      
               StatusMsg = '',      
               EditWho = @cUserName,       
               EditDate = GETDATE()      
            WHERE TaskDetailKey = @cUnAssignTaskKey      
               
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 171809          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lock Task Fail          
               GOTO UnAssign_RollBackTran          
            END      
               
            FETCH NEXT FROM @curUnAssign INTO @cUnAssignTaskKey      
         END      
         CLOSE @curUnAssign      
         DEALLOCATE @curUnAssign      
      
         -- 2. Confirm those locked and picked task      
         SET @curUnAssign = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR      
         SELECT TaskDetailKey      
         FROM dbo.TaskDetail WITH (NOLOCK)      
         WHERE Storerkey = @cStorerKey      
         AND   TaskType = 'ASTCPK'      
         AND   [Status] = '5'      
         AND   Groupkey = @cGroupKey      
         AND   UserKey = @cUserName      
         AND   DeviceID = @cCartID      
         OPEN @curUnAssign      
         FETCH NEXT FROM @curUnAssign INTO @cUnAssignTaskKey      
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            UPDATE dbo.TaskDetail SET       
               STATUS = '9',      
               EditWho = @cUserName,       
               EditDate = GETDATE()      
            WHERE TaskDetailKey = @cUnAssignTaskKey      
               
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 171830          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lock Task Fail          
               GOTO UnAssign_RollBackTran          
            END      
               
            FETCH NEXT FROM @curUnAssign INTO @cUnAssignTaskKey      
         END      
               
         GOTO UnAssign_Commit      
      
         UnAssign_RollBackTran:        
               ROLLBACK TRAN UnAssign        
         UnAssign_Commit:        
            WHILE @@TRANCOUNT > @nTranCount        
               COMMIT TRAN        
      
         IF @nErrNo <> 0      
            GOTO Quit      
                  
         -- Prepare next screen var        
         SET @cOutField01 = ''        
         SET @cOutField02 = ''         
         SET @cOutField03 = ''      
      
         EXEC rdt.rdtSetFocusField @nMobile, 1          
      
         -- Go to next screen        
         SET @nScn = @nScn_CartID        
         SET @nStep = @nStep_CartID

         -- Ext Scn SP
         IF @cExtendedScnSP <> ''
         BEGIN
            SET @nAction = 0
            GOTO Step_99
         END -- ExtendedScreenSP <> ''      
               
         GOTO Quit      
      END      
      
      IF @cOption = '2'      
      BEGIN      
         SELECT @nCartonScanned = COUNT( DISTINCT DropID)      
         FROM dbo.TaskDetail WITH (NOLOCK)      
         WHERE Storerkey = @cStorerKey      
         AND   TaskType = 'ASTCPK'      
         AND   [Status] = '3'      
         AND   Groupkey = @cGroupKey      
         AND   UserKey = @cUserName      
         AND   DeviceID = @cCartID      
         AND   DropID <> ''      
      
         -- Prepare next screen var        
         SET @cOutField01 = @cCartPickMethod        
         SET @cOutField02 = @cCartID        
         SET @cOutField03 = @cResult01        
         SET @cOutField04 = @cResult02        
         SET @cOutField05 = @cResult03        
         SET @cOutField06 = @cResult04        
         SET @cOutField07 = @cResult05        
         SET @cOutField08 = ''        
         SET @cOutField09 = @nCartonScanned        
      
         EXEC rdt.rdtSetFocusField @nMobile, 8      
      
         -- Go to next screen        
         SET @nScn = @nScn_CartMatrix        
         SET @nStep = @nStep_CartMatrix 

         -- Ext Scn SP
         IF @cExtendedScnSP <> ''
         BEGIN
            SET @nAction = 0
            GOTO Step_99
         END -- ExtendedScreenSP <> ''       
               
         GOTO Quit       
      END-- OPTION 2     
   END                  
                  
   IF @nInputKey = 0        
   BEGIN        
      SELECT @nCartonScanned = COUNT( DISTINCT DropID)      
    FROM dbo.TaskDetail WITH (NOLOCK)      
      WHERE Storerkey = @cStorerKey      
      AND   TaskType = 'ASTCPK'      
      AND   [Status] = '3'      
      AND   Groupkey = @cGroupKey      
      AND   UserKey = @cUserName      
      AND   DeviceID = @cCartID
      AND   DropID <> ''  -- FCR-652 Fix issue by Jackc    
               
      -- Prepare next screen var        
      SET @cOutField01 = @cCartPickMethod        
      SET @cOutField02 = @cCartID        
      SET @cOutField03 = @cResult01        
      SET @cOutField04 = @cResult02        
      SET @cOutField05 = @cResult03        
      SET @cOutField06 = @cResult04        
      SET @cOutField07 = @cResult05        
      SET @cOutField08 = ''        
      SET @cOutField09 = @nCartonScanned        
      
      EXEC rdt.rdtSetFocusField @nMobile, 8      
      
      -- Go to next screen        
      SET @nScn = @nScn_CartMatrix        
      SET @nStep = @nStep_CartMatrix
      
      -- Ext Scn SP
      IF @cExtendedScnSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScnSP AND type = 'P')
         BEGIN
            SET @nAction = 0

            EXECUTE [RDT].[rdt_ExtScnEntry] 
            @cExtendedScnSP, 
            @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @tExtScnData ,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT,  @cLottable01 OUTPUT,  
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT,  @cLottable02 OUTPUT,  
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT,  @cLottable03 OUTPUT,  
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT,  @dLottable04 OUTPUT,  
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT,  @dLottable05 OUTPUT,  
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT,  @cLottable06 OUTPUT, 
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT,  @cLottable07 OUTPUT, 
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT,  @cLottable08 OUTPUT, 
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT,  @cLottable09 OUTPUT, 
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT,  @cLottable10 OUTPUT, 
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT,  @cLottable11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT,  @cLottable12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT,  @dLottable13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT,  @dLottable14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT,  @dLottable15 OUTPUT,
            @nAction, 
            @nScn OUTPUT,  @nStep OUTPUT,
            @nErrNo   OUTPUT, 
            @cErrMsg  OUTPUT,
            @cExtScnUDF01   OUTPUT, @cExtScnUDF02 OUTPUT, @cExtScnUDF03 OUTPUT,
            @cExtScnUDF04   OUTPUT, @cExtScnUDF05 OUTPUT, @cExtScnUDF06 OUTPUT,
            @cExtScnUDF07   OUTPUT, @cExtScnUDF08 OUTPUT, @cExtScnUDF09 OUTPUT,
            @cExtScnUDF10   OUTPUT, @cExtScnUDF11 OUTPUT, @cExtScnUDF12 OUTPUT,
            @cExtScnUDF13   OUTPUT, @cExtScnUDF14 OUTPUT, @cExtScnUDF15 OUTPUT,
            @cExtScnUDF16   OUTPUT, @cExtScnUDF17 OUTPUT, @cExtScnUDF18 OUTPUT,
            @cExtScnUDF19   OUTPUT, @cExtScnUDF20 OUTPUT, @cExtScnUDF21 OUTPUT,
            @cExtScnUDF22   OUTPUT, @cExtScnUDF23 OUTPUT, @cExtScnUDF24 OUTPUT,
            @cExtScnUDF25   OUTPUT, @cExtScnUDF26 OUTPUT, @cExtScnUDF27 OUTPUT,
            @cExtScnUDF28   OUTPUT, @cExtScnUDF29 OUTPUT, @cExtScnUDF30 OUTPUT
            
            IF @nErrNo <> 0
            BEGIN
               GOTO  Quit
            END

            GOTO Quit
         END
      END -- ExtendedScreenSP <> '' 
   END             
   GOTO Quit                  
                  
   Step_UnAssign_Fail:                  
   BEGIN                  
      -- Reset this screen var                  
      SET @cOutField01 = '' --Option                  
   END                  
END                  
GOTO Quit            
      
/********************************************************************************          
Scn = 5688. Message screen        
   PICKING COMPLETED          
   ENTER = Next Task          
   ESC   = Exit TM          
********************************************************************************/          
Step_NextTask:        
BEGIN        
   IF @nInputKey = 1 -- ENTER          
   BEGIN          
     -- Prepare next screen var        
      SET @cOutField01 = ''        
      SET @cOutField02 = ''         
      SET @cOutField03 = ''      
      
      EXEC rdt.rdtSetFocusField @nMobile, 1          
      
      -- Go to next screen        
      SET @nScn = @nScn_CartID        
      SET @nStep = @nStep_CartID        
   END          
          
   IF @nInputKey = 0 -- ESC          
   BEGIN          
     -- Prepare next screen var        
      SET @cOutField01 = ''        
      SET @cOutField02 = ''         
      SET @cOutField03 = ''      
      
      EXEC rdt.rdtSetFocusField @nMobile, 1          
      
      -- Go to next screen        
      SET @nScn = @nScn_CartID        
      SET @nStep = @nStep_CartID        
   END

   IF @cExtendedScnSP <> ''
   BEGIN
      SET @nAction = 0
      GOTO Step_99
   END

   GOTO Quit          
           
   Step_NextTask_Fail:        
END        
GOTO Quit        
      
/********************************************************************************          
Scn = 5929. Task exists, continue?              
   Option   (field01, input)          
********************************************************************************/          
Step_ContTask:                  
BEGIN                  
   IF @nInputKey = 1 -- ENTER                  
   BEGIN                  
      -- Screen mapping                  
      SET @cOption = @cInField01                  
                  
      -- Validate blank                  
      IF @cOption = ''                  
      BEGIN                  
         SET @nErrNo = 171838                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option required                  
         GOTO Step_ContTask_Fail                  
      END                  
                  
      -- Validate option                  
      IF @cOption NOT IN ( '1', '2')      
      BEGIN                  
         SET @nErrNo = 171839                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option                  
         GOTO Step_ContTask_Fail                  
      END                  
      
      IF @cOption = '1'      
      BEGIN      
       SELECT TOP 1       
          @cCartType = StatusMsg,      
          @cGroupkey = Groupkey      
       FROM dbo.TaskDetail WITH (NOLOCK)      
       WHERE Storerkey = @cStorerKey      
         AND   TaskType = 'ASTCPK'      
         AND   [Status] = '3'      
         AND   Groupkey <> ''      
         AND   UserKey = @cUserName      
         AND   DeviceID = @cCartID      
       ORDER BY 1      
      
         SELECT @nCartLimit = Short      
         FROM dbo.CODELKUP WITH (NOLOCK)      
         WHERE LISTNAME = 'TMPICKMTD'      
         AND UDF01 = RIGHT( @cCartType, CHARINDEX( '-', REVERSE( @cCartType)) - 1)      
         AND   Storerkey = @cStorerKey      
               
         SELECT @nCartonCnt = COUNT( DISTINCT DropID)      
         FROM dbo.TaskDetail WITH (NOLOCK)      
       WHERE Storerkey = @cStorerKey      
         AND   TaskType = 'ASTCPK'      
         AND   [Status] IN ( '3', '5')      
         AND   Groupkey = @cGroupkey      
         AND   UserKey = @cUserName      
         AND   DeviceID = @cCartID      
         AND   DropID <> ''      
               
         IF @nCartonCnt < @nCartLimit AND       
            EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)      
            WHERE Storerkey = @cStorerKey      
            AND   TaskType = 'ASTCPK'      
            AND   [Status] IN ( '3', '5')      
            AND   Groupkey = @cGroupkey      
            AND   UserKey = @cUserName      
            AND   DeviceID = @cCartID      
            AND   DropID = '')      
         BEGIN                  
            SET @nErrNo = 171840                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MoreCtnToScan                  
            GOTO Step_ContTask_Fail                  
         END        
      END      
            
      IF @cOption = '2'      
      BEGIN      
         -- Prepare next screen var        
         SET @cOutField01 = ''        
         SET @cOutField02 = ''         
         SET @cOutField03 = ''      
      
         EXEC rdt.rdtSetFocusField @nMobile, 1          
           
         -- Go to next screen        
         SET @nScn = @nScn_CartID        
         SET @nStep = @nStep_CartID

         --FCR-652 new ext scn by Jack
         -- Ext Scn SP
         IF @cExtendedScnSP <> ''
         BEGIN
            SET @nAction = 0
            GOTO Step_99
         END -- ExtendedScreenSP <> ''        
               
         GOTO Quit      
      END      
      /*      
      -- Handling transaction                  
      SET @nTranCount = @@TRANCOUNT                  
      BEGIN TRAN  -- Begin our own transaction                  
      SAVE TRAN UnAssign_ContTask -- For rollback or commit only our own transaction          
                  
      -- Confirm                  
      IF @cOption = '1'                  
      BEGIN                  
         -- 1. unassign those locked but not picked task      
         SET @nErrNo = 0      
         SET @curUnAssign = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR      
         SELECT TaskDetailKey      
         FROM dbo.TaskDetail WITH (NOLOCK)      
         WHERE Storerkey = @cStorerKey      
         AND   TaskType = 'ASTCPK'      
         AND   [Status] = '3'      
         AND   Groupkey = @cGroupKey      
         AND   UserKey = @cUserName      
         AND   DeviceID = @cCartID      
         OPEN @curUnAssign      
         FETCH NEXT FROM @curUnAssign INTO @cUnAssignTaskKey      
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            UPDATE dbo.TaskDetail SET       
               STATUS = '0',      
               EditWho = @cUserName,       
               EditDate = GETDATE()      
            WHERE TaskDetailKey = @cUnAssignTaskKey      
               
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 171841          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Unassign Fail          
               GOTO UnAssign_RollBackTran1          
            END      
               
            FETCH NEXT FROM @curUnAssign INTO @cUnAssignTaskKey      
         END      
         CLOSE @curUnAssign      
         DEALLOCATE @curUnAssign      
      
         GOTO UnAssign_Commit1      
      
         UnAssign_RollBackTran1:        
               ROLLBACK TRAN UnAssign_ContTask        
         UnAssign_Commit1:        
            WHILE @@TRANCOUNT > @nTranCount        
               COMMIT TRAN        
      
         IF @nErrNo <> 0      
            GOTO Quit      
      END      
      */      
      SET @cInField08 = ''      
      SET @nInputKey = 1

      --FCR-652 new ext scn by Jack
      IF @cExtendedScnSP <> ''
      BEGIN
         
         SET @nAction = 0
         GOTO Step_99

      END -- ExtendedScreenSP <> ''

      GOTO Step_CartMatrix      
   END      
         
   IF @nInputKey = 0 -- ESC      
   BEGIN      
      -- Prepare next screen var        
      SET @cOutField01 = ''        
      SET @cOutField02 = ''         
      SET @cOutField03 = ''      
      
      EXEC rdt.rdtSetFocusField @nMobile, 1          
           
      -- Go to next screen        
      SET @nScn = @nScn_CartID        
      SET @nStep = @nStep_CartID 

      --FCR-652 new ext scn by Jack
      -- Ext Scn SP
      IF @cExtendedScnSP <> ''
      BEGIN
         
         SET @nAction = 0
         GOTO Step_99

      END -- ExtendedScreenSP <> ''

   END      
         
   GOTO Quit      
         
   Step_ContTask_Fail:      
   BEGIN                  
      -- Reset this screen var                  
      SET @cOutField01 = '' --Option                  
   END                  
END      
GOTO Quit

Step_99:
BEGIN
   
   IF @cExtendedScnSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedScnSP AND type = 'P')
      BEGIN
         DELETE FROM @tExtScnData
         INSERT INTO @tExtScnData (Variable, Value) VALUES 
            ('@cOption',   @cOption),
            ('@cGroupKey', @cGroupKey)

         DECLARE  @nPreSCn       INT,
                  @nPreInputKey  INT

         SET @nPreSCn = @nScn
         SET @nPreInputKey = @nInputKey
         
         EXECUTE [RDT].[rdt_ExtScnEntry] 
            @cExtendedScnSP,  --1855ExtScn01
            @nMobile, @nFunc, @cLangCode, @nStep, @nScn, @nInputKey, @cFacility, @cStorerKey, @tExtScnData,
            @cInField01 OUTPUT,  @cOutField01 OUTPUT,  @cFieldAttr01 OUTPUT, @cLottable01 OUTPUT,
            @cInField02 OUTPUT,  @cOutField02 OUTPUT,  @cFieldAttr02 OUTPUT, @cLottable02 OUTPUT,
            @cInField03 OUTPUT,  @cOutField03 OUTPUT,  @cFieldAttr03 OUTPUT, @cLottable03 OUTPUT,
            @cInField04 OUTPUT,  @cOutField04 OUTPUT,  @cFieldAttr04 OUTPUT, @dLottable04 OUTPUT,
            @cInField05 OUTPUT,  @cOutField05 OUTPUT,  @cFieldAttr05 OUTPUT, @dLottable05 OUTPUT,
            @cInField06 OUTPUT,  @cOutField06 OUTPUT,  @cFieldAttr06 OUTPUT, @cLottable06 OUTPUT,
            @cInField07 OUTPUT,  @cOutField07 OUTPUT,  @cFieldAttr07 OUTPUT, @cLottable07 OUTPUT,
            @cInField08 OUTPUT,  @cOutField08 OUTPUT,  @cFieldAttr08 OUTPUT, @cLottable08 OUTPUT,
            @cInField09 OUTPUT,  @cOutField09 OUTPUT,  @cFieldAttr09 OUTPUT, @cLottable09 OUTPUT,
            @cInField10 OUTPUT,  @cOutField10 OUTPUT,  @cFieldAttr10 OUTPUT, @cLottable10 OUTPUT,
            @cInField11 OUTPUT,  @cOutField11 OUTPUT,  @cFieldAttr11 OUTPUT, @cLottable11 OUTPUT,
            @cInField12 OUTPUT,  @cOutField12 OUTPUT,  @cFieldAttr12 OUTPUT, @cLottable12 OUTPUT,
            @cInField13 OUTPUT,  @cOutField13 OUTPUT,  @cFieldAttr13 OUTPUT, @dLottable13 OUTPUT,
            @cInField14 OUTPUT,  @cOutField14 OUTPUT,  @cFieldAttr14 OUTPUT, @dLottable14 OUTPUT,
            @cInField15 OUTPUT,  @cOutField15 OUTPUT,  @cFieldAttr15 OUTPUT, @dLottable15 OUTPUT,
            @nAction, 
            @nScn OUTPUT,  @nStep OUTPUT,
            @nErrNo   OUTPUT, 
            @cErrMsg  OUTPUT,
            @cExtScnUDF01 OUTPUT, @cExtScnUDF02 OUTPUT, @cExtScnUDF03 OUTPUT,
            @cExtScnUDF04 OUTPUT, @cExtScnUDF05 OUTPUT, @cExtScnUDF06 OUTPUT,
            @cExtScnUDF07 OUTPUT, @cExtScnUDF08 OUTPUT, @cExtScnUDF09 OUTPUT,
            @cExtScnUDF10 OUTPUT, @cExtScnUDF11 OUTPUT, @cExtScnUDF12 OUTPUT,
            @cExtScnUDF13 OUTPUT, @cExtScnUDF14 OUTPUT, @cExtScnUDF15 OUTPUT,
            @cExtScnUDF16 OUTPUT, @cExtScnUDF17 OUTPUT, @cExtScnUDF18 OUTPUT,
            @cExtScnUDF19 OUTPUT, @cExtScnUDF20 OUTPUT, @cExtScnUDF21 OUTPUT,
            @cExtScnUDF22 OUTPUT, @cExtScnUDF23 OUTPUT, @cExtScnUDF24 OUTPUT,
            @cExtScnUDF25 OUTPUT, @cExtScnUDF26 OUTPUT, @cExtScnUDF27 OUTPUT,
            @cExtScnUDF28 OUTPUT, @cExtScnUDF29 OUTPUT, @cExtScnUDF30 OUTPUT

         IF @cExtendedScnSP = 'rdt_1855ExtScn01'
         BEGIN
            IF @nPreScn = '6414' AND @nPreInputKey = 0 -- Back to Menu
            BEGIN
               SET @nFunc     =  @nScn
               SET @cGroupKey =  '' --V1.7 Clear groupkey when exists func
            END
            ELSE IF @nPreSCn = '6414' AND @nPreInputKey = 1 -- Save value to mobred
            BEGIN
               SET  @cSKU              = ISNULL(@cExtScnUDF01,'')                     
               SET  @nQTY              = CAST(@cExtScnUDF02 AS INT) 
               SET  @cFromLoc          = ISNULL(@cExtScnUDF03,'')
               SET  @cCartonID         = ISNULL(@cExtScnUDF04,'')
               SET  @cTaskDetailKey    = ISNULL(@cExtScnUDF05,'')
               SET  @cWaveKey          = ISNULL(@cExtScnUDF06,'')
               SET  @cCartID           = ISNULL(@cExtScnUDF07,'')
               SET  @cGroupKey         = ISNULL(@cExtScnUDF08,'')
               SET  @cPickZone         = ISNULL(@cExtScnUDF09,'')
               SET  @cResult01         = ISNULL(@cExtScnUDF10,'')
               SET  @cResult02         = ISNULL(@cExtScnUDF11,'')
               SET  @cResult03         = ISNULL(@cExtScnUDF12,'')        
               SET  @cResult04         = ISNULL(@cExtScnUDF13,'')
               SET  @cResult05         = ISNULL(@cExtScnUDF14,'')
               SET  @cMethod           = ISNULL(@cExtScnUDF15,'')
               SET  @cPickSlipNo       = ISNULL(@cExtScnUDF16,'')
            END -- SCN 6414  new scn 1 Enter
            ELSE IF @nPreSCn = '6416' AND @nPreInputKey = 1
            BEGIN
               SET @cCartonID       = ISNULL(@cExtScnUDF01,'')
               SET @cSuggFromLOC    = ISNULL(@cExtScnUDF02,'')
               SET @cSuggCartonID   = ISNULL(@cExtScnUDF03,'')
               SET @cSuggToteId     = ISNULL(@cExtScnUDF04,'')
               SET @cSuggSKU        = ISNULL(@cExtScnUDF05,'')
               SET @nSuggQty        = CAST(@cExtScnUDF06 AS INT)
               SET @cTaskDetailKey  = ISNULL(@cExtScnUDF07,'')
            END -- SCN 6416 new scn 2 enter
            --V1.6 JACKC
            ELSE IF @nPreSCn = 5929 AND @nPreInputKey = 1 AND @cOption = 1
            BEGIN
               --IF continue task, then update results returned from 6416 to rdtmobred
               SET @cCartonID       = ISNULL(@cExtScnUDF01,'')
               SET @cSuggFromLOC    = ISNULL(@cExtScnUDF02,'')
               SET @cSuggCartonID   = ISNULL(@cExtScnUDF03,'')
               SET @cSuggToteId     = ISNULL(@cExtScnUDF04,'')
               SET @cSuggSKU        = ISNULL(@cExtScnUDF05,'')
               SET @nSuggQty        = CAST(@cExtScnUDF06 AS INT)
               SET @cTaskDetailKey  = ISNULL(@cExtScnUDF07,'')
            END -- SCN 5929 Continue screen
            --V1.6 JACKC END
            ELSE IF @nScn = 6414 AND @nStep = 99
            BEGIN
               --V1.7 
               SET @cGroupKey = '' -- clear groupkey, cart id when back to 1 step
               SET @cCartID = ''
               --V1.7 end
            END
         END -- rdt_1855ExtScn01

         IF @nErrNo <> 0
            GOTO Step_99_Fail

         GOTO Quit
      END
   END

   Step_99_Fail:
      GOTO Quit
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
        
      V_SKU      = @cSKU,        
      V_SKUDescr = @cSKUDescr,        
      V_QTY      = @nQty,        
      V_Loc      = @cFromLoc,        
      V_CaseID   = @cCartonID,        
      V_TaskDetailKey = @cTaskDetailKey,      
      V_WaveKey  = @cWaveKey,
      V_PickSlipNo = @cPickSlipNo,      
            
      V_Integer1 = @nSuggQty,        
      V_Integer2 = @nPickedQty,        
      V_Integer3 = @nActQTY,        
              
      V_String1  = @cExtendedUpdateSP,        
      V_String2  = @cExtendedValidateSP,        
      V_String3  = @cExtendedInfoSP,        
      V_String4  = @cGetNextTaskSP,          
      V_String5  = @cDisableQTYFieldSP,         
      V_String6  = @cDisableQTYField,          
      V_String7  = @cSuggCartId,        
      V_String8  = @cCartID,        
      V_String9  = @cSuggFromLOC,        
      V_String10 = @cSuggCartonID,        
      V_String11 = @cSuggSKU,        
      V_String12 = @cGroupKey,        
      V_String13 = @cSuggToLOC,        
      V_String14 = @cDefaultQTY,          
      V_String15 = @cOverwriteToLOC,        
      V_String16 = @cDefaultQTY,        
      V_String17 = @cPickConfirmStatus,        
      V_String18 = @cSKUValidated,        
      V_String19 = @cDefaultQTYSP,        
      V_String20 = @cReasonCode,        
      V_String22 = @cPosition,      
      V_String23 = @cConfirmToLoc,      
      V_String24 = @cPickZone,      
      V_String25 = @cMethod,      
      V_String26 = @cResult01,      
      V_String27 = @cResult02,      
      V_String28 = @cResult03,      
      V_String29 = @cResult04,      
      V_String30 = @cResult05,      
      V_String31 = @cSuggToteId,      
      V_String32 = @cAreakey,          
      V_String33 = @cTTMStrategykey,          
      V_String34 = @cTTMTaskType,          
      V_String35 = @cRefKey01,          
      V_String36 = @cRefKey02,          
      V_String37 = @cRefKey03,          
      V_String38 = @cRefKey04,          
      V_String39 = @cRefKey05,          
      V_String41 = @cCartPickMethod,      
      V_String42 = @cContinuePickOnAssignedCart,      
      V_String43 = @cPickNoMixWave,
      V_String44 = @cExtendedScnSP, -- ExtScn Jack
      
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