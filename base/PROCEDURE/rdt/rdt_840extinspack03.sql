SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: rdt_840ExtInsPack03                                */
/*                                                                      */
/* Purpose: Insert/Update packdetail.                                   */
/*          Retrieve tracking no and used as packdetail.labelno         */
/*                                                                      */
/* Called By: RDT Pack By Track No                                      */ 
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2018-11-01   James     1.0   WMS6891 - Created                       */
/* 2020-06-02   James     1.1   WMS-13480 Remove printing (james01)     */
/* 2021-04-01   YeeKung   1.2   WMS-16717 Add serialno and serialqty    */
/*                              Params (yeekung01)                      */
/* 2021-04-16   James     1.3   WMS-16024 Standarized use of TrackingNo */
/*                              (james02)                               */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtInsPack03] (
   @nMobile                   INT, 
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3), 
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15), 
   @cOrderKey                 NVARCHAR( 10), 
   @cPickSlipNo               NVARCHAR( 10), 
   @cTrackNo                  NVARCHAR( 20), 
   @cSKU                      NVARCHAR( 20), 
   @nQty                      INT, 
   @nCartonNo                 INT,
   @cSerialNo                 NVARCHAR( 30), 
   @nSerialQTY                INT,  
   @cLabelNo                  NVARCHAR( 20) OUTPUT, 
   @nErrNo                    INT           OUTPUT, 
   @cErrMsg                   NVARCHAR( 20) OUTPUT  
)
AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT,
           @nPD_QTY           INT,
           @cReportType       NVARCHAR( 10),
           @cPrintJobName     NVARCHAR( 50),
           @cDataWindow       NVARCHAR( 50),
           @cTargetDB         NVARCHAR( 20),
           @cPaperPrinter     NVARCHAR( 10),
           @cLabelPrinter     NVARCHAR( 10),
           @cPickDetailKey    NVARCHAR( 10), 
           @cCarrierName      NVARCHAR( 30), 
           @cKeyName          NVARCHAR( 30), 
           @cUserName         NVARCHAR( 18), 
           @cLoadKey          NVARCHAR( 10),
           @cRoute            NVARCHAR( 10),
           @cConsigneeKey     NVARCHAR( 15), 
           @cCurLabelNo       NVARCHAR( 20),
           @cCurLabelLine     NVARCHAR( 5), 
           @cPack_LblNo       NVARCHAR( 20), 
           @cPack_SKU         NVARCHAR( 20), 
           @cShipLabel        NVARCHAR( 10),
           @cDelNotes         NVARCHAR( 10),
           @cFacility         NVARCHAR( 5),
           @cShipperKey       NVARCHAR( 15),
           @nPack_QTY         INT, 
           @nPickQty          INT, 
           @nPackQty          INT,
           @nNewCarton        INT,
           @nPD_CartonNo      INT,
           @nFromCartonNo     INT,
           @nToCartonNo       INT

   DECLARE @b_success         INT,
           @n_err             INT,
           @c_errmsg          NVARCHAR( 20)

   SET @nTranCount = @@TRANCOUNT    

   BEGIN TRAN    
   SAVE TRAN rdt_840ExtInsPack03    

   SELECT @cUserName = UserName, 
          @cFacility = Facility
   FROM rdt.rdtMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Piece scanning
   SET @nQty = 1
   SET @cLabelNo = ''
   SET @nNewCarton = 0

   IF EXISTS (SELECT 1 FROM rdt.rdtTrackLog WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               AND Storerkey = @cStorerkey
               AND CartonNo = @nCartonNo
               AND UserName = @cUserName
               AND SKU = @cSKU)   -- can scan many sku into 1 carton
   BEGIN
      UPDATE rdt.rdtTrackLog WITH (ROWLOCK) SET
         Qty = ISNULL(Qty, 0) + 1,
         EditWho = @cUserName,
         EditDate = GetDate()
      WHERE PickSlipNo = @cPickSlipNo
      AND Storerkey = @cStorerkey
      AND CartonNo = @nCartonNo
      AND UserName = @cUserName
      AND SKU = @cSKU

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 131351
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdLog Failed'
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      INSERT INTO rdt.rdtTrackLog ( PickSlipNo, Mobile, UserName, Storerkey, Orderkey, TrackNo, SKU, Qty, CartonNo )
      VALUES (@cPickSlipNo, @nMobile, @cUserName, @cStorerkey, @cOrderKey, @cTrackNo, @cSKU, 1, @nCartonNo  )

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 131352
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsLog Failed'
         GOTO RollBackTran
      END
   END

   SELECT @cLoadKey = ISNULL(RTRIM(LoadKey),'')
         , @cRoute = ISNULL(RTRIM(Route),'')
         , @cConsigneeKey = ISNULL(RTRIM(ConsigneeKey),'')
         , @cShipperKey = ISNULL(RTRIM(ShipperKey),'')
   FROM dbo.Orders WITH (NOLOCK)
   WHERE Orderkey = @cOrderkey
      
   -- Create PackHeader if not yet created
   IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
   BEGIN
      INSERT INTO dbo.PACKHEADER
      (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, [STATUS])
      VALUES
      (@cPickSlipNo, @cStorerkey, @cOrderkey, @cLoadKey, @cRoute, @cConsigneeKey, '', 0, '0')

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 131353
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPKHDR Failed'
         GOTO RollBackTran
      END
   END

   -- Update PackDetail.Qty if it is already exists
   IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerkey
               AND PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND SKU = @cSKU)   -- can scan many sku into 1 carton
   BEGIN
      UPDATE dbo.PackDetail WITH (ROWLOCK) SET
         Qty = Qty + @nQty,
         EditDate = GETDATE(),
         EditWho = 'rdt.' + sUser_sName()
      WHERE StorerKey = @cStorerkey
      AND PickSlipNo = @cPickSlipNo
      AND CartonNo = @nCartonNo
      AND SKU = @cSKU

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 131354
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKDET Failed'
         GOTO RollBackTran
      END
   END
   ELSE     -- Insert new PackDetail
   BEGIN
      -- Check if same carton exists before. Diff sku can scan into same carton
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerkey
                  AND PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo)
      BEGIN
         -- Get tracking no. Customer order can have > 1 carton
         -- If 1st carton then get the tracking no from orders.userdefine04
         IF @nCartonNo = 1
         BEGIN
            --SELECT @cTrackNo = UserDefine04
            SELECT @cTrackNo = TrackingNo -- (james02)
            FROM dbo.Orders WITH (NOLOCK) 
            WHERE StorerKey = @cStorerkey
            AND   OrderKey = @cOrderKey

            IF ISNULL( @cTrackNo, '') = ''
            BEGIN    
               SET @nErrNo = 131355    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO TRACKING #'    
               GOTO RollBackTran    
            END    
         END
         ELSE
         BEGIN
            -- Check if same carton exists before. Diff sku can scan into same carton    
            IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)    
                        WHERE StorerKey = @cStorerkey    
                        AND PickSlipNo = @cPickSlipNo    
                        AND CartonNo = @nCartonNo)    
            BEGIN    
               /** get new available pre-paid tracking number **/
               SELECT @cCarrierName = Code, 
                      @cKeyName = UDF05
               FROM dbo.Codelkup WITH (NOLOCK)
               WHERE Listname = 'CKCourier' 
               AND   StorerKey = @cStorerKey
               AND   Code = @cShipperKey

               SELECT @cTrackNo = MIN( TrackingNo)
               FROM dbo.CartonTrack WITH (NOLOCK)
               WHERE CarrierName = @cCarrierName 
               AND   Keyname = @cKeyName 
               AND   ISNULL( CarrierRef2, '') = ''

               IF ISNULL( @cTrackNo, '') = ''
               BEGIN    
                  SET @nErrNo = 131356    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NO TRACKING #'    
                  GOTO RollBackTran    
               END 
         
               /**update cartontrack **/
               UPDATE dbo.CartonTrack WITH (ROWLOCK) SET 
                  LabelNo = @cOrderKey,  
                  Carrierref2 = 'GET'
               WHERE CarrierName = @cCarrierName 
               AND   Keyname = @cKeyName 
               AND   CarrierRef2 = ''
               AND   TrackingNo = @cTrackNo

               IF @@ERROR <> 0
               BEGIN    
                  SET @nErrNo = 131357    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ASSIGN TRACK# Err'    
                  GOTO RollBackTran    
               END 
            END
            ELSE
            BEGIN
               SELECT TOP 1 @cTrackNo = LabelNo
               FROM dbo.PackDetail WITH (NOLOCK)    
               WHERE StorerKey = @cStorerkey    
               AND PickSlipNo = @cPickSlipNo    
               AND CartonNo = @nCartonNo
            END
         END

         SET @cLabelNo = @cTrackNo

         IF ISNULL( @cLabelNo, '') = ''
         BEGIN
            SET @nErrNo = 131358
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'
            GOTO RollBackTran
         END

         -- CartonNo = 0 & LabelLine = '0000', trigger will auto assign
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)
         VALUES
            (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nQty,
            '', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '')

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 131359
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS PACK Fail'
            GOTO RollBackTran
         END
         ELSE
            SELECT @nNewCarton = CartonNo 
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo
            AND   LabelNo = @cLabelNo
            AND   StorerKey = @cStorerKey
      END
      ELSE
      BEGIN
         SET @cCurLabelNo = ''
         SET @cCurLabelLine = ''

         SELECT TOP 1 @cCurLabelNo = LabelNo FROM dbo.PackDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo

         SELECT @cCurLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
         FROM PACKDETAIL WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo

         -- need to use the existing labelno
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)
         VALUES
            (@cPickSlipNo, @nCartonNo, @cCurLabelNo, @cCurLabelLine, @cStorerKey, @cSku, @nQty,
            '', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '')

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 131360
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS PACK Fail'
            GOTO RollBackTran
         END
         
         SET @cLabelNo = @cCurLabelNo
      END
   END

   SELECT @nPickQty = ISNULL( SUM( QTY), 0)
   FROM dbo.PickDetail WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey 
   AND   StorerKey = @cStorerkey

   SELECT @nPackQty = ISNULL( SUM( QTY), 0)
   FROM dbo.PackDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerkey
   AND   PickSlipNo = @cPickSlipNo

   IF  @nPickQty = @nPackQty
   BEGIN         
      DECLARE curPACKD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT CartonNo, LabelNo, SKU, SUM( Qty)
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerkey
      AND   PickSlipNo = @cPickSlipNo
      GROUP BY CartonNo, LabelNo, SKU
      ORDER BY CartonNo, LabelNo, SKU
      OPEN curPACKD
      FETCH NEXT FROM curPACKD INTO @nPD_CartonNo, @cPack_LblNo, @cPack_SKU, @nPack_QTY
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         -- Stamp pickdetail.caseid (to know which case in which pickdetail line)
         DECLARE curPICKD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey, QTY
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE OrderKey  = @cOrderKey
         AND   StorerKey  = @cStorerKey
         AND   SKU = @cPack_SKU
         AND   Status < '9'
         AND   CaseID = ''
         ORDER BY PickDetailKey
         OPEN curPICKD
         FETCH NEXT FROM curPICKD INTO @cPickDetailKey, @nPD_QTY
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            -- Exact match
            IF @nPD_QTY = @nPack_QTY
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  CaseID = @cPack_LblNo, 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 131361
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Case Fail'
                  GOTO RollBackTran
               END

               SET @nPack_QTY = @nPack_QTY - @nPD_QTY -- Reduce balance 
            END
            -- PickDetail have less
            ELSE IF @nPD_QTY < @nPack_QTY
            BEGIN
               -- Confirm PickDetail
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  CaseID = @cPack_LblNo, 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 131362
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Case Fail'
                  GOTO RollBackTran
               END

               SET @nPack_QTY = @nPack_QTY - @nPD_QTY -- Reduce balance
            END
            -- PickDetail have more, need to split
            ELSE IF @nPD_QTY > @nQty
            BEGIN
               -- Get new PickDetailkey
               DECLARE @cNewPickDetailKey NVARCHAR( 10)
               EXECUTE dbo.nspg_GetKey
                  'PICKDETAILKEY',
                  10 ,
                  @cNewPickDetailKey OUTPUT,
                  @b_success         OUTPUT,
                  @n_err             OUTPUT,
                  @c_errmsg          OUTPUT

               IF @b_success <> 1
               BEGIN
                  SET @nErrNo = 131363
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Get PDKey Fail'
                  GOTO RollBackTran
               END

               -- Create a new PickDetail to hold the balance
               INSERT INTO dbo.PICKDETAIL (
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,
                  Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,
                  QTY,
                  TrafficCop,
                  OptimizeCop)
               SELECT
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
                  Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
                  @nPD_QTY - @nPack_QTY, 
                  NULL, --TrafficCop,
                  '1'  --OptimizeCop
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 131364
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PDtl Fail'
                  GOTO RollBackTran
               END

               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  Qty = @nPack_QTY,   -- deduct original qty
                  CaseID = @cPack_LblNo, 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 131365
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Case Fail'
                  GOTO RollBackTran
               END

               SET @nPack_QTY = 0 -- Reduce balance  
            END

            IF @nPack_QTY = 0 
               BREAK -- Exit

            FETCH NEXT FROM curPICKD INTO @cPickDetailKey, @nPD_QTY
         END
         CLOSE curPICKD
         DEALLOCATE curPICKD

         FETCH NEXT FROM curPACKD INTO @nPD_CartonNo, @cPack_LblNo, @cPack_SKU, @nPack_QTY         
      END
      CLOSE curPACKD
      DEALLOCATE curPACKD
   END


   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_840ExtInsPack03  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  

END

GO