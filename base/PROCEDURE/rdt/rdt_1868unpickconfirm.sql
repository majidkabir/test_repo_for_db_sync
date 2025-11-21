SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1868UnpickConfirm                               */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date         Rev   Author      Purposes                              */
/* 2024-11-05   1.0   TLE109      FCR-917 Serial Unpack and Unpick      */
/************************************************************************/


CREATE   PROC rdt.rdt_1868UnpickConfirm (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cSerialNo        NVARCHAR( 100),
   @cPickSlipNo      NVARCHAR( 20),
   @cOrderKey        NVARCHAR( 20),
   @cPickDetailKey   NVARCHAR( 20),
   @cSKU             NVARCHAR( 40),
   @cToLOC           NVARCHAR( 20),
   @cLoadKey         NVARCHAR( 20),
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
   @cUnPickConfirmSP NVARCHAR( 20),
   @nTranCount       INT,
   @cSQL             NVARCHAR( MAX),
   @cSQLParam        NVARCHAR( MAX) 

   

   SET @nTranCount = @@TRANCOUNT

   SET @cUnPickConfirmSP = rdt.RDTGetConfig( @nFunc, 'UnPickConfirmSP', @cStorerKey)
   IF @cUnPickConfirmSP = '0'
   BEGIN
      SET @cUnPickConfirmSP = ''
   END
-------------------------------------------Customer---------------------------------------------

   IF @cUnPickConfirmSP <> '' AND EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cUnPickConfirmSP AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cUnPickConfirmSP) +
      ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
      ' @cSerialNo, @cPickSlipNo, @cOrderKey, @cPickDetailKey, @cSKU, @cToLOC, @cLoadKey, ' +
      ' @nErrNo OUTPUT, @cErrMsg OUTPUT ' 

      SET @cSQLParam = 
      ' @nMobile        INT,           ' +
      ' @nFunc          INT,           ' +
      ' @cLangCode      NVARCHAR( 3),  ' +
      ' @nStep          INT,           ' +
      ' @nInputKey      INT,           ' +
      ' @cFacility      NVARCHAR( 5),  ' +
      ' @cStorerKey     NVARCHAR( 15), ' +
      ' @cSerialNo      NVARCHAR( 100),' +
      ' @cPickSlipNo    NVARCHAR( 20), ' + 
      ' @cOrderKey      NVARCHAR( 20), ' +
      ' @cPickDetailKey NVARCHAR( 20), ' +
      ' @cSKU           NVARCHAR( 40), ' +
      ' @cToLOC         NVARCHAR( 20), ' +
      ' @cLoadKey       NVARCHAR( 20), ' +
      ' @nErrNo         INT,           ' +
      ' @cErrMsg        NVARCHAR( 20)  ' 

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
         @cSerialNo, @cPickslipNo, @cOrderKey, @cPickDetailKey, @cSKU, @cToLOC, @cLoadKey,
         @nErrNo OUTPUT, @cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      END
      GOTO Quit 
   END



