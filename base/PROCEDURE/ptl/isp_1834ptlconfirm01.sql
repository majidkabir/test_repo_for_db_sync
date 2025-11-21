SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: isp_1834PTLConfirm01                                */  
/* Copyright      : LF                                                  */  
/*                                                                      */  
/* Purpose: Insert PTLTran                                              */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 24-06-2019 1.0  YeeKung   WMS-9312 Created.                          */  
/* 05-10-2019 1.1  YeeKung   WMS-10796 Split the PTL                    */  
/************************************************************************/  
  
CREATE PROC [PTL].[isp_1834PTLConfirm01] (  
  @cDeviceIPAddress NVARCHAR(30),  
  @cDevicePosition  NVARCHAR(20),  
  @cFuncKey         NVARCHAR(2),  
  @nSerialNo        INT,  
  @cInputValue      NVARCHAR(20),  
  @nErrNo           INT OUTPUT,  
  @cErrMsg          NVARCHAR(125) OUTPUT  
 )  
AS  
BEGIN TRY  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_success                  INT  
         , @cLangCode                  NVARCHAR(5)='ENG'  
         , @nTranCount                 INT  
         , @bDebug                     INT  
         , @cOrderKey                  NVARCHAR(10)  
         , @cLoc                       NVARCHAR(10)  
         , @cLightSequence             NVARCHAR(10)  
         , @cModuleAddress             NVARCHAR(10)  
         , @cPriority                  NVARCHAR(10)  
         , @cPickSlipNo                NVARCHAR(10)  
         , @cSuggLoc                   NVARCHAR(10)  
         , @cSuggSKU                   NVARCHAR(10)  
         , @cModuleName                NVARCHAR(30)  
         , @cAlertMessage              NVARCHAR( 255)  
         , @cUOM                       NVARCHAR(10)  
         , @cPTSLoc                    NVARCHAR(10)  
         , @cPTLSKU                    NVARCHAR(20)  
         , @nExpectedQty               INT  
         , @cLightMode                 NVARCHAR(10)  
         , @cDisplayValue              NVARCHAR(5)  
         , @nCartonNo                  INT  
         , @cCaseID                    NVARCHAR(20)  
         , @cLabelNo                   NVARCHAR(20)  
         , @cPickDetailKey             NVARCHAR(10)  
         , @nPDQty                     INT  
         , @nNewPTLTranKey             INT  
         , @cUserName                  NVARCHAR(18)  
         , @cLightModeStatic           NVARCHAR(10)  
         , @cSuggUOM                   NVARCHAR(10)  
         , @cPrefUOM                   NVARCHAR(10)  
         , @cWaveKey                   NVARCHAR(10)  
         , @cDeviceProfileKey          NVARCHAR(10)  
         , @cDeviceID                  NVARCHAR(10)  
         , @cLightModeEnd              NVARCHAR(10)  
         , @cVarLightMode              NVARCHAR(10)  
         , @cLightPriority             NVARCHAR(1)  
  
         , @cHoldUserID                NVARCHAR(18)  
         , @cHoldDeviceProfileLogKey   NVARCHAR(20)  
         , @cHoldSuggSKU               NVARCHAR(20)  
         , @cHoldUOM                   NVARCHAR(10)  
         , @cPrevDevicePosition        NVARCHAR(10)  
         , @cLightModeHOLD             NVARCHAR(10)  
         , @nHoldPTLKey                INT  
         , @nVarPTLKey                 INT  
         , @cHoldCondition             NVARCHAR(1)  
         , @cSuggDevicePosition        NVARCHAR(10)  
     , @cEndCondition              NVARCHAR(1)  
         , @cLoadKey                   NVARCHAR(10)  
         , @cPTLOrderKey               NVARCHAR(10)  
         , @nActualQty                 INT  
         , @nUOMQty                    INT  
         , @cPDOrderKey                NVARCHAR(10)  
         , @nPackQty                   INT  
         , @cSuggDropID                NVARCHAR(20)  
         , @nTranCount01               INT  
         , @nNewExpectedQty            INT  
         , @nPTLTranKey                INT  
         , @nFunc                      INT  
         , @cStorerKey                 NVARCHAR(15)  
         , @cDeviceProfileLogKey       NVARCHAR(10)  
         , @cDropID                    NVARCHAR(20)  
         , @nQty                       INT  
         , @nPTLKey                    INT  
         , @bSuccess                   INT  
         , @cStatus                    NVARCHAR(5)  
         , @cHoldDeviceID              NVARCHAR(10)  
         , @cSecondaryPosition         NVARCHAR(10)  
         , @cOrgDisplayValue           NVARCHAR(5)  
         , @cLightModeColor            NVARCHAR(10)  
         , @cNewLightMode              NVARCHAR(10)  
         , @cNewPickDetailKey          NVARCHAR(10)  
         , @cRemark                    NVARCHAR(2)  
  
   SET @cLoc                        = ''  
   SET @cPTSLoc                     = ''  
   SET @cPriority                   = ''  
   SET @cPickSlipNo                 = ''  
   SET @cUOM                        = ''  
   SET @cPTSLoc                     = ''  
   SET @cAlertMessage               = ''  
   SET @cModuleName                 = ''  
   SET @cPTLSKU                     = ''  
   SET @cUOM                        = ''  
   SET @cLightMode                  = ''  
   SET @cDisplayValue               = ''  
   SET @cCaseID                     = ''  
   SET @cLabelNo                    = ''  
  
   SET @cPickDetailKey              = ''  
   SET @nPDQty                      = 0  
   SET @nNewPTLTranKey              = 0  
  
   SET @cUserName                   = ''  
   SET @cLightModeStatic            = ''  
   SET @cSuggUOM                    = ''  
   SET @cPrefUOM                    = ''  
   SET @cWaveKey                    = ''  
   SET @cDeviceProfileKey           = ''  
   SET @cDeviceID                   = ''  
   SET @cDeviceProfileLogKey        = ''  
   SET @cLightModeEnd               = ''  
   SET @cVarLightMode               = ''  
   SET @cLightPriority              = ''  
   SET @cHoldUserID                 = ''  
   SET @cHoldDeviceProfileLogKey    = ''  
   SET @cHoldSuggSKU                = ''  
   SET @cHoldUOM                    = ''  
   SET @cPrevDevicePosition         = ''  
   SET @cLightModeHOLD              = ''  
   SET @nHoldPTLKey                 = 0  
   SET @cModuleAddress              = ''  
   SET @nVarPTLKey                  = 0  
   SET @cHoldCondition              = ''  
   SET @cSuggDevicePosition         = ''  
   SET @cEndCondition               = ''  
   SET @cLoadKey                    = ''  
   SET @nActualQty                  = 0  
   SET @nUOMQty                     = 0  
   SET @cPDOrderKey                 = ''  
   SET @nPackQty                    = 0  
   SET @cOrgDisplayValue            = ''  
   SET @cPTLOrderKey                = ''  
   SET @cNewLightMode               = ''  
   SET @cNewPickDetailKey           = ''  
   SET @cRemark                     = ''  
  
   -- Get display value  
   SELECT  
      @cDeviceID = DeviceID,  
      @cOrgDisplayValue = LEFT( DisplayValue, 4),  
      @nFunc = Func  
   FROM PTL.LightStatus WITH (NOLOCK)  
   WHERE IPAddress = @cDeviceIPAddress  
      AND DevicePosition = @cDevicePosition  
  
   SELECT @cLightModeStatic = Short  
   FROM dbo.CodelKup WITH (NOLOCK)  
   WHERE ListName = 'LightMode'  
      AND Code = 'White'  
  
   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN PackInsert  
  
   IF @cInputValue = 'FULL'  
   BEGIN  
      GOTO QUIT  
   END  
   ELSE IF @cInputValue = 'HOLD' -- IN00028515  
   BEGIN  
      GOTO QUIT  
   END  
   ELSE IF @cInputValue = 'END' -- IN00028515  
   BEGIN  
      GOTO QUIT  
   END  
   ELSE  
   BEGIN  
      SET @nQty = RIGHT(@cInputValue , 3)     --CAST(@cInputValue AS INT)  
   END  
  
   -- If Quantity = 0 Terminate all the Light , and Go to UpdateDropID  
   SELECT TOP 1 @cPTSLoc               = PTL.DeviceID  
               ,@cPTLSKU               = PTL.SKU  
               ,@nExpectedQty          = PTL.ExpectedQty  
               ,@cLightSequence        = PTL.LightSequence  
               ,@cOrderKey             = PTL.OrderKey  
               ,@cDropID               = PTL.DropID  
               ,@cLightMode            = PTL.LightMode  
               ,@cUOM                  = PTL.UOM  
               ,@cWaveKey              = PTL.SourceKey  
               ,@cDeviceProfileLogKey  = PTL.DeviceProfileLogKey  
               ,@cUserName             = PTL.AddWho  
               ,@cLoc                  = PTL.Loc  
               ,@nPTLKey               = PTL.PTLKey  
               ,@cStorerKey            = PTL.StorerKey  
   FROM PTL.PTLTran PTL WITH (NOLOCK)  
   WHERE IPAddress = @cDeviceIPAddress  
      AND DevicePosition = @cDevicePosition  
      AND Status = '1'  
   Order By PTLKey  
  
   --SELECT Defaultcolor from rdt.rdtuser where username=@cUserName  
  
   SELECT @nFunc = Func  
   FROM PTL.LightStatus WITH (NOLOCK)  
   WHERE IPAddress = @cDeviceIPAddress  
      AND DevicePosition = @cDevicePosition  
  
   IF @@ROWCOUNT = 0  
   BEGIN  
      GOTO RollBackTran  
   END  
  
   IF ISNULL(@nPTLKey,0 ) = 0  
   BEGIN  
      SET @nErrNo = 141151  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PTLKeyNotFound'  
      GOTO RollBackTran  
   END  
  
   IF @nQty > @nExpectedQty  
   BEGIN  
      SET @nErrNo = 141152  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'QtyExceed'  
      GOTO RollBackTran  
   END  
  
   SET @nActualQty = @nQty  
  
   SELECT   @cCaseID = PTL.CaseID,  
            @cPTLOrderKey = PTL.OrderKey  
   FROM PTL.PTLTran PTL WITH (NOLOCK)  
   WHERE PTL.PTLKey = @nPTLKey  
   AND   PTL.Status = '1'  
  
   -- Update PickDetail.CaseID = LabelNo, Split Line if there is Short Pick and Create PackDetail  
   DECLARE CursorPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT  PD.PickDetailKey, PD.Qty, PD.OrderKey, PD.CaseID  
   FROM dbo.Pickdetail PD WITH (NOLOCK)  
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey  
      INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON OD.OrderKey = O.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber  
   WHERE PD.DropID = @cDropID  
      AND PD.Status = '5'  
      AND PD.SKU    = @cPTLSKU  
      --AND ISNULL(PD.CaseID,'')  = ''  
      AND PD.UOM = @cUOM  
      AND PD.Qty > 0  
      AND O.Orderkey = @cPTLOrderKey  
   ORDER BY PD.SKU  
  
   OPEN  CursorPickDetail  
   FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty, @cPDOrderKey, @cLabelNo  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      IF ISNULL(@cLabelNo,'' )  = ''  
      BEGIN  
         IF @nPDQty=@nActualQty  
         BEGIN  
            -- Confirm PickDetail  
            UPDATE dbo.PickDetail WITH (ROWLOCK)  
               SET CaseID = 'Sorted'  
                  , DropID = @cCaseID  
                  , EditDate = GetDate()  
                  , EditWho  = suser_sname()  
                  --, UOMQty   = @nQty  
                  , Trafficcop = NULL  
            WHERE  PickDetailKey = @cPickDetailKey  
            AND Status = '5'  
  
            SET @nErrNo = @@ERROR  
            IF @nErrNo <> 0  
            BEGIN  
               SET @nErrNo = 141153  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPDFail'  
               GOTO RollBackTran  
            END  
         END  
         ELSE IF @nActualQty > @nPDQty  
         BEGIN  
            -- Confirm PickDetail  
            UPDATE dbo.PickDetail WITH (ROWLOCK)  
            SET CaseID = 'Sorted'  
               , DropID = @cCaseID  
               , EditDate = GetDate()  
               --, UOMQty   = @nQty  
               , Trafficcop = NULL  
            WHERE  PickDetailKey = @cPickDetailKey  
            AND Status = '5'  
  
            SET @nErrNo = @@ERROR  
            IF @nErrNo <> 0  
            BEGIN  
               SET @nErrNo = 141154  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPDFail'  
               GOTO RollBackTran  
            END  
         END  
         ELSE  
         IF @nActualQty < @nPDQty AND @nActualQty > 0  
         BEGIN  
            IF @nActualQty > 0  
            BEGIN  
               EXECUTE dbo.nspg_GetKey  
                     'PICKDETAILKEY',  
                     10 ,  
                     @cNewPickDetailKey OUTPUT,  
                     @b_success         OUTPUT,  
                     @nErrNo            OUTPUT,  
                     @cErrMsg           OUTPUT  
  
               IF @b_success<>1  
               BEGIN  
                  SET @nErrNo = 141155  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GetPDKFail'  
                  GOTO RollBackTran  
               END  
  
               -- Create a new PickDetail to hold the balance  
               INSERT INTO dbo.PICKDETAIL (  
                  CaseID                  ,PickHeaderKey   ,OrderKey  
                  ,OrderLineNumber         ,LOT             ,StorerKey  
                  ,SKU                     ,AltSKU          ,UOM  
                  ,UOMQTY                  ,QTYMoved        ,STATUS  
                  ,DropID                  ,LOC             ,ID  
                  ,PackKey                 ,UpdateSource    ,CartonGroup  
                  ,CartonType              ,ToLoc           ,DoReplenish  
                  ,ReplenishZone           ,DoCartonize     ,PickMethod  
                  ,WaveKey                 ,EffectiveDate   ,ArchiveCop  
                  ,ShipFlag                ,PickSlipNo      ,PickDetailKey  
                  ,QTY                     ,TrafficCop      ,OptimizeCop  
                  ,TaskDetailkey  
                  )  
               SELECT  CaseID               ,PickHeaderKey   ,OrderKey  
                     ,OrderLineNumber      ,Lot             ,StorerKey  
                     ,SKU                  ,AltSku          ,UOM  
                     ,UOMQTY               ,QTYMoved        ,Status  
                     ,DropID               ,LOC             ,ID  
                     ,PackKey              ,UpdateSource    ,CartonGroup  
                     ,CartonType           ,ToLoc           ,DoReplenish  
                     ,ReplenishZone        ,DoCartonize     ,PickMethod  
                     ,WaveKey              ,EffectiveDate ,ArchiveCop  
                     ,ShipFlag             ,PickSlipNo      ,@cNewPickDetailKey  
                     ,@nPDQty - @nActualQty,NULL            ,'1'  --OptimizeCop,  
                     ,TaskDetailKey  
               FROM   dbo.PickDetail WITH (NOLOCK)  
               WHERE  PickDetailKey = @cPickDetailKey  
  
               IF @nErrNo <> 0  
               BEGIN  
                  SET @nErrNo = 141156  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INSPDFail'  
                  GOTO RollBackTran  
               END  
  
               -- Insert Primary PTL Record --  
               INSERT INTO PTL.PTLTran  
               (  
                  -- PTLKey -- this column value is auto-generated  
                  IPAddress,  DeviceID,     DevicePosition,  
                  [Status],   PTLType,     DropID,  
                  OrderKey,   Storerkey,    SKU,  
                  LOC,        ExpectedQty,  Qty,  
                  Remarks,    Lot,  
                  DeviceProfileLogKey, SourceKey, ConsigneeKey,  
                  CaseID,     LightMode,    LightSequence, UOM,  
                  AddWho  
  
               )  
              SELECT  IPAddress            ,DeviceID              ,DevicePosition  
                     ,'0'                  ,PTLType               ,DropID  
                     ,OrderKey             ,Storerkey             ,SKU  
                     ,LOC                  ,@nPDQty - @nActualQty ,0  
                     ,Remarks              ,Lot  
                     ,DeviceProfileLogKey  ,SourceKey             ,ConsigneeKey  
                     ,CaseID               ,LightMode             ,LightSequence  
                     ,UOM                  ,AddWho  
               FROM   PTL.PTLTRAN WITH (NOLOCK)  
               WHERE  PTLKey = @nPTLKey  
  
               IF @nErrNo <> 0  
               BEGIN  
                  SET @nErrNo = 141157  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPTLTranFail'  
                  GOTO RollBackTran  
               END  
  
               -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop  
               -- Change orginal PickDetail with exact QTY (with TrafficCop)  
               UPDATE dbo.PickDetail WITH (ROWLOCK)  
               SET    QTY = @nActualQty  
                     ,CaseID = 'Sorted'  
                     , DropID = @cCaseID  
                     , EditDate = GetDate()  
                     , EditWho  = suser_sname()  
                     , UOMQty   = @nQty  
                     , Trafficcop = NULL  
               WHERE  PickDetailKey = @cPickDetailKey  
               AND Status = '5'  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 141158  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPDFail'  
                  GOTO RollBackTran  
               END  
  
               -- Change orginal PickDetail with exact QTY (with TrafficCop)  
               UPDATE PTL.PTLTran WITH (ROWLOCK)  
               SET    ExpectedQty = @nActualQty  
                     , EditDate = GetDate()  
                     , EditWho  = suser_sname()  
               WHERE  PTLKey = @nPTLKey  
               AND Status = '1'  
  
               IF @@ERROR <> 0  
               BEGIN  
                  SET @nErrNo = 141159  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLTranFail'  
                  GOTO RollBackTran  
               END  
               BREAK;  
            END  
         END -- @nActualQty < @nPDQty  
         ELSE IF @nActualQty = 0  
         BEGIN  
            UPDATE dbo.PickDetail WITH (ROWLOCK)  
            SET    Status = '4'  
                  , EditDate = GetDate()  
                  , EditWho  = suser_sname()  
                  --, Trafficcop = NULL (ChewKP02)  
            WHERE  PickDetailKey = @cPickDetailKey  
            AND Status = '5'  
  
            IF @nErrNo <> 0  
            BEGIN  
               SET @nErrNo = 141160  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPDFail'  
               GOTO RollBackTran  
            END  
         END -- IF @nActualQty = 0  
      END  
      FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPDQty, @cPDOrderKey, @cLabelNo  
   END -- While Loop  
   CLOSE CursorPickDetail  
   DEALLOCATE CursorPickDetail  
  
   UPDATE PTL.PTLTRAN WITH (ROWLOCK)  
   SET   STATUS  = '9',  
         Qty = @nQty,  
         EditDate = GETDATE(),  
         EditWho = SUSER_SNAME()  
   WHERE PTLKey = @nPTLKey  
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 141161  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPTLTranFail'  
      GOTO RollBackTran  
   END  
  
   -- If Same Location have more SKU to be PTS  
   IF EXISTS ( SELECT 1 FROM PTL.PTLTran PTL WITH (NOLOCK)  
               WHERE PTL.DeviceProfileLogKey =  @cDeviceProfileLogKey  
                  AND PTL.Status = '0'  
                  AND PTL.DeviceID = @cPTSLoc  
                  AND PTL.StorerKey  = @cStorerKey  )  
   BEGIN  
  
      SELECT TOP 1  
                  @cSuggSKU       = PTL.SKU  
                 ,@cSuggUOM       = PTL.UOM  
                  ,@nNewExpectedQty = PTL.ExpectedQty  
                  ,@cDropID         = PTL.DropID  
      FROM PTL.PTLTran PTL WITH (NOLOCK)  
      INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON PTL.DeviceID = D.DeviceID AND PTL.StorerKey = D.StorerKey  
      WHERE PTL.DeviceProfileLogKey =  @cDeviceProfileLogKey  
         AND D.Priority = '1'  
         AND PTL.Status = '0'  
         AND PTL.DeviceID = @cPTSLoc  
         AND D.StorerKey  = @cStorerKey  
      Order by D.DeviceID,PTL.Remarks, PTL.SKU  
  
      SELECT @cSuggDevicePosition = DevicePosition  
      FROM dbo.DeviceProfile WITH (NOLOCK)  
      WHERE DeviceID = @cSuggLoc  
         AND Priority = '1'  
         AND StorerKey = @cStorerKey  
  
      DECLARE CursorLightUp CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
  
      SELECT PTLKey, DevicePosition, LightMode,Remarks  
      FROM PTL.PTLTran PTL WITH (NOLOCK)  
      WHERE PTL.Status              = '0'  
         AND PTL.AddWho             = @cUserName  
         AND DeviceID               = @cPTSLoc  
         AND SKU                    = @cSuggSKU  
         AND UOM                    = @cSuggUOM  
         AND DeviceProfileLogKey    = @cDeviceProfileLogKey  
         AND Dropid                 = @cDropID  
      ORDER BY DeviceID, PTLKey  
  
      SELECT @cLightModeColor = Code  
      FROM dbo.CodeLkup WITH (NOLOCK)  
      WHERE ListName = 'LIGHTMODE'  
         AND Short = @cLightMode  
         AND Code <> 'White'  
  
      OPEN CursorLightUp  
      FETCH NEXT FROM CursorLightUp INTO @nVarPTLKey, @cModuleAddress, @cLightMode,@cRemark  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         IF EXISTS ( SELECT 1 FROM dbo.DeviceProfile WITH (NOLOCK)  
                     WHERE DeviceID = @cPTSLoc  
                     AND DevicePosition = @cModuleAddress  
                     AND Priority = '0'  
                     AND StorerKey = @cStorerKey )  
         BEGIN  
            IF @nNewExpectedQty <=9  
               SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+'  '+CAST(@nNewExpectedQty AS NVARCHAR(3))  
            ELSE IF @nNewExpectedQty >=10 AND @nNewExpectedQty<=99  
               SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+' '+CAST(@nNewExpectedQty AS NVARCHAR(3))  
            ELSE IF @nNewExpectedQty >=100  
               SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+CAST(@nNewExpectedQty AS NVARCHAR(3))  
         END  
         ELSE  
         BEGIN  
            IF @nNewExpectedQty <=9  
               SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+'  '+CAST(@nNewExpectedQty AS NVARCHAR(3))  
            ELSE IF @nNewExpectedQty >=10 AND @nNewExpectedQty<=99  
               SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+' '+CAST(@nNewExpectedQty AS NVARCHAR(3))  
            ELSE IF @nNewExpectedQty >=100  
               SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+CAST(@nNewExpectedQty AS NVARCHAR(3))  
         END  
  
         EXEC [ptl].[isp_PTL_LightUpLoc]  
                  @n_Func         = @nFunc  
                  ,@n_PTLKey       = @nVarPTLKey  
                  ,@c_DisplayValue = @cDisplayValue  
                  ,@b_Success      = @bSuccess    OUTPUT  
                  ,@n_Err          = @nErrNo      OUTPUT  
                  ,@c_ErrMsg       = @cErrMsg     OUTPUT  
                  ,@c_ForceColor   = '' --@c_ForceColor  
                  ,@c_DeviceProLogKey = @cDeviceProfileLogKey  
  
         IF @nErrNo <> 0  
         BEGIN  
            SET @nErrNo = 141162  
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'LightUpFail'  
            GOTO RollBackTran  
         END  
  
         EXEC [PTL].[isp_PTL_TVLightUp]  
            @n_Func              = @nFunc  
            ,@n_PTLKey           = @nVarPTLKey  
            ,@b_Success          = @b_success   OUTPUT  
            ,@n_Err              = @nErrNo      OUTPUT  
            ,@c_ErrMsg           = @cErrMsg     OUTPUT  
            ,@c_DeviceID         = ''  
            ,@cLightModeColor    = @cLightModeColor  
            ,@c_InputType        = ''  
  
  
      FETCH NEXT FROM CursorLightUp INTO @nVarPTLKey, @cModuleAddress, @cLightMode,@cRemark  
      END  
      CLOSE CursorLightUp  
      DEALLOCATE CursorLightUp  
  
      GOTO QUIT  
   END  
   ELSE -- Task for Next Location  
   BEGIN  
  
      -- Unlock Current User --  
      EXEC [dbo].[isp_LightUpLocCheck]  
         @nPTLKey                = 0  
         ,@cStorerKey             = @cStorerKey  
         ,@cDeviceProfileLogKey   = ''  
         ,@cLoc                   = @cPTSLoc  
         ,@cType                  = 'UNLOCK'  
         ,@nErrNo                 = @nErrNo               OUTPUT  
         ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max  
      IF @nErrNo <> 0  
      BEGIN  
         SET @nErrNo = 141178  
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdLocklocFail'  
         GOTO RollBackTran  
      END  
  
      IF NOT EXISTS( SELECT 1 FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND CaseID <> 'SORTED')  
      BEGIN  
         SET @cLightModeEnd = rdt.RDTGetConfig( @nFunc, 'LightModeEnd', @cStorerKey)  
  
         EXEC PTL.isp_PTL_LightUpLoc  
            @n_Func           = @nFunc  
            ,@n_PTLKey         = 0  
            ,@c_DisplayValue   = 'End'  
            ,@b_Success        = @bSuccess    OUTPUT  
            ,@n_Err            = @nErrNo      OUTPUT  
            ,@c_ErrMsg         = @cErrMsg     OUTPUT  
            ,@c_DeviceID       = @cPTSLoc  
            ,@c_DevicePos      = @cDevicePosition  
            ,@c_DeviceIP       = @cDeviceIPAddress  
            ,@c_LModMode       = @cLightModeEnd  
  
         IF @nErrNo <> 0  
         BEGIN  
            SET @nErrNo = 141163  
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'LightUpFail'  
            GOTO RollBackTran  
         END  
  
         UPDATE dbo.dropid with (rowlock)  
         set status='9'  
         , EditDate = GetDate()  
         , EditWho  = suser_sname()  
         where dropid=@cCaseID  
  
         IF @nErrNo <> 0  
         BEGIN  
            SET @nErrNo = 141164  
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDpIDFail'  
            GOTO RollBackTran  
         END  
  
         UPDATE DBO.ORDERTOLOCDETAIL WITH (ROWLOCK)  
         SET STATUS=9  
         , EditDate = GetDate()  
         , EditWho  = suser_sname()  
         WHERE ORDERKEY=  @cOrderKey AND WAVEKEY=   @cWaveKey  
  
         IF @nErrNo <> 0  
         BEGIN  
            SET @nErrNo = 141165  
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdOTLFail'  
            GOTO RollBackTran  
         END  
  
         UPDATE dbo.DeviceProfileLog with (rowlock)  
         set status='9'  
         where dropid=@cCaseID  
  
         IF @nErrNo <> 0  
         BEGIN  
            SET @nErrNo = 141166  
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdDPLLog'  
            GOTO RollBackTran  
         END  
  
      END  
  
  
      SELECT TOP 1            @cSuggLoc         = D.DeviceID  
                              ,@cSuggSKU        = PTL.SKU  
                              ,@cSuggUOM        = PTL.UOM  
                              ,@nNewPTLTranKey  = PTL.PTLKey  
                              ,@cSuggDropID     = PTL.DropID  
                              ,@nNewExpectedQty = PTL.ExpectedQty  
                              ,@cNewLightMode   = PTL.LightMode  
                              ,@cRemark         = PTL.Remarks  
                              --,@cSuggDevicePosition = PTL.DevicePosition  
      FROM PTL.PTLTran PTL WITH (NOLOCK)  
      INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON PTL.DeviceID = D.DeviceID AND PTL.StorerKey = D.StorerKey  
      WHERE PTL.DeviceProfileLogKey =  @cDeviceProfileLogKey  
         AND D.Priority = '1'  
         AND PTL.Status = '0'  
         AND PTL.StorerKey = @cStorerKey  
      Order by PTL.LOC,D.DeviceID,PTL.Remarks, PTL.SKU  
  
      SELECT @cSuggDevicePosition = DevicePosition  
      FROM dbo.DeviceProfile WITH (NOLOCK)  
      WHERE DeviceID = @cSuggLoc  
         AND Priority = '1'  
         AND StorerKey = @cStorerKey  
  
      IF (ISNULL(@cSuggLoc,'')<>'')  
      BEGIN  
         EXEC [dbo].[isp_LightUpLocCheck]  
               @nPTLKey                = @nPTLKey  
               ,@cStorerKey             = @cStorerKey  
               ,@cDeviceProfileLogKey   = @cDeviceProfileLogKey  
               ,@cLoc                   = @cSuggLoc  
               ,@cType                  = 'LOCK'  
               ,@nErrNo                 = @nErrNo               OUTPUT  
               ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max  
         IF @nErrNo <> 0  
         BEGIN  
  
            EXEC [dbo].[isp_LightUpLocCheck]  
            @nPTLKey                 = @nPTLKey  
            ,@cStorerKey             = @cStorerKey  
            ,@cDeviceProfileLogKey   = @cDeviceProfileLogKey  
            ,@cLoc                   = @cPTSLOC  
            ,@cType                  = 'LOCK'  
            ,@nErrNo                 = @nErrNo OUTPUT  
            ,@cErrMsg                = @cErrMsg    OUTPUT -- screen limitation, 20 char max  
  
            EXEC [dbo].[isp_LightUpLocCheck]  
               @nPTLKey                = @nPTLKey  
               ,@cStorerKey             = @cStorerKey  
               ,@cDeviceProfileLogKey   = @cDeviceProfileLogKey  
               ,@cLoc                   = @cPTSLOC  
               ,@cType                  = 'HOLD'  
               ,@nErrNo                 = @nErrNo               OUTPUT  
               ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max  
               ,@cNextLoc               = @cSuggLoc  
               ,@cLockType              = 'HOLD'  
  
            SELECT @cLightModeColor = Code  
            FROM dbo.CodeLkup WITH (NOLOCK)  
            WHERE ListName = 'LiGHTMODE'  
               AND Short = @cLightMode  
               AND Code <> 'White'  
  
            EXEC [PTL].[isp_PTL_TVLightUp]  
               @n_Func              = @nFunc  
               ,@n_PTLKey           = @nNewPTLTranKey  
               ,@b_Success          = @b_success   OUTPUT  
               ,@n_Err              = @nErrNo      OUTPUT  
               ,@c_ErrMsg           = @cErrMsg     OUTPUT  
               ,@c_DeviceID         = ''  
               ,@cLightModeColor    = @cLightModeColor  
               ,@c_InputType        = 'HOLD'  
  
            --IF @nErrNo <> 0  
            --BEGIN  
            --   SET @nErrNo = 141169  
            --   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'TVLightUpFail'  
            --   GOTO RollBackTran  
            --END  
         END  
         ELSE  
         BEGIN  
  
            SELECT @cModuleAddress = DevicePosition  
            FROM dbo.DeviceProfile WITH (NOLOCK)  
            WHERE DeviceID           = @cPTSLoc  
               AND StorerKey          = @cStorerKey  
               AND Priority           = '1'  
            ORDER BY DeviceID  
  
            SELECT @cPrefUOM = Short  
            FROM dbo.CodeLkup WITH (NOLOCK)  
            WHERE ListName = 'LightUOM'  
               AND Code = @cSuggUOM  
  
            SELECT @cLightModeColor = Code  
            FROM dbo.CodeLkup WITH (NOLOCK)  
            WHERE ListName = 'LiGHTMODE'  
               AND Short = @cLightMode  
               AND Code <> 'White'  
  
            IF @nNewExpectedQty <=9  
               SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+'  '+CAST(@nNewExpectedQty AS NVARCHAR(3))  
            ELSE IF @nNewExpectedQty >=10 AND @nNewExpectedQty<=99  
               SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+' '+CAST(@nNewExpectedQty AS NVARCHAR(3))  
            ELSE IF @nNewExpectedQty >=100  
               SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+CAST(@nNewExpectedQty AS NVARCHAR(3))  
  
            --SET @cVarLightMode = @cLightMode  
            SET @cLightPriority = '1'  
  
            -- Display Next Location  --  
            EXEC [ptl].[isp_PTL_LightUpLoc]  
          @n_Func         = @nFunc  
                  ,@n_PTLKey       = @nNewPTLTranKey  
                  ,@c_DisplayValue = @cDisplayValue  
                  ,@b_Success      = @bSuccess    OUTPUT  
                  ,@n_Err          = @nErrNo      OUTPUT  
                  ,@c_ErrMsg       = @cErrMsg     OUTPUT  
                  ,@c_ForceColor   = '' --@c_ForceColor  
                  ,@c_DeviceID     = @cSuggLoc  
                  ,@c_DevicePos    = @cSuggDevicePosition  
                  ,@c_DeviceIP     = @cDeviceIPAddress  
                  ,@c_LModMode     = @cNewLightMode  
                  ,@c_DeviceProLogKey = @cDeviceProfileLogKey  
            IF @nErrNo <> 0  
            BEGIN  
               SET @nErrNo = 141167  
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'LightUpFail'  
               GOTO RollBackTran  
            END  
  
            SELECT @cLightModeColor = Code  
            FROM dbo.CodeLkup WITH (NOLOCK)  
            WHERE ListName = 'LiGHTMODE'  
            AND Short = @cNewLightMode  
            AND Code <> 'White'  
  
            EXEC [PTL].[isp_PTL_TVLightUp]  
               @n_Func              = @nFunc  
               ,@n_PTLKey           = @nNewPTLTranKey  
               ,@b_Success          = @b_success   OUTPUT  
               ,@n_Err              = @nErrNo      OUTPUT  
               ,@c_ErrMsg           = @cErrMsg     OUTPUT  
               ,@c_DeviceID         = ''  
               ,@cLightModeColor    = @cLightModeColor  
               ,@c_InputType        = ' '  
  
            --IF @nErrNo <> 0  
            --BEGIN  
            --   SET @nErrNo = 141168  
            --   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'TVLightUpFail'  
            --   GOTO RollBackTran  
            --END  
  
            --GOTO  PROCESS_HOLD_LOC  
            IF EXISTS( SELECT 1 FROM dbo.PTLLockLoc WITH (NOLOCK)  
               WHERE LockType = 'HOLD'  
                     AND NextLoc = @cPTSLoc )  
            BEGIN  
               GOTO PROCESS_HOLD_LOC  
            END  
  
         END  
      END  
      ELSE IF EXISTS( SELECT 1 FROM dbo.PTLLockLoc WITH (NOLOCK)  
               WHERE LockType = 'HOLD'  
                     AND NextLoc = @cPTSLoc )  
      BEGIN  
  
         EXEC [PTL].[isp_PTL_TVLightUp]  
         @n_Func              = @nFunc  
         ,@n_PTLKey           = @nPTLKey  
         ,@b_Success  = @b_success   OUTPUT  
         ,@n_Err              = @nErrNo      OUTPUT  
         ,@c_ErrMsg           = @cErrMsg     OUTPUT  
         ,@c_DeviceID         = ''  
         ,@cLightModeColor    = 'black'  
         ,@c_InputType        = ' '  
  
         --IF @nErrNo <> 0  
         --BEGIN  
         --   SET @nErrNo = 141170  
         --   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'TVLightUpFail'  
         --   GOTO RollBackTran  
         --END  
  
         GOTO PROCESS_HOLD_LOC  
      END  
      ELSE  
      BEGIN  
          EXEC [PTL].[isp_PTL_TVLightUp]  
               @n_Func              = @nFunc  
               ,@n_PTLKey           = @nPTLKey  
               ,@b_Success          = @b_success   OUTPUT  
               ,@n_Err              = @nErrNo      OUTPUT  
               ,@c_ErrMsg           = @cErrMsg     OUTPUT  
               ,@c_DeviceID         = ''  
               ,@cLightModeColor    = 'BLACK'  
               ,@c_InputType        = ' '  
  
         --IF @nErrNo <> 0  
         --BEGIN  
         --   SET @nErrNo = 141171  
         --   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'TVLightUpFail'  
         --   GOTO RollBackTran  
         --END  
      END  
   END  
   GOTO QUIT  
  
   PROCESS_HOLD_LOC:  
   BEGIN  
  
      SELECT TOP 1 @cHoldUserID = AddWho  
            ,@cPrevDevicePosition = DevicePosition  
            ,@cHoldDeviceID = DeviceID  
      FROM dbo.PTLLockLoc WITH (NOLOCK)  
      WHERE LockType = 'HOLD'  
      AND NextLoc = @cPTSLoc  
      ORDER BY PTLLockLocKey  
  
      --SELECT TOP 1  --@cHoldUserID = AddWho  
      --              @cHoldDeviceProfileLogKey = PTL.DeviceProfileLogKey  
      --            --, @cHoldSuggSKU = SKU  
   --            --, @cHoldUOM     = UOM  
      --            --, @cPrevDevicePosition = PTL.DevicePosition  
      --            --, @cHoldConsigneeKey = PTL.ConsigneeKey  
      --            , @nHoldPTLKey  = PTLKey  
      --FROM PTL.PTLTran PTL WITH (NOLOCK)  
      --INNER JOIN dbo.DeviceProfile DP ON DP.DeviceID = PTL.DeviceID  
      --WHERE PTL.DeviceID = @cPTSLoc  
      --AND PTL.LightSequence = '1'  
      --AND PTL.AddWho = @cHoldUserID -- PTLLockLOC.AddWho could be diff from PTLTran.AddHo  
      --AND PTL.Status = '0'  
      --AND DP.Priority = '1'  
      --Order By PTL.DeviceProfileLogKey  
  
      SELECT TOP 1    @cSuggLoc       = D.DeviceID  
                     ,@cSuggSKU       = PTL.SKU  
                     ,@cSuggUOM       = PTL.UOM  
                     ,@cSuggDevicePosition = PTL.DevicePosition  
                     ,@nNewPTLTranKey = PTL.PTLKey  
                     ,@cSuggDropID    = PTL.DropID  
                     ,@nNewExpectedQty = PTL.ExpectedQty  
                     ,@cNewLightMode   = PTL.LightMode  
                     ,@cHoldDeviceProfileLogKey = PTL.DeviceProfileLogKey  
                     ,@cRemark         = PTL.Remarks  
                     --,@cSuggDevicePosition = PTL.DevicePosition  
      FROM PTL.PTLTran PTL WITH (NOLOCK)  
      INNER JOIN dbo.DeviceProfile D WITH (NOLOCK) ON PTL.DeviceID = D.DeviceID AND PTL.StorerKey = D.StorerKey  
      WHERE  PTL.AddWho = @cHoldUserID -- PTLLockLOC.AddWho could be diff from PTLTran.AddHo  
      AND D.Priority = '1'  
      AND PTL.Status = '0'  
      AND PTL.StorerKey = @cStorerKey  
      Order by PTL.LOC, D.DeviceID,PTL.Remarks, PTL.SKU  
  
      IF ISNULL(@cHoldDeviceProfileLogKey,'')  <> ''  
      BEGIN  
         SELECT @cLightModeHOLD = DefaultLightColor  
         FROM rdt.rdtUser WITH (NOLOCK)  
         WHERE UserName = ISNULL(RTRIM(@cHoldUserID),'')  
  
         -- Unlock Current User --  
         EXEC [dbo].[isp_LightUpLocCheck]  
            @nPTLKey                = 0  
            ,@cStorerKey             = @cStorerKey  
            ,@cDeviceProfileLogKey   = ''  
            ,@cLoc                   = @cHoldDeviceID  
            ,@cType                  = 'UNLOCK'  
            ,@nErrNo                 = @nErrNo               OUTPUT  
            ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max  
         IF @nErrNo <> 0  
         BEGIN  
            SET @nErrNo = 141175  
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdLocklocFail'  
            GOTO RollBackTran  
         END  
  
         -- Lock Next User --  
         EXEC [dbo].[isp_LightUpLocCheck]  
            @nPTLKey                = @nNewPTLTranKey  
            ,@cStorerKey             = @cStorerKey  
            ,@cDeviceProfileLogKey   = ''  
            ,@cLoc                   = @cPTSLoc  
            ,@cType                  = 'LOCK'  
            ,@nErrNo                 = @nErrNo               OUTPUT  
            ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max  
         IF @nErrNo <> 0  
         BEGIN  
            SET @nErrNo = 141176  
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdLocklocFail'  
            GOTO RollBackTran  
         END  
  
         --EXEC PTL.isp_PTL_TerminateModule  
         --       @cStorerKey  
         --      ,@nFunc  
         --      ,@cHoldDeviceID  
         --      ,'1' -- Terminate by DeviceID  
         --      ,@bSuccess    OUTPUT  
         --      ,@nErrNo      OUTPUT  
         --      ,@cErrMsg     OUTPUT  
         --IF @nErrNo <> 0  
         --BEGIN  
         --   SET @nErrNo = 141172  
         --   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'TmntLgtFail'  
         --   GOTO RollBackTran  
         --END  
         IF @nNewExpectedQty <=9  
            SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+'  '+CAST(@nNewExpectedQty AS NVARCHAR(3))  
         ELSE IF @nNewExpectedQty >=10 AND @nNewExpectedQty<=99  
            SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+' '+CAST(@nNewExpectedQty AS NVARCHAR(3))  
         ELSE IF @nNewExpectedQty >=100  
            SET @cDisplayValue= CAST(@cRemark AS NVARCHAR(1))+CAST(@nNewExpectedQty AS NVARCHAR(3))  
         --SET @cVarLightMode = @cLightMode  
         SET @cLightPriority = '1'  
  
         -- Display Next Location  --  
         EXEC [ptl].[isp_PTL_LightUpLoc]  
               @n_Func         = @nFunc  
               ,@n_PTLKey       = @nNewPTLTranKey  
               ,@c_DisplayValue = @cDisplayValue  
               ,@b_Success      = @bSuccess    OUTPUT  
               ,@n_Err          = @nErrNo      OUTPUT  
               ,@c_ErrMsg       = @cErrMsg     OUTPUT  
               ,@c_ForceColor   = '' --@c_ForceColor  
               ,@c_DeviceID     = @cSuggLoc  
               ,@c_DevicePos    = @cSuggDevicePosition  
               ,@c_DeviceIP     = @cDeviceIPAddress  
               ,@c_LModMode     = @cNewLightMode  
               ,@c_DeviceProLogKey = @cHoldDeviceProfileLogKey  
  
         IF @nErrNo <> 0  
         BEGIN  
            SET @nErrNo = 141173  
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'LightUpFail'  
            GOTO RollBackTran  
         END  
  
         SELECT @cLightModeColor = Code  
         FROM dbo.CodeLkup WITH (NOLOCK)  
         WHERE ListName = 'LiGHTMODE'  
            AND Short = @cNewLightMode  
            AND Code <> 'White'  
  
         EXEC [PTL].[isp_PTL_TVLightUp]  
            @n_Func              = @nFunc  
            ,@n_PTLKey           = @nNewPTLTranKey  
            ,@b_Success          = @b_success   OUTPUT  
            ,@n_Err              = @nErrNo      OUTPUT  
            ,@c_ErrMsg           = @cErrMsg     OUTPUT  
            ,@c_DeviceID         = ''  
            ,@cLightModeColor    = @cLightModeColor  
            ,@c_InputType        = ' '  
  
         --IF @nErrNo <> 0  
         --BEGIN  
         --   SET @nErrNo = 141174  
         --   SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'TVLightUpFail'  
         --   GOTO RollBackTran  
         --END  
  
         END  
      ELSE  
      BEGIN  
         -- Unlock Current User --  
         EXEC [dbo].[isp_LightUpLocCheck]  
            @nPTLKey                = 0  
            ,@cStorerKey             = @cStorerKey  
            ,@cDeviceProfileLogKey   = ''  
            ,@cLoc                   = @cPTSLoc  
            ,@cType                  = 'UNLOCK'  
            ,@nErrNo                 = @nErrNo               OUTPUT  
            ,@cErrMsg                = @cErrMsg              OUTPUT -- screen limitation, 20 char max  
         IF @nErrNo <> 0  
         BEGIN  
            SET @nErrNo = 141177  
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UpdLocklocFail'  
            GOTO RollBackTran  
         END  
      END  
   END  
  
  
   COMMIT TRAN PackInsert  
   GOTO QUIT  
  
   RollBackTran:  
   ROLLBACK TRAN PackInsert  
  
   -- Raise error to go to catch block  
   RAISERROR ('', 16, 1) WITH SETERROR  
  
