SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: Flow thru receive carton                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2014-02-27 1.0  Ung      SOS302984 Created                           */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_Flowthru_CartonPick] (
   @nMobile    INT,
   @nFunc      INT, 
   @cLangCode  NVARCHAR( 3),
   @cUserName  NVARCHAR( 18),
   @cFacility  NVARCHAR( 5),
   @cStorerkey NVARCHAR( 15),
   @cOrderKey  NVARCHAR( 15),
   @cCartonID  NVARCHAR( 18),
   @cSKU       NVARCHAR( 18), 
   @cLOT       NVARCHAR( 10), 
   @cLOC       NVARCHAR( 10), 
   @cID        NVARCHAR( 18), 
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @cPackKey    NVARCHAR(10)
   DECLARE @cUOM        NVARCHAR(10)

   SET @cPackKey = ''
   SET @cUOM     = ''

   -- Get SKU info
   SELECT @cPackKey = PackKey FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
   SELECT @cUOM = PackUOM3 FROM Pack WITH (NOLOCK) WHERE PackKey = @cPackKey

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN
   SAVE TRAN rdt_Flowthru_CartonPick
   
   /*-------------------------------------------------------------------------------

                                     OrderDetail

   -------------------------------------------------------------------------------*/
   DECLARE @cOrderLineNumber NVARCHAR(5)
   
   -- Get OrderDetail info
   SET @cOrderLineNumber = ''         
   SELECT @cOrderLineNumber = OrderLineNumber 
   FROM dbo.OrderDetail WITH (NOLOCK) 
   WHERE OrderKey = @cOrderKey
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU

   IF @cOrderLineNumber = ''
   BEGIN
      -- Get next OrderLineNumber
      SELECT @cOrderLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( OrderLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
      FROM dbo.OrderDetail WITH (NOLOCK)  
      WHERE OrderKey = @cOrderKey 

      -- Insert Orderdetail
      INSERT INTO OrderDetail (OrderKey, OrderLineNumber, StorerKey, SKU, OpenQty, UOM, PackKey)
      VALUES (@cOrderKey, @cOrderLineNumber, @cStorerKey, @cSKU, 1, @cUOM, @cPackKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 85551
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS ORDTL FAIL
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      -- Update OrderDetail
      UPDATE dbo.OrderDetail WITH (ROWLOCK) SET 
         OpenQty = OpenQty + 1
      WHERE OrderKey = @cOrderKey
         AND OrderLineNumber = @cOrderLineNumber
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 85552
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD ORDTL FAIL
         GOTO RollBackTran
      END       
   END

   /*-------------------------------------------------------------------------------

                                     PickDetail

   -------------------------------------------------------------------------------*/
   DECLARE @cPickDetailKey NVARCHAR(10)
   DECLARE @bSuccess INT

   SET @cPickDetailKey = ''
   SET @bSuccess = 0
   EXECUTE nspg_getkey
      'PickDetailKey',
      10,
      @cPickDetailKey OUTPUT,
      @bSuccess       OUTPUT,  
      @nErrNo         OUTPUT,  
      @cErrMsg        OUTPUT  
   IF NOT @bSuccess = 1  
   BEGIN  
      SET @nErrNo = 85553
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GET PDKEY FAIL
      GOTO RollBackTran
   END  
   
   -- Insert PickDetail
   INSERT INTO PickDetail (PickDetailKey, PickHeaderKey, OrderKey, OrderLineNumber, StorerKey, SKU, PackKey, UOM, UOMQty, Qty, Status, LOT, LOC, ID)
   VALUES (@cPickDetailKey, '', @cOrderKey, @cOrderLineNumber, @cStorerKey, @cSKU, @cPackKey, '6', '1', 1, '0', @cLOT, @cLOC, @cID)
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 85554
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDTL FAIL
      GOTO RollBackTran
   END  
   
   -- Confirm pick
   UPDATE PickDetail SET
      Status = '5'
   WHERE PickDetailKey = @cPickDetailKey
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 85555
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDTL FAIL
      GOTO RollBackTran
   END  
   
   
   COMMIT TRAN rdt_Flowthru_CartonPick

   -- Logging
   EXEC RDT.rdt_STD_EventLog  
      @cActionType = '3', -- Pick
      @cUserID     = @cUserName,  
      @nMobileNo   = @nMobile,  
      @nFunctionID = @nFunc,  
      @cFacility   = @cFacility,  
      @cOrderKey   = @cOrderKey, 
      @cStorerKey  = @cStorerkey, 
      @cSKU        = @cSKU, 
      @cLocation   = @cLOC, 
      @cLOT        = @cLOT, 
      @cID         = @cID, 
      @cLottable02 = @cCartonID, 
      @nQTY        = 1

   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_Flowthru_CartonPick

Quit:
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN rdt_Flowthru_CartonPick 

GO