-------------------------------------------Standard---------------------------------------------

   DECLARE
   @nCartonNo      INT,
   @cFromLoc       NVARCHAR( 20),
   @cFromID        NVARCHAR( 36),
   @cDropID        NVARCHAR( 40),
   @cLabelNo       NVARCHAR( 20),
   @cLabelLine     NVARCHAR( 10),
   @cOrderLineNumber  NVArCHAR( 5)

   SET @cFromLOC = ''
   SET @cFromID = ''
   SET @cDropID = ''
   SET @cLabelNo = ''

   BEGIN TRAN
   SAVE TRAN tran_SerialUnpick

   IF @cOrderKey = '' AND @cLoadKey <> ''
   BEGIN
      SELECT TOP 1
         @cFromLOC       = PD.Loc,
         @cFromID        = PD.ID,
         @cDropID        = PD.DropID,
         @cOrderLineNumber = PD.OrderLineNumber,
         @cOrderKey = LPD.OrderKey
      FROM dbo.LoadPlanDetail AS LPD WITH(NOLOCK)
      INNER JOIN dbo.PICKDETAIL AS PD WITH(NOLOCK) ON LPD.OrderKey = PD.OrderKey
      WHERE LPD.LoadKey = @cLoadKey AND PD.StorerKey = @cStorerKey 
         AND PD.PickDetailKey = @cPickDetailKey AND PD.Sku = @cSKU 
         AND PD.Qty > 0
      ORDER BY PD.AddDate ASC
   END
   ELSE
   BEGIN
      SELECT TOP 1
         @cFromLOC       = Loc,
         @cFromID        = ID,
         @cDropID        = DropID,
         @cOrderLineNumber = OrderLineNumber
      FROM dbo.PICKDETAIL WITH(NOLOCK)
      WHERE StorerKey = @cStorerKey  AND OrderKey = @cOrderKey
         AND PickDetailKey = @cPickDetailKey AND Sku = @cSKU 
         AND Qty > 0
      ORDER BY AddDate ASC
   END




   IF @cFromLOC = ''
   BEGIN
      SET @nErrNo = 228266
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  --228266^From LOC Not Exists
      GOTO RollBackTran
   END


   UPDATE dbo.PICKDETAIL WITH(ROWLOCK)
   SET Qty = Qty - 1
   WHERE StorerKey = @cStorerKey AND PickDetailKey = @cPickDetailKey
      AND OrderKey = @cOrderKey AND Qty > 0
   SET @nErrNo = @@ERROR
   IF @nErrNo <> 0
   BEGIN
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      GOTO RollBackTran
   END

   DELETE FROM dbo.PICKDETAIL
   WHERE StorerKey = @cStorerKey AND PickDetailKey = @cPickDetailKey
      AND OrderKey = @cOrderKey AND Qty = 0
   SET @nErrNo = @@ERROR
   IF @nErrNo <> 0
   BEGIN
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      GOTO RollBackTran
   END

   UPDATE dbo.PickingInfo WITH(ROWLOCK)
   SET ScanOutDate = NULL
   WHERE PickSlipNo = @cPickSlipNo
   SET @nErrNo = @@ERROR
   IF @nErrNo <> 0
   BEGIN
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      GOTO RollBackTran
   END



   EXECUTE rdt.rdt_Move
      @nMobile     = @nMobile,    
      @cLangCode   = @cLangCode,    
      @nErrNo      = @nErrNo  OUTPUT,    
      @cErrMsg     = @cErrMsg OUTPUT,
      @cSourceType = 'rdt_1868UnpickConfirm',
      @cStorerKey  = @cStorerKey,
      @cFacility   = @cFacility,    
      @cFromLOC    = @cFromLOC,    
      @cToLOC      = @cToLOC,    
      @cFromID     = @cFromID,    
      @cSKU        = @cSKU,
      @nQTY        = 1, 
      @nFunc       = @nFunc,    
      @cOrderKey   = @cOrderKey,    
      @cDropID     = @cDropID
   IF @nErrNo <> 0       
   BEGIN
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      GOTO RollBackTran
   END

   -- OrderDetail's status should be 0,5 no need update to 1,2,3 
   -- UPDATE dbo.OrderDetail WITH (ROWLOCK)
   -- SET [Status] = CASE WHEN ( QtyAllocated > 0) AND ( QtyPicked > 0)  AND ( QtyAllocated <> QtyPicked) THEN '3' 
   --    WHEN (OpenQty +FreeGoodQty) = (QtyAllocated+QtyPicked+ShippedQty) THEN '2' 
   --    WHEN ((OpenQty + FreeGoodQty) <> QtyAllocated + QtyPicked) AND ( QtyAllocated + QtyPicked) > 0  AND ( ShippedQty = 0) THEN '1' 
   --    WHEN ( QtyAllocated + ShippedQty + QtyPicked = 0) THEN '0' END, 
   -- EditWho = SUSER_SNAME(),
   -- EditDate = GETDATE(),
   -- TrafficCop = NULL
   -- WHERE OrderKey = @cOrderKey AND   OrderLineNumber = @cOrderLineNumber
   -- SET @nErrNo = @@ERROR
   -- IF @nErrNo <> 0
   -- BEGIN
   --    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
   --    GOTO RollBackTran
   -- END

   COMMIT TRAN tran_SerialUnpick
   
   GOTO Quit

  

RollBackTran:
   ROLLBACK TRAN tran_SerialUnpick
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO