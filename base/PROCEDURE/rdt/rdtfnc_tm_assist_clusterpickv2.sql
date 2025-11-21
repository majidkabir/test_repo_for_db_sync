SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/
/* Store procedure: rdtfnc_TM_Assist_ClusterPickV2                            */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Purpose: For HUSQ                                                          */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Rev   Author   Purposes                                       */
/* 2024-10-10   1.0   JHU151   FCR-777 Created                                */
/* 13/01/2024   2.0   PPA374   Correcting issues on assignment where          */
/*                             pickdetail remains in status 5 with no ID      */
/* 13/01/2024   2.1   PPA374   Allowing to use same DropID for trolley        */
/* 17/01/2024   2.2   PPA374   Fix for method 3 close option no DROPID update */
/******************************************************************************/
        
CREATE   PROC [RDT].[rdtfnc_TM_Assist_ClusterPickV2](        
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
   @cSerialNo      NVARCHAR( 30) = '',
   @nSerialQTY     INT,
   @nMoreSNO       INT,
   @nBulkSNO       INT,
   @nBulkSNOQTY    INT,
   @cSerialNoCapture    NVARCHAR( 1),        
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
   @cLockOrderKey       NVARCHAR( 10),    
   @nCartLimit          INT,      
   @cWaveKey            NVARCHAR( 10),      
   @cUDF01              NVARCHAR( 30),      
   @cLong               NVARCHAR( 30),      
   @cCartType           NVARCHAR( 10) = '',      
   @nCartonCnt          INT = 0,      
   @cContinuePickOnAssignedCart  NVARCHAR( 1),      
   @cPickNoMixWave      NVARCHAR( 1),
   @cPickWaveKey        NVARCHAR( 10),
   @cMessage01          NVARCHAR( 20),
   @cMessage02          NVARCHAR( 20),
   @cMessage03          NVARCHAR( 20),
   @cMax                NVARCHAR(MAX),
   @cUnassignToLOCFlag  NVARCHAR( 1),

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
   @nQty             = V_QTY,
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
   @cUnassignToLOCFlag  = V_String40,--Dennis 21/01/2025
   @cCartPickMethod     = V_String41,      
   @cContinuePickOnAssignedCart = V_String42,      
   @cPickNoMixWave      = V_String43,
   @cExtendedScnSP      = V_String44, -- ExtScn Jackc
   @cSerialNoCapture    = V_String45,
   @cReasonCode         = V_String46,
   @cMax                = V_Max,
   
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
   @nStep_ContTask         INT,  @nScn_ContTask          INT,
   @nStep_SerialNo         INT,  @nScn_SerialNo          INT,
   @nStep_ReasonCD         INT,  @nScn_ReasonCD          INT,
   @nStep_PalletInf        INT,  @nScn_PalletInf         INT
        
SELECT        
   @nStep_CartID           = 1,  @nScn_CartID            = 6470,        
   @nStep_CartMatrix       = 2,  @nScn_CartMatrix        = 6471,        
   @nStep_Loc              = 3,  @nScn_Loc               = 6472,        
   @nStep_SKUQTY           = 4,  @nScn_SKUQTY            = 6473,        
   @nStep_ConfirmTote      = 5,  @nScn_ConfirmTote       = 6474,      
   @nStep_Option           = 6,  @nScn_Option            = 6475,        
   @nStep_ToLoc            = 7,  @nScn_ToLoc             = 6476,        
   @nStep_UnAssign         = 8,  @nScn_UnAssign          = 6477,      
   @nStep_NextTask         = 9,  @nScn_NextTask          = 6478,      
   @nStep_ContTask         = 10, @nScn_ContTask          = 6479,
   @nStep_SerialNo         = 11, @nScn_SerialNo          = 4830,
   @nStep_ReasonCD         = 12, @nScn_ReasonCD          = 6481,
   @nStep_PalletInf        = 13, @nScn_PalletInf         = 6482
        
        
IF @nFunc = 1867        
BEGIN        
   -- Redirect to respective screen        
   IF @nStep = 0  GOTO Step_Start            -- Menu. Func = 1867        
   IF @nStep = 1  GOTO Step_CartID           -- Scn = 6470. Scan Car ID        
   IF @nStep = 2  GOTO Step_CartMatrix       -- Scn = 6471. Cart Matrix        
   IF @nStep = 3  GOTO Step_Loc              -- Scn = 6472. Loc        
   IF @nStep = 4  GOTO Step_SKUQTY           -- Scn = 6473. SKU, Qty        
   IF @nStep = 5  GOTO Step_ConfirmTote      -- Scn = 6474. Confirm Carton        
   IF @nStep = 6  GOTO Step_Option           -- Scn = 6475. Option - short confirm
   IF @nStep = 7  GOTO Step_ToLoc            -- Scn = 6476. To Loc        
   IF @nStep = 8  GOTO Step_UnAssign         -- Scn = 6477. Unassign Cart        
   IF @nStep = 9  GOTO Step_NextTask         -- Scn = 6478. End Task/Exit TM        
   IF @nStep = 10 GOTO Step_ContTask         -- Scn = 6479. Task exists, continue
   IF @nStep = 11 GOTO Step_SerialNo         -- Scn = 6480. Serial No
   IF @nStep = 12 GOTO Step_ReasonCD         -- Scn = 6481. Reason Code
   IF @nStep = 13 GOTO Step_PalletInf        -- Scn = 6482. Pallet Info
   IF @nStep = 99 GOTO Step_99               -- Ext Scn Jackc       
         
END        
        
RETURN -- Do nothing if incorrect step        
        
/********************************************************************************        
Step_Start. Func = 1867        
********************************************************************************/        
Step_Start:        
BEGIN        
   -- Get task manager data          
   SET @cTaskDetailKey  = @cOutField06          
   SET @cAreaKey        = @cOutField07          
   SET @cTTMStrategyKey = @cOutField08          
          
   -- Get task info          
   SELECT TOP 1   --PPA374 Added TOP 1 15/01/2025
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
   
   SET @cSerialNoCapture = rdt.RDTGetConfig( @nFunc, 'SerialNoCapture', @cStorerKey)

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
Scn = 6470. Scan Cart Id        
   AreaKey     (field01, input)        
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
         SET @nErrNo = 227551          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need PickZone          
         EXEC rdt.rdtSetFocusField @nMobile, 1          
         GOTO Quit          
      END          
         
      -- Check pickzone valid          
      IF NOT EXISTS( SELECT 1 FROM dbo.TaskDetail TD WITH (NOLOCK)       
                     --JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)       
                     WHERE TD.Storerkey = @cStorerKey      
                     AND   TD.TaskType = 'ASTCPK'      
                     AND   TD.[Status] = '0'      
                     AND   TD.Groupkey <> ''      
                     AND   TD.UserKey = ''      
                     AND   TD.DeviceID = ''      
                     --AND   LOC.Facility = @cFacility
                     AND   TD.AreaKey = @cPickZone
                     --AND   LOC.PickZone = @cPickZone
                     )          
      BEGIN          
         SET @nErrNo = 227552          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKZone NoTask         
         EXEC rdt.rdtSetFocusField @nMobile, 1          
         SET @cOutField01 = ''          
         GOTO Quit          
      END          
      SET @cOutField01 = @cPickZone          
                
      -- Check blank          
      IF @cCartID = ''          
      BEGIN          
         SET @nErrNo = 227553          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need CartID          
         EXEC rdt.rdtSetFocusField @nMobile, 2          
         GOTO Quit          
      END          
      
      IF @cMethod <> '3'
      BEGIN
         -- Check cart valid          
         IF NOT EXISTS( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)       
                        WHERE DeviceType = 'CART'       
                        AND   DeviceID = @cCartID)          
         BEGIN          
            SET @nErrNo = 227554          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid CartID          
            EXEC rdt.rdtSetFocusField @nMobile, 2          
            SET @cOutField02 = ''          
            GOTO Quit          
         END
      END
          
      -- Check cart use by other          
      IF EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)       
                  WHERE Storerkey = @cStorerKey      
                  AND   TaskType = 'ASTCPK'      
                  AND   [STATUS] = '3'      
                  AND   DeviceID = @cCartID      
                  AND   UserKey <> @cUserName)          
      BEGIN          
         SET @nErrNo = 227555          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Cart in use          
         EXEC rdt.rdtSetFocusField @nMobile, 2          
         SET @cOutField02 = ''          
         GOTO Quit          
      END          
      SET @cOutField02 = @cCartID          

      DECLARE @cShort4CDLKUp     NVARCHAR(10)
      DECLARE @tMethodShort TABLE ( MethodShort    NVARCHAR( 30) )
      IF @cMethod = '1'
      BEGIN
         INSERT INTO @tMethodShort (MethodShort) 
         SELECT  short 
         FROM CodeLKUP WITH(NOLOCK) WHERE LISTNAME = 'HUSQPKTYPE' AND Code2 = 'UnderSized' AND StorerKey = @cStorerKey
      END
      ELSE IF @cMethod = '2'
      BEGIN
         INSERT INTO @tMethodShort (MethodShort) 
         SELECT  short  
         FROM CodeLKUP WITH(NOLOCK) WHERE LISTNAME = 'HUSQPKTYPE' AND Code2 = 'OverSized' AND StorerKey = @cStorerKey
      END
      ELSE IF @cMethod = '3'
      BEGIN
         INSERT INTO @tMethodShort (MethodShort) 
         SELECT  short  
         FROM CodeLKUP WITH(NOLOCK) WHERE LISTNAME = 'HUSQPKTYPE' AND Code2 = '' AND StorerKey = @cStorerKey
      END

      /**
      -- Check blank          
      IF @cMethod = ''          
      BEGIN          
         SET @nErrNo = 171806          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Method          
         EXEC rdt.rdtSetFocusField @nMobile, 3          
         GOTO Quit          
      END          
         **/

      -- Check Method valid          
      SELECT TOP 1 @cCartPickMethod = Long      --PPA374 added 15/01/2025
      FROM dbo.CODELKUP WITH (NOLOCK)      
      WHERE LISTNAME = 'TMPickMtd'      
      AND   Code = @cMethod      
      AND   Storerkey = @cStorerKey      
            
      IF ISNULL( @cCartPickMethod, '') = ''      
      BEGIN          
         SET @nErrNo = 227556          
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
                     JOIN dbo.PickDeTail PD WITH(NOLOCK) ON (TD.storerkey = PD.storerkey AND TD.taskdetailkey = PD.taskdetailkey)
                     --JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.Loc)
                     JOIN dbo.ORDERS ORD WITH(NOLOCK) ON (TD.Storerkey = ORD.Storerkey AND TD.OrderKey = ORD.OrderKey)
                     WHERE TD.Storerkey = @cStorerKey      
                     AND   TD.TaskType = 'ASTCPK'      
                     AND   TD.[Status] = '0'      
                     AND   TD.Groupkey <> ''      
                     AND   TD.UserKey = ''      
                     AND   TD.DeviceID = ''
                     AND   TD.AreaKey = @cPickZone
                     --AND   (
                           --(@cMethod <> '' AND ORD.UserDefine10 = @cShort4CDLKUp)
                           --OR (1=1)
                           --)
                     AND   (
                            (EXISTS(SELECT 1 FROM @tMethodShort MS WHERE ORD.UserDefine10 = MS.MethodShort) AND @cMethod <> '')
                            OR
                            @cMethod = ''
                           )
                     --AND   TD.PickMethod = @cCartPickMethod      
                     --AND   LOC.Facility = @cFacility       
                     --AND   LOC.PickZone = @cPickZone      
                     AND   EXISTS ( SELECT 1 FROM @tPickMethod PM WHERE TD.PickMethod = PM.Method))      
      BEGIN          
         SET @nErrNo = 227557          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No active Tasks for this Method          
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
            
      SELECT TOP 1 @nCartLimit = Short   --PPA374 Added TOP 1 15/01/2025   
      FROM dbo.CODELKUP WITH (NOLOCK)      
      WHERE LISTNAME = 'TMPICKMTD'      
      AND   Code = @cMethod      
      AND   Storerkey = @cStorerKey      
      
      -- (james03)
      IF @cPickNoMixWave = '1'
      BEGIN
         SELECT TOP 1 @cPickWaveKey = TD.WaveKey      
         FROM dbo.TaskDetail TD WITH (NOLOCK)      
         --JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.LOC)
         JOIN ORDERS ORD WITH(NOLOCK) ON (ORD.OrderKey = TD.OrderKey AND ORD.storerKey = TD.Storerkey)
         WHERE TD.Storerkey = @cStorerKey      
         AND   TD.TaskType = 'ASTCPK'      
         AND   TD.[Status] = '0'      
         AND   TD.Groupkey <> ''      
         AND   TD.UserKey = ''      
         AND   TD.DeviceID = ''
         AND   TD.AreaKey = @cPickZone
         --AND   (
           --    (@cMethod <> '' AND ORD.UserDefine10 = @cShort4CDLKUp)
           --    OR (1=1)
             --  )
         AND   (
                  (EXISTS(SELECT 1 FROM @tMethodShort MS WHERE ORD.UserDefine10 = MS.MethodShort) AND @cMethod <> '')
                  OR
                  @cMethod = ''
               )
         AND   ((TD.UserKeyOverRide = '') OR (TD.UserKeyOverRide = @cUserName))      
         --AND   LOC.Facility = @cFacility       
         --AND   LOC.PickZone = @cPickZone        
         AND   EXISTS ( SELECT 1 FROM @tPickMethod PM WHERE TD.PickMethod = PM.Method)      
         ORDER BY CASE WHEN TD.UserKeyOverRide = @cUserName THEN '0' ELSE '1' END, TD.WaveKey      
      END

      SET @nTranCount = @@TRANCOUNT      
      BEGIN TRAN      
      SAVE TRAN LockTask      

      SET @cWaveKey = ''
      SET @cGroupKey = ''      
      SET @nErrNo = 0      
      
      DECLARE @cTempGroupKey    NVARCHAR(30) = ''
      DECLARE @curLockTask CURSOR
      /**
      SELECT TOP 1 
            @cGroupkey = TD.GroupKey
      FROM dbo.TaskDetail TD WITH (NOLOCK)      
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.LOC)
      JOIN dbo.ORDERS ORD WITH(NOLOCK) ON (TD.Storerkey = ORD.Storerkey AND TD.OrderKey = ORD.OrderKey)
      WHERE TD.Storerkey = @cStorerKey      
      AND   TD.TaskType = 'ASTCPK'      
      AND   TD.[Status] = '0'      
      AND   TD.Groupkey <> ''      
      AND   TD.UserKey = ''      
      AND   TD.DeviceID = ''
      AND   (
               (EXISTS(SELECT 1 FROM @tMethodShort MS WHERE ORD.UserDefine10 = MS.MethodShort) AND @cMethod <> '')
               OR
               @cMethod = ''
            )
      AND   ((TD.UserKeyOverRide = '') OR (TD.UserKeyOverRide = @cUserName))      
      AND   (( @cPickNoMixWave = '0' AND TD.WaveKey = TD.WaveKey) OR ( @cPickNoMixWave = '1' AND TD.WaveKey = @cPickWaveKey))
      AND   LOC.Facility = @cFacility       
      AND   LOC.PickZone = @cPickZone        
      AND   EXISTS ( SELECT 1 FROM @tPickMethod PM WHERE TD.PickMethod = PM.Method)      
      ORDER BY TD.priority,TD.GroupKey,CASE WHEN TD.UserKeyOverRide = @cUserName THEN '0' ELSE '1' END, TD.WaveKey, TD.Caseid      
      **/

      SET @curLockTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR      
      SELECT TD.TaskDetailKey, TD.Caseid, TD.WaveKey, TD.GroupKey
      FROM dbo.TaskDetail TD WITH (NOLOCK)      
      --JOIN dbo.LOC LOC WITH (NOLOCK) ON ( TD.FromLoc = LOC.LOC)
      JOIN dbo.ORDERS ORD WITH(NOLOCK) ON (TD.Storerkey = ORD.Storerkey AND TD.OrderKey = ORD.OrderKey)
      WHERE TD.Storerkey = @cStorerKey      
      AND   TD.TaskType = 'ASTCPK'      
      AND   TD.[Status] = '0'      
      AND   TD.Groupkey <> ''
      --AND   TD.Groupkey = @cGroupkey
      AND   TD.UserKey = ''      
      AND   TD.DeviceID = ''
      AND   TD.AreaKey = @cPickZone
      --AND   (
        --    (@cMethod <> '' AND ORD.UserDefine10 = @cShort4CDLKUp)
         --   OR (1=1)
          --  )
      AND   (
               (EXISTS(SELECT 1 FROM @tMethodShort MS WHERE ORD.UserDefine10 = MS.MethodShort) AND @cMethod <> '')
               OR
               @cMethod = ''
            )
      AND   ((TD.UserKeyOverRide = '') OR (TD.UserKeyOverRide = @cUserName))      
      AND   (( @cPickNoMixWave = '0' AND TD.WaveKey = TD.WaveKey) OR ( @cPickNoMixWave = '1' AND TD.WaveKey = @cPickWaveKey))
      --AND   LOC.Facility = @cFacility       
      --AND   LOC.PickZone = @cPickZone        
      AND   EXISTS ( SELECT 1 FROM @tPickMethod PM WHERE TD.PickMethod = PM.Method)      
      --ORDER BY TD.GroupKey,CASE WHEN TD.UserKeyOverRide = @cUserName THEN '0' ELSE '1' END, TD.WaveKey, TD.Caseid
      ORDER BY TD.Priority,CASE WHEN TD.UserKeyOverRide = @cUserName THEN '0' ELSE '1' END,ORD.DeliveryDate,TD.GroupKey   
      OPEN @curLockTask      
      FETCH NEXT FROM @curLockTask INTO @cLockTaskKey, @cNewCaseID, @cPickWaveKey, @cGroupkey  
      WHILE @@FETCH_STATUS = 0      
      BEGIN
         IF @cTempGroupKey = ''
            SET @cTempGroupKey = @cGroupKey

         IF @cGroupKey <> @cTempGroupKey
         BEGIN
            SET @cGroupKey = @cTempGroupKey
            BREAK
         END
         /**
         IF @cCurCaseID <> @cNewCaseID      
         BEGIN      
            SET @cCurCaseID = @cNewCaseID      
            SET @nCtnCount = @nCtnCount + 1      
      
            IF @nCtnCount > @nCartLimit      
               BREAK      
         END
               
         IF @cGroupKey = ''      
            SET @cGroupKey = @cLockTaskKey      
         **/

         UPDATE dbo.TaskDetail SET       
            STATUS = '3',      
            UserKey = @cUserName,      
            --Groupkey = @cGroupKey,       
            DeviceID = @cCartID,      
            EditWho = @cUserName,       
            EditDate = GETDATE(),       
            StartTime = GETDATE()      
         WHERE TaskDetailKey = @cLockTaskKey      
               
         IF @@ERROR <> 0      
         BEGIN      
            SET @nErrNo = 227558          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lock Task Fail          
            GOTO LockTask_RollBackTran          
         END      
         
         FETCH NEXT FROM @curLockTask INTO @cLockTaskKey, @cNewCaseID, @cPickWaveKey, @cGroupkey  
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
                  ('1867_patchlog', GETDATE(), @cPatchTDKey, @cPatchCaseId, @cPatchLot, @cPatchLoc, @cPatchId, @cPatchSKU, @nPatchQty, @cPatchPDKey, @nPatchPD_Qty, @cOriPatchTDKey)  
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
            SET @nErrNo = 227559          
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
         SET @nErrNo = 227560          
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
                   AND   TD.TaskType IN ( 'ASTCPK')  
                   AND   TD.[Status] = '0'  
                   AND   NOT EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)  
                                      JOIN dbo.WAVEDETAIL WD WITH (NOLOCK) ON ( PD.OrderKey = WD.OrderKey)  
                                      WHERE TD.TaskDetailKey = PD.TaskDetailKey  
                                      AND   PD.Status IN ('0', '3')  
                                      AND   WD.WaveKey = @cWaveKey))  
      BEGIN      
         SET @nErrNo = 227561          
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
            

      
      SET @cMax = ''

      IF @cMethod = '3'
      BEGIN
         SELECT TOP 1
            @cMessage01 = TD.Message01,
            @cMessage02 = TD.Message02,
            @cMessage03 = TD.Message03
         FROM Taskdetail TD WITH(NOLOCK)
         WHERE TD.storerkey = @cStorerkey
         AND TD.Groupkey = @cGroupKey

         SET @cOutField01 = @cMessage01
         SET @cOutField02 = @cMessage02
         SET @cOutField03 = @cMessage03
         
         -- Go to next screen        
         SET @nScn = @nScn_PalletInf        
         SET @nStep = @nStep_PalletInf   
      END
      ELSE IF (@cMethod = ''
            AND EXISTS(SELECT 1 
                        FROM Taskdetail TD WITH(NOLOCK)
                        INNER JOIN ORDERS ORD WITH(NOLOCK) ON (TD.storerkey = ORD.Storerkey AND TD.OrderKey = ORD.OrderKey)
                        INNER JOIN PickDetail PKD WITH(NOLOCK) ON (TD.TaskDetailKey = PKD.TaskDetailKey)
                        WHERE TD.storerkey = @cStorerkey
                        AND TD.Groupkey = @cGroupKey
                        AND PKD.UOM = '6'
                        AND ORD.UserDefine10 IN (SELECT Short FROM CodeLKUP WITH(NOLOCK) WHERE LISTNAME = 'HUSQPKTYPE' AND UDF01 = 'NON-PARCEL' AND Storerkey = @cStorerKey)                        
                        )


            )
      BEGIN
         --SELECT @cShort4CDLKUp = short FROM CodeLKUP WITH(NOLOCK) WHERE LISTNAME = 'HUSQPKTYPE' AND UDF01 = 'NON-PARCEL' AND Storerkey = @cStorerKey

         SELECT TOP 1
            @cMessage01 = TD.Message01,
            @cMessage02 = TD.Message02,
            @cMessage03 = TD.Message03
         FROM Taskdetail TD WITH(NOLOCK)
         INNER JOIN ORDERS ORD WITH(NOLOCK) ON (TD.storerkey = ORD.Storerkey AND TD.OrderKey = ORD.OrderKey)
         INNER JOIN PickDetail PKD WITH(NOLOCK) ON (TD.TaskDetailKey = PKD.TaskDetailKey)
         WHERE TD.storerkey = @cStorerkey
         AND TD.Groupkey = @cGroupKey
         AND PKD.UOM = '6'
         --AND ORD.UserDefine10 = @cShort4CDLKUp

         IF @@ROWCOUNT > 0
         BEGIN
            SET @cOutField01 = @cMessage01
            SET @cOutField02 = @cMessage02
            SET @cOutField03 = @cMessage03

            -- Go to next screen        
            SET @nScn = @nScn_PalletInf        
            SET @nStep = @nStep_PalletInf  
         END
      END
      ELSE
      BEGIN

         SET @cResult01 = ''      
         SET @cResult02 = ''      
         SET @cResult03 = ''      
         SET @cResult04 = ''      
         SET @cResult05 = ''      
         
         -- Draw matrix           
         SET @nNextPage = 0            
         EXEC rdt.rdt_TM_Assist_ClusterPick_MatrixV2         
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
            @cGroupKey        = @cGroupKey,      
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
Scn = 6471. Cart ID/Matrix screen        
   Cart ID   (field01)        
   Result01  (field01)            
   Result02  (field02)            
   Result03  (field03)            
   Result04  (field04)            
   Result05  (field05)            
   Result06  (field06)            
   Result07  (field07)            
   Result08  (field08)
   Option  1-close
***********************************************************************************/        
Step_CartMatrix:        
BEGIN        
   DECLARE @cLstTote    NVARCHAR(20)
   DECLARE @cLstStatusMsg NVARCHAR(30)
   IF @nInputKey = 1 -- ENTER        
   BEGIN        
      -- Screen mapping
      SET @cCartonId = @cInField08
      SET @cOption = @cInField10
      
      -- close
      IF @cOption = '1'
      BEGIN
         SELECT  short  
         FROM CodeLKUP WITH(NOLOCK) WHERE LISTNAME = 'HUSQPKTYPE' AND Code2 = '' AND StorerKey = @cStorerKey

         -- method = 3
         IF EXISTS(SELECT 1
                     FROM TaskDetail TD WITH(NOLOCK)
                     INNER JOIN ORDERS ORD WITH(NOLOCK)
                     ON TD.storerkey = ORD.storerkey
                     AND TD.OrderKey = ORD.OrderKey
                     WHERE Groupkey = @cGroupKey         
                     AND   TD.UserKey = @cUserName      
                     AND   TD.DeviceID = @cCartID  
                     AND ORD.UserDefine10 IN 
                           (SELECT  short  
                           FROM CodeLKUP WITH(NOLOCK) 
                           WHERE LISTNAME = 'HUSQPKTYPE' AND Code2 = '' AND StorerKey = @cStorerKey
                           )
                     )
         BEGIN
            -- have not band tote
            IF NOT EXISTS(SELECT 1 FROM dbo.TaskDetail WITH(NOLOCK)
                           WHERE TaskType = 'ASTCPK'      
                           AND   [Status] = '3'      
                           AND   Groupkey = @cGroupKey      
                           AND   UserKey = @cUserName      
                           AND   DeviceID = @cCartId
                           AND   DropID <> '')
            BEGIN
               UPDATE dbo.TaskDetail
               SET GroupKey = ''
               WHERE TaskType = 'ASTCPK'      
               AND   [Status] = '3'      
               AND   Groupkey = @cGroupKey      
               AND   UserKey = @cUserName      
               AND   DeviceID = @cCartID   
               AND   DropID = ''   
            END
         END
         ELSE-- method = 1,2
         BEGIN
            UPDATE dbo.TaskDetail
            SET status = '0',
                UserKey = '',
                DeviceID = ''
            WHERE TaskType = 'ASTCPK'      
            AND   [Status] = '3'      
            AND   Groupkey = @cGroupKey      
            AND   UserKey = @cUserName      
            AND   DeviceID = @cCartID      
            AND   DropID = ''
         END
         

         IF EXISTS(SELECT 1
                  FROM dbo.TaskDetail WITH(NOLOCK)
                  WHERE TaskType = 'ASTCPK'      
                     AND   [Status] = '3'      
                     AND   Groupkey = @cGroupKey      
                     AND   UserKey = @cUserName      
                     AND   DeviceID = @cCartID      
                     AND   DropID <> '')
         BEGIN
            --Get task for next loc        
            SET @nErrNo = 0        
            SET @cSuggFromLOC = ''        
            EXEC [RDT].[rdt_TM_Assist_ClusterPick_GetTaskV2]         
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
         
            IF @cMethod = '3' 
            AND EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)      
               WHERE Storerkey = @cStorerKey      
               AND   TaskType = 'ASTCPK'      
               AND   [Status] IN ( '3', '5')      
               AND   Groupkey = @cGroupkey      
               AND   UserKey = @cUserName      
               AND   DeviceID = @cCartID      
               AND   DropID = '')
            BEGIN
               SELECT TOP 1
                  @cLstTote = DropID,
                  @cLstStatusMsg = StatusMsg
               FROM dbo.TaskDetail WITH (NOLOCK)      
               WHERE Storerkey = @cStorerKey      
               AND   TaskType = 'ASTCPK'      
               AND   [Status] IN ( '3', '5')      
               AND   Groupkey = @cGroupkey      
               AND   UserKey = @cUserName      
               AND   DeviceID = @cCartId
               AND   DropID <> ''
               ORDER BY EditDate DESC

               UPDATE dbo.TaskDetail
               SET DropID = @cLstTote,
                   StatusMsg = @cLstStatusMsg,
                   EditWho = @cUserName,
                   EditDate = GETDATE()
               WHERE Storerkey = @cStorerKey      
               AND   TaskType = 'ASTCPK'      
               AND   [Status] IN ( '3', '5')      
               AND   Groupkey = @cGroupkey      
               AND   UserKey = @cUserName      
               AND   DeviceID = @cCartId
               AND   DropID = ''
            END

            -- Prepare next screen var        
            SET @cOutField01 = @cCartPickMethod      
            SET @cOutField02 = @cSuggFromLOC         
            SET @cOutField03 = ''      
      
            -- Go to next screen        
            SET @nScn = @nScn_Loc        
            SET @nStep = @nStep_Loc        
                  
            GOTO Quit
         END
         ELSE             
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
      END

      IF @cOption NOT IN ('1','')
      BEGIN
         SET @nErrNo = 227562                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --Invalid Opt                  
         GOTO Step_Matrix_Fail   
      END

      -- Validate blank        
      IF ISNULL( @cCartonId, '') = ''        
      BEGIN        
         SELECT TOP 1 @nCartonScanned = COUNT( DISTINCT DropID)     --PPA374 Added TOP 1 15/01/2025 
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
            SET @nErrNo = 227563     
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Tote Id        
            GOTO Step_Matrix_Fail      
         END      
      
         SELECT TOP 1 @nCartLimit = Short      --PPA374 Added TOP 1 15/01/2025
         FROM dbo.CODELKUP WITH (NOLOCK)      
         WHERE LISTNAME = 'TMPICKMTD'      
         AND   Code = @cMethod      
         AND   Storerkey = @cStorerKey      
         
         IF @cMethod = '3'
         BEGIN            
            SELECT TOP 1 @nCartonCnt = COUNT(1)   --PPA374 Added TOP 1 15/01/2025
            FROM STRING_SPLIT(@cMax, '|')
         END
         else
         BEGIN
            SELECT TOP 1 @nCartonCnt = COUNT( DISTINCT DropID)      --PPA374 Added TOP 1 15/01/2025
            FROM dbo.TaskDetail WITH (NOLOCK)      
            WHERE Storerkey = @cStorerKey      
            AND   TaskType = 'ASTCPK'      
            AND   [Status] IN ( '3', '5')      
            AND   Groupkey = @cGroupkey      
            AND   UserKey = @cUserName      
            AND   DeviceID = @cCartID      
            AND   DropID <> ''
         END

         -- 1 cart to more order
         IF  
          EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)      
                     WHERE Storerkey = @cStorerKey      
                     AND   TaskType = 'ASTCPK'      
                     AND   [Status] IN ( '3', '5')      
                     AND   Groupkey = @cGroupkey      
                     AND   UserKey = @cUserName      
                     AND   DeviceID = @cCartID      
                     AND   DropID = '')
            AND @cMethod IN ('1','2')
         BEGIN      
            SET @nErrNo = 227564                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MoreCtnToScan                  
            GOTO Step_Matrix_Fail      
         END
         ELSE IF @cMethod = '3'
            AND EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)      
                     WHERE Storerkey = @cStorerKey      
                     AND   TaskType = 'ASTCPK'      
                     AND   [Status] IN ( '3', '5')      
                     AND   Groupkey = @cGroupkey      
                     AND   UserKey = @cUserName      
                     AND   DeviceID = @cCartID      
                     AND   CAST(Message03 AS INT) <> @nCartonCnt)
         BEGIN
            SET @nErrNo = 227565                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MoreCtnToScan                  
            GOTO Step_Matrix_Fail 
         END
         ELSE  --Something scanned      
         BEGIN
            IF @cMethod = '3'
            AND EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)      
                     WHERE Storerkey = @cStorerKey      
                     AND   TaskType = 'ASTCPK'      
                     AND   [Status] IN ( '3', '5')      
                     AND   Groupkey = @cGroupkey      
                     AND   UserKey = @cUserName      
                     AND   DeviceID = @cCartID      
                     AND   DropID = '')
            BEGIN
               SELECT TOP 1
                  @cLstTote = DropID,
                  @cLstStatusMsg = StatusMsg
               FROM dbo.TaskDetail WITH (NOLOCK)      
               WHERE Storerkey = @cStorerKey      
               AND   TaskType = 'ASTCPK'      
               AND   [Status] IN ( '3', '5')      
               AND   Groupkey = @cGroupkey      
               AND   UserKey = @cUserName      
               AND   DeviceID = @cCartId
               AND   DropID <> ''
               ORDER BY EditDate DESC

               UPDATE dbo.TaskDetail
               SET DropID = @cLstTote,
                   StatusMsg = @cLstStatusMsg,
                   EditWho = @cUserName,
                   EditDate = GETDATE()
               WHERE Storerkey = @cStorerKey      
               AND   TaskType = 'ASTCPK'      
               AND   [Status] IN ( '3', '5')      
               AND   Groupkey = @cGroupkey      
               AND   UserKey = @cUserName      
               AND   DeviceID = @cCartId
               AND   DropID = ''
               
            END

            --Get task for next loc        
            SET @nErrNo = 0        
            SET @cSuggFromLOC = ''        
            EXEC [RDT].[rdt_TM_Assist_ClusterPick_GetTaskV2]         
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
      
      IF CHARINDEX(' ',@cCartonId)>0 OR LEN(@cCartonId) <> 18 OR CONVERT(NVARCHAR(30),substring(@cCartonId,1,3)) <> '050'                 
      BEGIN                  
         SET @nErrNo = 229601                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 229601 Invalid Drop ID                
         GOTO Quit                
      END                 

      --1.Exists in pickdetail                
      --2.Exists in Packdetail               
      --3.Exists in Dropid        
     --4.Not the same trolley order
      ELSE IF ((EXISTS (SELECT 1 FROM dbo.PICKDETAIL WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cCartonId))                 
      OR EXISTS(select 1 FROM dbo.PackDetail (NOLOCK) where STORERKEY = @cStorerKey AND Dropid = @cCartonId)                 
      OR EXISTS(SELECT dropid FROM dbo.dropid (NOLOCK) WHERE Dropid = @cCartonId))
      AND (SELECT TOP 1 ORDERKEY FROM dbo.PICKDETAIL WITH(NOLOCK) WHERE StorerKey = @cStorerKey AND DropID = @cCartonId AND STATUS <> '9') <> right(@cResult01,10)
      BEGIN                    
         SET @nErrNo = 229602                    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--DropIDIsUsed                    
         GOTO Quit                
      END                  
      --Pickdetail from loc is not PICK, SHELF OR CASE loc                                 
      ELSE IF EXISTS (SELECT 1 FROM dbo.PICKDETAIL PD (NOLOCK)                   
                     JOIN dbo.LOC LOC WITH (NOLOCK) ON LOC.LOC = PD.Notes                  
                     WHERE PD.STORERKEY = @cStorerKey AND PD.dropid = @cCartonId                   
                     AND (LOC.LocationType NOT IN ('PICK','CASE','SHELF') AND LOC.Facility = @cFacility))                 
      BEGIN                     
         SET @nErrNo = 229603                    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDUsedforPAL                    
         GOTO Quit                 
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
         SET @nErrNo = 227566        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Assigned        
         GOTO Step_Matrix_Fail        
      END        
      
      IF @cMethod = '3'
      BEGIN
         IF @cMax <> ''
            SELECT TOP 1 @nCartonCnt = COUNT(1)   --PPA374 Added TOP 1 15/01/2025
               FROM STRING_SPLIT(@cMax, '|')

         IF EXISTS( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)      
                     WHERE Storerkey = @cStorerKey      
                     AND   TaskType = 'ASTCPK'      
                     AND   [Status] IN ( '3', '5')      
                     AND   Groupkey = @cGroupkey      
                     AND   UserKey = @cUserName      
                     AND   DeviceID = @cCartID      
                     AND   CAST(Message03 AS INT) = @nCartonCnt)
         BEGIN
            SET @nErrNo = 227567        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --All Assigned        
            GOTO Step_Matrix_Fail  
         END
      END
      ELSE
      Begin

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
            SET @nErrNo = 227567        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --All Assigned        
            GOTO Step_Matrix_Fail      
         END      
      End

      IF EXISTS ( SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK)      
                  WHERE Storerkey = @cStorerKey      
                  AND   DropID = @cCartonID      
                  AND  ([Status] = '4' OR       
                        [Status] < @cPickConfirmStatus OR       
                        ([Status] = '3' AND CaseID <> 'SORTED') OR      
                        ([Status] = '3' AND CaseID <> '')))       
      BEGIN      
         SET @nErrNo = 227568        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote In Use        
         GOTO Step_Matrix_Fail      
      END      
            
      IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)      
                  WHERE Storerkey = @cStorerKey      
                  --AND   TaskType = 'ASTCPK'      
                  AND   [Status] < '9'      
                  AND   DropID = @cCartonID)      
      BEGIN      
         SET @nErrNo = 227569        
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
      
      SELECT TOP 1 @nCartonScanned = COUNT( DISTINCT DropID)      --PPA374 Added TOP 1 15/01/2025
      FROM dbo.TaskDetail WITH (NOLOCK)      
      WHERE Storerkey = @cStorerKey      
      AND   TaskType = 'ASTCPK'      
      AND   [Status] = '3'      
      AND   Groupkey = @cGroupKey      
      AND   UserKey = @cUserName      
      AND   DeviceID = @cCartID      
      AND   DropID <> ''      
      
      SELECT TOP 1 @cCartonType = UDF01      --PPA374 Added TOP 1 15/01/2025
      FROM dbo.CODELKUP WITH (NOLOCK)      
      WHERE LISTNAME = 'TMPICKMTD'      
      AND   Code = @cMethod      
      AND   Storerkey = @cStorerKey      
         
      SET @cPickMethod = ''      
      SELECT TOP 1 @cPickMethod = Long       --PPA374 Added TOP 1 15/01/2025
      FROM dbo.CODELKUP WITH (NOLOCK)      
      WHERE LISTNAME = 'TMPICKMTD'      
      AND   Storerkey = @cStorerKey      
      --AND   UDF01 = SUBSTRING( @cCartonId, 1, 1)      
                        
      SELECT TOP 1 @cLockOrderKey = OrderKey
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE Storerkey = @cStorerKey
      AND   TaskType = 'ASTCPK'
      AND   [Status] = '3'
      AND   Groupkey = @cGroupKey
      AND   UserKey = @cUserName
      AND   DeviceID = @cCartID
      AND   DropID = ''
      AND   PickMethod = @cPickMethod
      ORDER BY OrderKey

      DECLARE @curLockOrder CURSOR 
      
      IF (@cMethod = '3')
      BEGIN
         SELECT TOP 1
            @cLockTaskKey = TaskDetailKey,
            @cMessage03 = Message03
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
         AND   TaskType = 'ASTCPK'
         AND   [Status] = '3'
         AND   Groupkey = @cGroupKey
         AND   UserKey = @cUserName
         AND   DeviceID = @cCartID
         AND   OrderKey = @cLockOrderKey
         AND   DropID = ''
         ORDER BY 1 

         DECLARE @nAssignedCartonCnt      INT
         SELECT TOP 1 @nAssignedCartonCnt = COUNT(DISTINCT DropID) --PPA374 Added TOP 1 15/01/2025
         FROM dbo.TaskDetail WITH(NOLOCK)
         WHERE Storerkey = @cStorerKey
            AND   TaskType = 'ASTCPK'
            AND   Groupkey = @cGroupKey
            AND   DeviceID = @cCartID
            AND   OrderKey = @cLockOrderKey
            AND   DropID <> '' 

         IF @nAssignedCartonCnt >= CAST(@cMessage03 AS INT)
         BEGIN      
            SET @nErrNo = 227570        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ayd Max Tote        
            GOTO Step_Matrix_Fail      
         END      
         
         UPDATE dbo.TaskDetail SET
            DropID = @cCartonID,
            StatusMsg =  CAST( @nCartonScanned + 1 AS NVARCHAR( 1)) + '-' + @cCartonType,
            EditWho = @cUserName,
            EditDate = GETDATE()
         WHERE TaskDetailKey = @cLockTaskKey
         
         IF ISNULL(@cMax,'') = ''
         BEGIN
            SET @cMax = @cCartonID
         END
         ELSE
         BEGIN
            SET @cMax = @cMax + '|' + @cCartonID
         END

         IF @@ERROR <> 0      
         BEGIN      
            SET @nErrNo = 227571        
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Assign Fail        
            GOTO Step_Matrix_Fail      
         End
      END
      --IF @cMethod IN ('1','2')
      ELSE
      BEGIN              
         SET @curLockOrder = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR      
         SELECT TaskDetailKey      
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
         AND   TaskType = 'ASTCPK'
         AND   [Status] = '3'
         AND   Groupkey = @cGroupKey
         AND   UserKey = @cUserName
         AND   DeviceID = @cCartID
         AND   OrderKey = @cLockOrderKey
         AND   DropID = ''      
         ORDER BY 1      
         OPEN @curLockOrder      
         FETCH NEXT FROM @curLockOrder INTO @cLockTaskKey      
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
               SET @nErrNo = 227572        
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Assign Fail        
            GOTO Step_Matrix_Fail      
            END      
               
            FETCH NEXT FROM @curLockOrder INTO @cLockTaskKey      
         END      
      END

      -- Draw matrix           
      SET @nNextPage = 0            
      EXEC rdt.rdt_TM_Assist_ClusterPick_MatrixV2         
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
         @cGroupKey        = @cGroupKey,      
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
Scn = 6472. Loc        
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
         SET @nErrNo = 227573        
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Loc        
         GOTO Step_Loc_Fail        
      END        
     
      -- Validate option        
      IF @cFromLoc <> @cSuggFromLOC        
      BEGIN        
         SET @nErrNo = 227574        
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
            
      SELECT TOP 1 @cSKUDescr = DESCR        --PPA374 Added TOP 1 15/01/2025
      FROM dbo.SKU WITH (NOLOCK)        
      WHERE StorerKey = @cStorerKey        
      AND   SKU = @cSuggSKU        
              
      SELECT TOP 1 @nSuggQty = ISNULL( SUM( PKD.Qty), 0)       --PPA374 Added TOP 1 15/01/2025 
      FROM dbo.PICKDETAIL PKD WITH (NOLOCK)
      INNER JOIN dbo.TaskDetail TD WITH(NOLOCK) ON (PKD.StorerKey = TD.StorerKey AND PKD.TaskDetailKey = TD.TaskDetailKey)
      WHERE PKD.StorerKey = @cStorerKey        
      AND   PKD.Loc = @cFromLoc        
      AND   PKD.Sku = @cSuggSKU        
      AND   PKD.CaseID = @cSuggCartonID        
      AND   PKD.[Status] < @cPickConfirmStatus        
      AND   TD.GroupKey = @cGroupKey
      AND   TD.TaskDetailKey = @cTaskdetailKey

      SELECT TOP 1 @nPickedQty = ISNULL( SUM( PKD.Qty), 0)    --PPA374 Added TOP 1 15/01/2025    
      FROM dbo.PICKDETAIL PKD WITH (NOLOCK)
      INNER JOIN dbo.TaskDetail TD WITH(NOLOCK) ON (PKD.StorerKey = TD.StorerKey AND PKD.TaskDetailKey = TD.TaskDetailKey)
      WHERE PKD.StorerKey = @cStorerKey        
      AND   PKD.Loc = @cFromLoc        
      AND   PKD.Sku = @cSuggSKU        
      AND   PKD.CaseID = @cSuggCartonID        
      AND   PKD.[Status] = @cPickConfirmStatus        
      AND   TD.GroupKey = @cGroupKey
      AND   TD.TaskDetailKey = @cTaskdetailKey

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
      SELECT TOP 1 @nCartonScanned = COUNT( DISTINCT DropID)      --PPA374 Added TOP 1 15/01/2025
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
Scn = 6473. SKU QTY screen          
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
                  SET @nErrNo = 227575          
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
               SET @nErrNo = 227576          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU          
               EXEC rdt.rdtSetFocusField @nMobile, 6      
               GOTO Step_SKUQTY_Fail          
            END          
          
            -- Check barcode return multi SKU          
            IF @nSKUCnt > 1          
            BEGIN          
               SET @nErrNo = 227577          
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
               SET @nErrNo = 227578          
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
         SET @nErrNo = 227579          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY          
         EXEC rdt.rdtSetFocusField @nMobile, 7 -- QTY          
         GOTO Step_SKUQTY_Fail          
      END          
          
      -- Check full short with QTY          
      IF @cSKUValidated = '99' AND @cQTY <> '0' AND @cQTY <> ''          
      BEGIN          
         SET @nErrNo = 227580          
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
         SET @nErrNo = 227581          
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
               GOTO Step_Matrix_Fail        
         END        
      END        
        
      -- Save to ActQTY          
      SET @nActQTY = @nActQTY + @nQTY          

      -- Serial No
      IF @cSerialNoCapture IN ('1', '3')  -- 1 = INBOUND & OUTBOUND; 2 = INBOUND ONLY; 3 = OUTBOUND ONLY
      BEGIN
         -- Validate QTY          
         IF @cQTY  = 0  AND @cSKUValidated <> '99'       
         BEGIN          
            SET @nErrNo = 227579          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY          
            EXEC rdt.rdtSetFocusField @nMobile, 7 -- QTY          
            GOTO Step_SKUQTY_Fail          
         END 

         EXEC rdt.rdt_SerialNo  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDescr, @nQTY, 'CHECK', 'PICKSLIP', @cPickSlipNo,
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
            @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
            @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn = 0,
            @nBulkSNO = 0,       @nBulkSNOQTY = 0,     @cSerialCaptureType = '3'

         IF @nErrNo <> 0
            GOTO Quit

         IF @nMoreSNO = 1
         BEGIN
            -- Go to Serial No screen
            SET @nScn = @nScn_SerialNo
            SET @nStep = @nStep_SerialNo

            GOTO Quit
         END
      END
            
      -- SKU scanned, remain in current screen          
      IF @cBarcode <> ''  AND @cBarcode <> '99'        
      BEGIN
         IF @cMethod = '3'
         BEGIN
            -- Confirm          
            EXEC rdt.rdt_TM_Assist_ClusterPick_ConfirmPickV2           
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
               @cSerialNo        = '',
               @nSerialQTY       = 0,
               @nBulkSNO         = 0,
               @nBulkSNOQTY      = 0,
               @nErrNo           = @nErrNo   OUTPUT,          
               @cErrMsg          = @cErrMsg  OUTPUT          
         
            IF @nErrNo <> 0          
               GOTO Quit   
               
            SELECT TOP 1 --PPA374 Added TOP 1 15/01/2025      
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
         else
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
      END          
          
      -- QTY short          
      IF @nActQTY < @nSuggQTY          
      BEGIN          
         SET @nActQTY = @nActQTY - @nQTY        
        
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
         EXEC rdt.rdt_TM_Assist_ClusterPick_ConfirmPickV2           
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
            @cSerialNo        = '',
            @nSerialQTY       = 0,
            @nBulkSNO         = 0,
            @nBulkSNOQTY      = 0,
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
               
         SELECT TOP 1 --PPA374 Added TOP 1 15/01/2025      
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
   Begin

      IF EXISTS(SELECT 1
               FROM PickSerialNo PSN WITH(NOLOCK)
               INNER JOIN PICKDETAIL PD WITH(NOLOCK) ON PSN.PickDetailKey = PD.PickDetailKey AND PSN.Storerkey = PD.Storerkey
               WHERE PD.Storerkey = @cStorerKey
               AND PD.TaskdetailKey = @cTaskdetailKey)
      BEGIN
         DELETE PSN 
         FROM PickSerialNo PSN
         JOIN PICKDETAIL PD ON PSN.PickDetailkey = PD.PickDetailkey AND PSN.storerkey = PD.Storerkey
         WHERE PD.TaskdetailKey = @cTaskdetailKey
         AND PSN.storerkey = @cStorerKey
      END      

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
Scn = 6474. Confirm Tote Id              
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
         SET @nErrNo = 227582                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Tote Id                  
         GOTO Step_ConfirmTote_Fail                  
      END                  

      

      -- Validate option                  
      IF @cCartonID <> @cCartonId2Confirm        
      BEGIN
         IF @cMethod <> '3'
         BEGIN
            SET @nErrNo = 227583                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Not Match                  
            GOTO Step_ConfirmTote_Fail 
         END
         /**ELSE IF NOT EXISTS(SELECT 1 
                        FROM dbo.PICKDETAIL PKD WITH(NOLOCK)
                        INNER JOIN TaskDetail TD WITH(NOLOCK)
                           ON PKD.storerkey = TD.storerkey
                           AND PKD.TaskDetailKey = TD.TaskDetailKey
                        WHERE TD.Storerkey = @cStorerKey      
                           AND   TD.TaskType = 'ASTCPK'
                           AND   TD.Groupkey = @cGroupkey      
                           AND   TD.UserKey = @cUserName      
                           AND   TD.DeviceID = @cCartId 
                           AND   PKD.DropID = @cCartonID
                           )
         Begin
            SET @nErrNo = 227584                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Not USE to pick                  
            GOTO Step_ConfirmTote_Fail
         END **/
         ELSE IF NOT EXISTS(SELECT 1
                           FROM STRING_SPLIT(@cMax, '|')
                           WHERE Value = @cCartonId2Confirm
                           )
         Begin
            SET @nErrNo = 227584                  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Tote Not USE to pick                  
            GOTO Step_ConfirmTote_Fail
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
               @cGroupKey, @cTaskDetailKey, @cPickZone, @cCartId, @cMethod, @cFromLoc, @cCartonId2Confirm,       
               @cSKU, @nQty, @cOption, @cToLoc, @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT        
        
            IF @nErrNo <> 0         
               GOTO Quit        
         END        
      END    

      -- Extended update        
      IF @cExtendedUpdateSP <> ''        
      BEGIN        
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')        
         Begin
            DELETE FROM @tExtUpdate
            INSERT INTO @tExtUpdate (Variable, Value) VALUES    
            ('@cCartonId2Confirm',     @cCartonId2Confirm)

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

      -- Get task in same LOC          
      SET @cSKUValidated = '0'          
      SET @nActQTY = 0          
                 
      SET @nErrNo = 0        
      EXEC [RDT].[rdt_TM_Assist_ClusterPick_GetTaskV2]         
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
         SELECT TOP 1 @cSKUDescr = DESCR        --PPA374 Added TOP 1 15/01/2025
         FROM dbo.SKU WITH (NOLOCK)        
         WHERE StorerKey = @cStorerKey        
         AND   SKU = @cSuggSKU        
        
         SELECT TOP 1 @nSuggQty = ISNULL( SUM( Qty), 0)        --PPA374 Added TOP 1 15/01/2025
         FROM dbo.PICKDETAIL WITH (NOLOCK)        
         WHERE StorerKey = @cStorerKey        
         AND   Loc = @cFromLoc        
         AND   Sku = @cSuggSKU        
         AND   CaseID = @cSuggCartonID        
         AND   [Status] < @cPickConfirmStatus      
        
         SELECT TOP 1 @nPickedQty = ISNULL( SUM( Qty), 0)        --PPA374 Added TOP 1 15/01/2025
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
         EXEC [RDT].[rdt_TM_Assist_ClusterPick_GetTaskV2]         
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
            SELECT TOP 1 @cSKUDescr = DESCR        --PPA374 Added TOP 1 15/01/2025
            FROM dbo.SKU WITH (NOLOCK)        
            WHERE StorerKey = @cStorerKey        
            AND   SKU = @cSuggSKU        
           

            SELECT TOP 1 @nSuggQty = ISNULL( SUM( PKD.Qty), 0)        --PPA374 Added TOP 1 15/01/2025
            FROM dbo.PICKDETAIL PKD WITH (NOLOCK)
            INNER JOIN dbo.TaskDetail TD WITH(NOLOCK) ON (PKD.StorerKey = TD.StorerKey AND PKD.TaskDetailKey = TD.TaskDetailKey)
            WHERE PKD.StorerKey = @cStorerKey        
            AND   PKD.Loc = @cFromLoc        
            AND   PKD.Sku = @cSuggSKU        
            AND   TD.DropID = @cSuggToteId        
            AND   PKD.[Status] < '9'        
            AND   TD.GroupKey = @cGroupKey
            AND   TD.TaskDetailKey = @cTaskdetailKey

            SELECT TOP 1 @nPickedQty = ISNULL( SUM( PKD.Qty), 0)        --PPA374 Added TOP 1 15/01/2025
            FROM dbo.PICKDETAIL PKD WITH (NOLOCK)
            INNER JOIN dbo.TaskDetail TD WITH(NOLOCK) ON (PKD.StorerKey = TD.StorerKey AND PKD.TaskDetailKey = TD.TaskDetailKey)
            WHERE PKD.StorerKey = @cStorerKey        
            AND   PKD.Loc = @cFromLoc        
            AND   PKD.Sku = @cSuggSKU        
            AND   TD.DropID = @cSuggToteId        
            AND   PKD.[Status] = @cPickConfirmStatus        
            AND   TD.GroupKey = @cGroupKey
            AND   TD.TaskDetailKey = @cTaskdetailKey    
              
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
               AND   TaskType = 'ASTCPK'        
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
      
               SELECT TOP 1 @cSuggToLOC = ToLoc      --PPA374 Added TOP 1 15/01/2025
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
               @cGroupKey, @cTaskDetailKey, @cPickZone, @cCartId, @cMethod, @cFromLoc, @cCartonId2Confirm,       
               @cSKU, @nQty, @cOption, @cToLoc, @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT        
        
            IF @nErrNo <> 0         
               GOTO Step_ConfirmTote_Fail
         END
      END


                      
      
      IF @cMethod = '3'
      BEGIN
         SELECT TOP 1 @cSKUDescr = DESCR        --PPA374 Added TOP 1 15/01/2025
         FROM dbo.SKU WITH (NOLOCK)        
         WHERE StorerKey = @cStorerKey        
         AND   SKU = @cSuggSKU        
         
         SELECT TOP 1 @nSuggQty = ISNULL( SUM( PKD.Qty), 0)        --PPA374 Added TOP 1 15/01/2025
         FROM dbo.PICKDETAIL PKD WITH (NOLOCK)
         INNER JOIN dbo.TaskDetail TD WITH(NOLOCK) ON (PKD.StorerKey = TD.StorerKey AND PKD.TaskDetailKey = TD.TaskDetailKey)
         WHERE PKD.StorerKey = @cStorerKey        
         AND   PKD.Loc = @cFromLoc        
         AND   PKD.Sku = @cSuggSKU        
         AND   PKD.CaseID = @cSuggCartonID        
         AND   PKD.[Status] < @cPickConfirmStatus        
         AND   TD.GroupKey = @cGroupKey
         AND   TD.TaskDetailKey = @cTaskdetailKey

         SELECT TOP 1 @nPickedQty = ISNULL( SUM( PKD.Qty), 0)        --PPA374 Added TOP 1 15/01/2025
         FROM dbo.PICKDETAIL PKD WITH (NOLOCK)
         INNER JOIN dbo.TaskDetail TD WITH(NOLOCK) ON (PKD.StorerKey = TD.StorerKey AND PKD.TaskDetailKey = TD.TaskDetailKey)
         WHERE PKD.StorerKey = @cStorerKey        
         AND   PKD.Loc = @cFromLoc        
         AND   PKD.Sku = @cSuggSKU        
         AND   PKD.CaseID = @cSuggCartonID        
         AND   PKD.[Status] = @cPickConfirmStatus        
         AND   TD.GroupKey = @cGroupKey
         AND   TD.TaskDetailKey = @cTaskdetailKey      
               
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
     
         
         EXEC rdt.rdtSetFocusField @nMobile, 6        
         
         SET @nActQTY = 0         
         
         -- Go to next screen        
         SET @nScn = @nScn_SKUQTY        
         SET @nStep = @nStep_SKUQTY
      END
      ELSE
      BEGIN
         -- User must confirm tote as this point because the sku already picked      
         -- User might not know where to put back sku      
         SET @nErrNo = 227585                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Confirm Tote                  
         GOTO Step_ConfirmTote_Fail  
      END
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
Scn = 6475. Confirm Short Pick?              
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
         SET @nErrNo = 227586                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option required                  
         GOTO Step_Option_Fail                  
      END                  
                  
      -- Validate option                  
      IF @cOption NOT IN ( '1', '2')      
      BEGIN                  
         SET @nErrNo = 227587                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option                  
         GOTO Step_Option_Fail                  
      END                  

	  
   --NICK
   DECLARE @NICKMSG NVARCHAR(500)
   SET @NICKMSG = CONCAT_WS(',', 'rdtfnc_TM_Assist_ClusterPickV2-Option',
		'@nMobile: ' + CAST(@nMobile AS NVARCHAR(10)),  
		'@nFunc: ' + CAST(@nFunc AS NVARCHAR(10)),  
		'@cLangCode: ' + @cLangCode,
		'@nInputKey: ' + CAST(@nInputKey AS NVARCHAR(10)),  
		'@cFacility: ' + @cFacility,
		'@cStorerKey: ' + @cStorerKey,
		'@cCartID: ' + @cCartID,
		'@cGroupKey: ' + @cGroupKey,
		'@cTaskDetailKey: ' + @cTaskDetailKey,
		'@nActQTY: ' + CAST(@nActQTY AS NVARCHAR(10))
	)
   INSERT INTO DocInfo (Tablename, Storerkey, key1, key2, key3, lineSeq, Data)
	VALUES ('NICKLOG', '', '', '', '', 0, @NICKMSG)

      
      -- Handling transaction                  
      SET @nTranCount = @@TRANCOUNT                  
      BEGIN TRAN  -- Begin our own transaction                  
      SAVE TRAN Step_Option -- For rollback or commit only our own transaction                  
                  
      -- Confirm                  
      IF @cOption = '1'                  
      BEGIN                  
         -- Confirm          
         EXEC rdt.rdt_TM_Assist_ClusterPick_ConfirmPickV2           
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
            @cSerialNo        = '',
            @nSerialQTY       = 0,
            @nBulkSNO         = 0,
            @nBulkSNOQTY      = 0,
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
         -- Prepare next screen var      
         SET @cOutField01 = ''   
         SET @nScn = @nScn_ReasonCD      
         SET @nStep = @nStep_ReasonCD      
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
Scn = 6476. To Loc             
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
         SET @nErrNo = 227588          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC needed          
         GOTO Step_ToLoc_Fail          
      END          
          
      -- Check if FromLOC match          
      IF @cToLOC <> @cSuggToLOC  AND ISNULL( @cSuggToLOC, '') <> ''        
      BEGIN   
                   
         -- Check ToLOC valid          
         IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC)          
         BEGIN          
            SET @nErrNo = 227589          
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC          
            GOTO Step_ToLoc_Fail          
         END
                
         IF @cOverwriteToLOC <> '1'          
         BEGIN          
            --should allow to overwrite only if TO_LOC is VAS
            --(LocationType = VAS), else the override is not allowed
            DECLARE @cToLoctionType    NVARCHAR(10)
            SELECT TOP 1 @cToLoctionType = LocationType --PPA374 Added TOP 1 15/01/2025
            FROM Loc WITH(NOLOCK)
            WHERE Loc = @cSuggToLOC

            IF @cToLoctionType <> N'VAS' OR
               NOT EXISTS(SELECT 1 FROM Loc WITH(NOLOCK) WHERE Loc = @cToLOC AND LocationType = 'VAS')
            BEGIN
               SET @nErrNo = 227590          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC Diff          
               GOTO Step_ToLoc_Fail   
            END
         END      
      END          

	     -- NICK
   --DECLARE @NICKMSG NVARCHAR(500)
   SET @NICKMSG = CONCAT_WS(',', 'rdtfnc_TM_Assist_ClusterPickV2',
   '@nMobile: ' + CAST(@nMobile AS NVARCHAR(5)),
   '@nFunc: ' + CAST(@nFunc AS NVARCHAR(5)),
   '@cLangCode: ' + @cLangCode,
   '@nStep: ' + CAST(@nStep AS NVARCHAR(5)) ,
   '@nInputKey: ' + CAST(@nInputKey AS NVARCHAR(5)),
   '@cFacility: ' + @cFacility,
   '@cStorerKey: ' + @cStorerKey,
   '@cTaskDetailKey: ' + @cTaskDetailKey,
   '@cToLOC: ' + @cToLOC
   )
   INSERT INTO DocInfo (Tablename, Storerkey, key1, key2, key3, lineSeq, Data)
	VALUES ('NICKLOG', '', '', '', '', 0, @NICKMSG)
      
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
      
      SET @cMax = ''

      IF @cUnassignToLOCFlag = '1' --Dennis 21/01/2025
      BEGIN
         SET @nTranCount = @@TRANCOUNT      
         BEGIN TRAN      
         SAVE TRAN UnAssign2      
            
         -- 1. unassign those locked but not picked task      
         SET @nErrNo = 0      
         DECLARE @curUnAssign2 CURSOR      
         SET @curUnAssign2 = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR      
         SELECT TaskDetailKey      
         FROM dbo.TaskDetail WITH (NOLOCK)      
         WHERE Storerkey = @cStorerKey      
         AND   TaskType = 'ASTCPK'      
         AND   [Status] = '3'      
         AND   Groupkey = @cGroupKey      
         AND   UserKey = @cUserName      
         AND   DeviceID = @cCartID
         OPEN @curUnAssign2      
         FETCH NEXT FROM @curUnAssign2 INTO @cUnAssignTaskKey      
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            UPDATE dbo.TaskDetail SET       
               STATUS = '0',      
               UserKey = '',      
               --Groupkey = '',       
               DeviceID = '',      
               DropID = '',      
               StatusMsg = '',      
               EditWho = @cUserName,       
               EditDate = GETDATE()      
            WHERE TaskDetailKey = @cUnAssignTaskKey      
               
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 227593          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lock Task Fail          
               GOTO UnAssign_RollBackTran2          
            END      
               
            FETCH NEXT FROM @curUnAssign2 INTO @cUnAssignTaskKey      
         END      
         CLOSE @curUnAssign2      
         DEALLOCATE @curUnAssign2      
      
         -- 2. Confirm those locked and picked task      
         SET @curUnAssign2 = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR      
         SELECT TaskDetailKey      
         FROM dbo.TaskDetail WITH (NOLOCK)      
         WHERE Storerkey = @cStorerKey      
         AND   TaskType = 'ASTCPK'      
         AND   [Status] = '5'      
         AND   Groupkey = @cGroupKey      
         AND   UserKey = @cUserName      
         AND   DeviceID = @cCartID      
         OPEN @curUnAssign2      
         FETCH NEXT FROM @curUnAssign2 INTO @cUnAssignTaskKey      
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            UPDATE dbo.TaskDetail SET       
               STATUS = '9',      
               EditWho = @cUserName,       
               EditDate = GETDATE()      
            WHERE TaskDetailKey = @cUnAssignTaskKey      
               
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 227594          
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lock Task Fail          
               GOTO UnAssign_RollBackTran2          
            END      
               
            FETCH NEXT FROM @curUnAssign2 INTO @cUnAssignTaskKey      
         END      
         
         SET @cUnassignToLOCFlag = '' --Dennis 21/01/2025

         GOTO UnAssign_Commit2      
      
         UnAssign_RollBackTran2:        
               ROLLBACK TRAN UnAssign2        
         UnAssign_Commit2:        
            WHILE @@TRANCOUNT > @nTranCount        
               COMMIT TRAN        
      
         IF @nErrNo <> 0      
            GOTO Quit      
         
         SET @cMax = ''
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
Scn = 6477. UnAssign Cart?              
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
         SET @nErrNo = 227591                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option required                  
         GOTO Step_UnAssign_Fail                  
      END                  
                  
      -- Validate option                  
      IF @cOption NOT IN ('1', '2')       
      BEGIN                  
         SET @nErrNo = 227592                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option                  
         GOTO Step_UnAssign_Fail                  
      END                  
      
      IF @cOption = '1'
      BEGIN
         IF @cSKU <> ''  AND @cCartonID <> ''--Dennis 21/01/2025
         BEGIN
            SELECT TOP 1 @cSuggToLOC = ToLoc      --PPA374 Added TOP 1 15/01/2025
            FROM dbo.TaskDetail WITH (NOLOCK)      
            WHERE TaskDetailKey = @cTaskDetailKey

            IF @cConfirmToLoc = '1' 
            BEGIN
               SET @cUnassignToLOCFlag = '1' --Dennis 21/01/2025

               -- Prepare next screen var          
               SET @cOutField01 = @cCartPickMethod      
               SET @cOutField02 = @cSuggToLOC -- To LOC          
               SET @cOutField03 = ''

               SET @nScn = @nScn_ToLoc          
               SET @nStep = @nStep_ToLoc
               GOTO QUIT
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
            END
         END

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
               --Groupkey = '',       
               DeviceID = '',      
               DropID = '',      
               StatusMsg = '',      
               EditWho = @cUserName,       
               EditDate = GETDATE()      
            WHERE TaskDetailKey = @cUnAssignTaskKey      
            
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 227593          
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
               SET @nErrNo = 227594          
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
      
         SET @cMax = ''
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
         SELECT TOP 1 @nCartonScanned = COUNT( DISTINCT DropID)      --PPA374 Added TOP 1 15/01/2025
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
      SELECT TOP 1 @nCartonScanned = COUNT( DISTINCT DropID)      --PPA374 Added TOP 1 15/01/2025
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
Scn = 6478. Message screen        
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
Scn = 6479. Task exists, continue?              
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
         SET @nErrNo = 227595                  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option required                  
         GOTO Step_ContTask_Fail                  
      END                  
                  
      -- Validate option                  
      IF @cOption NOT IN ( '1', '2')      
      BEGIN                  
         SET @nErrNo = 227596                  
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
      
         SELECT TOP 1 @nCartLimit = Short     --PPA374 Added TOP 1 15/01/2025 
         FROM dbo.CODELKUP WITH (NOLOCK)      
         WHERE LISTNAME = 'TMPICKMTD'      
         AND UDF01 = RIGHT( @cCartType, CHARINDEX( '-', REVERSE( @cCartType)) - 1)      
         AND   Storerkey = @cStorerKey      
               
         SELECT TOP 1 @nCartonCnt = COUNT( DISTINCT DropID)      --PPA374 Added TOP 1 15/01/2025
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
            SET @nErrNo = 227597                  
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

/********************************************************************************
Step 9. Screen = 6480. Serial No
   SKU            (Field01)
   SKUDesc1       (Field02)
   SKUDesc2       (Field03)
   SerialNo       (Field04, input)
   Scan           (Field05)
********************************************************************************/
Step_SerialNo:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Update SKU setting
      EXEC rdt.rdt_SerialNo @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, @cSKUDescr, @nQTY, 'UPDATE', 'PICKSLIP', @cPickSlipNo,
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
         @nMoreSNO   OUTPUT,  @cSerialNo   OUTPUT,  @nSerialQTY   OUTPUT,
         @nErrNo     OUTPUT,  @cErrMsg     OUTPUT,  @nScn,
         @nBulkSNO   OUTPUT,  @nBulkSNOQTY OUTPUT,  @cSerialCaptureType = '3'

      IF @nErrNo <> 0
         GOTO Quit

      DECLARE @nPickSerialQTY INT
      IF @nBulkSNO > 0
         SET @nPickSerialQTY = @nBulkSNOQTY
      ELSE IF @cSerialNo <> ''
         SET @nPickSerialQTY = @nSerialQTY
      ELSE
         SET @nPickSerialQTY = @nQTY
      
      /**
      
   
      -- Confirm          
      EXEC rdt.rdt_TM_Assist_ClusterPick_ConfirmPickV2           
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
         @nQTY             = @nPickSerialQTY,         
         @cSerialNo        = @cSerialNo,
         @nSerialQTY       = @nSerialQTY,
         @nBulkSNO         = @nBulkSNO,
         @nBulkSNOQTY      = @nBulkSNOQTY,
         @tConfirm         = @tConfirm,        
         @nErrNo           = @nErrNo   OUTPUT,          
         @cErrMsg          = @cErrMsg  OUTPUT   
        

      
      IF @nErrNo <> 0          
         GOTO Quit 
      **/       
      /**
      DECLARE @nPickedSNQty      INT
      SELECT @nPickedSNQty = COUNT(1)
      FROM PickSerialNo PSN WITH(NOLOCK)
      INNER JOIN PICKDETAIL PD WITH(NOLOCK) ON PSN.PickDetailKey = PD.PickDetailKey AND PSN.Storerkey = PD.Storerkey
      INNER JOIN Taskdetail TD WITH(NOLOCK) ON PD.TaskdetailKey = TD.TaskdetailKey AND PD.Storerkey = TD.Storerkey
      WHERE TD.Storerkey = @cStorerKey
      AND TD.TaskdetailKey = @cTaskdetailKey
**/
      INSERT INTO PickSerialNo (PickDetailKey, StorerKey, SKU, SerialNo, QTY)
      SELECT TOP 1
         PD.PickDetailkey,
         PD.StorerKey,
         PD.SKU,
         @cSerialNo,
         @nSerialQTY
      FROM PickDetail PD WITH(NOLOCK)
      WHERE PD.Storerkey = @cStorerKey
      AND PD.Sku = @cSKu
      AND PD.TaskdetailKey = @cTaskdetailKey
      AND   PD.[Status] < '5'
      AND   PD.QTY > 0 
      AND   PD.Status <> '4'

      IF @nMoreSNO = 1
         GOTO Quit

      -- QTY fulfill or method 3   
      IF @nActQTY = @nSuggQTY
      OR EXISTS(SELECT 1 FROM Taskdetail TD WITH(NOLOCK)
               INNER JOIN ORDERS ORD WITH(NOLOCK)
                  ON TD.storerkey = ORD.storerkey
                  AND TD.OrderKey = ORD.OrderKey
               WHERE TD.Storerkey = @cStorerKey
               AND TD.Sku = @cSKu
               AND TD.TaskdetailKey = @cTaskdetailKey
               AND ORD.UserDefine10 IN
                        (SELECT  short  
                           FROM CodeLKUP WITH(NOLOCK) 
                        WHERE LISTNAME = 'HUSQPKTYPE' 
                        AND Code2 = '' 
                        AND StorerKey = @cStorerkey)
               )
      BEGIN          
         -- Confirm          
         EXEC rdt.rdt_TM_Assist_ClusterPick_ConfirmPickV2           
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
            @cSerialNo        = '',
            @nSerialQTY       = 0,
            @nBulkSNO         = 0,
            @nBulkSNOQTY      = 0,
            @nErrNo           = @nErrNo   OUTPUT,          
            @cErrMsg          = @cErrMsg  OUTPUT          
        
         IF @nErrNo <> 0          
            GOTO Quit          
             
         SELECT TOP 1 --PPA374 Added TOP 1 15/01/2025      
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

      -- Prepare next screen var        
      SET @cOutField01 = @cCartPickMethod      
      SET @cOutField02 = @cFromLoc      
      SET @cOutField03 = @cSuggSKU        
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20)        
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20)        
      SET @cOutField06 = ''   -- SKU/UPC        
      SET @cOutField07 = CASE WHEN @cDefaultQTY = '0' THEN '' ELSE @cDefaultQTY END -- QTY        
      SET @cOutField08 = @nActQTY        
      SET @cOutField09 = @nSuggQty        
      SET @cOutField15 = '' -- ExtendedInfo    
      
      SET @cSKUValidated = '1'        
               
      IF @cDisableQTYField = '1'          
      BEGIN          
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- SKU                                   
      END          
      ELSE          
      BEGIN          
         IF @cDefaultQTY = '0'      
            EXEC rdt.rdtSetFocusField @nMobile, 7 -- MQTY          
         ELSE      
            EXEC rdt.rdtSetFocusField @nMobile, 6 -- SKU                                    
      END 
                            
      SET @nScn = @nScn_SKUQTY      
      SET @nStep = @nStep_SKUQTY

      GOTO QUIT
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
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

   Step_SerialNo_Quit:
END
GOTO Quit


Step_ReasonCD:
BEGIN
   IF @nInputKey = 1
   Begin
      SET @cReasonCode = @cInField01

      -- Check blank ReasonCD          
      IF @cReasonCode = ''          
      BEGIN          
         SET @nErrNo = 227598          
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ReasonCD needed          
         GOTO Step_ReasonCD_Fail          
      END  
      
      IF NOT EXISTS(SELECT 1 
                  FROM CodeLKUP WITH(NOLOCK)
                  WHERE ListName = 'HUSQTMRSN'
                  AND Storerkey = @cStorerkey
                  AND Code2 = @cReasonCode
                  )
      BEGIN
         SET @nErrNo = 227599 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --Invalid Reason   
         GOTO Step_ReasonCD_Fail    
      END

      DECLARE @cRefTaskdetailKey       NVARCHAR(10)
      SELECT TOP 1 @cRefTaskdetailKey = RefTaskKey --PPA374 Added TOP 1 15/01/2025
      FROM TaskDetail WITH(NOLOCK)
      WHERE storerKey = @cStorerKey
      AND TaskdetailKey = @cTaskdetailKey

      IF ISNULL(@cRefTaskdetailKey,'') = ''
         SET @cRefTaskdetailKey = @cTaskdetailKey
         
      UPDATE TaskDetail
      SET ReasonKey = @cReasonCode
      WHERE storerKey = @cStorerKey
      AND TaskdetailKey = @cRefTaskdetailKey


      IF EXISTS(SELECT 1
               FROM PickDetail PD WITH(NOLOCK)
               WHERE storerkey = @cStorerKey
               AND taskdetailkey = @cTaskDetailKey
               AND status = '5')
         AND @nActQTY > 0
      BEGIN
         SELECT TOP 1 --PPA374 Added TOP 1 15/01/2025      
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
      else
      Begin
         -- Get task in same LOC          
         SET @cSKUValidated = '0'          
         SET @nActQTY = 0          
                  
         SET @nErrNo = 0        
         EXEC [RDT].[rdt_TM_Assist_ClusterPick_GetTaskV2]         
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
            SELECT TOP 1 @cSKUDescr = DESCR      --PPA374 Added TOP 1 15/01/2025  
            FROM dbo.SKU WITH (NOLOCK)        
            WHERE StorerKey = @cStorerKey        
            AND   SKU = @cSuggSKU        
         
            SELECT TOP 1 @nSuggQty = ISNULL( SUM( Qty), 0)        --PPA374 Added TOP 1 15/01/2025
            FROM dbo.PICKDETAIL WITH (NOLOCK)        
            WHERE StorerKey = @cStorerKey        
            AND   Loc = @cFromLoc        
            AND   Sku = @cSuggSKU        
            AND   CaseID = @cSuggCartonID        
            AND   [Status] < @cPickConfirmStatus      
         
            SELECT TOP 1 @nPickedQty = ISNULL( SUM( Qty), 0)     --PPA374 Added TOP 1 15/01/2025   
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
            EXEC [RDT].[rdt_TM_Assist_ClusterPick_GetTaskV2]         
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
               SELECT TOP 1 @cSKUDescr = DESCR       --PPA374 Added TOP 1 15/01/2025 
               FROM dbo.SKU WITH (NOLOCK)        
               WHERE StorerKey = @cStorerKey        
               AND   SKU = @cSuggSKU        
            

               SELECT TOP 1 @nSuggQty = ISNULL( SUM( PKD.Qty), 0)        --PPA374 Added TOP 1 15/01/2025
               FROM dbo.PICKDETAIL PKD WITH (NOLOCK)
               INNER JOIN dbo.TaskDetail TD WITH(NOLOCK) ON (PKD.StorerKey = TD.StorerKey AND PKD.TaskDetailKey = TD.TaskDetailKey)
               WHERE PKD.StorerKey = @cStorerKey        
               AND   PKD.Loc = @cFromLoc        
               AND   PKD.Sku = @cSuggSKU        
               AND   PKD.CaseID = @cSuggCartonID        
               AND   PKD.[Status] < @cPickConfirmStatus        
               AND   TD.GroupKey = @cGroupKey
               AND   TD.TaskDetailKey = @cTaskdetailKey

               SELECT TOP 1 @nPickedQty = ISNULL( SUM( PKD.Qty), 0)   --PPA374 Added TOP 1 15/01/2025     
               FROM dbo.PICKDETAIL PKD WITH (NOLOCK)
               INNER JOIN dbo.TaskDetail TD WITH(NOLOCK) ON (PKD.StorerKey = TD.StorerKey AND PKD.TaskDetailKey = TD.TaskDetailKey)
               WHERE PKD.StorerKey = @cStorerKey        
               AND   PKD.Loc = @cFromLoc        
               AND   PKD.Sku = @cSuggSKU        
               AND   PKD.CaseID = @cSuggCartonID        
               AND   PKD.[Status] = @cPickConfirmStatus        
               AND   TD.GroupKey = @cGroupKey
               AND   TD.TaskDetailKey = @cTaskdetailKey    
               
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
                  AND   TaskType = 'ASTCPK'        
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
         
                  SELECT TOP 1 @cSuggToLOC = ToLoc      --PPA374 Added TOP 1 15/01/2025
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
   END

   IF @nInputKey = 0
   BEGIN
      -- Prepare next screen var          
      SET @cOption = ''          
      SET @cOutField01 = @cCartPickMethod      
      SET @cOutField02 = '' -- Option          
   
      -- Enable field          
      SET @cFieldAttr07 = '' -- QTY          
         
      SET @nScn = @nScn_Option          
      SET @nStep = @nStep_Option  
   END

   Step_ReasonCD_Fail:

