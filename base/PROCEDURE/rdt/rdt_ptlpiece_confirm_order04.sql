SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_PTLPiece_Confirm_Order04                        */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Purpose: Confirm by order                                            */  
/*                                                                      */  
/* Date       Rev  Author      Purposes                                 */  
/* 01-03-2021 1.0  YeeKung     WMS-16220 Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_PTLPiece_Confirm_Order04] (  
    @nMobile      INT  
   ,@nFunc        INT  
   ,@cLangCode    NVARCHAR( 3)  
   ,@nStep        INT  
   ,@nInputKey    INT  
   ,@cFacility    NVARCHAR( 5)  
   ,@cStorerKey   NVARCHAR( 15)  
   ,@cLight       NVARCHAR( 1)  
   ,@cStation     NVARCHAR( 10)  
   ,@cMethod      NVARCHAR( 1)   
   ,@cSKU         NVARCHAR( 20)  
   ,@cIPAddress   NVARCHAR( 40) OUTPUT  
   ,@cPosition    NVARCHAR( 10) OUTPUT  
   ,@nErrNo       INT           OUTPUT  
   ,@cErrMsg      NVARCHAR(250) OUTPUT  
   ,@cResult01    NVARCHAR( 20) OUTPUT  
   ,@cResult02    NVARCHAR( 20) OUTPUT  
   ,@cResult03    NVARCHAR( 20) OUTPUT  
   ,@cResult04    NVARCHAR( 20) OUTPUT  
   ,@cResult05    NVARCHAR( 20) OUTPUT  
   ,@cResult06    NVARCHAR( 20) OUTPUT  
   ,@cResult07    NVARCHAR( 20) OUTPUT  
   ,@cResult08    NVARCHAR( 20) OUTPUT  
   ,@cResult09    NVARCHAR( 20) OUTPUT  
   ,@cResult10    NVARCHAR( 20) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @bSuccess          INT  
   DECLARE @nTranCount        INT  
   DECLARE @nQTY_PD           INT  
  
   DECLARE @cCartonID         NVARCHAR( 20)  
   DECLARE @cOrderKey         NVARCHAR( 10)  
   DECLARE @cPickDetailKey    NVARCHAR( 10)  
   DECLARE @cDisplay          NVARCHAR( 5)  
   DECLARE @cUpdateDropID     NVARCHAR( 1)  
   DECLARE @cPrintLabelSP     NVARCHAR( 20)  -- (cc01)  
     
   -- Handling transaction  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_PTLPiece_Confirm -- For rollback or commit only our own transaction  

   SET @cDisplay = ''   
  
   -- Storer configure  
   SET @cUpdateDropID = rdt.RDTGetConfig( @nFunc, 'UpdateDropID', @cStorerKey)  
     
   SET @cPrintLabelSP = rdt.RDTGetConfig( @nFunc, 'PrintLabelSP', @cStorerKey) -- (cc01)  
     
   -- Find PickDetail to offset  
   SET @cOrderKey = ''  
   SELECT TOP 1   
      @cOrderKey = O.OrderKey,   
      @cPickDetailKey = PD.PickDetailKey,   
      @nQTY_PD = QTY  
   FROM rdt.rdtPTLPieceLog L WITH (NOLOCK)   
      JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = L.OrderKey)  
      JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
   WHERE L.Station = @cStation  
      AND PD.SKU = @cSKU  
      AND PD.Status <= '5'  
      AND PD.CaseID = ''  
      AND PD.QTY > 0  
      AND PD.Status <> '4'  
      AND O.Status <> 'CANC'   
      AND O.SOStatus <> 'CANC'  
   ORDER BY L.Position  
  
   -- Check blank  
   IF @cOrderKey = ''  
   BEGIN  
      SET @nErrNo =164001  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No order  
      GOTO ROLLBACKTRAN
   END  
     
   -- Get assign info  
   SET @cCartonID = ''  
   IF @cUpdateDropID = '1'  
      SELECT @cCartonID = CartonID  
      FROM rdt.rdtPTLPieceLog WITH (NOLOCK)   
      WHERE Station = @cStation   
         AND OrderKey = @cOrderKey  
  
   /***********************************************************************************************  
  
                                              CONFIRM ORDER  
  
   ***********************************************************************************************/  
          
   -- Exact match  
   IF @nQTY_PD = 1  
   BEGIN  
      -- Confirm PickDetail  
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
         CaseID = 'SORTED',   
         DropID = CASE WHEN @cUpdateDropID =  '1' THEN @cCartonID ELSE DropID END,   
         EditDate = GETDATE(),   
         EditWho  = SUSER_SNAME(),   
         Trafficcop = NULL  
      WHERE PickDetailKey = @cPickDetailKey  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo =164002  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
         GOTO RollBackTran  
      END  
   END  
        
   -- PickDetail have more  
   ELSE IF @nQTY_PD > 1  
   BEGIN  
      -- Get new PickDetailkey  
      DECLARE @cNewPickDetailKey NVARCHAR( 10)  
      EXECUTE dbo.nspg_GetKey  
         'PICKDETAILKEY',   
         10 ,  
         @cNewPickDetailKey OUTPUT,  
         @bSuccess          OUTPUT,  
         @nErrNo            OUTPUT,  
         @cErrMsg           OUTPUT  
      IF @bSuccess <> 1  
      BEGIN  
         SET @nErrNo =164003  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey  
         GOTO RollBackTran  
      END  
  
      -- Create new a PickDetail to hold the balance  
      INSERT INTO dbo.PickDetail (  
         CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,   
         UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,   
         ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
         EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,   
         PickDetailKey,   
         QTY,   
         TrafficCop,  
         OptimizeCop, Channel_ID)   -- INC1356666
      SELECT   
         CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,   
         UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,   
         CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
         EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,   
         @cNewPickDetailKey,   
         @nQTY_PD - 1, -- QTY  
         NULL,        -- TrafficCop  
         '1',         -- OptimizeCop
         Channel_ID   -- INC1356666
      FROM dbo.PickDetail WITH (NOLOCK)   
  WHERE PickDetailKey = @cPickDetailKey                 
      IF @@ERROR <> 0  
      BEGIN  
   SET @nErrNo =164004  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail  
         GOTO RollBackTran  
      END  
  
      -- Check RefKeyLookup  
      IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)  
      BEGIN  
         -- Insert RefKeyLookup  
         INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickslipNo, OrderKey, OrderLineNumber, Loadkey)  
         SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey  
         FROM RefKeyLookup WITH (NOLOCK)   
         WHERE PickDetailKey = @cPickDetailKey  
         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 101258  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail  
            GOTO RollBackTran  
         END  
      END  
        
      -- Change orginal PickDetail with exact QTY (with TrafficCop)  
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
         QTY = 1,   
         CaseID = 'SORTED',   
         DropID = CASE WHEN @cUpdateDropID =  '1' THEN @cCartonID ELSE DropID END,   
         EditDate = GETDATE(),   
         EditWho  = SUSER_SNAME(),   
         Trafficcop = NULL  
      WHERE PickDetailKey = @cPickDetailKey   
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo =164006  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
         GOTO RollBackTran  
      END  
   END  
     
   
   -- Get position info  
   SELECT   
      @cIPAddress = IPAddress,   
      @cPosition = Position  
   FROM rdt.rdtPTLPieceLog WITH (NOLOCK)   
   WHERE Station = @cStation  
      AND OrderKey = @cOrderKey  
  
   -- Get method info  
   DECLARE @cBatchKey NVARCHAR(20)  
   SELECT TOP 1   
      @cBatchKey = BatchKey   
   FROM rdt.rdtPTLPieceLog (NOLOCK)   
   WHERE Station = @cStation  
      AND OrderKey = @cOrderKey  
  
   -- Get PackTask info  
   DECLARE @nRowRef        BIGINT  
   DECLARE @cPreAssignPos  NVARCHAR(10)  
   SELECT   
      @nRowRef = RowRef,   
      @cPreAssignPos = DevicePosition  
   FROM PackTask WITH (NOLOCK)   
   WHERE TaskBatchNo = @cBatchKey  
      AND OrderKey = @cOrderKey  
  
   -- Exceed not yet assign position  
   IF @cPreAssignPos = ''  
   BEGIN  
      -- Get position info  
      DECLARE @cLogicalName NVARCHAR(10)  
      SELECT @cLogicalName = LogicalName  
      FROM DeviceProfile WITH (NOLOCK)  
      WHERE DeviceType = 'STATION'  
         AND DeviceID = @cStation  
         AND DevicePosition = @cPosition  
        
      -- Update PackTask  
      UPDATE PackTask SET  
         DevicePosition = @cPosition,  
         LogicalName = @cLogicalName,   
         EditWho = SUSER_SNAME(),   
         EditDate = GETDATE()  
      WHERE RowRef = @nRowRef  
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo =164008  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PTask Fail  
         GOTO RollBackTran  
      END  
   END  
     
   -- EventLog  
   EXEC RDT.rdt_STD_EventLog  
     @cActionType = '3',   
     @nMobileNo   = @nMobile,  
     @nFunctionID = @nFunc,  
     @cFacility   = @cFacility,  
     @cStorerKey  = @cStorerkey,  
     @cOrderKey   = @cOrderKey,  
     @cPickSlipNo = @cBatchKey,  
     @cDropID     = @cPosition,   
     @cSKU        = @cSKU,  
     @cDeviceID   = @cStation,  
     @nQty        = @nQTY_PD  
     
   -- Draw matrix (and light up)  
   EXEC rdt.rdt_PTLPiece_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey  
      ,@cLight  
      ,@cStation  
      ,@cMethod  
      ,@cSKU  
      ,@cIPAddress   
      ,@cPosition  
      ,@cDisplay  
      ,@nErrNo     OUTPUT  
      ,@cErrMsg    OUTPUT  
      ,@cResult01  OUTPUT  
      ,@cResult02  OUTPUT  
      ,@cResult03  OUTPUT  
      ,@cResult04  OUTPUT  
      ,@cResult05  OUTPUT  
      ,@cResult06  OUTPUT  
      ,@cResult07  OUTPUT  
      ,@cResult08  OUTPUT  
      ,@cResult09  OUTPUT  
      ,@cResult10  OUTPUT  
   IF @nErrNo <> 0  
      GOTO RollBackTran  
  
   COMMIT TRAN rdt_PTLPiece_Confirm  
   GOTO Quit  
     
