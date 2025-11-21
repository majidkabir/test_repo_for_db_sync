SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/  
/* Store procedure: rdtfnc_TM_ClusterPick                                  */  
/* Copyright      : LF Logistics                                           */  
/*                                                                         */  
/* Purpose: Post pack sort                                                 */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date         Rev  Author   Purposes                                     */  
/* 2020-03-17   1.0  James    WMS-12055 Created                            */ 
/* 2020-10-28   1.1  LZG      INC1337154 - Fixed suggested Qty (ZG01)      */ 
/* 2021-07-15   1.2  James    WMS-17429 Add display pick method (james01)  */
/*                            Add reconfirm carton id screen               */
/*                            Add confirm toloc config                     */
/* 2021-08-26   1.3  James    WMS-17689 Add skip step 1 & 2 (james02)      */
/* 2022-05-17   1.4  James    WMS-19545 Fix skip task not getting new task */
/*                            issue (james03)                              */
/* 2023-04-19   1.5  James    WMS-22212 Allow blank suggested cart id and  */
/*                            assign cart id to the available groupkey     */
/*                            Allow different UOM qty input (james04)      */
/***************************************************************************/  
  
CREATE   PROC [RDT].[rdtfnc_TM_ClusterPick](  
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
   @cResult01        NVARCHAR( 20),      
   @cResult02           NVARCHAR( 20),      
   @cResult03           NVARCHAR( 20),      
   @cResult04           NVARCHAR( 20),      
   @cResult05           NVARCHAR( 20),      
   @cResult06           NVARCHAR( 20),      
   @cResult07           NVARCHAR( 20),      
   @cResult08           NVARCHAR( 20),      
   @nNextPage           INT,  
   @nActQTY             INT,  
   @cPickMethod         NVARCHAR( 10),
   @cCartPickMethod     NVARCHAR( 20),
   @cPosition           NVARCHAR( 20),
   @cConfirmCartonId    NVARCHAR( 1),
   @cNextScreen         NVARCHAR( 10),
   @cCartonID2Confirm   NVARCHAR( 20),
   @cFlowThruStepCartID NVARCHAR( 1),
   @cFlowThruStepMatrix NVARCHAR( 1),
   @cCartonID2Close     NVARCHAR( 20),
   @cNewCartonID        NVARCHAR( 20),
   @cConfirmToLoc       NVARCHAR( 1),
   @cCurrentSuggLoc     NVARCHAR( 10),
   @cAssignGroupKeyWhenNoSuggCartId    NVARCHAR( 1),
   @cScanDevicePosition NVARCHAR( 1),
   @cSuggDPosition      NVARCHAR( 20),
   @cDPosition          NVARCHAR( 20),
   @cPUOM               NVARCHAR(  1),
   @cPUOM_Desc          NCHAR( 5),
   @cMUOM_Desc          NCHAR( 5),
   @nPUOM_Div           INT,
   @nPQTY               INT,
   @nMQTY               INT,
   @nPQtyCursor         INT,
   @cSkipToLoc          NVARCHAR( 1),
   @nAfterStep          INT,
   @curRelTask          CURSOR,
   @cRelTaskKey         NVARCHAR( 10),
   
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
   @cPUOM            = V_UOM,
   
   @nSuggQty       = V_Integer1,  
   @nPickedQty     = V_Integer2,  
   @nActQTY        = V_Integer3,  
   @nPUOM_Div      = V_Integer4,
   @nPQTY          = V_Integer5,
   @nMQTY          = V_Integer6,
   @nPQtyCursor    = V_Integer7,
   
   @cExtendedUpdateSP   = V_String1,  
   @cExtendedValidateSP = V_String2,  
   @cExtendedInfoSP     = V_String3,  
   @cGetNextTaskSP      = V_String4,    
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
   @cReasonCode         = V_String20,  
   @cCartPickMethod     = V_String21,
   @cPosition           = V_String22,
   @cConfirmCartonId    = V_String23,
   @cNextScreen         = V_String24,
   @cFlowThruStepCartID = V_String25,
   @cFlowThruStepMatrix = V_String26,
   @cConfirmToLoc       = V_String27,
   @cAssignGroupKeyWhenNoSuggCartId = V_String28,
   @cScanDevicePosition = V_String29,
   @cSuggDPosition      = V_String30,
   @cDPosition          = V_String31,
   @cAreakey            = V_String32,    
   @cTTMStrategykey     = V_String33,    
   @cTTMTaskType        = V_String34,    
   @cRefKey01           = V_String35,    
   @cRefKey02           = V_String36,    
   @cRefKey03           = V_String37,    
   @cRefKey04           = V_String38,    
   @cRefKey05           = V_String39,    
   @cMUOM_Desc          = V_String40,
   @cPUOM_Desc          = V_String41,
   @cSkipToLoc          = V_String42,
   
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
   @nStep_CartonId         INT,  @nScn_CartonId          INT,  
   @nStep_SKUQTY           INT,  @nScn_SKUQTY            INT,  
   @nStep_Option           INT,  @nScn_Option            INT,  
   @nStep_CloseCarton      INT,  @nScn_CloseCarton       INT,  
   @nStep_ToLoc            INT,  @nScn_ToLoc             INT,  
   @nStep_NextTask         INT,  @nScn_NextTask          INT,  
   @nStep_ReasonCode       INT,  @nScn_ReasonCode        INT,  
   @nStep_ConfirmCartonId  INT,  @nScn_ConfirmCartonId   INT
  
SELECT  
   @nStep_CartID           = 1,  @nScn_CartID            = 5680,  
   @nStep_CartMatrix       = 2,  @nScn_CartMatrix        = 5681,  
   @nStep_Loc              = 3,  @nScn_Loc               = 5682,  
   @nStep_CartonId         = 4,  @nScn_CartonId          = 5683,  
   @nStep_SKUQTY           = 5,  @nScn_SKUQTY            = 5684,  
   @nStep_Option           = 6,  @nScn_Option            = 5685,  
   @nStep_CloseCarton      = 7,  @nScn_CloseCarton       = 5686,  
   @nStep_ToLoc            = 8,  @nScn_ToLoc             = 5687,  
   @nStep_NextTask         = 9,  @nScn_NextTask          = 5688,  
   @nStep_ReasonCode       = 10, @nScn_ReasonCode        = 2190,  
   @nStep_ConfirmCartonId  = 11, @nScn_ConfirmCartonId   = 5689
  
  
IF @nFunc = 640  
BEGIN  
   -- Redirect to respective screen  
   IF @nStep = 0  GOTO Step_Start            -- Menu. Func = 640  
   IF @nStep = 1  GOTO Step_CartID           -- Scn = 5680. Scan Car ID  
   IF @nStep = 2  GOTO Step_CartMatrix       -- Scn = 5681. Cart Matrix  
   IF @nStep = 3  GOTO Step_Loc              -- Scn = 5682. Loc  
   IF @nStep = 4  GOTO Step_CartonId         -- Scn = 5683. Carton Id  
   IF @nStep = 5  GOTO Step_SKUQTY           -- Scn = 5684. SKU, Qty  
   IF @nStep = 6  GOTO Step_Option           -- Scn = 5685. Option  
   IF @nStep = 7  GOTO Step_CloseCarton      -- Scn = 5686. Close Carton  
   IF @nStep = 8  GOTO Step_ToLoc            -- Scn = 5687. To Loc  
   IF @nStep = 9  GOTO Step_NextTask         -- Scn = 5688. End Task/Exit TM  
   IF @nStep = 10 GOTO Step_ReasonCode       -- Scn = 2190. Reason code    
   IF @nStep = 11 GOTO Step_ConfirmCartonId  -- Scn = 5689. Confirm CartonID    
END  
  
RETURN -- Do nothing if incorrect step  
  
/********************************************************************************  
Step_Start. Func = 640  
********************************************************************************/  
Step_Start:  
BEGIN  
	
   -- Get task manager data    
   SET @cTaskDetailKey  = @cOutField06    
   SET @cAreaKey        = @cOutField07    
   SET @cTTMStrategyKey = @cOutField08    
    
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

   -- (james01)
   SET @cConfirmCartonId = rdt.RDTGetConfig( @nFunc, 'ConfirmCartonId', @cStorerKey)    

   SET @cConfirmToLoc = rdt.RDTGetConfig( @nFunc, 'ConfirmToLoc', @cStorerKey)
   
   -- (james02)
   SET @cFlowThruStepCartID = rdt.RDTGetConfig( @nFunc, 'FlowThruStepCartID', @cStorerKey)
   
   SET @cFlowThruStepMatrix = rdt.RDTGetConfig( @nFunc, 'FlowThruStepMatrix', @cStorerKey)

   -- (james04)
   SET @cAssignGroupKeyWhenNoSuggCartId = rdt.RDTGetConfig( @nFunc, 'AssignGroupKeyWhenNoSuggCartId', @cStorerKey)
   
   SET @cScanDevicePosition = rdt.RDTGetConfig( @nFunc, 'ScanDevicePosition', @cStorerKey)
   
   SET @nPQtyCursor = rdt.RDTGetConfig( @nFunc, 'PQtyCursor', @cStorerKey)
   
   SET @cSkipToLoc = rdt.RDTGetConfig( @nFunc, 'SkipToLoc', @cStorerKey)
   
   -- Get task info    
   SELECT    
      @cTTMTaskType = TaskType,    
      @cStorerKey   = Storerkey,    
      @cSuggCartId  = DeviceID,  
      @cSuggFromLOC = FromLOC,  
      @cSuggToLOC = ToLoc,  
      @cGroupKey    = GroupKey, 
      @cCartPickMethod = PickMethod  
   FROM dbo.TaskDetail WITH (NOLOCK)    
   WHERE TaskDetailKey = @cTaskDetailKey    
   
   -- Prepare next screen var  
   SET @cOutField01 = @cSuggCartId  
   SET @cOutField02 = ''   
   SET @cOutField03 = @cCartPickMethod

   SET @cReasonCode = ''    
     
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
   
   IF @cFlowThruStepCartID = '1'
   BEGIN
      SET @cInField02 = @cSuggCartId
      SET @nInputKey = 1
      GOTO Step_CartID
   END
      
END  
GOTO Quit  
  
/************************************************************************************  
Scn = 5680. Scan Cart Id  
   Cart ID (field01)  
   Cart ID (field01, input)  
************************************************************************************/  
Step_CartID:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  

      -- Screen mapping  
      SET @cCartID = @cInField02  
  
      -- Check blank  
      IF ISNULL( @cCartID, '') = ''   
      BEGIN  
         SET @nErrNo = 148901  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartId req  
         GOTO Step_CartID_Fail  
      END  
  
      IF ISNULL( @cSuggCartId, '') <> ''  
      BEGIN  
         IF @cCartID <> @cSuggCartId  
         BEGIN  
            SET @nErrNo = 148902  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CartIdNotMatch  
            GOTO Step_CartID_Fail  
         END  
      END  
      ELSE
      BEGIN
      	IF @cAssignGroupKeyWhenNoSuggCartId <> '1'
         BEGIN  
            SET @nErrNo = 148930  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Assign Cart Id  
            GOTO Step_CartID_Fail  
         END 
         ELSE
         BEGIN
         	IF NOT EXISTS ( SELECT 1
         	                FROM dbo.DeviceProfile WITH (NOLOCK)
         	                WHERE DeviceID = @cCartID
         	                AND   DeviceType = 'CART'
         	                AND   StorerKey = @cStorerKey)
            BEGIN  
               SET @nErrNo = 148931  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid CartId  
               GOTO Step_CartID_Fail  
            END 
            -- Assign user enter cart id to taskdetail
            DECLARE @cAssignTaskKey    NVARCHAR( 10)
            DECLARE @curAssignCartId   CURSOR
            
            -- Handling transaction            
            SET @nTranCount = @@TRANCOUNT            
            BEGIN TRAN  -- Begin our own transaction            
            SAVE TRAN AssignCartID -- For rollback or commit only our own transaction            

            SET @curAssignCartID = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT TaskDetailKey
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   TaskType = 'CPK'
            AND   Groupkey = @cGroupKey
            AND   UserKey = @cUserName
            AND   [Status] = '3'
            ORDER BY 1
            OPEN @curAssignCartID
            FETCH NEXT FROM @curAssignCartID INTO @cAssignTaskKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
            	UPDATE dbo.TaskDetail SET 
            	   DeviceID = @cCartID,
            	   EditWho = @cUserName,
            	   EditDate = GETDATE()
            	WHERE TaskDetailKey = @cAssignTaskKey
            	
            	IF @@ERROR <> 0
               BEGIN  
                  SET @nErrNo = 148932  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Assign Cart Er
                  ROLLBACK TRAN AssignCartID            
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
                     COMMIT TRAN            
                  BREAK            
               END 
            	
            	FETCH NEXT FROM @curAssignCartID INTO @cAssignTaskKey
            END
            
            IF @nErrNo <> 0
               GOTO Step_CartID_Fail

            COMMIT TRAN AssignCartID -- Only commit change made here            
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started            
               COMMIT TRAN           
         END
      END
      /*
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
         SET @nErrNo = 171831    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TaskQtyXTally    
         GOTO Step_CartID_Fail    
      END
      */
      -- Extended validate  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +   
               ' @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption, ' +  
               ' @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
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
               ' @tExtValidate   VariableTable READONLY, ' +   
               ' @nErrNo         INT           OUTPUT, ' +  
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,   
               @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption,   
               @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0   
               GOTO Step_CartID_Fail  
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
               GOTO Step_CartID_Fail  
         END  
      END          
      
      -- Draw matrix     
      SET @nNextPage = 0      
      EXEC rdt.rdt_TM_ClusterPick_Matrix   
         @nMobile          = @nMobile,   
         @nFunc            = @nFunc,   
         @cLangCode        = @cLangCode,   
         @nStep            = @nStep,   
         @nInputKey        = @nInputKey,   
         @cFacility        = @cFacility,   
         @cStorerKey       = @cStorerKey,   
         @cGroupKey        = @cGroupKey,   
         @cTaskDetailKey   = @cTaskDetailKey,  
         @cResult01        = @cResult01   OUTPUT,    
         @cResult02        = @cResult02   OUTPUT,    
         @cResult03        = @cResult03   OUTPUT,    
         @cResult04        = @cResult04   OUTPUT,       
         @cResult05        = @cResult05   OUTPUT,    
         @cResult06        = @cResult06   OUTPUT,    
         @cResult07        = @cResult07   OUTPUT,    
         @cResult08        = @cResult08   OUTPUT,       
         @nNextPage        = @nNextPage   OUTPUT,    
         @nErrNo           = @nErrNo      OUTPUT,    
         @cErrMsg          = @cErrMsg     OUTPUT  
      
      IF @nErrNo <> 0      
         GOTO Step_CartID_Fail      
        
      -- Prepare next screen var  
      SET @cOutField01 = @cCartID  
      SET @cOutField02 = @cResult01  
      SET @cOutField03 = @cResult02  
      SET @cOutField04 = @cResult03  
      SET @cOutField05 = @cResult04  
      SET @cOutField06 = @cResult05  
      SET @cOutField07 = @cResult06  
      SET @cOutField08 = @cResult07  
      SET @cOutField09 = @cResult08  
      SET @cOutField10 = @cCartPickMethod
      
      SET @cFromLoc = ''  
      SET @cCartonID = ''  
      SET @cSKU = ''  
      SET @nQTY = 0  
        
      -- Go to next screen  
      SET @nScn = @nScn_CartMatrix  
      SET @nStep = @nStep_CartMatrix   
      
      IF @cFlowThruStepMatrix = '1'
      BEGIN
         SET @nInputKey = 1
         GOTO Step_CartMatrix
      END
   END  
  
   IF @nInputKey = 0 -- Esc or No  
   BEGIN/*  
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
      */  
      -- Go to Reason Code Screen    
      SET @cOutField01 = ''    
      SET @cOutField02 = ''    
      SET @cOutField03 = ''    
      SET @cOutfield04 = ''    
      SET @cOutField05 = ''    
      SET @cOutField09 = ''    
    
      SET @nScn  = 2109    
      SET @nStep = @nStep + 9 -- Step 10  
   END  
   GOTO Quit  
  
   Step_CartID_Fail:  
   BEGIN  
      SET @cCartID = ''  
  
      SET @cOutField02 = ''  
   END  
     
   GOTO Quit  
END  
GOTO Quit  
  
/***********************************************************************************  
Scn = 5681. Cart ID/Matrix screen  
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
      --Get task for next loc  
      SET @nErrNo = 0  
      SET @cSuggFromLOC = ''  
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
  
      IF @nErrNo <> 0  
         GOTO Quit  

      -- Prepare next screen var  
      SET @cOutField01 = @cSuggFromLOC   
      SET @cOutField02 = ''   
      SET @cOutField03 = @cCartPickMethod

      -- Go to next screen  
      SET @nScn = @nScn_Loc  
      SET @nStep = @nStep_Loc  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare next screen var  
      SET @cOutField01 = @cSuggCartId  
      SET @cOutField02 = ''   
      SET @cOutField03 = @cCartPickMethod   
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
        
      -- Go to next screen  
      SET @nScn = @nScn_CartID  
      SET @nStep = @nStep_CartID  
   END  
   GOTO Quit  
END  
GOTO Quit  
  
/********************************************************************************  
Scn = 5681. Loc  
   Loc (field01)  
   Loc (field01, input)  
********************************************************************************/  
Step_Loc:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cFromLoc = @cInField02  
  
      -- Validate blank  
      IF ISNULL( @cFromLoc, '') = ''  
      BEGIN  
         SET @nErrNo = 148903  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Loc  
         GOTO Step_Loc_Fail  
      END  
  
      -- Validate option  
      IF @cFromLoc <> @cSuggFromLOC  
      BEGIN  
         SET @nErrNo = 148904  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Loc Not Match  
         GOTO Step_Loc_Fail  
      END  

      -- Show carton position
      EXEC rdt.[rdt_TM_ClusterPick_ShowCartonPos]   
         @nMobile          = @nMobile,   
         @nFunc            = @nFunc,   
         @cLangCode        = @cLangCode,   
         @nStep            = @nStep,   
         @nInputKey        = @nInputKey,   
         @cFacility        = @cFacility,   
         @cStorerKey       = @cStorerKey,   
         @cGroupKey        = @cGroupKey,   
         @cTaskDetailKey   = @cTaskDetailKey,  
         @cCartonID        = @cSuggCartonID,    
         @cPosition        = @cPosition   OUTPUT,
         @nErrNo           = @nErrNo      OUTPUT,    
         @cErrMsg          = @cErrMsg     OUTPUT  
      
      IF @nErrNo <> 0      
         GOTO Step_CartID_Fail      

      IF @cScanDevicePosition = '1'
         SELECT @cSuggDPosition = DropID
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey
         
      -- Prepare next screen var  
      SET @cOutField01 = @cFromLoc   
      SET @cOutField02 = @cSuggCartonID
      SET @cOutField03 = ''
      SET @cOutField04 = @cPosition
      SET @cOutField05 = @cCartPickMethod
      SET @cOutField06 = @cSuggDPosition
            
      -- Go to next screen  
      SET @nScn = @nScn_CartonId  
      SET @nStep = @nStep_CartonId  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare next screen var  
      SET @cOutField01 = @cSuggCartId  
      SET @cOutField02 = ''   
      SET @cOutField03 = @cCartPickMethod
      
      -- Go to next screen  
      SET @nScn = @nScn_CartID  
      SET @nStep = @nStep_CartID  
   END  
   GOTO Quit  
  
   Step_Loc_Fail:  
   BEGIN  
      SET @cFromLOC = ''  
  
      SET @cOutField02 = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************  
Scn = 5681. Carton ID  
   Loc       (field01)  
   Carton ID (field02)  
   Carton ID (field03, input)  
********************************************************************************/  
Step_CartonID:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cCartonID = @cInField03  
      SET @cDPosition = @cInField03
  
      -- Validate blank  
      IF ISNULL( @cCartonID, '') = '' AND ISNULL( @cDPosition, '') = ''
      BEGIN  
         SET @nErrNo = 148905  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Case Id  
         GOTO Step_CartonID_Fail  
      END  
  
      -- Validate option  
      IF ( @cScanDevicePosition = '1' AND @cDPosition <> @cSuggDPosition) OR 
         ( @cScanDevicePosition = '0' AND @cCartonID <> @cSuggCartonID)  
      BEGIN  
         SET @nErrNo = 148906  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseIdNotMatch  
         GOTO Step_CartonID_Fail  
      END  

      -- user scan device position instead of carton id
      -- Use back system assigned carton id
      IF @cScanDevicePosition = '1'
         SET @cCartonID = @cSuggCartonID

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
        
      -- Get SKU info
      SELECT
         @cSKUDescr = IsNULL( DescR, ''),
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
            @nPUOM_Div = CAST( IsNULL(
            CASE @cPUOM
               WHEN '2' THEN Pack.CaseCNT
               WHEN '3' THEN Pack.InnerPack
               WHEN '6' THEN Pack.QTY
               WHEN '1' THEN Pack.Pallet
               WHEN '4' THEN Pack.OtherUnit1
               WHEN '5' THEN Pack.OtherUnit2
            END, 1) AS INT)
      FROM dbo.SKU SKU WITH (NOLOCK)
         INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
         AND SKU.SKU = @cSuggSKU

      SET @nQTY = CASE WHEN CAST( @cDefaultQTY AS INT) > 0 THEN CAST( @cDefaultQTY AS INT) ELSE 0 END
      
      -- Convert to prefer UOM QTY
      IF @cPUOM = '6' OR -- When preferred UOM = master unit
         @nPUOM_Div = 0  -- UOM not setup
      BEGIN
         SET @cPUOM_Desc = ''
         SET @nPQTY = 0
         SET @nMQTY = @nQTY
         SET @cFieldAttr11 = 'O' -- @nPQTY
      END
      ELSE
      BEGIN
         SET @nPQTY = @nQTY / @nPUOM_Div -- Calc QTY in preferred UOM
         SET @nMQTY = @nQTY % @nPUOM_Div -- Calc the remaining in master unit
         SET @cFieldAttr11 = '' -- @nPQTY
      END
         
      SELECT @nSuggQty = ISNULL( SUM( Qty), 0)  
      FROM dbo.PICKDETAIL WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   Loc = @cFromLoc  
      AND   Sku = @cSuggSKU  
      AND   CaseID = @cCartonID  
      AND   [Status] < @cPickConfirmStatus  
  
      SELECT @nPickedQty = ISNULL( SUM( Qty), 0)  
      FROM dbo.PICKDETAIL WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   Loc = @cFromLoc  
      AND   Sku = @cSuggSKU  
      AND   CaseID = @cCartonID  
      AND   [Status] = @cPickConfirmStatus  
      
      -- Prepare next screen var  
      SET @cOutField01 = @cCartonID  
      SET @cOutField02 = @cSuggSKU  
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  
      SET @cOutField05 = ''   -- SKU/UPC  
      SET @cOutField06 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
      SET @cOutField07 = rdt.rdtRightAlign( RTRIM( CAST( @nPickedQty AS NVARCHAR( 3))), 3)  
      SET @cOutField08 = CAST( @nSuggQty AS NVARCHAR( 3))  
      SET @cOutField09 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
      SET @cOutField10 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
      SET @cOutField11 = CASE WHEN @nPQTY = 0 OR @cFieldAttr11 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END -- PQTY
      SET @cOutField12 = CASE WHEN @nMQTY = 0 THEN '' ELSE CAST( @nMQTY AS NVARCHAR( 7)) END -- MQTY
      SET @cOutField13 = @cCartPickMethod
      
      ---- Enable field  
      --IF @cDisableQTYField = '1'  
      --   SET @cFieldAttr06 = 'O'  
      --ELSE  
      --   SET @cFieldAttr06 = ''  
  
      EXEC rdt.rdtSetFocusField @nMobile, 5  
  
      SET @nActQTY = 0  
      SET @cSKUValidated = '0'  
  
      -- Go to next screen  
      SET @nScn = @nScn_SKUQTY  
      SET @nStep = @nStep_SKUQTY  
   END  
  
   IF @nInputKey = 0 -- ESC  
   BEGIN  
      -- Prepare next screen var  
      SET @cOutField01 = @cSuggFromLoc  
      SET @cOutField02 = ''   
      SET @cOutField03 = @cCartPickMethod

      -- Go to next screen  
      SET @nScn = @nScn_Loc  
      SET @nStep = @nStep_Loc  
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
            @nMobile, @nFunc, @cLangCode, @nStep_CartonId, @nStep, @nInputKey, @cFacility, @cStorerKey,   
            @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption,   
            @tExtInfo, @cExtendedInfo OUTPUT  
            
            IF @cExtendedInfo <> ''
               SET @cOutField15 = @cExtendedInfo
      END  
   END          

   GOTO Quit  
  
   Step_CartonID_Fail:  
   BEGIN  
      SET @cCartonID = ''  
  
      SET @cOutField03 = ''  
   END  
END  
GOTO Quit  
  
/********************************************************************************    
Scn = 5684. SKU QTY screen    
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
      DECLARE @cPQTY       NVARCHAR( 7)
      DECLARE @cMQTY       NVARCHAR( 7)
      
      -- Screen mapping    
      SET @cBarcode = ''  
      SET @cBarcode = @cInField05 -- SKU    
      SET @cUPC = LEFT( @cInField05, 30)    
      --SET @cQTY = CASE WHEN @cFieldAttr06 = 'O' THEN @cOutField06 ELSE @cInField06 END    

      SET @cPQTY = CASE WHEN @cFieldAttr11 = 'O' THEN @cOutField11 ELSE @cInField11 END
      SET @cMQTY = CASE WHEN @cFieldAttr12 = 'O' THEN @cOutField12 ELSE @cInField12 END
          
      -- Retain value    
      --SET @cOutField06 = CASE WHEN @cFieldAttr06 = 'O' THEN @cOutField06 ELSE @cInField06 END -- MQTY    
      SET @cOutField11 = CASE WHEN @cFieldAttr11 = 'O' THEN @cOutField11 ELSE @cInField11 END -- PQTY
      SET @cOutField12 = CASE WHEN @cFieldAttr12 = 'O' THEN @cOutField12 ELSE @cInField12 END -- MQTY

      -- Validate PQTY
      IF @cPQTY <> '' AND RDT.rdtIsValidQTY( @cPQTY, 0) = 0
      BEGIN
         SET @nErrNo = 59427
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 11 -- PQTY
         GOTO Step_SKUQTY_Fail
      END
      SET @nPQTY = CAST( @cPQTY AS INT)

      -- Validate MQTY
      IF @cMQTY <> '' AND RDT.rdtIsValidQTY( @cMQTY, 0) = 0
      BEGIN
         SET @nErrNo = 59428
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid QTY
         EXEC rdt.rdtSetFocusField @nMobile, 12 -- MQTY
         GOTO Step_SKUQTY_Fail
      END
      SET @nMQTY = CAST( @cMQTY AS INT)

      -- Calc total QTY in master UOM
      SET @nQTY = rdt.rdtConvUOMQTY( @cStorerKey, @cSKU, @cPQTY, @cPUOM, 6) -- Convert to QTY in master UOM
      SET @cQTY = @nQTY + @nMQTY
      
      IF ISNULL( @cQTY, '') = '' OR CAST( @cQTY AS INT) = 0
         SET @cQTY = ''
         
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
                  SET @nErrNo = 148907    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Need SKU    
                  EXEC rdt.rdtSetFocusField @nMobile, 5 -- SKU    
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
            --SET @cOutField06 = '0'    
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
                  GOTO Step_SKUQTY_Fail    
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
               SET @nErrNo = 148908    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU    
               GOTO Step_SKUQTY_Fail    
            END    
    
            -- Check barcode return multi SKU    
            IF @nSKUCnt > 1    
            BEGIN    
               SET @nErrNo = 148909    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod    
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
               SET @nErrNo = 148910    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wrong SKU    
               EXEC rdt.rdtSetFocusField @nMobile, 11  -- SKU    
               GOTO Step_SKUQTY_Fail    
            END    
    
            -- Mark SKU as validated    
            SET @cSKUValidated = '1'    
         END    
      END    
    
      -- Validate QTY    
      IF @cQTY <> '' AND RDT.rdtIsValidQTY( @cQTY, 0) = 0    
      BEGIN    
         SET @nErrNo = 148911    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid QTY    
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY    
         GOTO Step_SKUQTY_Fail    
      END    
    
      -- Check full short with QTY    
      IF @cSKUValidated = '99' AND @cQTY <> '0' AND @cQTY <> ''    
      BEGIN    
         SET @nErrNo = 148912    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AllShortWithQTY    
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY    
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
      --IF @nActQTY > @nSuggQTY    
      IF ( @nActQTY + @nQTY) > @nSuggQTY
      BEGIN    
         SET @nErrNo = 148913    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Over pick    
         --SET @cErrMsg = CAST( @nActQTY AS NVARCHAR( 3)) + '|' + CAST( @nQTY AS NVARCHAR( 3)) + '|' + CAST( @nSuggQTY AS NVARCHAR( 3))    
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- QTY    
         GOTO Step_SKUQTY_Fail    
      END   
          
      -- Extended validate  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +   
               ' @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption, ' +  
               ' @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
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
               ' @tExtValidate   VariableTable READONLY, ' +   
               ' @nErrNo         INT           OUTPUT, ' +  
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,   
               @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption,   
               @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0   
               GOTO Step_CartID_Fail  
         END  
      END  
  
      -- Save to ActQTY    
      SET @nActQTY = @nActQTY + @nQTY    
    
      -- SKU scanned, remain in current screen    
      IF @cBarcode <> ''  AND @cBarcode <> '99'  
      BEGIN    
         SET @nQTY = CASE WHEN CAST( @cDefaultQTY AS INT) > 0 THEN CAST( @cDefaultQTY AS INT) ELSE 0 END
      
         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @nMQTY = @nQTY
            SET @cFieldAttr11 = 'O' -- @nPQTY
         END
         ELSE
         BEGIN
            SET @nPQTY = @nQTY / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY = @nQTY % @nPUOM_Div -- Calc the remaining in master unit
            SET @cFieldAttr11 = '' -- @nPQTY
         END

         SET @cOutField05 = '' -- SKU    
         --SET @cOutField06 = CASE WHEN @cDefaultQTY = '0' THEN '' ELSE @cDefaultQTY END -- QTY  
         SET @cOutField07 = rdt.rdtRightAlign( RTRIM( CAST( @nActQTY AS NVARCHAR( 3))), 3)  
         SET @cOutField08 = CAST( @nSuggQty AS NVARCHAR( 3))  
         SET @cOutField11 = CASE WHEN @nPQTY = 0 OR @cFieldAttr11 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END -- PQTY
         SET @cOutField12 = CASE WHEN @nMQTY = 0 THEN '' ELSE CAST( @nMQTY AS NVARCHAR( 7)) END -- MQTY

         --SET @cOutField07 = @nActQTY  
         SET @cSKUValidated = '1'  
           
         IF @cDisableQTYField = '1'    
         BEGIN    
            EXEC rdt.rdtSetFocusField @nMobile, 5 -- SKU    
            IF @nActQTY <> @nSuggQTY    
               GOTO Quit_StepSKUQTY           
         END    
         ELSE    
         BEGIN    
            IF @cDefaultQTY = '0'
            BEGIN
               IF @nPQtyCursor = 1
                  EXEC rdt.rdtSetFocusField @nMobile, 11 -- PQTY    
               ELSE
               	EXEC rdt.rdtSetFocusField @nMobile, 12 -- MQTY    
            END
            ELSE
               EXEC rdt.rdtSetFocusField @nMobile, 5 -- SKU
               
            --EXEC rdt.rdtSetFocusField @nMobile, 6 -- MQTY    
            IF @nActQTY <> @nSuggQTY    
               GOTO Quit_StepSKUQTY           
            --GOTO Quit_StepSKUQTY         
         END    
      END    
    
      -- QTY short    
      IF @nActQTY < @nSuggQTY    
      BEGIN    
         IF @cDisableQTYField = '1'
            SET @nActQTY = @nActQTY - @nQTY

         -- Prepare next screen var    
         SET @cOption = ''    
         SET @cOutField01 = '' -- Option    
         SET @cOutField02 = @cCartPickMethod

         -- Enable field    
         SET @cFieldAttr06 = '' -- QTY    
    
         SET @nScn = @nScn_Option    
         SET @nStep = @nStep_Option    
      END    
    
      -- QTY fulfill    
      IF @nActQTY = @nSuggQTY    
      BEGIN    
         -- Confirm    
         EXEC rdt.rdt_TM_ClusterPick_ConfirmPick     
            @nMobile          = @nMobile,    
            @nFunc            = @nFunc,    
            @cLangCode        = @cLangCode,    
            @nStep            = @nStep,    
            @nInputKey        = @nInputKey,    
            @cFacility        = @cFacility,    
            @cStorerKey       = @cStorerKey,    
            @cType            = 'CONFIRM',   -- CONFIRM/SHORT/CLOSE    
            @cTaskDetailKey   = @cTaskDetailKey,    
            @nQTY             = @nActQTY,    
            @tConfirm         = @tConfirm,  
            @nErrNo           = @nErrNo   OUTPUT,    
            @cErrMsg          = @cErrMsg  OUTPUT    
  
         IF @nErrNo <> 0    
            GOTO Quit    
    
         -- Get task in same LOC    
         SET @cSKUValidated = '0'    
         SET @nActQTY = 0    
           
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
            @cType            = 'NEXTSKU',  
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
            -- Get SKU info
            SELECT
               @cSKUDescr = IsNULL( DescR, ''),
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
                  @nPUOM_Div = CAST( IsNULL(
                  CASE @cPUOM
                     WHEN '2' THEN Pack.CaseCNT
                     WHEN '3' THEN Pack.InnerPack
                     WHEN '6' THEN Pack.QTY
                     WHEN '1' THEN Pack.Pallet
                     WHEN '4' THEN Pack.OtherUnit1
                     WHEN '5' THEN Pack.OtherUnit2
                  END, 1) AS INT)
            FROM dbo.SKU SKU WITH (NOLOCK)
               INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSKU

            SET @nQTY = CASE WHEN CAST( @cDefaultQTY AS INT) > 0 THEN CAST( @cDefaultQTY AS INT) ELSE 0 END
      
            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY = 0
               SET @nMQTY = @nQTY
               SET @cFieldAttr11 = 'O' -- @nPQTY
            END
            ELSE
            BEGIN
               SET @nPQTY = @nQTY / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY = @nQTY % @nPUOM_Div -- Calc the remaining in master unit
               SET @cFieldAttr11 = '' -- @nPQTY
            END
         
            SELECT @nSuggQty = ISNULL( SUM( Qty), 0)  
            FROM dbo.PICKDETAIL WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
            AND   Loc = @cFromLoc  
            AND   Sku = @cSuggSKU  
            AND   CaseID = @cCartonID  
            AND   [Status] < @cPickConfirmStatus  
  
            SELECT @nPickedQty = ISNULL( SUM( Qty), 0)  
            FROM dbo.PICKDETAIL WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
            AND   Loc = @cFromLoc  
            AND   Sku = @cSuggSKU  
            AND   CaseID = @cCartonID  
            AND   [Status] = @cPickConfirmStatus  
        
            -- Prepare next screen var  
            SET @cOutField01 = @cCartonID  
            SET @cOutField02 = @cSuggSKU  
            SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  
            SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  
            SET @cOutField05 = ''   -- SKU/UPC  
            SET @cOutField06 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
            SET @cOutField07 = @nPickedQty  
            SET @cOutField08 = @nSuggQty  
            SET @cOutField09 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
            SET @cOutField10 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
            SET @cOutField11 = CASE WHEN @nPQTY = 0 OR @cFieldAttr11 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END -- PQTY
            SET @cOutField12 = CASE WHEN @nMQTY = 0 THEN '' ELSE CAST( @nMQTY AS NVARCHAR( 7)) END -- MQTY
            SET @cOutField13 = @cCartPickMethod
            SELECT @cSKUDescr = DESCR  
            FROM dbo.SKU WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
            AND   SKU = @cSuggSKU  
  
            EXEC rdt.rdtSetFocusField @nMobile, 5  
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
               @cType            = 'NEXTCARTON',  
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
               IF @cConfirmCartonId = '1'
               BEGIN
                  -- Show carton position
                  EXEC rdt.[rdt_TM_ClusterPick_ShowCartonPos]   
                     @nMobile          = @nMobile,   
                     @nFunc            = @nFunc,   
                     @cLangCode        = @cLangCode,   
                     @nStep            = @nStep,   
                     @nInputKey        = @nInputKey,   
                     @cFacility        = @cFacility,   
                     @cStorerKey       = @cStorerKey,   
                     @cGroupKey        = @cGroupKey,   
                     @cTaskDetailKey   = @cTaskDetailKey,  
                     @cCartonID        = @cCartonID,    
                     @cPosition        = @cPosition   OUTPUT,
                     @nErrNo           = @nErrNo      OUTPUT,    
                     @cErrMsg          = @cErrMsg     OUTPUT  
      
                  IF @nErrNo <> 0      
                     GOTO Step_CartID_Fail      
         
                  SET @cNextScreen = 'NEXTCARTON'
                  
                  -- Prepare next screen var  
                  SET @cOutField01 = @cFromLoc   
                  SET @cOutField02 = @cCartonID  
                  SET @cOutField03 = ''
                  SET @cOutField04 = @cPosition   
                  SET @cOutField05 = @cCartPickMethod
      
                  -- Go to next screen  
                  SET @nScn = @nScn_ConfirmCartonId  
                  SET @nStep = @nStep_ConfirmCartonId  
                  GOTO Quit   
               END
            
               SELECT TOP 1   
                  @cTaskDetailKey = TaskDetailKey,  
                  @cFromLoc = FromLoc  
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

               IF @cScanDevicePosition = '1'
                  SELECT @cSuggDPosition = DropID
                  FROM dbo.TaskDetail WITH (NOLOCK)
                  WHERE TaskDetailKey = @cTaskDetailKey

               -- Prepare next screen var  
               SET @cOutField01 = @cSuggFromLOC   
               SET @cOutField02 = @cSuggCartonID  
               SET @cOutField03 = ''   
               SET @cOutField04 = @cPosition
               SET @cOutField05 = @cCartPickMethod
               SET @cOutField06 = @cSuggDPosition

               -- Go to next screen  
               SET @nScn = @nScn_CartonId  
               SET @nStep = @nStep_CartonId  
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
                  IF @cConfirmCartonId = '1'
                  BEGIN
                     -- Show carton position
                     EXEC rdt.[rdt_TM_ClusterPick_ShowCartonPos]   
                        @nMobile          = @nMobile,   
                        @nFunc            = @nFunc,   
                        @cLangCode        = @cLangCode,   
                        @nStep            = @nStep,   
                        @nInputKey        = @nInputKey,   
                        @cFacility        = @cFacility,   
                        @cStorerKey       = @cStorerKey,   
                        @cGroupKey        = @cGroupKey,   
                        @cTaskDetailKey   = @cTaskDetailKey,  
                        @cCartonID        = @cCartonID,    
                        @cPosition        = @cPosition   OUTPUT,
                        @nErrNo           = @nErrNo      OUTPUT,    
                        @cErrMsg          = @cErrMsg     OUTPUT  
      
                     IF @nErrNo <> 0      
                        GOTO Step_CartID_Fail      
         
                     SET @cNextScreen = 'NEXTLOC'
                     
                     -- Prepare next screen var  
                     SET @cOutField01 = @cFromLoc   
                     SET @cOutField02 = @cCartonID  
                     SET @cOutField03 = ''
                     SET @cOutField04 = @cPosition   
                     SET @cOutField05 = @cCartPickMethod
      
                     -- Go to next screen  
                     SET @nScn = @nScn_ConfirmCartonId  
                     SET @nStep = @nStep_ConfirmCartonId  
                     GOTO Quit   
                  END
                  
                  SELECT TOP 1   
                     @cTaskDetailKey = TaskDetailKey,  
                     @cFromLoc = FromLoc  
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
                  SET @cOutField01 = @cSuggFromLOC   
                  SET @cOutField02 = ''  
                  SET @cOutField03 = @cCartPickMethod
                  
                  -- Go to next screen  
                  SET @nScn = @nScn_Loc  
                  SET @nStep = @nStep_Loc  
               END    
               ELSE  
               BEGIN  
                  -- Clear 'No Task' error from previous get task    
                  SET @nErrNo = 0    
                  SET @cErrMsg = ''    

                  IF @cConfirmCartonId = '1'
                  BEGIN
                     -- Show carton position
                     EXEC rdt.[rdt_TM_ClusterPick_ShowCartonPos]   
                        @nMobile          = @nMobile,   
                        @nFunc            = @nFunc,   
                        @cLangCode        = @cLangCode,   
                        @nStep            = @nStep,   
                        @nInputKey        = @nInputKey,   
                        @cFacility        = @cFacility,   
                        @cStorerKey       = @cStorerKey,   
                        @cGroupKey        = @cGroupKey,   
                        @cTaskDetailKey   = @cTaskDetailKey,  
                        @cCartonID        = @cCartonID,    
                        @cPosition        = @cPosition   OUTPUT,
                        @nErrNo           = @nErrNo      OUTPUT,    
                        @cErrMsg          = @cErrMsg     OUTPUT  
      
                     IF @nErrNo <> 0      
                        GOTO Step_CartID_Fail      
         
                     SET @cNextScreen = 'TOLOC'
                  
                     -- Prepare next screen var  
                     SET @cOutField01 = @cFromLoc   
                     SET @cOutField02 = @cCartonID  
                     SET @cOutField03 = ''
                     SET @cOutField04 = @cPosition   
                     SET @cOutField05 = @cCartPickMethod
      
                     -- Go to next screen  
                     SET @nScn = @nScn_ConfirmCartonId  
                     SET @nStep = @nStep_ConfirmCartonId  
                     GOTO Quit   
                  END
               
                  -- Scan out    
                  SET @nErrNo = 0    
                  EXEC rdt.rdt_TM_ClusterPick_ScanOut @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey    
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
               
                  -- Prepare next screen var    
                  SET @cOutField01 = @cSuggToLOC -- To LOC    
                  SET @cOutField02 = CASE WHEN @cConfirmToLoc = '1' THEN '' ELSE @cSuggToLOC END  
                  SET @cOutField03 = @cCartPickMethod
                  
                  -- Go to To LOC screen    
                  SET @nScn = @nScn_ToLoc    
                  SET @nStep = @nStep_ToLoc    
               END    
            END  
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
               GOTO Step_SKUQTY_Fail  
         END  
      END          
          
      Quit_StepSKUQTY:    
      IF CAST( @cQTY AS INT) > 0 -- Qty field already have value, this is consider picked
         SET @cSKUValidated = 0

      IF @cConfirmToLoc = '0' AND @cOutField02 = @cSuggToLOC AND @nStep = @nStep_ToLoc
      BEGIN
         SET @cInField02 = @cOutField02
         GOTO Step_ToLoc         
      END
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      IF @cScanDevicePosition = '1'
         SELECT @cSuggDPosition = DropID
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

      -- Prepare next screen var  
      SET @cOutField01 = @cFromLoc   
      SET @cOutField02 = @cSuggCartonID  
      SET @cOutField03 = ''   
      SET @cOutField04 = @cPosition
      SET @cOutField05 = @cCartPickMethod
      SET @cOutField06 = @cSuggDPosition

      -- Go to next screen  
      SET @nScn = @nScn_CartonId  
      SET @nStep = @nStep_CartonId   
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
            @nMobile, @nFunc, @cLangCode, @nStep_SKUQTY, @nStep, @nInputKey, @cFacility, @cStorerKey,   
            @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption,   
            @tExtInfo, @cExtendedInfo OUTPUT  
            
            IF @cExtendedInfo <> ''
               SET @cOutField15 = @cExtendedInfo
      END  
   END          

   GOTO Quit    
    
   Step_SKUQTY_Fail:    
   BEGIN    
      IF @cSKUValidated = '1'  
         SET @cOutField05 = @cSKU  
      ELSE  
         SET @cOutField05 = '' -- SKU    
   END    
END    
GOTO Quit    
  
/********************************************************************************    
Scn = 5685. Confirm Short Pick?        
   Option   (field01, input)    
********************************************************************************/    
Step_Option:            
BEGIN            
   IF @nInputKey = 1 -- ENTER            
   BEGIN            
      -- Screen mapping            
      SET @cOption = @cInField01            
            
      -- Validate blank            
      IF @cOption = ''            
      BEGIN            
         SET @nErrNo = 148914            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Option required            
         GOTO Step_Option_Fail            
      END            
            
      -- Validate option            
      IF @cOption NOT IN ( '1', '2')--AND @cOption <> '2' AND @cOption <> '3'   
      BEGIN            
         SET @nErrNo = 148915            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option            
         GOTO Step_Option_Fail            
      END            
    
      /*    
         Option=1 = Short pick sku    
         Option=2 = Balance pick later, go to next sku or next loc or next zone    
         Option=3 = Close drop id              
      */    
      DECLARE @cConfirmType NVARCHAR( 10)            
      IF @cOption = '1'            
         SET @cConfirmType = 'SHORT'            
      ELSE            
         SET @cConfirmType = 'CLOSE'        
    
      /*
      IF @cOption = '2'
      BEGIN    
         -- Get task in same LOC, same carton, same sku    
         SET @nErrNo = 0  
         SET @cSuggFromLOC = @cFromLoc  
         SET @cSuggCartonID = @cCartonID  
         SET @cSuggSKU = ''  
         SET @nSuggQty = 0  
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
            @cType            = 'NEXTSKU',  
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
            -- Prepare SKU QTY screen var    
            SELECT @cSKUDescr = DESCR  
            FROM dbo.SKU WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
            AND   SKU = @cSuggSKU  
  
            SELECT @nPickedQty = ISNULL( SUM( Qty), 0)  
            FROM dbo.PICKDETAIL WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
            AND   Loc = @cFromLoc  
            AND   Sku = @cSuggSKU  
            AND   CaseID = @cCartonID  
            AND   [Status] = @cPickConfirmStatus  
        
            -- Prepare next screen var  
            SET @cOutField01 = @cCartonID  
            SET @cOutField02 = @cSuggSKU  
            SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  
            SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  
            SET @cOutField05 = ''   -- SKU/UPC  
            SET @cOutField06 = CASE WHEN @cDefaultQTY = '0' THEN '' ELSE @cDefaultQTY END -- QTY  
            SET @cOutField07 = @nPickedQty  
            SET @cOutField08 = @nSuggQty  
            SET @cOutField09 = @cCartPickMethod
            
            -- Enable field  
            IF @cDisableQTYField = '1'  
               SET @cFieldAttr06 = 'O'  
            ELSE  
               SET @cFieldAttr06 = ''  
  
            SET @cSKUValidated = '0'  
  
            EXEC rdt.rdtSetFocusField @nMobile, 5  
        
            -- Go to next screen  
            SET @nScn = @nScn_SKUQTY  
            SET @nStep = @nStep_SKUQTY  
  
            GOTO Quit    
         END    
         ELSE    
         BEGIN    
            -- Get task with same loc, different carton  
            SET @nErrNo = 0  
            SET @cSuggFromLOC = @cFromLoc  
            SET @cSuggCartonID = ''  
            SET @cSuggSKU = ''  
            SET @nSuggQty = 0  
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
               @cType            = 'NEXTCARTON',  
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
               -- Prepare next screen var  
               SET @cOutField01 = @cFromLoc   
               SET @cOutField02 = @cSuggCartonID  
               SET @cOutField03 = ''   
               SET @cOutField04 = @cPosition
               SET @cOutField05 = @cCartPickMethod
               
               -- Go to next screen  
               SET @nScn = @nScn_CartonId  
               SET @nStep = @nStep_CartonId  
                 
               GOTO Quit  
            END  
            ELSE  
            BEGIN  
               -- Get task with different loc  
               SET @nErrNo = 0  
               SET @cSuggFromLOC = ''  
               SET @cSuggCartonID = ''  
               SET @cSuggSKU = ''  
               SET @nSuggQty = 0  
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
                  -- Prepare next screen var  
                  SET @cOutField01 = @cSuggFromLOC   
                  SET @cOutField02 = ''   
                  SET @cOutField03 = @cCartPickMethod
                  
                  -- Go to next screen  
                  SET @nScn = @nScn_Loc  
                  SET @nStep = @nStep_Loc  
        
                  GOTO Quit  
               END  
               ELSE        
               BEGIN       
                  -- Prepare next screen var    
                  SET @cOutField01 = @cSuggToLOC  
                  SET @cOutField02 = '' -- To Loc    
                  SET @cOutField03 = @cCartPickMethod
                  
                  -- Go to To Loc screen    
                  SET @nScn = @nScn_ToLoc    
                  SET @nStep = @nStep_ToLoc    
                      
                  GOTO Quit    
               END    
            END  
         END    
      END    */
  
      IF @cOption = '2' -- Close DropID            
      BEGIN            
         -- Goto PickZone Screen            
         SET @cOutField01 = ''            
         SET @cOutField02 = ''        
         SET @cOutField03 = @cCartPickMethod
         
         SET @nScn = @nScn_CloseCarton            
         SET @nStep = @nStep_CloseCarton            
            
         EXEC rdt.rdtSetFocusField @nMobile, 1 -- Carton to close            
         GOTO Quit            
      END            
  
      -- Handling transaction            
      SET @nTranCount = @@TRANCOUNT            
      BEGIN TRAN  -- Begin our own transaction            
      SAVE TRAN Step_Option -- For rollback or commit only our own transaction            
            
      -- Confirm            
      IF @cOption = '1'            
      BEGIN            
         -- Confirm    
         EXEC rdt.rdt_TM_ClusterPick_ConfirmPick     
            @nMobile          = @nMobile,    
            @nFunc            = @nFunc,    
            @cLangCode        = @cLangCode,    
            @nStep            = @nStep,    
            @nInputKey        = @nInputKey,    
            @cFacility        = @cFacility,    
            @cStorerKey       = @cStorerKey,    
            @cType            = @cConfirmType,  -- CONFIRM/SHORT/CLOSE    
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
         -- Get task in same LOC, same carton, same sku    
         SET @cSuggFromLOC = @cFromLoc  
         SET @cSuggCartonID = @cCartonID  
         SET @cSuggSKU = ''  
         SET @nSuggQty = 0  
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
            @cType            = 'NEXTSKU',  
            @cTaskDetailKey   = @cTaskDetailKey OUTPUT,  
            @cFromLoc         = @cSuggFromLOC   OUTPUT,  
            @cCartonId        = @cSuggCartonID OUTPUT,  
            @cSKU             = @cSuggSKU       OUTPUT,  
            @nQty             = @nSuggQty       OUTPUT,  
            @tGetTask         = @tGetTask,   
            @nErrNo           = @nErrNo         OUTPUT,  
            @cErrMsg          = @cErrMsg        OUTPUT  
  
         IF @nErrNo = 0  
         BEGIN                   
            -- Get SKU info
            SELECT
               @cSKUDescr = IsNULL( DescR, ''),
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
                  @nPUOM_Div = CAST( IsNULL(
                  CASE @cPUOM
                     WHEN '2' THEN Pack.CaseCNT
                     WHEN '3' THEN Pack.InnerPack
                     WHEN '6' THEN Pack.QTY
                     WHEN '1' THEN Pack.Pallet
                     WHEN '4' THEN Pack.OtherUnit1
                     WHEN '5' THEN Pack.OtherUnit2
                  END, 1) AS INT)
            FROM dbo.SKU SKU WITH (NOLOCK)
               INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
               AND SKU.SKU = @cSuggSKU

            SET @nQTY = CASE WHEN CAST( @cDefaultQTY AS INT) > 0 THEN CAST( @cDefaultQTY AS INT) ELSE 0 END
      
            -- Convert to prefer UOM QTY
            IF @cPUOM = '6' OR -- When preferred UOM = master unit
               @nPUOM_Div = 0  -- UOM not setup
            BEGIN
               SET @cPUOM_Desc = ''
               SET @nPQTY = 0
               SET @nMQTY = @nQTY
               SET @cFieldAttr11 = 'O' -- @nPQTY
            END
            ELSE
            BEGIN
               SET @nPQTY = @nQTY / @nPUOM_Div -- Calc QTY in preferred UOM
               SET @nMQTY = @nQTY % @nPUOM_Div -- Calc the remaining in master unit
               SET @cFieldAttr11 = '' -- @nPQTY
            END
         
            SELECT @nSuggQty = ISNULL( SUM( Qty), 0)  
            FROM dbo.PICKDETAIL WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
            AND   Loc = @cFromLoc  
            AND   Sku = @cSuggSKU  
            AND   CaseID = @cCartonID  
            AND   [Status] < @cPickConfirmStatus  
  
            SELECT @nPickedQty = ISNULL( SUM( Qty), 0)  
            FROM dbo.PICKDETAIL WITH (NOLOCK)  
            WHERE StorerKey = @cStorerKey  
            AND   Loc = @cFromLoc  
            AND   Sku = @cSuggSKU  
            AND   CaseID = @cCartonID  
            AND   [Status] = @cPickConfirmStatus  
        
            -- Prepare next screen var  
            SET @cOutField01 = @cCartonID  
            SET @cOutField02 = @cSuggSKU  
            SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  
            SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  
            SET @cOutField05 = ''   -- SKU/UPC  
            SET @cOutField06 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
            SET @cOutField07 = @nPickedQty  
            SET @cOutField08 = @nSuggQty  
            SET @cOutField09 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
            SET @cOutField10 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
            SET @cOutField11 = CASE WHEN @nPQTY = 0 OR @cFieldAttr11 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END -- PQTY
            SET @cOutField12 = CASE WHEN @nMQTY = 0 THEN '' ELSE CAST( @nMQTY AS NVARCHAR( 7)) END -- MQTY
            SET @cOutField13 = @cCartPickMethod
  
            SET @nActQTY = 0
            SET @cSKUValidated = '0'  
            
            EXEC rdt.rdtSetFocusField @nMobile, 5  
  
            -- Go to next screen  
            SET @nScn = @nScn_SKUQTY  
            SET @nStep = @nStep_SKUQTY  
         END    
         ELSE    
         BEGIN    
            -- Clear 'No Task' error from previous get task    
            SET @nErrNo = 0    
            SET @cErrMsg = ''    
  
            -- Get task with same loc, different carton  
            SET @nErrNo = 0  
            SET @cSuggFromLOC = @cFromLoc  
            SET @cSuggCartonID = ''  
            SET @cSuggSKU = ''  
            SET @nSuggQty = 0  
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
               @cType            = 'NEXTCARTON',  
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
                  @cFromLoc = FromLoc,
                  @cSuggDPosition = DropID
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
               SET @cOutField01 = @cFromLoc   
               SET @cOutField02 = @cSuggCartonID  
               SET @cOutField03 = ''   
               SET @cOutField04 = @cPosition
               SET @cOutField05 = @cCartPickMethod
               SET @cOutField06 = @cSuggDPosition
               
               SET @cErrMsg = ''  
                 
               -- Go to next screen  
               SET @nScn = @nScn_CartonId  
               SET @nStep = @nStep_CartonId  
                 
               GOTO Quit  
            END  
            ELSE  
            BEGIN  
               -- Clear 'No Task' error from previous get task    
               SET @nErrNo = 0    
               SET @cErrMsg = ''    
  
               -- Get task with different loc  
               SET @nErrNo = 0  
               SET @cSuggFromLOC = ''  
               SET @cSuggCartonID = ''  
               SET @cSuggSKU = ''  
               SET @nSuggQty = 0  
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
                     @cFromLoc = FromLoc  
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
                  SET @cOutField01 = @cSuggFromLOC   
                  SET @cOutField02 = ''   
                  SET @cOutField03 = @cCartPickMethod
                  
                  SET @cErrMsg = ''  
  
                  -- Go to next screen  
                  SET @nScn = @nScn_Loc  
                  SET @nStep = @nStep_Loc  
        
                  GOTO Quit  
               END  
               ELSE        
               BEGIN       
                  -- Scan out    
                  SET @nErrNo = 0    
                  EXEC rdt.rdt_TM_ClusterPick_ScanOut @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey    
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
               
                  -- Prepare next screen var    
                  SET @cOutField01 = @cSuggToLOC -- To LOC    
                  SET @cOutField02 = CASE WHEN @cConfirmToLoc = '1' THEN '' ELSE @cSuggToLOC END  
                  SET @cOutField03 = @cCartPickMethod
                  
                  -- Go to To LOC screen    
                  SET @nScn = @nScn_ToLoc    
                  SET @nStep = @nStep_ToLoc    
                     
                  IF @cConfirmToLoc = '0' AND @cOutField02 = @cSuggToLOC AND @nStep = @nStep_ToLoc
                  BEGIN
                     SET @cInField02 = @cOutField02
                     GOTO Step_ToLoc         
                  END

                  GOTO Quit    
               END    
            END  
         END       
      END            
   END            
            
   IF @nInputKey = 0  
   BEGIN  
      SELECT @nPickedQty = ISNULL( SUM( Qty), 0)  
      FROM dbo.PICKDETAIL WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   Loc = @cFromLoc  
      AND   Sku = @cSuggSKU  
      AND   CaseID = @cCartonID  
      AND   [Status] = @cPickConfirmStatus  
        
      -- Prepare next screen var  
      SET @cOutField01 = @cCartonID  
      SET @cOutField02 = @cSuggSKU  
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  
      SET @cOutField05 = ''   -- SKU/UPC  
      SET @cOutField06 = CASE WHEN @cDefaultQTY = '0' THEN '' ELSE @cDefaultQTY END -- QTY  
      SET @cOutField07 = @nActQTY--@nPickedQty  
      SET @cOutField08 = @nSuggQty  
      SET @cOutField09 = @cCartPickMethod
      
      -- Enable field  
      IF @cDisableQTYField = '1'  
         SET @cFieldAttr06 = 'O'  
      ELSE  
         SET @cFieldAttr06 = ''  
  
      EXEC rdt.rdtSetFocusField @nMobile, 5  --SKU  
  
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
            @nMobile, @nFunc, @cLangCode, @nStep_CartonId, @nStep, @nInputKey, @cFacility, @cStorerKey,   
            @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption,   
            @tExtInfo, @cExtendedInfo OUTPUT  
            
            IF @cExtendedInfo <> ''
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
Scn = 5686. Close Carton        
   Carton To Close   (field01, input)    
   New Carton ID     (field01, input)  
********************************************************************************/    
Step_CloseCarton:            
BEGIN            
   IF @nInputKey = 1 -- ENTER            
   BEGIN            
      -- Screen mapping    
      SET @cCartonID2Close = @cInField01
      SET @cNewCartonID = @cInField02    
            
      -- Validate blank            
      IF @cCartonID2Close = ''            
      BEGIN            
         SET @nErrNo = 148916            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseId required            
         SET @cOutField01 = ''
         SET @cOutField02 = @cNewCartonID
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_CloseCarton_Fail            
      END            

      IF @cCartonID <> @cCartonID2Close
      BEGIN            
         SET @nErrNo = 148917            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseId Not Match
         SET @cOutField01 = ''
         SET @cOutField02 = @cNewCartonID
         EXEC rdt.rdtSetFocusField @nMobile, 1    
         GOTO Step_CloseCarton_Fail            
      END            
      
      IF @cNewCartonID = ''
      BEGIN            
         SET @nErrNo = 148929            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need New CaseID            
         SET @cOutField01 = @cCartonID2Close
         SET @cOutField02 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2    
         GOTO Step_CloseCarton_Fail            
      END            
      
      --SET @cConfirmType = 'CLOSE'

      -- Confirm    
      EXEC rdt.rdt_TM_ClusterPick_ConfirmPick     
         @nMobile          = @nMobile,    
         @nFunc            = @nFunc,    
         @cLangCode        = @cLangCode,    
         @nStep            = @nStep,    
         @nInputKey        = @nInputKey,    
         @cFacility        = @cFacility,    
         @cStorerKey       = @cStorerKey,    
         @cType            = 'CONFIRM',   -- CONFIRM/SHORT/CLOSE    
         @cTaskDetailKey   = @cTaskDetailKey,    
         @nQTY             = @nActQTY,    
         @tConfirm         = @tConfirm,  
         @nErrNo           = @nErrNo   OUTPUT,    
         @cErrMsg          = @cErrMsg  OUTPUT    
  
      IF @nErrNo <> 0    
         GOTO Quit    
    
      -- Get task in same LOC    
      SET @cSKUValidated = '0'    
      SET @nActQTY = 0    
           
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
         @cType            = 'NEXTSKU',  
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
         -- Get SKU info
         SELECT
            @cSKUDescr = IsNULL( DescR, ''),
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
               @nPUOM_Div = CAST( IsNULL(
               CASE @cPUOM
                  WHEN '2' THEN Pack.CaseCNT
                  WHEN '3' THEN Pack.InnerPack
                  WHEN '6' THEN Pack.QTY
                  WHEN '1' THEN Pack.Pallet
                  WHEN '4' THEN Pack.OtherUnit1
                  WHEN '5' THEN Pack.OtherUnit2
               END, 1) AS INT)
         FROM dbo.SKU SKU WITH (NOLOCK)
            INNER JOIN dbo.Pack Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
            AND SKU.SKU = @cSKU

         SET @nQTY = CASE WHEN CAST( @cDefaultQTY AS INT) > 0 THEN CAST( @cDefaultQTY AS INT) ELSE 0 END
      
         -- Convert to prefer UOM QTY
         IF @cPUOM = '6' OR -- When preferred UOM = master unit
            @nPUOM_Div = 0  -- UOM not setup
         BEGIN
            SET @cPUOM_Desc = ''
            SET @nPQTY = 0
            SET @nMQTY = @nQTY
            SET @cFieldAttr11 = 'O' -- @nPQTY
         END
         ELSE
         BEGIN
            SET @nPQTY = @nQTY / @nPUOM_Div -- Calc QTY in preferred UOM
            SET @nMQTY = @nQTY % @nPUOM_Div -- Calc the remaining in master unit
            SET @cFieldAttr11 = '' -- @nPQTY
         END
         
         SELECT @nSuggQty = ISNULL( SUM( Qty), 0)  
         FROM dbo.PICKDETAIL WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND   Loc = @cFromLoc  
         AND   Sku = @cSuggSKU  
         AND   CaseID = @cCartonID  
         AND   [Status] < @cPickConfirmStatus  
  
         SELECT @nPickedQty = ISNULL( SUM( Qty), 0)  
         FROM dbo.PICKDETAIL WITH (NOLOCK)  
         WHERE StorerKey = @cStorerKey  
         AND   Loc = @cFromLoc  
         AND   Sku = @cSuggSKU  
         AND   CaseID = @cCartonID  
         AND   [Status] = @cPickConfirmStatus  
        
         -- Prepare next screen var  
         SET @cOutField01 = @cCartonID  
         SET @cOutField02 = @cSuggSKU  
         SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  
         SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  
         SET @cOutField05 = ''   -- SKU/UPC  
         SET @cOutField06 = '1:' + CASE WHEN @nPUOM_Div > 99999 THEN '*' ELSE CAST( @nPUOM_Div AS NCHAR( 5)) END
         SET @cOutField07 = @nPickedQty  
         SET @cOutField08 = @nSuggQty  
         SET @cOutField09 = rdt.rdtRightAlign( @cPUOM_Desc, 5)
         SET @cOutField10 = rdt.rdtRightAlign( @cMUOM_Desc, 5)
         SET @cOutField11 = CASE WHEN @nPQTY = 0 OR @cFieldAttr11 = 'O' THEN '' ELSE CAST( @nPQTY AS NVARCHAR( 7)) END -- PQTY
         SET @cOutField12 = CASE WHEN @nMQTY = 0 THEN '' ELSE CAST( @nMQTY AS NVARCHAR( 7)) END -- MQTY
         SET @cOutField13 = @cCartPickMethod
         
         EXEC rdt.rdtSetFocusField @nMobile, 5  
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
            @cType            = 'NEXTCARTON',  
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
            IF @cConfirmCartonId = '1'
            BEGIN
               -- Show carton position
               EXEC rdt.[rdt_TM_ClusterPick_ShowCartonPos]   
                  @nMobile          = @nMobile,   
                  @nFunc            = @nFunc,   
                  @cLangCode        = @cLangCode,   
                  @nStep            = @nStep,   
                  @nInputKey        = @nInputKey,   
                  @cFacility        = @cFacility,   
                  @cStorerKey       = @cStorerKey,   
                  @cGroupKey        = @cGroupKey,   
                  @cTaskDetailKey   = @cTaskDetailKey,  
                  @cCartonID        = @cCartonID,    
                  @cPosition        = @cPosition   OUTPUT,
                  @nErrNo           = @nErrNo      OUTPUT,    
                  @cErrMsg          = @cErrMsg     OUTPUT  
      
               IF @nErrNo <> 0      
                  GOTO Step_CartID_Fail      
         
               SET @cNextScreen = 'NEXTCARTON'
                  
               -- Prepare next screen var  
               SET @cOutField01 = @cFromLoc   
               SET @cOutField02 = @cCartonID  
               SET @cOutField03 = ''
               SET @cOutField04 = @cPosition   
               SET @cOutField05 = @cCartPickMethod
               SET @cOutField06 = @cSuggDPosition
               
               -- Go to next screen  
               SET @nScn = @nScn_ConfirmCartonId  
               SET @nStep = @nStep_ConfirmCartonId  
               GOTO Quit   
            END
            
            SELECT TOP 1   
               @cTaskDetailKey = TaskDetailKey,  
               @cFromLoc = FromLoc,
               @cSuggDPosition = DropID  
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
            SET @cOutField01 = @cSuggFromLOC   
            SET @cOutField02 = @cSuggCartonID  
            SET @cOutField03 = ''   
            SET @cOutField04 = @cPosition
            SET @cOutField05 = @cCartPickMethod
            SET @cOutField06 = @cSuggDPosition
            
            -- Go to next screen  
            SET @nScn = @nScn_CartonId  
            SET @nStep = @nStep_CartonId  
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
               IF @cConfirmCartonId = '1'
               BEGIN
                  -- Show carton position
                  EXEC rdt.[rdt_TM_ClusterPick_ShowCartonPos]   
                     @nMobile          = @nMobile,   
                     @nFunc            = @nFunc,   
                     @cLangCode        = @cLangCode,   
                     @nStep            = @nStep,   
                     @nInputKey        = @nInputKey,   
                     @cFacility        = @cFacility,   
                     @cStorerKey       = @cStorerKey,   
                     @cGroupKey        = @cGroupKey,   
                     @cTaskDetailKey   = @cTaskDetailKey,  
                     @cCartonID        = @cCartonID,    
                     @cPosition        = @cPosition   OUTPUT,
                     @nErrNo           = @nErrNo      OUTPUT,    
                     @cErrMsg          = @cErrMsg     OUTPUT  
      
                  IF @nErrNo <> 0      
                     GOTO Step_CartID_Fail      
         
                  SET @cNextScreen = 'NEXTLOC'
                     
                  -- Prepare next screen var  
                  SET @cOutField01 = @cFromLoc   
                  SET @cOutField02 = @cCartonID  
                  SET @cOutField03 = ''
                  SET @cOutField04 = @cPosition   
                  SET @cOutField05 = @cCartPickMethod
                  SET @cOutField06 = @cSuggDPosition
                  
                  -- Go to next screen  
                  SET @nScn = @nScn_ConfirmCartonId  
                  SET @nStep = @nStep_ConfirmCartonId  
                  GOTO Quit   
               END
                  
               SELECT TOP 1   
                  @cTaskDetailKey = TaskDetailKey,  
                  @cFromLoc = FromLoc  
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
               SET @cOutField01 = @cSuggFromLOC   
               SET @cOutField02 = ''  
               SET @cOutField03 = @cCartPickMethod
                  
               -- Go to next screen  
               SET @nScn = @nScn_Loc  
               SET @nStep = @nStep_Loc  
            END    
            ELSE  
            BEGIN  
               -- Clear 'No Task' error from previous get task    
               SET @nErrNo = 0    
               SET @cErrMsg = ''    

               IF @cConfirmCartonId = '1'
               BEGIN
                  -- Show carton position
                  EXEC rdt.[rdt_TM_ClusterPick_ShowCartonPos]   
                     @nMobile          = @nMobile,   
                     @nFunc            = @nFunc,   
                     @cLangCode        = @cLangCode,   
                     @nStep            = @nStep,   
                     @nInputKey        = @nInputKey,   
                     @cFacility        = @cFacility,   
                     @cStorerKey       = @cStorerKey,   
                     @cGroupKey        = @cGroupKey,   
                     @cTaskDetailKey   = @cTaskDetailKey,  
                     @cCartonID        = @cCartonID,    
                     @cPosition        = @cPosition   OUTPUT,
                     @nErrNo           = @nErrNo      OUTPUT,    
                     @cErrMsg          = @cErrMsg     OUTPUT  
      
                  IF @nErrNo <> 0      
                     GOTO Step_CartID_Fail      
         
                  SET @cNextScreen = 'TOLOC'
                  
                  -- Prepare next screen var  
                  SET @cOutField01 = @cFromLoc   
                  SET @cOutField02 = @cCartonID  
                  SET @cOutField03 = ''
                  SET @cOutField04 = @cPosition   
                  SET @cOutField05 = @cCartPickMethod
      
                  -- Go to next screen  
                  SET @nScn = @nScn_ConfirmCartonId  
                  SET @nStep = @nStep_ConfirmCartonId  
                  GOTO Quit   
               END
               
               -- Scan out    
               SET @nErrNo = 0    
               EXEC rdt.rdt_TM_ClusterPick_ScanOut @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey    
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
               
               -- Prepare next screen var    
               SET @cOutField01 = @cSuggToLOC -- To LOC    
               SET @cOutField02 = CASE WHEN @cConfirmToLoc = '1' THEN '' ELSE @cSuggToLOC END  
               SET @cOutField03 = @cCartPickMethod
                  
               -- Go to To LOC screen    
               SET @nScn = @nScn_ToLoc    
               SET @nStep = @nStep_ToLoc    
            END    
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
               GOTO Step_SKUQTY_Fail  
         END  
      END          
      
      IF @cConfirmToLoc = '0' AND @cOutField02 = @cSuggToLOC AND @nStep = @nStep_ToLoc
      BEGIN
         SET @cInField02 = @cOutField02
         GOTO Step_ToLoc         
      END
   END            
            
   IF @nInputKey = 0  
   BEGIN  
      SELECT @nPickedQty = ISNULL( SUM( Qty), 0)  
      FROM dbo.PICKDETAIL WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
      AND   Loc = @cFromLoc  
      AND   Sku = @cSuggSKU  
      AND   CaseID = @cCartonID  
      AND   [Status] = @cPickConfirmStatus  
        
      -- Prepare next screen var  
      SET @cOutField01 = @cCartonID  
      SET @cOutField02 = @cSuggSKU  
      SET @cOutField03 = SUBSTRING( @cSKUDescr, 1, 20)  
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 21, 20)  
      SET @cOutField05 = ''   -- SKU/UPC  
      SET @cOutField06 = CASE WHEN @cDefaultQTY = '0' THEN '' ELSE @cDefaultQTY END -- QTY  
      SET @cOutField07 = @nPickedQty  
      SET @cOutField08 = @nSuggQty  
  
      -- Enable field  
      IF @cDisableQTYField = '1'  
      BEGIN  
         SET @cFieldAttr06 = 'O'  
         SET @cOutField06 = CASE WHEN @cDefaultQTY = '0' THEN '1' ELSE @cDefaultQTY END  
      END  
      ELSE  
         SET @cFieldAttr06 = ''  
  
      SET @cSKUValidated = '0'  
  
      EXEC rdt.rdtSetFocusField @nMobile, 5  --SKU  
        
      -- Go to next screen  
      SET @nScn = @nScn_SKUQTY  
      SET @nStep = @nStep_SKUQTY  
   END       
   GOTO Quit            
            
   Step_CloseCarton_Fail:            
   BEGIN            
      SET @cOutField03 = @cCartPickMethod
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
      SET @cSuggToLOC = @cOutField01  
      SET @cToLOC = @cInField02    
  
      IF @cSkipToLoc = '0'
      BEGIN
         -- Check blank FromLOC    
         IF @cToLOC = ''    
         BEGIN    
            SET @nErrNo = 148918    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC needed    
            GOTO Step_ToLoc_Fail    
         END    
    
         -- Check if FromLOC match    
         IF @cToLOC <> @cSuggToLOC  AND ISNULL( @cSuggToLOC, '') <> ''  
         BEGIN    
            IF @cOverwriteToLOC = '0'    
            BEGIN    
               SET @nErrNo = 148919    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToLOC Diff    
               GOTO Step_ToLoc_Fail    
            END    
             
            -- Check ToLOC valid    
            IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC)    
            BEGIN    
               SET @nErrNo = 148920    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC    
               GOTO Step_ToLoc_Fail    
            END    
         END    

         -- Handling transaction            
         SET @nTranCount = @@TRANCOUNT            
         BEGIN TRAN  -- Begin our own transaction            
         SAVE TRAN Step_ConfirmToLoc -- For rollback or commit only our own transaction            
            
         SET @nErrNo = 0  
         EXEC rdt.rdt_TM_ClusterPick_ConfirmToLoc   
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
  
               IF @nErrNo > 0   
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
      END

      -- Last check point on previous skip/not pick loc
      --Get task for next loc  
      SET @nErrNo = 0  
      SET @cSuggFromLOC = ''  

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

      IF @nErrNo <> 0   -- Still no task, go to picking completed screen
      BEGIN
         SET @cSuggFromLOC = ''
         
         -- Prepare next screen var    
         SET @cOutField01 = @cCartID    
          
         SET @nScn = @nScn_NextTask  
         SET @nStep = @nStep_NextTask
            
         GOTO Quit
      END   
      ELSE
      BEGIN
         -- Prepare next screen var  
         SET @cOutField01 = @cSuggFromLOC   
         SET @cOutField02 = ''   
         SET @cOutField03 = @cCartPickMethod

         -- Go to next screen  
         SET @nScn = @nScn_Loc  
         SET @nStep = @nStep_Loc
            
         GOTO Quit  
      END
   END
       
     
   Step_ToLoc_Fail:    
   BEGIN    
      SET @cToLOC = ''    
      SET @cOutField02 = '' -- To LOC    
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
      DECLARE @cNextTaskType NVARCHAR(10)    
          
      SET @cErrMsg = ''    
      SET @cNextTaskDetailKey = ''    
      SET @cNextTaskType = ''    
    
      -- Get next task    
      EXEC dbo.nspTMTM01    
          @c_sendDelimiter = null    
         ,@c_ptcid         = 'RDT'    
         ,@c_userid        = @cUserName    
         ,@c_taskId        = 'RDT'    
         ,@c_databasename  = NULL    
         ,@c_appflag       = NULL    
         ,@c_recordType    = NULL    
         ,@c_server        = NULL    
         ,@c_ttm           = NULL    
         ,@c_areakey01     = @cAreaKey    
         ,@c_areakey02     = ''    
         ,@c_areakey03  = ''    
         ,@c_areakey04     = ''    
         ,@c_areakey05     = ''    
         ,@c_lastloc       = @cSuggToLOC    
         ,@c_lasttasktype  = @cTTMTaskType    
         ,@c_outstring     = @c_outstring    OUTPUT    
         ,@b_Success       = @bSuccess       OUTPUT    
         ,@n_err           = @nErrNo         OUTPUT    
         ,@c_errmsg        = @cErrMsg        OUTPUT    
         ,@c_TaskDetailKey = @cNextTaskDetailKey OUTPUT    
         ,@c_ttmtasktype   = @cNextTaskType  OUTPUT    
         ,@c_RefKey01      = @cRefKey01      OUTPUT -- this is the field value to parse to 1st Scn in func    
         ,@c_RefKey02      = @cRefKey02      OUTPUT -- this is the field value to parse to 1st Scn in func    
         ,@c_RefKey03      = @cRefKey03      OUTPUT -- this is the field value to parse to 1st Scn in func    
         ,@c_RefKey04      = @cRefKey04      OUTPUT -- this is the field value to parse to 1st Scn in func    
         ,@c_RefKey05      = @cRefKey05      OUTPUT -- this is the field value to parse to 1st Scn in func    
    
      IF @bSuccess = 0 OR @nErrNo <> 0    
         GOTO Step_NextTask_Fail    
    
      -- No task    
      IF @cNextTaskDetailKey = ''    
      BEGIN    
         -- Logging    
         EXEC RDT.rdt_STD_EventLog    
             @cActionType = '9', -- Sign out function    
             @cUserID     = @cUserName,    
             @nMobileNo   = @nMobile,    
             @nFunctionID = @nFunc,    
             @cFacility   = @cFacility,    
             @cStorerKey  = @cStorerKey    
    
         -- Go back to Task Manager Main Screen    
         SET @cErrMsg = 'No More Task'    
         SET @cAreaKey = ''    
         SET @cOutField01 = ''  -- Area    
         SET @cOutField02 = ''    
         SET @cOutField03 = ''    
         SET @cOutField04 = ''    
         SET @cOutField05 = ''    
         SET @cOutField06 = ''    
         SET @cOutField07 = ''    
         SET @cOutField08 = ''    
    
         SET @nFunc = 1756    
         SET @nScn = 2100    
         SET @nStep = 1    
         GOTO QUIT    
      END    
    
      -- Have next task    
      IF @cNextTaskDetailKey <> ''    
      BEGIN    
         SET @cTaskDetailKey = @cNextTaskDetailKey    
         SET @cTTMTaskType = @cNextTaskType    
         SET @cOutField01 = @cRefKey01    
         SET @cOutField02 = @cRefKey02    
         SET @cOutField03 = @cRefKey03    
         SET @cOutField04 = @cRefKey04    
         SET @cOutField05 = @cRefKey05    
         SET @cOutField06 = @cTaskDetailKey    
         SET @cOutField07 = @cAreaKey    
         SET @cOutField08 = @cTTMStrategykey    
         SET @cOutField09 = ''    
      END    
    
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
         SET @nErrNo = 148921    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NextTaskFncErr    
         GOTO Step_NextTask_Fail    
      END    
    
      -- Check if screen setup    
      SELECT TOP 1 @nToScn = Scn FROM RDT.RDTScn WITH (NOLOCK) WHERE Func = @nToFunc ORDER BY Scn    
      IF @nToScn = 0    
      BEGIN    
         SET @nErrNo = 148922    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NextTaskScnErr    
         GOTO Step_NextTask_Fail    
      END    
    
      -- Enable field    
      SET @cFieldAttr04 = '' -- @cDropID    
      SET @cFieldAttr08 = '' -- @nSKU    
      SET @cFieldAttr14 = '' -- @nPQTY    
      SET @cFieldAttr15 = '' -- @nMQTY    
    
      -- Logging    
      EXEC RDT.rdt_STD_EventLog    
         @cActionType = '9', -- Sign Out function    
         @cUserID     = @cUserName,    
         @nMobileNo   = @nMobile,    
         @nFunctionID = @nFunc,    
         @cFacility   = @cFacility,    
         @cStorerKey  = @cStorerKey    
    
      SET @nFunc = @nToFunc    
      SET @nScn  = @nToScn    
      SET @nStep = @nToStep    
    
      IF @cTTMTaskType = 'CPK'    
         GOTO Step_Start    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      EXEC RDT.rdt_STD_EventLog    
       @cActionType = '9', -- Sign Out function    
       @cUserID     = @cUserName,    
       @nMobileNo   = @nMobile,    
       @nFunctionID = @nFunc,    
       @cFacility   = @cFacility,    
       @cStorerKey  = @cStorerKey    
    
      -- Enable field    
      SET @cFieldAttr04 = '' -- @cDropID    
      SET @cFieldAttr08 = '' -- @nSKU    
      SET @cFieldAttr14 = '' -- @nPQTY    
      SET @cFieldAttr15 = '' -- @nMQTY    
    
      -- Go back to Task Manager Main Screen    
      SET @nFunc = 1756    
      SET @nScn = 2100    
      SET @nStep = 1    
    
      SET @cAreaKey = ''    
      SET @cOutField01 = ''  -- Area    
   END    
   GOTO Quit    
     
   Step_NextTask_Fail:  
