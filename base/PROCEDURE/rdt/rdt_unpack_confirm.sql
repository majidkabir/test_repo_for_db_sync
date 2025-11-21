SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Unpack_Confirm                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 30-05-2017 1.0  Ung         WMS-1919 Created                         */
/* 2020-04-23 1.1  James       WMS-13005 Add update pickdetail (james01)*/
/************************************************************************/

CREATE PROC [RDT].[rdt_Unpack_Confirm] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cPickSlipNo  NVARCHAR( 10)
   ,@cFromDropID  NVARCHAR( 20)
   ,@cSKU         NVARCHAR( 20) 
   ,@nCartonNo    INT           
   ,@cLabelNo     NVARCHAR( 20) 
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nPDCartonNo INT
   DECLARE @cPDLabelNo  NVARCHAR( 20)
   DECLARE @cLabelLine  NVARCHAR( 5)
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 10)
   DECLARE @cPrev_OrderKey       NVARCHAR( 10) = ''
   DECLARE @cPD_OrderKey         NVARCHAR( 10) = ''
   DECLARE @cPD_OrderLineNumber  NVARCHAR( 5) = ''
   DECLARE @cPD_PickDetailKey    NVARCHAR( 10)
   DECLARE @cPickConfirmStatus   NVARCHAR( 1)
   DECLARE @cUpdatePickdetail    NVARCHAR( 1)
   DECLARE @cOrderLineNumber     NVARCHAR( 5)
   DECLARE @cNewStatus           NVARCHAR( 10)  
   DECLARE @cOrdType             NVARCHAR( 10)  
   DECLARE @cPickDetailCartonID  NVARCHAR( 20)
   DECLARE @bSuccess             INT  
   DECLARE @curPD                CURSOR
   DECLARE @cPrev_LabelNo        NVARCHAR( 20)
   DECLARE @cSQL                 NVARCHAR( MAX)
   DECLARE @cSQLParam            NVARCHAR( MAX)

   SET @nErrNo = 0

   SET @cUpdatePickdetail = rdt.RDTGetConfig( @nFunc, 'UpdatePickdetail', @cStorerKey)      
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   SET @cPickDetailCartonID = rdt.RDTGetConfig( @nFunc, 'PickDetailCartonID', @cStorerKey)
   -- PickDetail.CaseID or PickDetail.DropID
   IF @cPickDetailCartonID = '0'
      SET @cPickDetailCartonID = ''

   IF OBJECT_ID('tempdb..#CartonID') IS NOT NULL  
      DROP TABLE #CartonID

   IF OBJECT_ID('tempdb..#ORDERS') IS NOT NULL  
      DROP TABLE #ORDRES

   CREATE TABLE #CartonID  (  
      RowRef            BIGINT IDENTITY(1,1)  Primary Key,  
      CartonID          NVARCHAR( 20))  

   CREATE TABLE #ORDERS  (  
      RowRef            BIGINT IDENTITY(1,1)  Primary Key,  
      OrderKey          NVARCHAR( 10),
      OrderLineNumber   NVARCHAR( 5))  
         
   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_Unpack_Confirm -- For rollback or commit only our own transaction
   
   
   -- Unpack confirm
   IF EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '9')
   BEGIN
      UPDATE dbo.PackHeader SET
         Status = '0',
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE PickSlipNo = @cPickSlipNo
      SET @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
   END
   
   SET @cPrev_LabelNo = ''

   SET @curPD = CURSOR FOR
      SELECT CartonNo, LabelNo, LabelLine
      FROM PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
         AND (@cFromDropID = '' OR DropID = @cFromDropID)
         AND (@nCartonNo = 0 OR CartonNo = @nCartonNo)
         AND (@cLabelNo = '' OR LabelNo = @cLabelNo)
         AND (@cSKU = '' OR SKU = @cSKU)
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @nPDCartonNo, @cPDLabelNo, @cLabelLine
   WHILE @@FETCH_STATUS = 0
   BEGIN
      DELETE PackDetail
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nPDCartonNo
         AND LabelNo = @cPDLabelNo
         AND LabelLine = @cLabelLine
      SET @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
      
      IF @cPrev_LabelNo <> @cPDLabelNo 
      BEGIN
         INSERT INTO #CartonID (CartonID) VALUES (@cPDLabelNo)
         
         SET @cPrev_LabelNo = @cPDLabelNo
      END 

      FETCH NEXT FROM @curPD INTO @nPDCartonNo, @cPDLabelNo, @cLabelLine
   END
   CLOSE @curPD
   DEALLOCATE @curPD

   -- Update pickdetail
   IF @cUpdatePickdetail = '1'
   BEGIN
      SELECT @cZone = Zone, 
             @cLoadKey = ExternOrderKey,
             @cOrderKey = OrderKey
      FROM dbo.PickHeader WITH (NOLOCK)     
      WHERE PickHeaderKey = @cPickSlipNo  
      
      -- Cross Dock PickSlip   
      IF ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP'  
      BEGIN
         SET @cSQL =   
         ' SELECT PD.PickDetailKey, PD.OrderKey, PD.OrderLineNumber ' +
         ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +
         ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.PickDetailKey = RKL.PickDetailKey) ' 
         IF @cPickDetailCartonID <> ''
            SET @cSQL = @cSQL + ' JOIN #CartonID t ON ( PD.' + @cPickDetailCartonID + ' = t.CartonID) ' 
         SET @cSQL = @cSQL +
         ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +
         ' AND   PD.StorerKey = @cStorerKey ' +
         ' AND ( PD.Status = @cPickConfirmStatus OR PD.Status = ''5'') ' 
      END
      -- Discrete PickSlip
      ELSE IF ISNULL(@cOrderKey, '') <> '' 
      BEGIN
          SET @cSQL =
         ' SELECT PD.PickDetailKey, PD.OrderKey, PD.OrderLineNumber ' +
         ' FROM dbo.PickDetail PD WITH (NOLOCK)  ' 
         IF @cPickDetailCartonID <> ''
            SET @cSQL = @cSQL + ' JOIN #CartonID t ON ( PD.' + @cPickDetailCartonID + ' = t.CartonID) ' 
         SET @cSQL = @cSQL +
         ' WHERE PD.OrderKey = @cOrderKey ' +
         ' AND   PD.StorerKey = @cStorerKey ' +
         ' AND ( PD.Status = @cPickConfirmStatus OR PD.Status = ''5'') ' 
      END
      -- Conso PickSlip
      ELSE
      BEGIN
         SET @cSQL =
         ' SELECT PD.PickDetailKey, PD.OrderKey, PD.OrderLineNumber ' +
         ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
         ' JOIN dbo.PickDetail PD (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)   ' 
         IF @cPickDetailCartonID <> ''
            SET @cSQL = @cSQL + ' JOIN #CartonID t ON ( PD.' + @cPickDetailCartonID + ' = t.CartonID) ' 
         SET @cSQL = @cSQL +
         ' WHERE LPD.LoadKey = @cLoadKey ' +
         ' AND   PD.StorerKey = @cStorerKey ' +
         ' AND ( PD.Status = @cPickConfirmStatus OR PD.Status = ''5'') ' 
      END
      -- Other Pickslip
      BEGIN
         SET @cSQL =
         ' SELECT PD.PickDetailKey, PD.OrderKey, PD.OrderLineNumber ' +
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' 
         IF @cPickDetailCartonID <> ''
            SET @cSQL = @cSQL + ' JOIN #CartonID t ON ( PD.' + @cPickDetailCartonID + ' = t.CartonID) ' 
         SET @cSQL = @cSQL +
         ' WHERE PD.PickSlipNo = @cPickSlipNo ' +
         ' AND   PD.StorerKey = @cStorerKey ' +
         ' AND ( PD.Status = @cPickConfirmStatus OR PD.Status = ''5'') ' 
      END

   -- Open cursor  
   SET @cSQL =   
      ' SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' +   
         @cSQL +   
      ' OPEN @curPD '   

   SET @cSQLParam =   
      ' @curPD                CURSOR OUTPUT, ' +   
      ' @cStorerKey           NVARCHAR( 15), ' +   
      ' @cLoadKey             NVARCHAR( 10), ' +   
      ' @cOrderKey            NVARCHAR( 10), ' + 
      ' @cPickSlipNo          NVARCHAR( 10), ' + 
      ' @cPickConfirmStatus   NVARCHAR( 1),  ' +
      ' @cPickDetailCartonID  NVARCHAR( 20), ' +
      ' @cPD_PickDetailKey    NVARCHAR( 10) OUTPUT, ' +
      ' @cPD_OrderKey         NVARCHAR( 10) OUTPUT, ' +
      ' @cPD_OrderLineNumber  NVARCHAR( 5)  OUTPUT  ' 
  
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam  
      ,@curPD                 OUTPUT
      ,@cStorerKey  
      ,@cLoadKey   
      ,@cOrderKey 
      ,@cPickSlipNo
      ,@cPickConfirmStatus
      ,@cPickDetailCartonID
      ,@cPD_PickDetailKey     OUTPUT
      ,@cPD_OrderKey          OUTPUT
      ,@cPD_OrderLineNumber   OUTPUT
      
      FETCH NEXT FROM @curPD INTO @cPD_PickDetailKey, @cPD_OrderKey, @cPD_OrderLineNumber
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @cSQL =
         ' UPDATE dbo.PickDetail SET  ' +
         '   [Status] = ''0'',        ' 
         IF @cPickDetailCartonID <> ''
            SET @cSQL = @cSQL + @cPickDetailCartonID + ' = '''', ' 
         SET @cSQL = @cSQL +
         '   EditWho = SUSER_SNAME(), ' +
         '   EditDate = GETDATE()     ' +
         ' WHERE PickDetailKey = @cPickDetailKey  ' +
         ' SET @nErrNo = @@ERROR '

         SET @cSQLParam =   
            ' @cPickDetailKey       NVARCHAR( 10), ' +
            ' @cPickDetailCartonID  NVARCHAR( 10), ' +
            ' @nErrNo               INT  OUTPUT  ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam
         ,@cPD_PickDetailKey
         ,@cPickDetailCartonID
         ,@nErrNo    OUTPUT
   
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PICK FAIL
            GOTO RollBackTran
         END

         IF NOT EXISTS ( SELECT 1 FROM #ORDERS WHERE OrderKey = @cPD_OrderKey AND OrderLineNumber = @cPD_OrderLineNumber)
            INSERT INTO #ORDERS(OrderKey, OrderLineNumber) VALUES (@cPD_OrderKey, @cPD_OrderLineNumber)
         
         FETCH NEXT FROM @curPD INTO @cPD_PickDetailKey, @cPD_OrderKey, @cPD_OrderLineNumber
      END
      CLOSE @curPD
      DEALLOCATE @curPD

      -- Update orderdetail
      SET @curPD = CURSOR FOR
      SELECT t.OrderKey, t.OrderLineNumber  
      FROM #ORDERS t 
      ORDER BY t.OrderKey, t.OrderLineNumber
      OPEN @curPD  
      FETCH NEXT FROM @curPD INTO @cOrderKey, @cOrderLineNumber  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         -- Update orderdetail back to allocated state  
         UPDATE dbo.OrderDetail WITH (ROWLOCK) SET   
            [Status] = CASE WHEN ( QtyAllocated > 0) AND ( QtyPicked > 0)  AND ( QtyAllocated <> QtyPicked) THEN '3'  
                            WHEN ( OpenQty + FreeGoodQty) = ( QtyAllocated + QtyPicked + ShippedQty) THEN '2'  
                            WHEN ((OpenQty + FreeGoodQty) <> QtyAllocated + QtyPicked)  
                             AND ( QtyAllocated + QtyPicked) > 0   
                             AND ( ShippedQty = 0) THEN '1'  
                            WHEN ( QtyAllocated + ShippedQty + QtyPicked = 0) THEN '0' END,  
            EditWho = SUSER_SNAME(),
            EditDate = GETDATE(),
            TrafficCop = NULL  
         WHERE OrderKey = @cOrderKey  
         AND   OrderLineNumber = @cOrderLineNumber  
         SET @nErrNo = @@ERROR

         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PICK FAIL
            GOTO RollBackTran
         END
  
         FETCH NEXT FROM @curPD INTO @cOrderKey, @cOrderLineNumber  
      END  
      CLOSE @curPD  
      DEALLOCATE @curPD  

      -- Update orders
      SET @curPD = CURSOR FOR
      SELECT DISTINCT t.OrderKey  
      FROM #ORDERS t 
      ORDER BY t.OrderKey
      OPEN @curPD  
      FETCH NEXT FROM @curPD INTO @cOrderKey  
      WHILE @@FETCH_STATUS = 0  
      BEGIN  
         SELECT @cNewStatus = [Status], @cOrdType = Type  
         FROM dbo.Orders WITH (NOLOCK)   
         WHERE StorerKey = @cStorerKey
         AND   OrderKey = @cOrderKey  
     
         SET @cNewStatus = ''  
         EXECUTE dbo.ispGetOrderStatus   
            @c_OrderKey    = @cOrderKey  
           ,@c_StorerKey   = @cStorerKey  
           ,@c_OrdType     = @cOrdType  
           ,@c_NewStatus   = @cNewStatus  OUTPUT  
           ,@b_Success     = @bSuccess    OUTPUT  
           ,@n_err         = @nErrNo      OUTPUT  
           ,@c_errmsg      = @cErrMsg     OUTPUT  
  
         IF @cNewStatus = ''  
         BEGIN      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Get status err  
            GOTO RollBackTran  
         END    
  
         UPDATE dbo.ORDERS SET    
            [Status] = @cNewStatus,  
            TrafficCop = NULL  
         WHERE StorerKey = @cStorerKey  
         AND   OrderKey = @cOrderKey  
         SET @nErrNo = @@ERROR

         IF @@ERROR <> 0      
         BEGIN      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd orders err  
            GOTO RollBackTran  
         END    
         
         FETCH NEXT FROM @curPD INTO @cOrderKey
      END 
      CLOSE @curPD  
      DEALLOCATE @curPD  
      
      IF EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) 
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   ISNULL( ScanOutDate, '') <> '')
      BEGIN
         UPDATE dbo.PickingInfo WITH (ROWLOCK) SET   
            ScanOutDate = NULL  
         WHERE PickSlipNo = @cPickSlipNo  
         SET @nErrNo = @@ERROR

         IF @@ERROR <> 0      
         BEGIN      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd ScanOut Err  
            GOTO RollBackTran  
         END  
      END
   END
   
   
   COMMIT TRAN rdt_Unpack_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Unpack_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO