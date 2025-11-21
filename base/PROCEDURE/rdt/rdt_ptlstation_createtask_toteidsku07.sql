SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
      
/************************************************************************/      
/* Store procedure: rdt_PTLStation_CreateTask_ToteIDSKU07               */      
/* Copyright      : LFLogistics                                         */      
/*                                                                      */      
/* Purpose: Get Pickdetail.ID = Scanned ID to create task               */      
/*                                                                      */      
/* Date       Rev Author      Purposes                                  */      
/* 2021-08-04 1.0 yeekung     WMS-17625 Created                         */     
/* 2021-10-12 1.1 yeekung     JSM-24985 remove sum(qty) (yeekung01)     */ 
/* 2021-11-29 1.2 yeekung      Perf tuning (yeekung02)                  */     
/************************************************************************/      
      
CREATE PROC [RDT].[rdt_PTLStation_CreateTask_ToteIDSKU07] (      
    @nMobile      INT      
   ,@nFunc        INT      
   ,@cLangCode    NVARCHAR(3)      
   ,@nStep        INT      
   ,@nInputKey    INT      
   ,@cFacility    NVARCHAR(5)      
   ,@cStorerKey   NVARCHAR(15)      
   ,@cType        NVARCHAR(20)        
   ,@cLight       NVARCHAR(1)   -- 0 = no light, 1 = use light      
   ,@cStation1    NVARCHAR(10)        
   ,@cStation2    NVARCHAR(10)        
   ,@cStation3    NVARCHAR(10)        
   ,@cStation4    NVARCHAR(10)        
   ,@cStation5    NVARCHAR(10)        
   ,@cMethod      NVARCHAR(10)      
   ,@cScanID      NVARCHAR(20)      OUTPUT      
   ,@cCartonID    NVARCHAR(20)      
   ,@nErrNo       INT               OUTPUT      
   ,@cErrMsg      NVARCHAR(20)      OUTPUT      
   ,@cScanSKU     NVARCHAR(20) = '' OUTPUT      
   ,@cSKUDescr    NVARCHAR(60) = '' OUTPUT      
   ,@nQTY         INT          = 0  OUTPUT      
)      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE @nTranCount     INT      
   DECLARE @bSuccess       INT      
   DECLARE @cSQL           NVARCHAR( MAX)      
   DECLARE @cSQLParam      NVARCHAR( MAX)      
         
   DECLARE @cOrderKey      NVARCHAR( 10)      
   DECLARE @nPDQTY         INT      
   DECLARE @nPTLQty        INT      
         
   SET @nErrNo = 0       
      
   DECLARE @tOrders TABLE      
   (      
      wavekey  NVARCHAR(20) NOT NULL,      
      orderkey NVARCHAR(20) NOT NULL      
   )      
            
   /***********************************************************************************************      
                                              Generate PTLTran      
   ***********************************************************************************************/      
   -- Check order not yet assign carton ID (for Exceed continuous backend assign new orders)      
   IF EXISTS( SELECT 1       
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)      
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)      
         AND CartonID = '')      
   BEGIN      
      SET @nErrNo = 172951      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AssignCartonID      
      GOTO Quit      
   END      
         
    -- Get orders in station      
   INSERT INTO @tOrders (wavekey,orderkey)       
   SELECT wavekey,orderkey      
   FROM rdt.rdtPTLStationLog WITH (NOLOCK)       
   WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)      
      AND wavekey <>''      
      AND orderkey<>''      
      
      
   IF ISNULL(@cScanSKU,'')=''      
   BEGIN      
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- sku      
      GOTO Quit      
   END      
      
   -- Check task       
   IF NOT EXISTS( SELECT 1       
      FROM @tOrders O       
         JOIN PickDetail PD WITH (NOLOCK) ON (pd.OrderKey=o.orderkey)      
         JOIN sku sku WITH (NOLOCK) ON (sku.sku=pd.sku)      
      WHERE PD.StorerKey = @cStorerKey      
         AND PD.dropID = @cScanID      
         AND PD.CaseID = ''      
         AND PD.QTY > 0      
         AND PD.Status <> '4')         BEGIN      
      SET @nErrNo = 172952      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No task      
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC/ID      
      SET @nErrNo = -1 -- Remain in current screen      
      SET @cScanID = ''      
      SET @cScanSKU = ''      
      GOTO Quit      
   END      
         
   SET @nTranCount = @@TRANCOUNT      
   BEGIN TRAN      
   SAVE TRAN rdt_PTLStation_CreateTask      
      
   DECLARE @nRowRef      INT      
   DECLARE @cIPAddress   NVARCHAR(40)      
   DECLARE @cPosition    NVARCHAR(10)      
   DECLARE @cStation     NVARCHAR(10)      
   DECLARE @cDropID      NVARCHAR(20)      
   DECLARE @cPickslipNo  NVARCHAR(20)      
   DECLARE @cbatchkey    NVARCHAR(20)      
      
   SET @nPDQTY = 0      
   SET @nQTY = 0      
  
   --(yeekung01)  
      
   --SELECT @nQTY=SUM( PD.QTY)      
   --FROM  PickDetail PD WITH (NOLOCK)       
   --   JOIN sku sku WITH (NOLOCK) ON (sku.sku=pd.sku AND pd.Storerkey=sku.StorerKey)      
   --WHERE PD.StorerKey = @cStorerKey       
   --   AND PD.dropID = @cScanID      
   --   AND pd.sku=@cScanSKU      
   --   AND PD.CaseID = ''      
   --   AND PD.QTY > 0      
   --   AND PD.Status <> '4'      
         
   DECLARE @curPD CURSOR      
   SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT o.orderkey,sku.sku, SUM( PD.QTY),DropID      
         FROM @tOrders O       
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.orderkey=o.orderkey)      
            JOIN sku sku WITH (NOLOCK) ON (sku.sku=pd.sku AND pd.Storerkey=sku.StorerKey)      
         WHERE PD.StorerKey = @cStorerKey       
            AND PD.dropID = @cScanID      
            AND pd.sku=@cScanSKU      
            AND PD.CaseID = ''      
            AND PD.QTY > 0      
            AND PD.Status <> '4'      
         GROUP BY o.orderkey,sku.sku,DropID      
   OPEN @curPD      
   FETCH NEXT FROM @curPD INTO @cOrderKey,@cScanSKU, @nPDQTY,@cScanID      
   WHILE @@FETCH_STATUS = 0      
   BEGIN      
      -- Get station info      
      SET @nRowRef = 0      
      SELECT       
         @nRowRef = RowRef,       
         @cStation = Station,       
         @cIPAddress = IPAddress,       
         @cPosition = Position       
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)      
      WHERE Station IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)      
         AND orderkey=@cOrderKey      
            
      IF @nRowRef > 0      
      BEGIN      
         -- Check PTLTran generated      
         IF NOT EXISTS( SELECT 1      
            FROM PTL.PTLTran WITH (NOLOCK)      
            WHERE DeviceID = @cStation      
               AND IPAddress = @cIPAddress       
               AND DevicePosition = @cPosition      
               AND GroupKey = @nRowRef      
               AND Func = @nFunc      
               AND DropID = @cScanID      
               AND OrderKey = @cOrderKey      
               )      
         BEGIN      
            --(yeekung01)  
            --IF @nQty = @nPDQty       
            --BEGIN      
            --   SET @nPTLQty = @nQty      
            --   SET @nQty = 0       
            --END      
            --ELSE IF @nQty > @nPDQty       
            --BEGIN      
            --   SET @nPTLQty = @nPDQty      
            --   SET @nQty = @nQty - @nPDQty      
            --END      
            --ELSE IF @nQty < @nPDQty       
            --BEGIN      
            --   SET @nPTLQty = @nQty      
            --   SET @nQty = 0      
            --END   

            DECLARE @cLOC NVARCHAR(20)
            
            SELECT @cLOC =LOC
            FROM dbo.DeviceProfile (NOLOCK)
            WHERE deviceid=@cStation
            AND DevicePosition=@cPosition  
            AND @cIPAddress=@cIPAddress 
                  
            -- Generate PTLTran      
            INSERT INTO PTL.PTLTran (      
               IPAddress, DevicePosition, DeviceID, PTLType,loc  ,  
               SourceKey, StorerKey, SKU, ExpectedQTY, QTY, DropID, Func, GroupKey, SourceType)      
            VALUES (      
               @cIPAddress, @cPosition, @cStation, 'STATION', @cLOC ,     
               '', @cStorerKey, @cScanSKU, @nPDQty, 0,  @cScanID, @nFunc, @nRowRef, 'rdt_PTLStation_CreateTask_ToteIDSKU07')      
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 1729538      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPTLTranFail      
               GOTO RollbackTran      
            END      
         END      
      END      
      FETCH NEXT FROM @curPD INTO @cOrderKey,@cScanSKU, @nPDQTY,@cScanID      
   END      
   CLOSE @curPD                     
   DEALLOCATE @curPD      
         
   COMMIT TRAN rdt_PTLStation_CreateTask      
      
         
   GOTO Quit      
      
RollBackTran:      
   ROLLBACK TRAN rdt_PTLStation_CreateTask      
Quit:      
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started      
      COMMIT TRAN      
      
END 

GO