END  
GOTO Quit  
  
/********************************************************************************    
Step 10. screen = 2109. Reason code screen    
     REASON CODE (Field01, input)    
********************************************************************************/    
Step_ReasonCode:    
BEGIN    
   IF @nInputKey = 1 -- ENTER    
   BEGIN    
      -- Screen mapping    
      DECLARE @nShortQTY INT    
      SET @cReasonCode = @cInField01    
    
      -- Check blank reason    
      IF @cReasonCode = ''    
      BEGIN    
        SET @nErrNo = 148922    
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Reason needed    
        GOTO Step_ReasonCode_Fail    
      END    
    
      IF NOT EXISTS( SELECT TOP 1 1    
         FROM CodeLKUP WITH (NOLOCK)    
         WHERE ListName = 'RDTTASKRSN'    
            AND StorerKey = @cStorerKey    
            AND Code = @cTTMTaskType    
            AND @cReasonCode IN (UDF01, UDF02, UDF03, UDF04, UDF05))    
      BEGIN    
        SET @nErrNo = 148923    
        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Reason    
        GOTO Step_ReasonCode_Fail    
      END    
  
      -- Extended validate  
      IF @cExtendedValidateSP <> ''  
      BEGIN  
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedValidateSP AND type = 'P')  
         BEGIN  
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +  
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +   
               ' @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption, ' +  
               ' @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
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
               ' @tExtValidate   VariableTable READONLY, ' +   
               ' @nErrNo         INT           OUTPUT, ' +  
               ' @cErrMsg        NVARCHAR( 20) OUTPUT  '  
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,   
               @cGroupKey, @cTaskDetailKey, @cCartId, @cFromLoc, @cCartonId, @cSKU, @nQty, @cOption,   
               @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
            IF @nErrNo <> 0   
               GOTO Step_ReasonCode_Fail  
         END  
      END  
  
      DECLARE @b_Success   INT  
  
      -- Update ReasonCode    
      SET @nShortQTY = @nActQTY    
      EXEC dbo.nspRFRSN01    
          @c_sendDelimiter = NULL    
         ,@c_ptcid         = 'RDT'    
         ,@c_userid        = @cUserName    
         ,@c_taskId        = 'RDT'    
         ,@c_databasename  = NULL    
         ,@c_appflag       = NULL    
         ,@c_recordType    = NULL    
         ,@c_server        = NULL    
         ,@c_ttm           = NULL    
         ,@c_TaskDetailKey = @cTaskDetailKey    
         ,@c_fromloc       = @cSuggFromLOC    
         ,@c_fromid        = ''    
         ,@c_toloc         = @cSuggToloc    
         ,@c_toid          = ''    
         ,@n_qty           = @nShortQTY    
         ,@c_PackKey       = ''    
         ,@c_uom           = ''    
         ,@c_reasoncode    = @cReasonCode    
         ,@c_outstring     = @c_outstring    OUTPUT    
         ,@b_Success       = @b_Success      OUTPUT    
         ,@n_err           = @nErrNo         OUTPUT    
         ,@c_errmsg        = @cErrMsg        OUTPUT    
         ,@c_userposition  = '1' -- 1=at from LOC    
      IF @b_Success = 0 OR @nErrNo <> 0    
         GOTO Step_ReasonCode_Fail    
    
      -- Get task reason info    
      DECLARE @cContinueProcess         NVARCHAR(10)    
      DECLARE @cRemoveTaskFromUserQueue NVARCHAR(10)    
      DECLARE @cTaskStatus              NVARCHAR(10)    
      SELECT    
         @cContinueProcess = ContinueProcessing,    
         @cRemoveTaskFromUserQueue = RemoveTaskFromUserQueue,    
         @cTaskStatus = TaskStatus    
      FROM dbo.TaskManagerReason WITH (NOLOCK)    
      WHERE TaskManagerReasonKey = @cReasonCode    
    
      IF @cRemoveTaskFromUserQueue = '1'    
      BEGIN    
         INSERT INTO TaskManagerSkipTasks (UserID, TaskDetailKey, TaskType, LOT, FromLOC, ToLOC, FromID, ToID, CaseID)    
         SELECT UserKey, TaskDetailKey, TaskType, LOT, FromLOC, ToLOC, FromID, ToID, CaseID    
         FROM dbo.TaskDetail WITH (NOLOCK)    
         WHERE TaskDetailKey = @cTaskdetailKey    
         IF @@ERROR <> 0    
         BEGIN    
            SET @nErrNo = 148923    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsSkipTskFail    
            GOTO Step_ReasonCode_Fail    
         END    
      END    
    
      -- Update TaskDetail.Status    
      IF @cTaskStatus <> ''    
      BEGIN    
         -- Skip task    
         IF @cTaskStatus = '0'    
         BEGIN    
            UPDATE dbo.TaskDetail SET    
                UserKey = ''    
               ,ReasonKey = ''    
               ,Status = '0'    
               ,EditDate = GETDATE()    
               ,EditWho  = SUSER_SNAME()    
               ,TrafficCop = NULL    
            WHERE TaskDetailKey = @cTaskDetailKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 148925    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskdetFail    
               GOTO Step_ReasonCode_Fail    
            END    
         END    
    
         -- Cancel task    
         IF @cTaskStatus = 'X'    
         BEGIN    
            UPDATE dbo.TaskDetail SET    
                Status = 'X'    
               ,EditDate = GETDATE()    
               ,EditWho  = SUSER_SNAME()    
               ,TrafficCop = NULL    
            WHERE TaskDetailKey = @cTaskDetailKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 148926    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskdetFail    
               GOTO Step_ReasonCode_Fail    
            END    
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
               GOTO Step_ReasonCode_Fail  
         END  
      END          
    
      -- Continue process current task    
      IF @cContinueProcess = '1'    
      BEGIN    
         --Get task for next loc  
         SET @nErrNo = 0  
         SET @cCurrentSuggLoc = @cSuggFromLOC   -- Save current suggested loc

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
  
         IF @nErrNo <> 0   -- No task, search task from beginning
         BEGIN
            --Get task for next loc  
            SET @nErrNo = 0  
            SET @cSuggFromLOC = ''  

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

            IF @nErrNo <> 0   -- Still no task, go to picking completed screen
            BEGIN
               SET @cSuggFromLOC = ''
         
               -- Prepare next screen var    
               SET @cOutField01 = @cCartID    
          
               SET @nScn = @nScn_NextTask  
               SET @nStep = @nStep_NextTask
            
               GOTO Quit
            END   
            ELSE
            BEGIN
               -- Prepare next screen var  
               SET @cOutField01 = @cSuggFromLOC   
               SET @cOutField02 = ''   
               SET @cOutField03 = @cCartPickMethod

               -- Go to next screen  
               SET @nScn = @nScn_Loc  
               SET @nStep = @nStep_Loc
            
               GOTO Quit  
            END
         END  
  
         IF @cSuggFromLOC <> '' AND @cCurrentSuggLoc <> @cSuggFromLOC
         BEGIN
            -- Prepare next screen var  
            SET @cOutField01 = @cSuggFromLOC   
            SET @cOutField02 = ''   
            SET @cOutField03 = @cCartPickMethod

            -- Go to next screen  
            SET @nScn = @nScn_Loc  
            SET @nStep = @nStep_Loc
            
            GOTO Quit  
         END

         --SET @cSuggFromLOC = ''
         
         ---- Prepare next screen var    
         --SET @cOutField01 = @cCartID    
          
         --SET @nScn = @nScn_NextTask  
         --SET @nStep = @nStep_NextTask   
      END    
      ELSE    
      BEGIN    
      	-- For those assigned deviceid, dropid when start picking need clear deviceid, dropid 
      	IF @cAssignGroupKeyWhenNoSuggCartId = '1'
      	BEGIN
      	   SET @curRelTask = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      	   SELECT TaskDetailKey
      	   FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
   		   AND   TaskType = 'CPK'
   		   AND   Groupkey = @cGroupKey
   		   AND   [Status] < '5'
   		   OPEN @curRelTask
   		   FETCH NEXT FROM @curRelTask INTO @cRelTaskKey
   		   WHILE @@FETCH_STATUS = 0
   		   BEGIN
   			   UPDATE TaskDetail SET 
   			      DeviceID = '', 
   			      DropID = '', 
   			      EditWho = @cUserName, 
   			      EditDate = GETDATE()
   			   WHERE TaskDetailKey = @cRelTaskKey

               IF @@ERROR <> 0    
               BEGIN    
                  SET @nErrNo = 148934    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdTaskdetFail    
                  GOTO Step_ReasonCode_Fail    
               END    
            
   			   FETCH NEXT FROM @curRelTask INTO @cRelTaskKey
   		   END
      	END
      	
         -- Setup RDT storer config ContProcNotUpdTaskStatus, to avoid nspRFRSN01 set TaskDetail.Status = '9', when ContinueProcess <> 1    
    
         -- Go to next task/exit TM screen    
         -- Logging    
         EXEC RDT.rdt_STD_EventLog    
             @cActionType = '9', -- Sign out function    
             @cUserID     = @cUserName,    
             @nMobileNo   = @nMobile,    
             @nFunctionID = @nFunc,    
             @cFacility   = @cFacility,    
             @cStorerKey  = @cStorerKey,    
             @nStep       = @nStep    
    
         -- Go back to Task Manager Main Screen    
         SET @cErrMsg = ''    
         SET @cAreaKey = ''    
         SET @cOutField01 = ''  -- Area    
         SET @cOutField02 = ''    
         SET @cOutField03 = ''    
         SET @cOutField04 = ''    
         SET @cOutField05 = ''    
         SET @cOutField06 = ''    
         SET @cOutField07 = ''    
         SET @cOutField08 = ''    
    
         SET @nFunc = 1756    
         SET @nScn = 2100    
         SET @nStep = 1    
         GOTO QUIT    
      END    
   END    
    
   IF @nInputKey = 0 -- ESC    
   BEGIN    
      -- Prepare next screen var  
      SET @cOutField01 = @cSuggCartId  
      SET @cOutField02 = ''   
    
      -- Go to next screen  
      SET @nScn = @nScn_CartID  
      SET @nStep = @nStep_CartID  
   END    
   GOTO Quit    
    
   Step_ReasonCode_Fail:    
   BEGIN    
      SET @cReasonCode = ''    
    
      -- Reset this screen var    
      SET @cOutField01 = ''    
   END    
