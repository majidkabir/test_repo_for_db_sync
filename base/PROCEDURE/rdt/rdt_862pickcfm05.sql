SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/************************************************************************/    
/* Store procedure: rdt_862PickCfm05                                    */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Confirm pick, insert packdetail & packinfo                  */    
/*                                                                      */    
/* Called from: rdtfnc_Pick                                             */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2019-05-14 1.0  James    WMS-8909 Created                            */    
/* 2019-05-14 1.1  James    Add Loadkey in PackHeader for conso(james01)*/    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_862PickCfm05] (    
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 18),
   @cPickSlipNo   NVARCHAR( 10),
   @cDropID       NVARCHAR( 18),
   @cLOC          NVARCHAR( 10),
   @cID           NVARCHAR( 18),
   @cStorerKey    NVARCHAR( 15),
   @cSKU          NVARCHAR( 20),
   @cUOM          NVARCHAR( 10),
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @nTaskQTY      INT,
   @nPQTY         INT,
   @cUCCTask      NVARCHAR( 1),
   @cPickType     NVARCHAR( 1),
   @bSuccess      INT            OUTPUT,
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT,  -- screen limitation, 20 NVARCHAR max
   @nDebug        INT = 0
) AS    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    

   DECLARE 
      @cOrderKey           NVARCHAR( 10)     
     ,@cFacility           NVARCHAR( 5)    
     ,@cUserName           NVARCHAR( 18)    
     ,@cPackKey            NVARCHAR( 10)  
     ,@cNewPickDetailKey   NVARCHAR( 10)   
     ,@cNewPDUOM           NVARCHAR( 10)   
     ,@cSplitPDByUOM       NVARCHAR( 1)   
     ,@nNewPDUOMQty        INT  
     ,@nPDMode             INT  
     ,@nUOMQty             INT          
     ,@nInnerQty           INT   
     ,@nPDMod              INT  
     ,@b_success           INT  
     ,@nPD_Qty             INT
     ,@nCartonNo           INT
     ,@nToScanOut          INT
     ,@nConfirmQTY         INT
     ,@cPSType             NVARCHAR( 10)
     ,@cLabelNo            NVARCHAR( 20)
     ,@cLabelLine          NVARCHAR( 5)
     ,@cZone               NVARCHAR( 18)  
     ,@cPH_OrderKey        NVARCHAR( 10) 
     ,@cPH_LoadKey         NVARCHAR( 10) 
     ,@cRoute              NVARCHAR( 30)      
     ,@cConsigneekey       NVARCHAR( 18)   
     ,@cOrderRefNo         NVARCHAR( 18)
     ,@cLoadKey            NVARCHAR( 10)
     ,@cPD_ID              NVARCHAR( 18)
     ,@cPD_SKU             NVARCHAR( 20)


       
   SELECT @cFacility = Facility    
         ,@cUserName = UserName    
         ,@nFunc     = Func    
   FROM rdt.rdtMobRec WITH (NOLOCK)    
   WHERE Mobile = @nMobile  

   SELECT @cZone = Zone, 
          @cPH_OrderKey = OrderKey
   FROM dbo.PickHeader WITH (NOLOCK)     
   WHERE PickHeaderKey = @cPickSlipNo    

   SET @nErrNo = 0    
   SET @nConfirmQTY = @nPQTY

   -- Validate parameters    
   IF (@nTaskQTY IS NULL OR @nTaskQTY <= 0)    
   BEGIN    
      SET @nErrNo = 138551    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Bad TaskQTY'    
      GOTO Fail    
   END    
    
   IF (@nConfirmQTY > @nTaskQTY)    
   BEGIN    
      SET @nErrNo = 138552    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Over pick'    
      GOTO Fail    
   END    
    
   -- PickDetail in the task    
   DECLARE @tPD TABLE    
   (    
      PickDetailKey    NVARCHAR( 18) NOT NULL,     
      PD_QTY           INT NOT NULL DEFAULT (0),     
      Final_QTY        INT NOT NULL DEFAULT (0),     
      OrderKey         NVARCHAR( 10) NOT NULL, -- (ChewKP01)    
    PRIMARY KEY CLUSTERED     
    (    
     [PickDetailKey]    
    )    
   )    
   
   SET @cPSType = ''
   -- conso picklist   
   If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' 
   BEGIN    
      -- Get PickDetail in the task    
      INSERT INTO @tPD (PickDetailKey, PD_QTY, OrderKey)    
      SELECT PD.PickDetailKey, PD.QTY, PD.OrderKey    
      FROM dbo.PickHeader PH (NOLOCK)     
      JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)    
      JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
      JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)    
      WHERE PH.PickHeaderKey = @cPickSlipNo    
         AND PD.Status < '5' -- Not yet picked    
         AND PD.LOC = @cLOC    
         AND PD.ID = @cID    
         AND PD.SKU = @cSKU    
         AND PD.UOM = @cUOM    
         AND LA.Lottable01 = @cLottable01    
         AND LA.Lottable02 = @cLottable02    
         AND LA.Lottable03 = @cLottable03    
         AND IsNULL( @dLottable04, 0) = IsNULL( LA.Lottable04, 0)     
       SET @cPSType = 'CONSO'      
   END    
   ELSE  -- discrete picklist    
   BEGIN    
      IF ISNULL(@cPH_OrderKey, '') <> '' 
      BEGIN  
         -- Get PickDetail in the task    
         INSERT INTO @tPD (PickDetailKey, PD_QTY, OrderKey)    
         SELECT PD.PickDetailKey, PD.QTY, PD.OrderKey    
         FROM dbo.PickHeader PH (NOLOCK)     
            INNER JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)    
            INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)    
         WHERE PH.PickHeaderKey = @cPickSlipNo    
            AND PD.Status < '5' -- Not yet picked    
            AND PD.LOC = @cLOC    
            AND PD.ID = @cID    
            AND PD.SKU = @cSKU    
            AND PD.UOM = @cUOM 
            AND LA.Lottable01 = @cLottable01    
            AND LA.Lottable02 = @cLottable02    
            AND LA.Lottable03 = @cLottable03    
            AND IsNULL( @dLottable04, 0) = IsNULL( LA.Lottable04, 0)     

         SET @cPSType = 'DISCRETE'      
      END   
      ELSE
      BEGIN
         -- Get PickDetail in the task    
         INSERT INTO @tPD (PickDetailKey, PD_QTY, OrderKey)    
         SELECT PD.PickDetailKey, PD.QTY, PD.OrderKey    
         FROM dbo.PickHeader PH (NOLOCK)     
         INNER JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey  
         INNER JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)      
         INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)      
         WHERE PH.PickHeaderKey = @cPickSlipNo    
            AND PD.Status < '5' -- Not yet picked    
            AND PD.LOC = @cLOC    
            AND PD.ID = @cID    
            AND PD.SKU = @cSKU    
            AND PD.UOM = @cUOM    
            AND LA.Lottable01 = @cLottable01    
            AND LA.Lottable02 = @cLottable02    
            AND LA.Lottable03 = @cLottable03    
            AND IsNULL( @dLottable04, 0) = IsNULL( LA.Lottable04, 0)     

         SET @cPSType = 'DISCRETE'      
      END   
   END    
       
   IF @@ERROR <> 0    
   BEGIN    
      SET @nErrNo = 138553    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Get PKDtl fail'    
      GOTO Fail    
   END    
    
   -- Validate task still exists    
   IF NOT EXISTS( SELECT 1 FROM @tPD)    
   BEGIN    
      SET @nErrNo = 138554    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Task changed'    
      GOTO Fail    
   END    
    
   -- Validate task already changed by other    
   IF (SELECT SUM( PD_QTY) FROM @tPD) <> @nTaskQTY    
   BEGIN    
      SET @nErrNo = 138555    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Task changed'    
      GOTO Fail    
   END    
    
   DECLARE @cPickDetailKey  NVARCHAR( 18)    
   DECLARE @nTask_Bal  INT    
    
   -- Prepare cursor    
   DECLARE @curPD CURSOR    
          
   If @cPSType = 'CONSO' 
   BEGIN    
      SET @curPD = CURSOR SCROLL FOR     
         SELECT t.PickDetailKey, t.PD_QTY, t.OrderKey    
         FROM @tPD t    
         JOIN Orders O WITH (NOLOCK) ON (t.OrderKey = O.OrderKey)    
         ORDER BY O.Priority, t.Orderkey    
      OPEN @curPD    
   END    
   ELSE    
   BEGIN    
      SET @curPD = CURSOR SCROLL FOR     
         SELECT PickDetailKey, PD_QTY, OrderKey    
         FROM @tPD    
         ORDER BY PickDetailKey    
      OPEN @curPD    
   END    
       
   SET @nTask_Bal = @nConfirmQTY    
    
   -- Loop PickDetail to offset    
   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nPD_QTY, @cOrderKey -- (ChewKP01)    
   WHILE @@FETCH_STATUS = 0    
   BEGIN    
      -- Exact match    
      IF @nTask_Bal = @nPD_QTY    
      BEGIN    
         UPDATE @tPD SET     
            Final_QTY = @nPD_QTY    
         WHERE PickDetailKey = @cPickDetailKey     
    
         SET @nTask_Bal = 0    
             
         EXEC RDT.rdt_STD_EventLog    
             @cActionType   = '3', -- Picking    
             @cUserID      = @cUserName,    
             @nMobileNo     = @nMobile,    
             @nFunctionID   = @nFunc,    
             @cFacility     = @cFacility,    
             @cStorerKey    = @cStorerKey,    
             @cLocation     = @cLOC,    
             @cID           = @cID,    
             @cSKU          = @cSKU,    
             @cUOM          = @cUOM,    
             @nQTY          = @nPD_QTY,    
             @cLottable02   = @cLottable02,     
             @cLottable03   = @cLottable03,     
             @dLottable04   = @dLottable04,     
             @cRefNo1       = @cPickSlipNo,    
             @cRefNo2       = @cDropID,    
             @cRefNo3       = @cPickType,    
             @cOrderKey     = @cOrderKey,     
             @cPickSlipNo   = @cPickSlipNo,     
             @cDropID       = @cDropID    
                 
         BREAK -- Finish    
      END    
    
      -- Over match    
      ELSE IF @nTask_Bal > @nPD_QTY    
      BEGIN    
         UPDATE @tPD SET     
            Final_QTY = @nPD_QTY    
         WHERE PickDetailKey = @cPickDetailKey     
    
         SET @nTask_Bal = @nTask_Bal - @nPD_QTY  -- Reduce task balance, get next PD to offset    
             
         -- (ChewKP01)    
         EXEC RDT.rdt_STD_EventLog    
             @cActionType   = '3', -- Picking    
             @cUserID       = @cUserName,    
             @nMobileNo     = @nMobile,    
             @nFunctionID   = @nFunc,    
             @cFacility     = @cFacility,    
             @cStorerKey    = @cStorerKey,    
             @cLocation     = @cLOC,    
             @cID           = @cID,    
             @cSKU          = @cSKU,    
             @cUOM          = @cUOM,    
             @nQTY          = @nPD_QTY,    
             @cLottable02   = @cLottable02,     
             @cLottable03   = @cLottable03,     
             @dLottable04   = @dLottable04,     
             @cRefNo1       = @cPickSlipNo,    
             @cRefNo2       = @cDropID,    
             @cRefNo3       = @cPickType,    
             @cOrderKey     = @cOrderKey,    
             @cPickSlipNo   = @cPickSlipNo,    
             @cDropID       = @cDropID    
                 
      END    
    
      -- Under match (short pick)    
      ELSE IF @nTask_Bal < @nPD_QTY    
      BEGIN    
         -- Reduce PD balance    
         UPDATE @tPD SET     
            Final_QTY = @nTask_Bal    
         WHERE PickDetailKey = @cPickDetailKey     
    
         SET @nTask_Bal = 0    
             
         -- (ChewKP01)    
         EXEC RDT.rdt_STD_EventLog    
             @cActionType   = '3', -- Picking    
             @cUserID       = @cUserName,    
             @nMobileNo     = @nMobile,    
             @nFunctionID   = @nFunc,    
             @cFacility     = @cFacility,    
             @cStorerKey    = @cStorerKey,    
             @cLocation     = @cLOC,    
             @cID           = @cID,    
             @cSKU          = @cSKU,    
             @cUOM          = @cUOM,    
             @nQTY          = @nTask_Bal,    
             @cLottable02   = @cLottable02,     
             @cLottable03   = @cLottable03,     
             @dLottable04   = @dLottable04,     
             @cRefNo1       = @cPickSlipNo,    
             @cRefNo2       = @cDropID,    
             @cRefNo3       = @cPickType,    
             @cOrderKey     = @cOrderKey,    
             @cPickSlipNo   = @cPickSlipNo,    
             @cDropID       = @cDropID    
             
         BREAK  -- Finish    
      END    
    
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nPD_QTY, @cOrderKey 
   END  -- Loop PickDetail    
    
   -- Still have balance, means offset has error    
   IF @nTask_Bal <> 0    
   BEGIN    
      SET @nErrNo = 138556    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'offset error'    
      CLOSE @curPD    
      DEALLOCATE @curPD    
      GOTO Fail    
   END    
    
   CLOSE @curPD    
   DEALLOCATE @curPD    
    
   DECLARE @nRowCount INT    
   DECLARE @nRowCount_PD INT    
   DECLARE @nRowCount_UCC INT    
    
   -- Get rowcount    
   SELECT @nRowCount_PD = COUNT(1) FROM @tPD    
   SELECT @nRowCount_UCC = COUNT( 1)     
   FROM RDT.RDTTempUCC (NOLOCK)    
   WHERE TaskType = 'PICK'    
      AND PickSlipNo = @cPickSlipNo    
      AND LOC = @cLOC    
      AND ID = @cID    
      AND SKU = @cSKU    
      AND Lottable02 = @cLottable02    
      AND Lottable03 = @cLottable03    
      AND Lottable04 = @dLottable04    
    
   /* Update PickDetail    
      NOTE: Short pick will leave record in @tPD untouch (Final_QTY = 0)    
            Those records will update PickDetail as short pick (PickDetail.QTY = 0 AND Status = 5)    
   */    
   BEGIN TRAN    
   IF @cPickType <> 'D'    
   BEGIN    
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
         DropID = @cDropID,
         QTY = Final_QTY,     
         Status = 5    
      FROM dbo.PickDetail PD    
         INNER JOIN @tPD T ON (PD.PickDetailKey = T.PickDetailKey)    
      -- Compare just in case PickDetail changed    
      WHERE PD.Status < '5'    
         AND PD.QTY = T.PD_QTY    
   END    
   ELSE    
   IF @cPickType = 'D'    
   BEGIN    
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
--         DropID = @cDropID, ignore the update on dropid if pick by dropid only    
         QTY = Final_QTY,     
         Status = 5    
      FROM dbo.PickDetail PD    
         INNER JOIN @tPD T ON (PD.PickDetailKey = T.PickDetailKey)    
      -- Compare just in case PickDetail changed    
      WHERE PD.Status < '5'    
         AND PD.QTY = T.PD_QTY    
   END    
    
   SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT    
          
   -- Check if update PickDetail fail    
   IF @nErrNo <> 0    
   BEGIN    
      SET @nErrNo = 138557    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PKDtl fail'    
      GOTO RollBackTran    
   END    
    
   -- Check if other process had updated PickDetail    
   IF @nRowCount <> @nRowCount_PD    
   BEGIN    
      SET @nErrNo = 138558    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Task changed'    
      GOTO RollBackTran    
   END    
    
   set @nToScanOut = 0
   -- Scan out pickslip if fully picked
   If @cPSType = 'CONSO' 
   BEGIN
      -- conso picklist 
      IF NOT EXISTS ( SELECT 1 
                        FROM dbo.PickHeader PH WITH (NOLOCK)   
                        JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)  
                        JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
                        WHERE PH.PickHeaderKey = @cPickSlipNo  
                        AND   PD.StorerKey = @cStorerKey
                        AND   PD.Status < '5' )
         SET @nToScanOut = 1
   END
   ELSE  
   BEGIN  
      -- discrete picklist  
      IF NOT EXISTS ( SELECT 1 
                        FROM dbo.PickHeader PH (NOLOCK)   
                        INNER JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)  
                        WHERE PH.PickHeaderKey = @cPickSlipNo  
                        AND   PD.StorerKey = @cStorerKey
                        AND   PD.Status < '5' )
         SET @nToScanOut = 1
   END  

   IF @nToScanOut = 1
   BEGIN
      -- Scan out pickslip
      UPDATE dbo.PickingInfo WITH (ROWLOCK) SET   
         ScanOutDate = GETDATE(),   
         AddWho = sUser_sName()   
      WHERE PickSlipNo = @cPickSlipNo  
      AND   ScanOutDate IS NULL

      IF @@ERROR <> 0
      BEGIN  
         SET @nErrNo = 138559  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Scan Out Fail'  
         GOTO RollBackTran  
      END  
   END

   -- Generate packheader here
   IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
   BEGIN
      SELECT 
         @cRoute = [Route],
         @cOrderRefNo = SUBSTRING(ExternOrderKey, 1, 18),
         @cConsigneekey = ConsigneeKey,
         @cLoadKey = LoadKey
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      If @cPSType = 'CONSO'
         INSERT INTO dbo.PackHeader
         (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, AddWho) 
         VALUES
         (@cRoute, '', @cOrderRefNo, @cLoadKey, @cConsigneekey, @cStorerKey, @cPickSlipNo, 'rdt.' + sUser_sName())
      ELSE
         INSERT INTO dbo.PackHeader
         (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, AddWho) 
         VALUES
         (@cRoute, @cOrderKey, @cOrderRefNo, @cLoadKey, @cConsigneekey, @cStorerKey, @cPickSlipNo, 'rdt.' + sUser_sName())

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 138560
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPHdrFail'
         GOTO RollBackTran
      END
   END

   -- Generate packdetail here
   -- 1 ID = 1 CTN = 1 Label = 1 Drop ID
   DECLARE CUR_PACKD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT PD.ID, PD.SKU, ISNULL( SUM( Qty), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK)
   JOIN @tPD t ON ( PD.PickDetailKey = t.PickDetailKey)
   GROUP BY PD.ID, PD.SKU
   ORDER BY PD.ID, PD.SKU
   OPEN CUR_PACKD
   FETCH NEXT FROM CUR_PACKD INTO @cPD_ID, @cPD_SKU, @nPD_Qty
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                        WHERE PickSlipNo = @cPickSlipNo 
                        AND   LabelNo = @cID)
      BEGIN
         SET @nCartonNo = 0

         SET @cLabelNo = @cPD_ID

         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, DropID)
         VALUES
            (@cPickSlipNo, @nCartonNo, @cLabelNo, '00000', @cStorerKey, @cPD_SKU, @nPD_Qty,
            'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cPD_ID)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 138561
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         -- check same sku + id + lot. different lot split into different labelline
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                           WHERE PickSlipNo = @cPickSlipNo 
                           AND   SKU = @cPD_SKU 
                           AND   LabelNo = @cPD_ID)
         BEGIN
            SET @nCartonNo = 0
            SET @cLabelNo = @cPD_ID
            SET @cLabelLine = ''

            SELECT @nCartonNo = CartonNo
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
            AND   PickSlipNo = @cPickSlipNo
            AND   SKU = @cPD_SKU 
            AND   LabelNo = @cPD_ID
               
            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE Pickslipno = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND @cLabelNo = @cPD_ID

            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, DropID)
            VALUES
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cPD_SKU, @nPD_QTY,
               'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cPD_ID)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 138562
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET
               QTY = QTY + @nPD_Qty
            WHERE StorerKey = @cStorerKey
            AND   PickSlipNo = @cPickSlipNo
            AND   SKU = @cPD_SKU
            AND   LabelNo = @cPD_ID

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 138563
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
               GOTO RollBackTran
            END
         END
      END

      -- 1 ID = 1 CTN = 1 Label = 1 Drop ID
      SELECT @nCartonNo = MAX( CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo 
      AND   LabelNo = @cID

      IF NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) 
                      WHERE PickSlipNo = @cPickSlipNo 
                      AND   CartonNo = @nCartonNo)
      BEGIN
         INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, QTY, CartonType) VALUES
         (@cPickSlipNo, @nCartonNo, @nPD_Qty, 'L')

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 138564
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PackInfo Fail'
            GOTO RollBackTran
         END
      END

      FETCH NEXT FROM CUR_PACKD INTO @cPD_ID, @cPD_SKU, @nPD_Qty
   END
   CLOSE CUR_PACKD
   DEALLOCATE CUR_PACKD

   COMMIT TRAN    
    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN    
Fail:  
Quit:

GO