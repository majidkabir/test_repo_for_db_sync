SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_529ExtUpdateSP02                                */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Split PickDetail                                            */  
/*                                                                      */  
/* Called from: 3                                                       */  
/*    1. From PowerBuilder                                              */  
/*    2. From scheduler                                                 */  
/*    3. From others stored procedures or triggers                      */  
/*    4. From interface program. DX, DTS                                */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 11-Feb-2014 1.0  ChewKP      Created                                 */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_529ExtUpdateSP02] (  
   @cFromDropID       NVARCHAR( 20),  
   @cToDropID         NVARCHAR( 20),  
   @cFromLabelNo      NVARCHAR( 20),
   @cToLabelNo        NVARCHAR( 20),
   @nQTY_Move         INT,  
   @cStorerKey        NVARCHAR( 15),  
   @cOldPickDetailKey NVARCHAR( 10),  
   @cLangCode         VARCHAR (3),  
   @nErrNo            INT           OUTPUT,   
   @cErrMsg           NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max  
) AS  
BEGIN  
   SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE   
      @b_success         INT,  
      @n_err             INT,  
      @c_errmsg          NVARCHAR( 255),  
      @cPickDetailKey    NVARCHAR( 10),  
      @cPickSlipNo       NVARCHAR( 10), 
      @cOrderKey         NVARCHAR( 10), 
      @cLoadKey          NVARCHAR( 10), 
      @cOrderLineNumber  NVARCHAR(  5)  
   
   
   -- (ChewKP01)
   SET @cPickSlipNo       = ''
   SET @cOrderKey         = ''
   SET @cLoadKey          = ''
   SET @cOrderLineNumber  = ''
   
  
   SET @b_success = 0  
     
   EXECUTE dbo.nspg_GetKey  
      'PICKDETAILKEY',   
      10 ,  
      @cPickDetailKey  OUTPUT,  
      @b_success        OUTPUT,  
      @n_err            OUTPUT,  
      @c_errmsg         OUTPUT  
     
   IF @b_success <> 1  
   BEGIN  
      SET @nErrNo = 85051  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetDetKeyfail  
      GOTO Fail              
   END  
  
   BEGIN TRAN  
  
   --split pickdetail  
   INSERT INTO dbo.PICKDETAIL  
   (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, Storerkey, Sku, AltSku,   
   UOM, UOMQty, Qty, QtyMoved, Status, DropID, Loc, ID, PackKey, UpdateSource,   
   CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,   
   WaveKey, EffectiveDate, TrafficCop, ArchiveCop, OptimizeCop, ShipFlag, PickSlipNo)  
   SELECT @cPickDetailKey AS PickDetailKey, @cToLabelNo, PickHeaderKey, OrderKey, OrderLineNumber, Lot, Storerkey, Sku, AltSku,   
   UOM, UOMQty, @nQTY_Move AS QTY, QtyMoved, [STATUS] AS Status, @cToDropID AS DropID, Loc, ID, PackKey, UpdateSource,   
   CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,   
   WaveKey, EffectiveDate, TrafficCop, ArchiveCop, '1', ShipFlag, PickSlipNo   
   FROM dbo.PickDetail WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey  
      AND CaseID = @cFromLabelNo  
      AND PickDetailKey = @cOldPickDetailKey  
  
--   UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
--   Status = '5', -- coz the insert trigger on pickdetail force not to accept STATUS equal to PICKED, when inserted  
--   Trafficcop = NULL     
--   WHERE StorerKey = @cStorerKey  
--      AND DropID = @cFromDropID  
--      AND PickDetailKey = @cPickDetailKey  
  
   UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
   Qty = Qty - @nQTY_Move,  
   TrafficCop = NULL  
  WHERE StorerKey = @cStorerKey  
      AND CaseID = @cFromLabelNo
      AND PickDetailKey = @cOldPickDetailKey  
  
   IF @@ERROR = 0  
      COMMIT TRAN  
   ELSE  
   BEGIN  
      ROLLBACK TRAN  
      SET @nErrNo = 85052  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPDtlFail  
      GOTO Fail  
   END  
   
   --Insert RefKeyLookup (ChewKP01) 
--   BEGIN TRAN 
--      
--   SELECT  @cPickSlipNo      = PD.PickslipNo 
--          ,@cOrderKey        = PD.OrderKey
--          ,@cOrderLineNumber = PD.OrderLineNumber
--          ,@cLoadKey         = O.LoadKey
--   FROM dbo.PickDetail PD WITH (NOLOCK)
--   INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
--   WHERE PD.PickDetailKey = @cPickDetailKey
--     AND PD.StorerKey     = @cStorerKey
--   
--   
--   INSERT INTO RefKeyLooKup (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, LoadKey)
--   VALUES (@cPickDetailKey , @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadKey)
--   
--   IF @@ERROR = 0  
--      COMMIT TRAN  
--   ELSE  
--   BEGIN  
--      ROLLBACK TRAN  
--      SET @nErrNo = 63887  
--      SET @cErrMsg = rdt.rdtgetmessage( 63887, @cLangCode, 'DSP') -- UpdRefKeyFail
--      GOTO Fail  
--   END  
   
     
   Fail:  
  
END

GO