END    
GOTO Quit    

/********************************************************************************  
Scn = 5689. Confirm Carton ID  
   Loc       (field01)  
   Carton ID (field02)  
   Carton ID (field03, input)  
********************************************************************************/  
Step_ConfirmCartonID:  
BEGIN  
   IF @nInputKey = 1 -- ENTER  
   BEGIN  
      -- Screen mapping  
      SET @cCartonID2Confirm = @cOutField02
      SET @cCartonID = @cInField03  
  
      -- Validate blank  
      IF ISNULL( @cCartonID, '') = ''  
      BEGIN  
         SET @nErrNo = 148927  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need Case Id  
         GOTO Step_ConfirmCartonID_Fail  
      END  
  
      -- Validate option  
      IF @cCartonID <> @cCartonID2Confirm  
      BEGIN  
         SET @nErrNo = 148928  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --CaseIdNotMatch  
         GOTO Step_ConfirmCartonID_Fail  
      END  

      SELECT TOP 1   
         @cTaskDetailKey = TaskDetailKey,  
         @cFromLoc = FromLoc  
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
         
      IF @cNextScreen = 'NEXTCARTON'
      BEGIN
         -- Show carton position
         EXEC rdt.[rdt_TM_ClusterPick_ShowCartonPos]   
            @nMobile          = @nMobile,   
            @nFunc            = @nFunc,   
            @cLangCode        = @cLangCode,   
            @nStep            = @nStep,   
            @nInputKey        = @nInputKey,   
            @cFacility        = @cFacility,   
            @cStorerKey       = @cStorerKey,   
            @cGroupKey        = @cGroupKey,   
            @cTaskDetailKey   = @cTaskDetailKey,  
            @cCartonID        = @cSuggCartonID,    
            @cPosition        = @cPosition   OUTPUT,
            @nErrNo           = @nErrNo      OUTPUT,    
            @cErrMsg          = @cErrMsg     OUTPUT  
      
         IF @nErrNo <> 0      
            GOTO Step_ConfirmCartonID_Fail      
           
          IF @cScanDevicePosition = '1'
             SELECT @cSuggDPosition = DropId
             FROM dbo.TaskDetail WITH (NOLOCK)
             WHERE TaskDetailKey = @cTaskDetailKey
             
         -- Prepare next screen var  
         SET @cOutField01 = @cSuggFromLOC   
         SET @cOutField02 = @cSuggCartonID  
         SET @cOutField03 = ''   
         SET @cOutField04 = @cPosition
         SET @cOutField05 = @cCartPickMethod
         SET @cOutField06 = @cSuggDPosition
         
         -- Go to next screen  
         SET @nScn = @nScn_CartonId  
         SET @nStep = @nStep_CartonId  
      END
      ELSE IF @cNextScreen = 'NEXTLOC'
      BEGIN
         -- Prepare next screen var  
         SET @cOutField01 = @cSuggFromLOC   
         SET @cOutField02 = ''  
         SET @cOutField03 = @cCartPickMethod
                  
         -- Go to next screen  
         SET @nScn = @nScn_Loc  
         SET @nStep = @nStep_Loc  
      END
      ELSE  -- TOLOC
      BEGIN
         -- Scan out    
         SET @nErrNo = 0    
         EXEC rdt.rdt_TM_ClusterPick_ScanOut @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey    
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
               
         -- Prepare next screen var    
         SET @cOutField01 = @cSuggToLOC -- To LOC    
         SET @cOutField02 = CASE WHEN @cConfirmToLoc = '1' THEN '' ELSE @cSuggToLOC END  
         SET @cOutField03 = @cCartPickMethod
                  
         -- Go to To LOC screen    
         SET @nScn = @nScn_ToLoc    
         SET @nStep = @nStep_ToLoc  

         IF @cConfirmToLoc = '0' AND @cOutField02 = @cSuggToLOC AND @nStep = @nStep_ToLoc
         BEGIN
            SET @cInField02 = @cOutField02
            GOTO Step_ToLoc         
         END
      END
   END  
  
   --IF @nInputKey = 0 -- ESC  
   --BEGIN  
   --   -- Prepare next screen var  
   --   SET @cOutField01 = @cSuggFromLoc  
   --   SET @cOutField02 = ''   
   --   SET @cOutField03 = @cCartPickMethod

   --   -- Go to next screen  
   --   SET @nScn = @nScn_Loc  
   --   SET @nStep = @nStep_Loc  
   --END  
   GOTO Quit  
  
   Step_ConfirmCartonID_Fail:  
   BEGIN  
      SET @cCartonID = ''  
  
      SET @cOutField03 = ''  
   END  
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
      V_UOM      = @cPUOM,
      
      V_Integer1 = @nSuggQty,  
      V_Integer2 = @nPickedQty,  
      V_Integer3 = @nActQTY,  
      V_Integer4 = @nPUOM_Div,
      V_Integer5 = @nPQTY,
      V_Integer6 = @nMQTY,
      V_Integer7 = @nPQtyCursor,

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
      V_String21 = @cCartPickMethod,
      V_String22 = @cPosition,
      V_String23 = @cConfirmCartonId,
      V_String24 = @cNextScreen,
      V_String25 = @cFlowThruStepCartID,
      V_String26 = @cFlowThruStepMatrix,
      V_String27 = @cConfirmToLoc,
      V_String28 = @cAssignGroupKeyWhenNoSuggCartId,
      V_String29 = @cScanDevicePosition,
      V_String30 = @cSuggDPosition,
      V_String31 = @cDPosition,
         
      V_TaskDetailKey = @cTaskDetailKey,  
              
      V_String32   = @cAreakey,    
      V_String33   = @cTTMStrategykey,    
      V_String34   = @cTTMTaskType,    
      V_String35   = @cRefKey01,    
      V_String36   = @cRefKey02,    
      V_String37   = @cRefKey03,    
      V_String38   = @cRefKey04,    
      V_String39   = @cRefKey05,    
      V_String40   = @cMUOM_Desc,
      V_String41   = @cPUOM_Desc,
      V_String42   = @cSkipToLoc,
      
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
  
   -- Execute TM module initialization (ung01)    
   IF (@nFunc <> 640 AND @nStep = 0) AND  -- Other module that begin with step 0    
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