RollBackTran:  
BEGIN

   DECLARE @cDevicePos nvarchar(20)

   select top 1 @cDevicePos=logicalpos
   from deviceprofile (nolock) 
   where deviceid=@cStation
   and storerkey=@cStorerKey
   order by logicalpos desc


   exec [PTL].[isp_PTL_Light_TMS]
    @n_Func          = @nFunc
   ,@n_PTLKey        = 0
   ,@b_Success       = 0
   ,@n_Err           = @nErrNo    
   ,@c_ErrMsg        = @cErrMsg OUTPUT
   ,@c_DeviceID      = @cStation
   ,@c_DevicePos     = @cDevicePos
   ,@c_DeviceIP      = ''
   ,@c_DeviceStatus  = '1'

   ROLLBACK TRAN rdt_PTLPiece_Confirm -- Only rollback change made here  
END
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
     
   -- (cc01)  
   IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = @cPrintLabelSP AND type = 'P')    
   BEGIN    
      DECLARE @cSQLStatement NVARCHAR(1000)    
      DECLARE @cSQLParms     NVARCHAR(1000)    
                   
      SET @cSQLStatement = N'EXEC rdt.' + @cPrintLabelSP +     
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cOrderKey,' +    
         ' @nErrNo     OUTPUT,' +    
         ' @cErrMsg    OUTPUT '    
       
      SET @cSQLParms =     
         '@nMobile     INT,       ' +    
         '@nFunc       INT,       ' +  
         '@cLangCode   NVARCHAR(3),   ' +  
         '@nStep       INT,       ' +    
         '@nInputKey   INT,       ' +   
         '@cFacility   NVARCHAR(5),   ' +   
         '@cStorerKey  NVARCHAR(15),  ' +   
         '@cStation     NVARCHAR( 10), '+  
         '@cMethod      NVARCHAR( 1),  '+  
         '@cOrderKey    NVARCHAR( 10), '+          
         '@nErrNo      INT          OUTPUT, ' +    
         '@cErrMsg     NVARCHAR(250) OUTPUT  '     
                                  
      EXEC sp_ExecuteSQL @cSQLStatement, @cSQLParms,        
         @nMobile    
         ,@nFunc  
         ,@cLangCode    
         ,@nStep  
         ,@nInputKey  
         ,@cFacility  
         ,@cStorerKey  
         ,@cStation  
         ,@cMethod  
         ,@cOrderKey  
         ,@nErrNo   OUTPUT    
         ,@cErrMsg  OUTPUT    
   END    
END

GO