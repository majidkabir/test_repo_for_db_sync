SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_837ExtUpd01                                     */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Update pickdetail status                                    */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2020-04-27  1.0  James       WMS-13005. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_837ExtUpd01]
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT, 
   @nInputKey      INT, 
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15), 
   @cPickSlipNo    NVARCHAR( 10), 
   @cFromDropID    NVARCHAR( 20), 
   @cFromSKU       NVARCHAR( 20), 
   @nCartonNo      INT, 
   @cLabelNo       NVARCHAR( 20), 
   @tExtUpdate     VariableTable READONLY,  
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 10)
   DECLARE @cPD_OrderKey         NVARCHAR( 10) = ''
   DECLARE @cPD_OrderLineNumber  NVARCHAR( 5) = ''
   DECLARE @cPD_PickDetailKey    NVARCHAR( 10)
   DECLARE @cOrderLineNumber     NVARCHAR( 5)
   DECLARE @cNewStatus           NVARCHAR( 10)  
   DECLARE @cOrdType             NVARCHAR( 10)  
   DECLARE @bSuccess             INT  
   DECLARE @curPD       CURSOR

   IF OBJECT_ID('tempdb..#ORDERS') IS NOT NULL  
      DROP TABLE #ORDRES

   CREATE TABLE #ORDERS  (  
      RowRef            BIGINT IDENTITY(1,1)  Primary Key,  
      OrderKey          NVARCHAR( 10),
      OrderLineNumber   NVARCHAR( 5))  

   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_837ExtUpd01 -- For rollback or commit only our own transaction

   IF @nStep = 3  -- Confirm unpack
   BEGIN
   -- Update pickdetail
      SELECT @cZone = Zone, 
             @cLoadKey = ExternOrderKey,
             @cOrderKey = OrderKey
      FROM dbo.PickHeader WITH (NOLOCK)     
      WHERE PickHeaderKey = @cPickSlipNo  
      
      -- Cross Dock PickSlip   
      IF ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP'  
      BEGIN
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT PD.PickDetailKey, PD.OrderKey, PD.OrderLineNumber 
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK) 
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON ( PD.PickDetailKey = RKL.PickDetailKey) 
         WHERE RKL.PickSlipNo = @cPickSlipNo 
         AND   PD.StorerKey = @cStorerKey 
         AND   PD.Status = '5'
      END
      -- Discrete PickSlip
      ELSE IF ISNULL(@cOrderKey, '') <> '' 
      BEGIN
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey, PD.OrderKey, PD.OrderLineNumber 
         FROM dbo.PickDetail PD WITH (NOLOCK)  
         WHERE PD.OrderKey = @cOrderKey 
         AND   PD.StorerKey = @cStorerKey 
         AND   PD.Status = '5'
      END
      -- Conso PickSlip
      ELSE
      BEGIN
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT PD.PickDetailKey, PD.OrderKey, PD.OrderLineNumber 
          FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
          JOIN dbo.PickDetail PD (NOLOCK) ON ( PD.OrderKey = LPD.OrderKey)   
          WHERE LPD.LoadKey = @cLoadKey 
          AND   PD.StorerKey = @cStorerKey 
          AND   PD.Status = '5'
      END
      -- Other Pickslip
      BEGIN
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT PD.PickDetailKey, PD.OrderKey, PD.OrderLineNumber 
          FROM dbo.PickDetail PD WITH (NOLOCK) 
          WHERE PD.PickSlipNo = @cPickSlipNo 
          AND   PD.StorerKey = @cStorerKey 
          AND   PD.Status = '5'
      END

      -- Open cursor  
      OPEN @curPD 
      FETCH NEXT FROM @curPD INTO @cPD_PickDetailKey, @cPD_OrderKey, @cPD_OrderLineNumber
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE dbo.PickDetail SET 
            [Status] = '0', 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE()     
          WHERE PickDetailKey = @cPD_PickDetailKey  
          SET @nErrNo = @@ERROR 
   
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
   END

   COMMIT TRAN rdt_837ExtUpd01
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_837ExtUpd01 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO