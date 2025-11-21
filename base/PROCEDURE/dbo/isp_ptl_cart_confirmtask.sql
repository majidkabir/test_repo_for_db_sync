SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp_PTL_Cart_ConfirmTask                            */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Comfirm Pick                                                */
/*                                                                      */
/* Called from: rdtfnc_TM_CartPicking                                   */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2014-02-05  1.0  James       SOS296464 Created                       */
/* 2014-05-12  1.1  James       Add eventlog (james01)                  */
/* 2014-05-13  1.2  ChewKP      Hardcode SPK task for WCSRoute          */
/*                              generation (ChewKP01)                   */
/* 2014-05-15  1.3  ChewKP      Offset shall follow DropID.PickslipNo   */
/*                              and LoadKey (ChewKP02)                  */
/* 2014-06-04  1.4  ChewKP      Delete Route Before Create (ChewKP03)   */
/* 2021-08-23  1.5  Chermaine   WMS-17814 Add ChannelID (cc01)          */
/************************************************************************/

CREATE PROC [dbo].[isp_PTL_Cart_ConfirmTask] (
   @nPTLKey                INT,
   @cStorerKey             NVARCHAR( 15), 
   @cDeviceProfileLogKey   NVARCHAR(10), 
   @cDropID                NVARCHAR( 20), 
   @nQty                   INT, 
   @nErrNo                 INT          OUTPUT,
   @cErrMsg                NVARCHAR(20) OUTPUT -- screen limitation, 20 char max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @b_success   INT,
   @n_err               INT,
   @c_errmsg            NVARCHAR( 250),
   @cPickDetailKey      NVARCHAR( 10),
   @nPickQty            INT,
   @nQTY_PD             INT,
   @nTranCount          INT,
   @cConsigneeKey       NVARCHAR( 15), 
   @cLOC                NVARCHAR( 10), 
   @cSKU                NVARCHAR( 20),  
   @cOrderKey           NVARCHAR( 10), 
   @cLangCode           NVARCHAR( 3), 
   @nNewPTLKey          INT, 
   @nExpectedQty        INT, 
   @bShortPick          INT,
   @cRemarks            NVARCHAR( 500), 
   @cDeviceID           NVARCHAR( 20), 
   @cDevicePosition     NVARCHAR( 10), 
   @cLightMode          NVARCHAR( 10), 
   @cSourceKey          NVARCHAR( 10), 
   @cAddWho             NVARCHAR( 18), 
   @cLoadKey            NVARCHAR( 10), 
   @cTaskType           NVARCHAR( 10), 
   @cUserName           NVARCHAR( 18), 
   @cFacility           NVARCHAR( 5), 
   @cActionFlag         NVARCHAR( 1), 
   @nMobile             INT, 
   @nFunc               INT,
   @cPickslipNo         NVARCHAR(10) -- (ChewKP02) 
   
   SET @cLoadKey = ''
   SET @cFacility = ''
   SET @cActionFlag = ''
   SET @cTaskType = ''
   SET @cPickSlipNo = '' -- (ChewKP02) 
   
   SET @nPickQty = @nQty
   SET @bShortPick = CASE WHEN @nPickQty = 0 THEN 1 ELSE 0 END
   
   SET @cActionFlag = CASE WHEN @bShortPick = 0 THEN 'N' ELSE 'S' END
   
   SELECT @cLoadKey = LoadKey 
         ,@cPickSlipNo = PickSlipNo -- (ChewKP01) 
   FROM dbo.DropID WITH (NOLOCK) 
   WHERE DropID = ISNULL(RTRIM(@cDropID),'')   

   SELECT @cUserName = UserName, 
          @cFacility = Facility, 
          @cTaskType = V_String34, 
          @nMobile = Mobile, 
          @nFunc = Func 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE UserName = sUser_sName()

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN PTL_Cart_ConfirmTask

   -- Get PTL candidate to offset
   DECLARE curRPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT LOC, SKU, ConsigneeKey, DropID, SourceKey, Addwho 
   FROM dbo.PTLTran WITH (NOLOCK)
   WHERE PTLKey = @nPTLKey
   AND   [Status] = '1'
   OPEN curRPL
   FETCH NEXT FROM curRPL INTO @cLOC, @cSKU, @cConsigneeKey, @cDropID, @cSourceKey, @cAddWho
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- If no record returned
      IF ISNULL( @cLOC, '') = ''
      BEGIN
         SET @nErrNo = 85010
         SET @cErrMsg = 'NO PTL TRAN'
         GOTO RollBackTran
      END

      IF EXISTS ( SELECT 1 
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)
                  WHERE PD.StorerKey  = @cStorerKey
                  AND   PD.SKU = @cSKU
                  AND   PD.LOC = @cLOC
                  AND   PD.Status = '0'
                  AND   TD.Message03 = @cConsigneeKey
                  AND   TD.WaveKey = @cSourceKey
                  AND   TD.Status = '3'
                  AND   PD.PickSlipNo = @cPickSlipNo -- (ChewKP02)
                  HAVING SUM( PD.QTY) <= 0)
      BEGIN
         SET @nErrNo = 85011
         SET @cErrMsg = 'NoQty2Offset'
         GOTO RollBackTran
      END

      -- Get PickDetail candidate to offset based on PTL's candidate
      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.OrderKey, PD.PickDetailKey, PD.QTY
      FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.TaskDetail TD WITH (NOLOCK) ON (PD.TaskDetailKey = TD.TaskDetailKey)
      WHERE PD.StorerKey  = @cStorerKey
      AND   PD.SKU = @cSKU
      AND   PD.LOC = @cLOC
      AND   PD.Status = '0'
      AND   TD.Message03 = @cConsigneeKey
      AND   TD.WaveKey = @cSourceKey
      AND   TD.Status = '3'
      AND   PD.PickSlipNo = @cPickSlipNo -- (ChewKP02)
      ORDER BY PD.PickDetailKey
      OPEN curPD
      FETCH NEXT FROM curPD INTO @cOrderKey, @cPickDetailKey, @nQTY_PD
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Short pick
         IF @nPickQty = 0
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
               Status = '4'
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 85001
               SET @cErrMsg = 'OffSetPDtlFail'
               GOTO RollBackTran
            END

            -- EventLog 
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '3', -- Picking
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerKey,
               @cLocation     = @cLoc,
               @cDropID       = @cDropID, 
               @cOrderKey     = @cOrderKey, 
               @cSKU          = @cSKU,
               @nQTY          = @nQTY_PD,
               @cLoadKey      = @cLoadKey,
               @cRefNo1       = @nPTLKey,   
               @cRefNo2       = @cDeviceProfileLogKey, 
               @cRefNo3       = @cConsigneeKey,   
               @cRefNo4       = @cSourceKey, 
               @cRefNo5       = @cTaskType  
         END
         
         -- Exact match
         IF @nQTY_PD = @nPickQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
               Status = '5'
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 85002
               SET @cErrMsg = 'OffSetPDtlFail'
               GOTO RollBackTran
            END

            SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance 

            -- EventLog 
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '3', -- Picking
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerKey,
               @cLocation     = @cLoc,
               @cDropID       = @cDropID, 
               @cOrderKey     = @cOrderKey, 
               @cSKU          = @cSKU,
               @nQTY          = @nQTY_PD,
               @cLoadKey      = @cLoadKey,
               @cRefNo1       = @nPTLKey,   
               @cRefNo2       = @cDeviceProfileLogKey, 
               @cRefNo3       = @cConsigneeKey,   
               @cRefNo4       = @cSourceKey, 
               @cRefNo5       = @cTaskType  
         END
         -- PickDetail have less
         ELSE IF @nQTY_PD < @nPickQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               DropID = @cDropID,
               Status = '5'
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 85003
               SET @cErrMsg = 'OffSetPDtlFail'
               GOTO RollBackTran
            END

            SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance

            -- EventLog 
            EXEC RDT.rdt_STD_EventLog
               @cActionType   = '3', -- Picking
               @cUserID       = @cUserName,
               @nMobileNo     = @nMobile,
               @nFunctionID   = @nFunc,
               @cFacility     = @cFacility,
               @cStorerKey    = @cStorerKey,
               @cLocation     = @cLoc,
               @cDropID       = @cDropID, 
               @cOrderKey     = @cOrderKey, 
               @cSKU          = @cSKU,
               @nQTY          = @nQTY_PD,
               @cLoadKey      = @cLoadKey,
               @cRefNo1       = @nPTLKey,   
               @cRefNo2       = @cDeviceProfileLogKey, 
               @cRefNo3       = @cConsigneeKey,   
               @cRefNo4       = @cSourceKey, 
               @cRefNo5       = @cTaskType  
               
         END
         -- PickDetail have more, need to split
         ELSE IF @nQTY_PD > @nPickQty
         BEGIN
            IF @nPickQty > 0 -- SOS# 176144
            BEGIN
               -- If Status = '5' (full pick), split line if neccessary
               -- If Status = '4' (short pick), no need to split line if already last RPL line to update,
               -- just have to update the pickdetail.qty = short pick qty
               -- Get new PickDetailkey
               DECLARE @cNewPickDetailKey NVARCHAR( 10)
               EXECUTE dbo.nspg_GetKey
                  'PICKDETAILKEY',
                  10 ,
                  @cNewPickDetailKey OUTPUT,
                  @b_success         OUTPUT,
                  @n_err             OUTPUT,
                  @c_errmsg          OUTPUT

               IF @b_success <> 1
               BEGIN
                  SET @nErrNo = 85004
                  SET @cErrMsg = 'GetDetKeyFail'
                  GOTO RollBackTran
               END

               -- Create a new PickDetail to hold the balance
               INSERT INTO dbo.PICKDETAIL (
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
                  Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey, TaskDetailKey, 
                  QTY,
                  TrafficCop,
                  OptimizeCop,
                  Channel_ID)  --(cc01)
               SELECT
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
                  '0', DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey, TaskDetailKey, 
                  @nQTY_PD - @nPickQty, -- QTY
                  NULL, --TrafficCop,
                  '1' ,--OptimizeCop
                  Channel_ID  --(cc01)
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 85005
                  SET @cErrMsg = 'Ins PDtl Fail'
                  GOTO RollBackTran
               END

               -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  QTY = @nPickQty,
                  Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 85006
                  SET @cErrMsg = 'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  DropID = @cDropID,
                  Status = '5'
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 85007
                  SET @cErrMsg = 'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               SET @nPickQty = 0 -- Reduce balance  

               -- EventLog 
               EXEC RDT.rdt_STD_EventLog
                  @cActionType   = '3', -- Picking
                  @cUserID       = @cUserName,
                  @nMobileNo     = @nMobile,
                  @nFunctionID   = @nFunc,
                  @cFacility     = @cFacility,
                  @cStorerKey    = @cStorerKey,
                  @cLocation     = @cLoc,
                  @cDropID       = @cDropID, 
                  @cOrderKey     = @cOrderKey, 
                  @cSKU          = @cSKU,
                  @nQTY          = @nQTY_PD,
                  @cLoadKey      = @cLoadKey,
                  @cRefNo1       = @nPTLKey,   
                  @cRefNo2       = @cDeviceProfileLogKey, 
                  @cRefNo3       = @cConsigneeKey,   
                  @cRefNo4       = @cSourceKey, 
                  @cRefNo5       = @cTaskType  
               END
         END

         IF @nPickQty = 0 
         BEGIN
            BREAK -- Exit   (james04)
         END

         FETCH NEXT FROM curPD INTO @cOrderKey, @cPickDetailKey, @nQTY_PD
      END
      CLOSE curPD
      DEALLOCATE curPD

      FETCH NEXT FROM curRPL INTO @cLOC, @cSKU, @cConsigneeKey, @cDropID, @cSourceKey, @cAddWho
   END
   CLOSE curRPL
   DEALLOCATE curRPL

   -- Split PTLTRAN if Qty Picked < Expected
   IF EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK) 
               WHERE PTLKey = @nPTLKey
               AND   [Status] = '1'
               AND   ExpectedQty > @nQty) AND @bShortPick = 0  -- Not from short pick qty
   BEGIN
      SET @cRemarks =  'Spilted line from PTLKey: ' + CAST( @nPTLKey AS NVARCHAR( 5))

      INSERT INTO PTLTran
      (  DeviceID,           StorerKey,        DeviceProfileLogKey, 
         IPAddress,          DevicePosition,   [Status],
         PTL_Type,           DropID,           OrderKey,
         SKU,                LOC,              ExpectedQty,
         Qty,                Remarks,          MessageNum, 
         SourceKey,          ConsigneeKey 
      )
      SELECT 
         DeviceID,           StorerKey,        DeviceProfileLogKey,
         IPAddress,          DevicePosition,   '0' AS [Status],
         PTL_Type,           DropID,           OrderKey,
         SKU,                LOC,              ExpectedQty - @nQty AS ExpectedQty,
         Qty,                @cRemarks AS Remarks,          MessageNum,  
         @cSourceKey AS SourceKey,          ConsigneeKey
      FROM dbo.PTLTran WITH (NOLOCK)
      WHERE PTLKey = @nPTLKey
      AND   [Status] = '1'
      
      SELECT @nNewPTLKey = @@IDENTITY 

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 85008
         SET @cErrMsg = 'INS PTL FAIL'
         GOTO RollBackTran
      END
      /*
      -- Relight up the panel for remaining qty
      EXECUTE nspGetRight
         NULL, 
         @cStorerKey,
         NULL,
         'LightMode',
         @b_success             OUTPUT,
         @cLightMode            OUTPUT,
         @n_Err                 OUTPUT,
         @c_errmsg              OUTPUT
         
      IF @b_success <> 1
         GOTO RollBackTran
      */
      
      SELECT @cLightMode = Short 
      FROM dbo.CodeLKUp WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   ListName = 'LIGHTMODE'
      AND   Code = 'TOTE'

      IF ISNULL( @cLightMode, '') = ''
      BEGIN
         SET @nErrNo = 85009
         SET @cErrMsg = 'NO LIGHT MODE'
         GOTO RollBackTran
      END      

      SELECT 
         @cDeviceID = DeviceID, 
         @cDevicePosition = DevicePosition, 
         @nExpectedQty = ExpectedQty
      FROM dbo.PTLTran WITH (NOLOCK) 
      WHERE PTLKey = @nNewPTLKey
      
      SET @nErrNo = 0
      EXEC [dbo].[isp_DPC_LightUpLoc] 
         @c_StorerKey = @cStorerKey 
        ,@n_PTLKey    = @nNewPTLKey    
        ,@c_DeviceID  = @cDeviceID  
        ,@c_DevicePos = @cDevicePosition 
        ,@n_LModMode  = @cLightMode  
        ,@n_Qty       = @nExpectedQty       
        ,@b_Success   = @b_Success   OUTPUT  
        ,@n_Err       = @nErrNo      OUTPUT
        ,@c_ErrMsg    = @cErrMsg     OUTPUT

      IF @nErrNo <> 0
         GOTO RollBackTran

   END

   -- (ChewKPXX) 
   INSERT INTO TRACEINFO ( TraceName , TimeIn, Col1 ,Col2 , Col3 , Col4 , Col5 ) 
   VALUES ( 'CARTPK', GETDATE(), @cDropID, @cTaskType, @cActionFlag, @cLoadKey, '' )
   
   -- (ChewKP03) 
   -- Delete Existing WCSrouting Before Create 
   -- Insert WCSrouting
   EXEC [dbo].[ispWCSRO01]            
     @c_StorerKey     = @cStorerKey
   , @c_Facility      = @cFacility         
   , @c_ToteNo        = @cDropID          
   , @c_TaskType      = 'SPK' -- (ChewKP01)          
   , @c_ActionFlag    = 'D' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual       
   , @c_TaskDetailKey = ''
   , @c_Username      = @cUserName
   , @c_RefNo01       = @cLoadKey            
   , @c_RefNo02       = ''
   , @c_RefNo03       = ''
   , @c_RefNo04       = ''
   , @c_RefNo05       = ''
   , @b_debug         = '0'
   , @c_LangCode      = 'ENG' 
   , @n_Func          = 0        
   , @b_Success       = @b_success OUTPUT            
   , @n_ErrNo         = @nErrNo    OUTPUT          
   , @c_ErrMsg        = @cErrMSG   OUTPUT  
   
               
   -- Insert WCSrouting
   EXEC [dbo].[ispWCSRO01]            
     @c_StorerKey     = @cStorerKey
   , @c_Facility      = @cFacility         
   , @c_ToteNo        = @cDropID          
   , @c_TaskType      = 'SPK' -- (ChewKP01)          
   , @c_ActionFlag    = @cActionFlag -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual       
   , @c_TaskDetailKey = ''
   , @c_Username      = @cUserName
   , @c_RefNo01       = @cLoadKey            
   , @c_RefNo02       = ''
   , @c_RefNo03       = ''
   , @c_RefNo04       = ''
   , @c_RefNo05       = ''
   , @b_debug         = '0'
   , @c_LangCode      = 'ENG' 
   , @n_Func          = 0        
   , @b_Success       = @b_success OUTPUT            
   , @n_ErrNo         = @nErrNo    OUTPUT          
   , @c_ErrMsg        = @cErrMSG   OUTPUT  

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN PTL_Cart_ConfirmTask

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN PTL_Cart_ConfirmTask
        
END

GO