END
GOTO Quit

Step_PalletInf:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SET @cResult01 = ''      
      SET @cResult02 = ''      
      SET @cResult03 = ''      
      SET @cResult04 = ''      
      SET @cResult05 = ''      
      
      -- Draw matrix           
      SET @nNextPage = 0            
      EXEC rdt.rdt_TM_Assist_ClusterPick_MatrixV2         
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
         @cGroupKey        = @cGroupKey,      
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
   /**
   IF @nInputKey = 0
   BEGIN
      /**
      -- Prepare next screen var        
      SET @cOutField01 = ''        
      SET @cOutField02 = ''         
      SET @cOutField03 = ''      
      
      EXEC rdt.rdtSetFocusField @nMobile, 1  

      SET @nScn = @nScn_CartID
      SET @nStep = @nStep_CartID
      **/

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
   **/
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
      V_String40 = @cUnassignToLOCFlag,--Dennis 21/01/2025
      V_String41 = @cCartPickMethod,      
      V_String42 = @cContinuePickOnAssignedCart,      
      V_String43 = @cPickNoMixWave,
      V_String44 = @cExtendedScnSP, -- ExtScn Jack
      V_string45 = @cSerialNoCapture,
      V_String46 = @cReasonCode,
      V_Max      = @cMax,
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