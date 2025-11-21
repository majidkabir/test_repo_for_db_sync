SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_MoveByDropID_SplitPickDetail                    */  
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
/* 03-Mar-2008 1.0  James       Created                                 */  
/* 31-Dec-2011 1.1  Shong       Insert with OptimizeCop to stop fire    */
/*                              Trigger                                 */  
/* 29-Mar-2012 1.2  ChewKP      Insert RefKeyLookup (ChewKP01)          */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_MoveByDropID_SplitPickDetail] (  
   @cFromDropID       NVARCHAR( 20),  
   @cToDropID         NVARCHAR( 20),  
   @nQTY_Move         INT,  
   @cStorerKey        NVARCHAR( 15),  
   @cOldPickDetailKey    NVARCHAR( 10),  
   @cLangCode         VARCHAR (3),  
   @nErrNo            INT          OUTPUT,   
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
      @cPickSlipNo       NVARCHAR( 10), -- (ChewKP01)
      @cOrderKey         NVARCHAR( 10), -- (ChewKP01)
      @cLoadKey          NVARCHAR( 10), -- (ChewKP01)
      @cOrderLineNumber  NVARCHAR(  5)  -- (ChewKP01)
   
   
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
      SET @nErrNo = 63885  
      SET @cErrMsg = rdt.rdtgetmessage( 63885, @cLangCode, 'DSP') -- GetDetKey fail  
      GOTO Fail              
   END  
  
   BEGIN TRAN  
  
   --split pickdetail  
   INSERT INTO dbo.PICKDETAIL  
   (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, Storerkey, Sku, AltSku,   
   UOM, UOMQty, Qty, QtyMoved, Status, DropID, Loc, ID, PackKey, UpdateSource,   
   CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,   
   WaveKey, EffectiveDate, TrafficCop, ArchiveCop, OptimizeCop, ShipFlag, PickSlipNo)  
   SELECT @cPickDetailKey AS PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, Storerkey, Sku, AltSku,   
   UOM, UOMQty, @nQTY_Move AS QTY, QtyMoved, [STATUS] AS Status, @cToDropID AS DropID, Loc, ID, PackKey, UpdateSource,   
   CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,   
   WaveKey, EffectiveDate, TrafficCop, ArchiveCop, '1', ShipFlag, PickSlipNo   
   FROM dbo.PickDetail WITH (NOLOCK)   
   WHERE StorerKey = @cStorerKey  
      AND DropID = @cFromDropID  
      AND PickDetailKey = @cOldPickDetailKey  
  
--   UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
--   Status = '5', -- coz the insert trigger on pickdetail force not to accept STATUS equal to PICKED, when inserted  
--   Trafficcop = NULL     
--   WHERE StorerKey = @cStorerKey  
--      AND DropID = @cFromDropID  
--      AND PickDetailKey = @cPickDetailKey  
  
   UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
   Qty = Qty - @nQTY_Move,  
   CartonGroup = 'M',  
   TrafficCop = NULL  
  WHERE StorerKey = @cStorerKey  
      AND DropID = @cFromDropID  
      AND PickDetailKey = @cOldPickDetailKey  
  
   IF @@ERROR = 0  
      COMMIT TRAN  
   ELSE  
   BEGIN  
      ROLLBACK TRAN  
      SET @nErrNo = 63886  
      SET @cErrMsg = rdt.rdtgetmessage( 63886, @cLangCode, 'DSP') -- Upd PDtl Fail  
      GOTO Fail  
   END  
   
   --Insert RefKeyLookup (ChewKP01) 
   BEGIN TRAN 
      
   SELECT  @cPickSlipNo      = PD.PickslipNo 
          ,@cOrderKey        = PD.OrderKey
          ,@cOrderLineNumber = PD.OrderLineNumber
          ,@cLoadKey         = O.LoadKey
   FROM dbo.PickDetail PD WITH (NOLOCK)
   INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
   WHERE PD.PickDetailKey = @cPickDetailKey
     AND PD.StorerKey     = @cStorerKey
   
   
   INSERT INTO RefKeyLooKup (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, LoadKey)
   VALUES (@cPickDetailKey , @cPickSlipNo, @cOrderKey, @cOrderLineNumber, @cLoadKey)
   
   IF @@ERROR = 0  
      COMMIT TRAN  
   ELSE  
   BEGIN  
      ROLLBACK TRAN  
      SET @nErrNo = 63887  
      SET @cErrMsg = rdt.rdtgetmessage( 63887, @cLangCode, 'DSP') -- UpdRefKeyFail
      GOTO Fail  
   END  
   
     
   Fail:  
  
END

GO