END TRY  
BEGIN CATCH  
   -- Check error that cause trans become uncommitable, that need to rollback  
   IF XACT_STATE() = -1  
      ROLLBACK TRAN  
  
  
   -- Update Error Message Back to PTL.LightInput  
   --UPDATE PTL.LightInput WITH (ROWLOCK) SET  
   --   ErrorMessage = CAST(@nErrNo AS NVARCHAR(5))  + '-' +  @cErrMsg  
   --WHERE DevicePosition = @cDeviceIPAddress  
   --AND IPAddress = @cDevicePosition  
  
  
  
   INSERT INTO TraceInfo (TraceName, TimeIn, step1, Step2, step3, step4, step5, Col1, Col2, Col3, Col4, col5)  
   VALUES  
   (  
     'isp_1834PTLConfirm01 CATCH',                         -- TraceName  
      GETDATE(),           -- TimeIn  
      CAST( @nErrNo AS NVARCHAR( 5)),                       -- Step1  
      SUBSTRING( @cErrMsg, 1, 20),                          -- Step2  
      CAST( ISNULL( ERROR_NUMBER(), '') AS NVARCHAR(10)),   -- Step3  
      SUBSTRING( ISNULL( ERROR_PROCEDURE(), ''), 1, 20),    -- Step4  
      SUBSTRING( ISNULL( ERROR_PROCEDURE(), ''), 21, 20),   -- Step5  
      CAST( ISNULL( ERROR_LINE(), '') AS NVARCHAR(10)),     -- Col1  
      LTRIM( SUBSTRING( ERROR_MESSAGE(), 1, 20)),           -- Col2  
      LTRIM( SUBSTRING( ERROR_MESSAGE(), 21, 20)),          -- Col3  
      LTRIM( SUBSTRING( ERROR_MESSAGE(), 41, 20)),          -- Col4  
      LTRIM( SUBSTRING( ERROR_MESSAGE(), 61, 20))           -- Col5  
   )  
  
   -- RelightUp  
   EXEC PTL.isp_PTL_LightUpLoc  
      @n_Func           = @nFunc  
     ,@n_PTLKey         = 0  
     ,@c_DisplayValue   = @cOrgDisplayValue  
     ,@b_Success        = @bSuccess    OUTPUT  
     ,@n_Err            = @nErrNo      OUTPUT  
     ,@c_ErrMsg         = @cErrMsg     OUTPUT  
     ,@c_DeviceID       = @cDeviceID  
     ,@c_DevicePos      = @cDevicePosition  
     ,@c_DeviceIP       = @cDeviceIPAddress  
     ,@c_LModMode       = '99'  
  
   INSERT INTO TraceInfo (TraceName, TimeIn, step1, Step2, step3, step4, step5, Col1, Col2, Col3, Col4, col5)  
   VALUES  
   (  
      'isp_1834PTLConfirm01 CATCH2',                        -- TraceName  
      GETDATE(), -- TimeIn  
      ISNULL(@cDeviceIPAddress,'') ,   -- Step1  
      ISNULL(@cDevicePosition,''),                          -- Step2  
      CAST( ISNULL( @nHoldPTLKey, '') AS NVARCHAR(10)),     -- Step3  
      ISNULL(@cPTSLoc,''),                                  -- Step4  
      CAST( ISNULL( @nPTLKey   , '') AS NVARCHAR(10)),      -- Step5  
      CAST( ISNULL( @nFunc   , '') AS NVARCHAR(10)),        -- Col1  
      ISNULL(@cSuggLoc,''),                                 -- Col2  
      ISNULL(@cOrgDisplayValue,'') ,                        -- Col3  
      ISNULL(@cDeviceID,'') ,                              -- Col4  
      CAST( ISNULL( @nErrNo, '') AS NVARCHAR(10))           -- Col5  
   )  
END CATCH  
  
  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  

GO