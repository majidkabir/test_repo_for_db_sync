SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdt_PTLPiece_Confirm_Order08                           */  
/* Copyright      : LF Logistics                                           */  
/*                                                                         */  
/* Purpose: Confirm by order                                               */  
/*                                                                         */  
/* Date       Rev  Author     Purposes                                     */  
/* 09-07-2021 1.0  Chermaine  WMS-17331 Created                            */  
/* 13-12-2022 1.1  yeekung    WMS-21238 update order status                */  
/***************************************************************************/  
  
CREATE   PROC [RDT].[rdt_PTLPiece_Confirm_Order08] (  
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
  
   DECLARE   
    @cDropID           NVARCHAR( 20),  
      @cCartonID         NVARCHAR( 20),  
      @cOrderKey         NVARCHAR( 10),  
      @cOrderLineNumber  NVARCHAR( 5),  
      @cPickDetailKey    NVARCHAR( 10),  
      @cPickSlipNo       NVARCHAR( 10),  
      @cLoadkey          NVARCHAR( 10),  
      @cLightMode        NVARCHAR( 4),  
      @cDisplay          NVARCHAR( 5),  
      @cBatchKey         NVARCHAR(10),  
      @cWaveKey          NVARCHAR(10),  
      @cTotalBatchOrder  NVARCHAR(5),  
      @cToTalNotSorted   NVARCHAR(5),  
      @cSortedQty        NVARCHAR(5),  
      @cToTalQty         NVARCHAR(5),  
      @cToTalOpen        NVARCHAR(5),  
      @cDPLoc            NVARCHAR(10),  
      @cLOC              NVARCHAR(20)  
  
   -- Handling transaction    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN  -- Begin our own transaction    
   SAVE TRAN rdt_PTLPiece_Confirm -- For rollback or commit only our own transaction    
     
   SET @cDisplay = ''   
  
   IF @cLight = '1'  
   BEGIN  
     -- Check light not yet press  
      IF EXISTS( SELECT 1 FROM PTL.LightStatus WITH (NOLOCK) WHERE DeviceID = @cStation AND DisplayValue <> '' AND storerKey = @cStorerKey)  
      BEGIN  
         SET @nErrNo = 175251  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Light NotPress  
         GOTO ROLLBACKTRAN  
      END  
   END  
  
   -- Get assign info  
   SET @cDropID = ''  
   SELECT top 1 @cDropID = dropID  
  , @cBatchKey = BatchKey   
 FROM rdt.rdtPTLPieceLog WITH (NOLOCK)   
 WHERE Station = @cStation   
 order by editdate desc;   
  
   -- Find PickDetail to offset  
   SET @cOrderKey = ''  
   SELECT TOP 1   
      @cOrderKey = O.OrderKey,   
      @cPickDetailKey = PD.PickDetailKey,   
      @cWaveKey = PD.WaveKey,  
      @nQTY_PD = QTY,  
      @cCartonID = L.CartonID  
   FROM Orders O WITH (NOLOCK)   
      JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
      LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.dropID = @cDropID AND L.Station = @cStation)  
      JOIN PackTask PT WITH (NOLOCK) ON (L.batchKey = PT.TaskBatchNo)  
   WHERE PD.dropID = @cDropID  
      AND PD.SKU = @cSKU  
      AND PD.Status <= '5'  
      AND PD.CaseID <> 'SORTED'  
      AND PD.QTY > 0  
      AND PD.Status <> '4'  
      AND O.Status <> 'CANC'   
      AND O.SOStatus <> 'CANC'  
   ORDER BY L.RowRef DESC -- Match order with position first  
     
   -- Check blank  
   IF @cOrderKey = ''  
   BEGIN  
      SET @nErrNo = 175252  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No order  
      GOTO ROLLBACKTRAN  
   END  
     
   -- Get assign info  
   SET @cIPAddress = ''  
   SET @cPosition = ''  
   SELECT   
      @cCartonID = CartonID,   
      @cIPAddress = IPAddress,   
      @cPosition = Position,  
      @cLOC = Loc  
   FROM rdt.rdtPTLPieceLog WITH (NOLOCK)   
   WHERE Station = @cStation   
      AND OrderKey = @cOrderKey  
     
   IF @cLight <> '1' -- light spoil do confirm here  
   BEGIN  
     /***********************************************************************************************    
    
                                              CONFIRM ORDER    
    
      ***********************************************************************************************/    
      INSERT INTO PTL.PTLTran (    
         IPAddress, DeviceID, DevicePosition, Status, PTLType,     
         DeviceProfileLogKey, DropID, OrderKey, Storerkey, SKU, LOC, ExpectedQTY, QTY, SourceKey)    
      VALUES (    
         @cIPAddress, @cStation, @cPosition, '9', 'PIECE',     
         '', @cCartonID, @cOrderKey, @cStorerKey, @cSKU, @cLOC, @nQTY_PD, 0, @cBatchKey)    
             
      IF @@ERROR <> ''    
      BEGIN    
         SET @nErrNo = 175253    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail    
         GOTO RollBackTran    
      END    
            
      -- Exact match  
      IF @nQTY_PD = 1  
      BEGIN  
       IF @cCartonID = ''  
       BEGIN  
          -- Confirm PickDetail  
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
               -- Status = '5',  
               CaseID = 'SORTED',  
               EditDate = GETDATE(),   
               EditWho  = SUSER_SNAME(),   
               Trafficcop = NULL  
            WHERE PickDetailKey = @cPickDetailKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 175254  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
               GOTO RollBackTran  
            END  
       END  
       ELSE  
       BEGIN  
        -- Confirm PickDetail  
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
               -- Status = '5',  
               CaseID = 'SORTED',  
               dropID = @cCartonID,  
               EditDate = GETDATE(),   
               EditWho  = SUSER_SNAME(),   
               Trafficcop = NULL  
            WHERE PickDetailKey = @cPickDetailKey  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 175255  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
               GOTO RollBackTran  
            END  
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
            SET @nErrNo = 175256  
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
            OptimizeCop, Channel_ID)  
         SELECT   
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,   
            UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,   
            CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,  
            EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,   
            @cNewPickDetailKey,   
            @nQTY_PD - 1, -- QTY  
            NULL, -- TrafficCop  
            '1'   -- OptimizeCop  
            , Channel_ID  
         FROM dbo.PickDetail WITH (NOLOCK)   
     WHERE PickDetailKey = @cPickDetailKey                 
         IF @@ERROR <> 0  
         BEGIN  
      SET @nErrNo = 175257  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail  
            GOTO RollBackTran  
         END         
     
         -- Get RefKeyLookup info  
         SELECT  
            @cPickSlipNo = PickSlipNo,   
            @cOrderLineNumber = OrderLineNumber,  
            @cLoadkey = Loadkey  
         FROM RefKeyLookup WITH (NOLOCK)   
         WHERE PickDetailKey = @cPickDetailKey  
     
         -- Split RefKeyLookup  
         IF @@ROWCOUNT > 0  
         BEGIN  
            -- Insert into  
            INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickslipNo, OrderKey, OrderLineNumber, Loadkey)  
            VALUES (@cNewPickDetailKey, @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadkey)  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 175258  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail  
               GOTO RollBackTran  
            END  
         END  
           
         IF @cCartonID = ''  
         BEGIN  
          -- Change orginal PickDetail with exact QTY (with TrafficCop)  
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
               QTY = 1,   
               CaseID = 'SORTED',   
               EditDate = GETDATE(),   
               EditWho  = SUSER_SNAME(),   
               Trafficcop = NULL  
            WHERE PickDetailKey = @cPickDetailKey   
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 175259  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
               GOTO RollBackTran  
            END  
         END  
         ELSE  
         BEGIN  
          -- Change orginal PickDetail with exact QTY (with TrafficCop)  
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
               QTY = 1,   
               CaseID = 'SORTED',   
               dropID = @cCartonID,  
               EditDate = GETDATE(),   
               EditWho  = SUSER_SNAME(),   
               Trafficcop = NULL  
            WHERE PickDetailKey = @cPickDetailKey   
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 175260  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail  
               GOTO RollBackTran  
            END  
         END  
      END  
   END  
     
   -- Assign order  
   IF @cPosition = ''  
   BEGIN  
      -- Get position not yet assign  
      SELECT TOP 1  
         @cIPAddress = DP.IPAddress,   
         @cPosition = DP.DevicePosition,  
         @cDPLoc = DP.Loc  
      FROM dbo.DeviceProfile DP WITH (NOLOCK)  
      WHERE DP.DeviceType = 'STATION'  
         AND DP.DeviceID = @cStation  
         AND NOT EXISTS( SELECT 1  
            FROM rdt.rdtPTLPieceLog Log WITH (NOLOCK)  
            WHERE Log.Station = @cStation  
               AND Log.Position = DP.DevicePosition)  
      ORDER BY DP.LogicalPos, DP.DevicePosition  
        
      -- Check position available  
      IF @cPosition = ''  
      BEGIN  
         SET @nErrNo = 175261  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoPos4NewOrder  
         GOTO Quit  
      END  
        
      -- Save assign  
  
      INSERT rdt.rdtPTLPieceLog (Station, IPAddress, Position, BatchKey, OrderKey, dropID, Loc)    
      SELECT @cStation, @cIPAddress, @cPosition, @cBatchKey, @cOrderKey, @cDropID, @cDPLoc    
      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 175262  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS LOG FAIL  
         GOTO Quit  
      END  
   END  
     
   --Get Display Info        
 SELECT   
      @cTotalBatchOrder = COUNT (DISTINCT OrderKey)  
   FROM packTask (NOLOCK) WHERE taskBatchNo = @cBatchKey  
    
 SELECT   
      @cToTalNotSorted = COUNT (DISTINCT PD.OrderKey)  
   FROM Orders O WITH (NOLOCK)   
      JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
      LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)  
      JOIN PackTask PT WITH (NOLOCK) ON (L.batchKey = PT.TaskBatchNo)  
   WHERE PT.taskBatchNo = @cBatchKey  
      AND PD.Status <> '4'  
      AND O.Status <> 'CANC'   
      AND O.SOStatus <> 'CANC'  
      AND PD.CaseID <> 'Sorted'  
   GROUP BY PD.storerKey ,  PD.Orderkey  
        
   SELECT   
      @cToTalQty = SUM(Qty)  
   FROM Orders O WITH (NOLOCK)   
      JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
      --LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)  
      JOIN PackTask PT WITH (NOLOCK) ON (PD.orderKey = PT.OrderKey )  
   WHERE PT.taskBatchNo = @cBatchKey  
      AND PD.Status <> '4'  
      AND O.Status <> 'CANC'   
      AND O.SOStatus <> 'CANC'  
   GROUP BY PD.storerKey ,  PD.Orderkey  
        
   SELECT   
      @cSortedQty = SUM(Qty)  
   FROM Orders O WITH (NOLOCK)   
      JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
      --LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)  
      JOIN PackTask PT WITH (NOLOCK) ON (PD.orderKey = PT.OrderKey )  
   WHERE PT.taskBatchNo = @cBatchKey  
      AND PD.Status <> '4'  
      AND O.Status <> 'CANC'   
      AND O.SOStatus <> 'CANC'  
      AND PD.CaseID = 'Sorted'  
   GROUP BY PD.storerKey ,  PD.Orderkey  
        
   SET @cToTalOpen = CONVERT(INT,@cTotalBatchOrder) - CONVERT(INT,@cToTalNotSorted)  
   SET @cResult01 = 'WaveID: ' + @cWaveKey  
   SET @cResult02 = 'TskBatch#:' + @cBatchKey  
   SET @cResult03 = 'Open/TtlOrd: ' + @cToTalOpen + '/' + @cTotalBatchOrder  
   SET @cResult04 = 'Open/TtlQty: ' + @cSortedQty + '/' + @cToTalQty  
     
   -- Update current SKU  
   UPDATE rdt.rdtPTLPieceLog SET  
      SKU = @cSKU  
   WHERE IPAddress = @cIPAddress  
      AND Position = @cPosition  
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 175263  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PLog Fail  
      GOTO Quit  
   END  
   
	IF @cLight='1'
	BEGIN
		SELECT   
			@cToTalQty = SUM(Qty)  
		FROM Orders O WITH (NOLOCK)   
			JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)  
			--LEFT JOIN rdt.rdtPTLPieceLog L WITH (NOLOCK) ON (L.OrderKey = O.OrderKey AND L.Station = @cStation)  
			JOIN PackTask PT WITH (NOLOCK) ON (PD.orderKey = PT.OrderKey )  
		WHERE PT.taskBatchNo = @cBatchKey  
			AND PD.sku=@csku
			AND PD.dropid=@cdropid
			AND PD.Status <> '4'  
			AND O.Status <> 'CANC'   
			AND O.SOStatus <> 'CANC'  
		GROUP BY PD.storerKey ,  PD.Orderkey 
		
		IF NOT EXISTS (SELECT 1 
							FROM PTL.PTLTRAN (NOLOCK)
							where storerkey=@cStorerKey
							and dropid=@cDropID
							and orderkey=@cOrderKey
							AND SourceKey=@cBatchKey)
		BEGIN

			INSERT INTO PTL.PTLTran (    
				IPAddress, DeviceID, DevicePosition, Status, PTLType,     
				DeviceProfileLogKey, DropID, OrderKey, Storerkey, SKU, LOC, ExpectedQTY, QTY, SourceKey)    
			VALUES (    
				@cIPAddress, @cStation, @cPosition, '0', 'PIECE',     
				'', @cDropID, @cOrderKey, @cStorerKey, @cSKU, @cLOC, @cToTalQty, 0, @cBatchKey)    
		END
		ELSE
		BEGIN
			UPDATE PTL.PTLTRAN 
			set Status=0
			where storerkey=@cStorerKey
				and dropid=@cDropID
				and orderkey=@cOrderKey
				AND SourceKey=@cBatchKey
		END
             
		IF @@ERROR <> ''    
		BEGIN    
			SET @nErrNo = 175264    
			SET @cErrMsg = rdt.rdtgetmessage( @nErrNo ,@cLangCode ,'DSP') --INS PTL Fail    
			GOTO RollBackTran    
		END   
	END
     
   EXEC RDT.rdt_STD_EventLog    
     @cActionType = '3',   
     @nMobileNo   = @nMobile,    
     @nFunctionID = @nFunc,    
     @cFacility   = @cFacility,    
     @cStorerKey  = @cStorerkey,  
     @cOrderKey   = @cOrderKey,  
     @cSKU        = @cSKU,   
     @nQTY        = @nQTY_PD,  
     @cCaseID     = @cCartonID  
     
   -- Auto unassign position if fully sorted    
   IF NOT EXISTS( SELECT 1     
      FROM Orders O WITH (NOLOCK)    
         JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)    
      WHERE O.OrderKey = @cOrderKey    
         AND PD.CaseID <> 'Sorted'   
         AND PD.QTY > 0    
         AND PD.Status <> '4'    
         AND O.Status <> 'CANC'     
         AND O.SOStatus <> 'CANC')    
   BEGIN    
      DELETE rdt.rdtPTLPieceLog    
      WHERE Station = @cStation    
         AND OrderKey = @cOrderKey    
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 175265    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DEL Log Fail    
         GOTO RollBackTran    
      END    

      UPDATE orders  WITH (ROWLOCK)
      set status='3'
      where orderkey=@cOrderKey
      AND storerkey=@cstorerkey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 175267
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdOrderFail
         GOTO RollBackTran
      END

      UPDATE orderdetail  WITH (ROWLOCK)
      set status='3'
      where orderkey=@cOrderKey
      AND storerkey=@cstorerkey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 175267
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdODFail
         GOTO RollBackTran
      END
          
      IF @cLight = '1'    
      BEGIN    
         SET @cDisplay = 'END'     
      END    
      ELSE    
      BEGIN    
         SET @nErrNo = 175266    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ORDER COMPLETED    
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg, '', @cPosition, @cCartonID        
         SET @nErrNo = 0    
         SET @cErrMsg = ''    
      END    
   END    
  
   -- Handling transaction  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_PTLPiece_Confirm -- For rollback or commit only our own transaction     
  
   -- Draw matrix   
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
   ROLLBACK TRAN rdt_PTLPiece_Confirm -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO