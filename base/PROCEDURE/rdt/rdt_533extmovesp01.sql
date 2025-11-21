SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_533ExtMoveSP01                                  */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Move by PaclDetail.LabelNo                                  */
/*                                                                      */
/* Modifications log:                                                   */
/* Date       Rev  Author   Purposes                                    */
/* 2019-03-05 1.0  James    WMS8054 - Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_533ExtMoveSP01] (
   @nMobile      INT,
   @nFunc        INT, 
   @cLangCode    NVARCHAR( 3), 
   @cUserName    NVARCHAR( 18), 
   @cFacility    NVARCHAR( 5), 
   @cStorerKey   NVARCHAR( 15),
   @cPickSlipNo  NVARCHAR( 10),
   @cFromLabelNo NVARCHAR( 20),
   @cToLabelNo   NVARCHAR( 20),
   @cCartonType  NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20),
   @nQTY_Move    INT,
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nQTY           INT
   DECLARE @nQty_Bal       INT
   DECLARE @nTranCount     INT
   DECLARE @nRowCount      INT

   DECLARE @nFromCartonNo  INT
   DECLARE @cFromLabelLine NVARCHAR( 5)
   DECLARE @cFromSKU       NVARCHAR( 20)
   DECLARE @nFromQTY       INT

   DECLARE @nToCartonNo    INT
   DECLARE @cToLabelLine   NVARCHAR( 5)

   DECLARE @nCountPS       INT
   DECLARE @nPackQty       INT

   SET @nErrNo = 0
   SET @cErrMsg = ''


   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_533ExtMoveSP01

   SET @nFromCartonNo = 0
   SELECT @nFromCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cFromLabelNo

   SET @nCountPS = 0
   SELECT
      @nCountPS = COUNT( DISTINCT PH.PickSlipNo)
   FROM dbo.PackHeader PH WITH (NOLOCK)
      INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   WHERE PH.StorerKey = @cStorerKey
      AND PD.LabelNo = @cToLabelNo

   SET @nToCartonNo = 0
   SELECT @nToCartonNo = CartonNo
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo 
   AND   LabelNo    = @cToLabelNo 
   AND   StorerKey = @cStorerKey
                
   -- If Carton to Carton Move, which is SKU = BLANK  
   -- Just update the UCC Label Number. The rest of the information remain  
   IF ISNULL(RTRIM(@cSKU),'') = ''  
   BEGIN  
      DECLARE CUR_PACKD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT CartonNo, LabelLine
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo 
      AND   LabelNo    = @cFromLabelNo 
      ORDER BY 2
      OPEN CUR_PACKD
      FETCH NEXT FROM CUR_PACKD INTO @nFromCartonNo, @cFromLabelLine
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SELECT @cToLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   PickSlipNo = @cPickSlipNo
         AND   CartonNo = @nToCartonNo
         AND   LabelNo = @cToLabelNo

         UPDATE PD  
            SET CartonNo = @nToCartonNo,
                LabelNo = @cToLabelNo,  
                LabelLine = @cToLabelLine,
                ArchiveCop = NULL  
         FROM dbo.PackDetail PD  
         WHERE PD.PickSlipNo = @cPickSlipNo  
            AND PD.LabelNo    = @cFromLabelNo  
            AND PD.CartonNo = @nFromCartonNo
            AND PD.LabelLine = @cFromLabelLine
            AND PD.StorerKey = @cStorerKey  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 135401  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackD Fail'  
            GOTO RollBackTran  
         END  

         FETCH NEXT FROM CUR_PACKD INTO @nFromCartonNo, @cFromLabelLine
      END
      CLOSE CUR_PACKD
      DEALLOCATE CUR_PACKD

      -- Update PickDetail DropID  
      UPDATE PICKDETAIL WITH (ROWLOCK)  
      SET CaseID = @cToLabelNo,  
          TrafficCop = NULL  
      WHERE PickSlipNo = @cPickSlipNo  
        AND CaseID     = @cFromLabelNo  
        AND StorerKey = @cStorerKey  

      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 135402  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickD Fail'  
         GOTO RollBackTran  
      END  
   END  
   ELSE  
   BEGIN  
      SELECT TOP 1  
            @nFromCartonNo = CartonNo,  
            @cFromLabelLine= LabelLine,  
            @cFromSKU      = SKU,  
            @nFromQTY      = QTY  
      FROM dbo.PackDetail PD WITH (NOLOCK)  
      WHERE PD.PickSlipNo = @cPickSlipNo  
         AND PD.LabelNo = @cFromLabelNo  
         AND PD.StorerKey = @cStorerKey  
         AND PD.SKU = @cSKU  
  
      IF @nToCartonNo = 0  
      BEGIN  
         -- Give From Drop ID Carton# to To Drop ID  
         SET @nToCartonNo = @nFromCartonNo  
  
         -- If From Carton no = To Carton No, Need to assign new carton# for From Carton.  
         SELECT @nFromCartonNo = IsNULL(MAX(CartonNo), 0) + 1  
         FROM   dbo.PackDetail WITH (NOLOCK)  
         WHERE  PickSlipNo = @cPickSlipNo  
  
         -- Change the From DropID Carton to new Carton#  
         UPDATE PD  
         SET CartonNo = @nFromCartonNo,  
             ArchiveCop = NULL  
         FROM dbo.PackDetail PD  
         WHERE PD.PickSlipNo = @cPickSlipNo  
            AND PD.LabelNo    = @cFromLabelNo
            AND PD.StorerKey = @cStorerKey  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 135403  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackD Fail'  
            GOTO RollBackTran  
         END  
      END  
  
      IF @nQTY_Move > @nFromQTY  
         SET @nQTY = @nFromQTY  
      ELSE  
         SET @nQTY = @nQTY_Move  

      SET @cToLabelLine = ''  
      SELECT  
         @cToLabelLine = LabelLine  
      FROM dbo.PackDetail WITH (NOLOCK)  
      WHERE PickSlipNo = @cPickSlipNo  
         AND LabelNo = @cToLabelNo  
         AND StorerKey = @cStorerKey  
         AND SKU = @cFromSKU  
  
      SET @nRowCount = @@ROWCOUNT  
  
      IF @nRowCount = 0  
      BEGIN  
         SELECT @cToLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
         FROM dbo.PackDetail (NOLOCK)  
         WHERE Pickslipno = @cPickSlipNo  
             AND CartonNo = @nToCartonNo  
  
         -- Insert to PackDetail line  
         INSERT INTO dbo.PackDetail  
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY,  
             AddWho, AddDate, EditWho, EditDate)  
         VALUES  
            (@cPickSlipNo, @nToCartonNo, @cToLabelNo, @cToLabelLine, @cStorerKey, @cFromSKU, @nQTY,  
             'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE())  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 135404  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackD Fail'  
            GOTO RollBackTran  
         END  
      END  
      ELSE  
      BEGIN  
         -- Update TO PackDetail line  
         UPDATE dbo.PackDetail SET  
            QTY = QTY + @nQTY,  
            EditWho = 'rdt.' + sUser_sName(),  
            EditDate = GETDATE()  
         WHERE PickSlipNo = @cPickSlipNo  
            AND CartonNo = @nToCartonNo  
            AND LabelNo = @cToLabelNo  
            AND LabelLine = @cToLabelLine  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 135405  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackD Fail'  
            GOTO RollBackTran  
         END   
      END  
      --- End Update To Drop ID  
  
  
      -- Update PackDetail - From DropID  
      UPDATE PackDetail SET  
         QTY = QTY - @nQTY  
      WHERE PickSlipNo = @cPickSlipNo  
         AND CartonNo = @nFromCartonNo  
         AND LabelNo = @cFromLabelNo  
         AND LabelLine = @cFromLabelLine  

      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 135406  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackD Fail'  
         GOTO RollBackTran  
      END  
  
      -- Update pickdetail DropID  
      DECLARE @nRemainQty     INT,  
              @nPickDetailQty INT,  
              @cPickDetailKey NVARCHAR(10),  
              @cPickLot       NVARCHAR(10),  
              @cPickLOC       NVARCHAR(10),  
              @cPickID        NVARCHAR(18),  
              @cOrderKey      NVARCHAR(10),  
              @cOrderLineNumber NVARCHAR(5)  
  
      SET  @nRemainQty = @nQTY_Move  
  
      DECLARE Cur_OffSet_PickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PickDetailKey, Qty, LOT, LOC, ID, OrderKey, OrderLineNumber  
         FROM   PICKDETAIL WITH (NOLOCK)  
         WHERE PickSlipNo = @cPickSlipNo  
           AND CaseID     = @cFromLabelNo  
           AND StorerKey  = @cStorerKey  
           AND SKU        = @cSKU  
         ORDER BY CASE WHEN  Qty = @nRemainQty THEN 1  
                       WHEN  Qty > @nRemainQty THEN 2  
                       ELSE  9  
                  END,  
                  Qty  
  
      OPEN Cur_OffSet_PickDetail  
      FETCH NEXT FROM Cur_OffSet_PickDetail INTO @cPickDetailKey, @nPickDetailQty,  
                      @cPickLOT, @cPickLOC, @cPickID, @cOrderKey, @cOrderLineNumber  
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         IF @nRemainQty >= @nPickDetailQty  
         BEGIN  
            UPDATE PICKDETAIL WITH (ROWLOCK)  
               SET CaseID = @cToLabelNo, TrafficCop = NULL  
            WHERE PickDetailKey = @cPickDetailKey  

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 135407  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickD Fail'  
               GOTO RollBackTran  
            END  

            SET @nRemainQty = @nRemainQty - @nPickDetailQty  
         END  
         ELSE IF @nRemainQty < @nPickDetailQty  
         BEGIN  
            DECLARE   
               @b_success         INT,  
               @n_err             INT,  
               @c_errmsg          NVARCHAR( 255),  
               @cLoadKey          NVARCHAR( 10)
   
   
            -- (ChewKP01)
            SET @cPickSlipNo       = ''
            SET @cOrderKey         = ''
            SET @cLoadKey          = ''
            SET @cOrderLineNumber  = ''
   
  
            SET @b_success = 0  
     
            EXECUTE dbo.nspg_GetKey  
               'PICKDETAILKEY',   
               10 ,  
               @cPickDetailKey   OUTPUT,  
               @b_success        OUTPUT,  
               @n_err            OUTPUT,  
               @c_errmsg         OUTPUT  
     
            IF @b_success <> 1  
            BEGIN  
               SET @nErrNo = 135408  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GetDetKey fail'
               GOTO RollBackTran              
            END  
  
            --split pickdetail  
            INSERT INTO dbo.PICKDETAIL  
            (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, Storerkey, Sku, AltSku,   
            UOM, UOMQty, Qty, QtyMoved, Status, DropID, Loc, ID, PackKey, UpdateSource,   
            CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,   
            WaveKey, EffectiveDate, TrafficCop, ArchiveCop, OptimizeCop, ShipFlag, PickSlipNo)  
            SELECT @cPickDetailKey AS PickDetailKey, @cToLabelNo AS CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, Storerkey, Sku, AltSku,   
            UOM, UOMQty, @nQTY_Move AS QTY, QtyMoved, [STATUS] AS Status, DropID, Loc, ID, PackKey, UpdateSource,   
            CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,   
            WaveKey, EffectiveDate, TrafficCop, ArchiveCop, '1', ShipFlag, PickSlipNo   
            FROM dbo.PickDetail WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey  
               AND CaseID = @cFromLabelNo  
               AND PickDetailKey = @cPickDetailKey  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 135409  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickD Fail'  
               GOTO RollBackTran  
            END   

            UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
            Qty = Qty - @nQTY_Move,  
            CartonGroup = 'M',  
            TrafficCop = NULL  
           WHERE StorerKey = @cStorerKey  
               AND CaseID = @cFromLabelNo  
               AND PickDetailKey = @cPickDetailKey  
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 135410  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickD Fail'  
               GOTO RollBackTran  
            END  

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

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 135411  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsRefLK Fail'  
               GOTO RollBackTran  
            END  

            SET @nRemainQty = 0  
            BREAK  
         END -- IF @nRemainQty < @nPickDetailQty  
  
         IF @nRemainQty = 0  
            BREAK  
  
         FETCH NEXT FROM Cur_OffSet_PickDetail INTO @cPickDetailKey, @nPickDetailQty,  
                         @cPickLOT, @cPickLOC, @cPickID, @cOrderKey, @cOrderLineNumber  
  
      END  
      CLOSE Cur_OffSet_PickDetail  
      DEALLOCATE Cur_OffSet_PickDetail  
  
   END -- UPDATE  
  
   -- Check if fully offset (when by SKU)  
   IF @cSKU <> '' AND @nRemainQty <> 0  
   BEGIN  
      SET @nErrNo = 135412  
      SET @cErrMsg = rdt.rdtgetmessage( 74655, @cLangCode, 'DSP') --'OffsetError'  
      GOTO RollBackTran  
   END  
  
/*--------------------------------------------------------------------------------------------------  
  
                                             PackInfo  
  
--------------------------------------------------------------------------------------------------*/  
   DECLARE @nCartonWeight FLOAT  
   DECLARE @nCartonCube   FLOAT  
   DECLARE @nNewCartonCube   FLOAT  
  
   SELECT @nFromCartonNo = CartonNo  
   FROM dbo.PackDetail WITH (NOLOCK)  
   WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cFromLabelNo  
  
   SELECT @nToCartonNo   = CartonNo  
   FROM dbo.PackDetail WITH (NOLOCK)  
   WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cToLabelNo  
  
   -- From carton  
   IF EXISTS( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nFromCartonNo)  
   BEGIN  
      -- Recalc from carton's weight, cube  
      SELECT  
         @nCartonWeight = ISNULL( SUM( PD.QTY * SKU.STDGrossWGT), 0),  
         @nCartonCube   = ISNULL( SUM( PD.QTY * SKU.STDCube), 0),
         @nPackQty = ISNULL( SUM( Qty), 0)
      FROM dbo.PackDetail PD WITH (NOLOCK)  
         INNER JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)  
      WHERE PD.PickSlipNo = @cPickSlipNo  
         AND PD.CartonNo = @nFromCartonNo  
  
      IF NOT EXISTS( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nFromCartonNo)  
      BEGIN  
         INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, Weight, Cube)  
         --VALUES ( @cPickSlipNo, @nFromCartonNo, @nCartonWeight, @nCartonCube)  
         VALUES ( @cPickSlipNo, @nFromCartonNo, 0, 0)  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 135413  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPKInfoFail'  
            GOTO RollBackTran  
         END  
      END  
      ELSE  
      BEGIN  
         -- Update PackInfo  
         UPDATE dbo.PackInfo SET  
            Weight = 0,
            Qty = @nPackQty
         WHERE PickSlipNo = @cPickSlipNo  
            AND CartonNo = @nFromCartonNo  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 135414   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPKInfoFail'  
            GOTO RollBackTran  
         END   
      END  
   END  
   ELSE  
   BEGIN  
      DELETE dbo.PackInfo WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nFromCartonNo  

      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 135415  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelPKInfoFail'  
         GOTO RollBackTran  
      END  
   END  
  
   -- To carton  
   IF EXISTS( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nToCartonNo)  
   BEGIN  
      -- Recalc to carton's weight, cube  
      IF @nCountPS = 0
         SELECT @nNewCartonCube = Cube
         FROM dbo.Cartonization CZ WITH (NOLOCK)
         JOIN Storer ST WITH (NOLOCK) ON CZ.CartonizationGroup = ST.CartonGroup
         WHERE StorerKey = @cStorerKey
         AND   CartonType = @cCartonType

      SELECT  
         @nCartonWeight = ISNULL( SUM( PD.QTY * SKU.STDGrossWGT), 0),  
         @nCartonCube   = ISNULL( SUM( PD.QTY * SKU.STDCube), 0),
         @nPackQty = ISNULL( SUM( Qty), 0)
      FROM dbo.PackDetail PD WITH (NOLOCK)  
         INNER JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)  
      WHERE PD.PickSlipNo = @cPickSlipNo  
         AND PD.CartonNo = @nToCartonNo  
        
      IF NOT EXISTS( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nToCartonNo)  
      BEGIN  
         INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, Weight, Cube, Qty)  
         --VALUES ( @cPickSlipNo, @nToCartonNo, @nCartonWeight, @nCartonCube)  
         VALUES ( @cPickSlipNo, @nToCartonNo, 0, @nCartonCube, @nPackQty)  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 135416  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelPKInfoFail'  
            GOTO RollBackTran  
         END  
      END  
      ELSE  
      BEGIN  
         UPDATE dbo.PackInfo SET  
            --Weight = @nCartonWeight,  
            Weight = 0,
            Qty = @nPackQty
         WHERE PickSlipNo = @cPickSlipNo  
            AND CartonNo = @nToCartonNo  

         IF @@ERROR <> 0  
         BEGIN  
            SET @nErrNo = 135417  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPKInfoFail'  
            GOTO RollBackTran  
         END  
      END  
   END  
   ELSE  
   BEGIN  
      DELETE dbo.PackInfo WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nToCartonNo  

      IF @@ERROR <> 0  
      BEGIN  
         SET @nErrNo = 135418  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelPKInfoFail'  
         GOTO RollBackTran  
      END  
   END  
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_533ExtMoveSP01 -- Only rollback change made in rdt_533ExtMoveSP01
   Quit:
      -- Commit until the level we started
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN
Fail:
END

GO