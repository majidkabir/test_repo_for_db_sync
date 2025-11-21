SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_593Print24_Confirm                              */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Farbory scan pallet id, generate pack & pack cfm            */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2019-08-27  1.0  Ung      WMS-10180 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_593Print24_Confirm] (
   @nMobile          INT,
   @nFunc            INT,
   @nStep            INT,
   @cLangCode        NVARCHAR( 3),
   @cStorerKey       NVARCHAR( 15),
   @cID              NVARCHAR( 18),
   @cOrderKey        NVARCHAR( 10),
   @cAllowMixPallet  NVARCHAR( 1), 
   @cNewPalletID     NVARCHAR( 18), 
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT
                           
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @nQTY           INT
   DECLARE @cLabelNo       NVARCHAR( 20)
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @nCartonNo      INT
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @curPack        CURSOR 

   -- Get pick slip
   SET @cPickSlipNo = ''
   SELECT @cPickSlipNo = PickheaderKey FROM dbo.PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_593Print24_Confirm

   -- Create PickHeader
   IF @cPickSlipNo = ''
   BEGIN
      EXECUTE dbo.nspg_GetKey
         'PICKSLIP',
         9,
         @cPickSlipNo   OUTPUT,
         @bsuccess      OUTPUT,
         @nErrNo        OUTPUT,
         @cErrMsg       OUTPUT
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 143751
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Getkey fail
         GOTO RollBackTran
      END

      SET @cPickSlipNo = 'P' + @cPickSlipNo

      INSERT INTO dbo.PickHeader
         (PickHeaderKey, ExternOrderKey, OrderKey, PickType, Zone)
      VALUES
         (@cPickSlipNo, '', @cOrderKey, '0', 'D')
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 143752
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKHdr Fail
         GOTO RollBackTran
      END
   END

   -- Scan-in
   IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
   BEGIN
      DECLARE @cUserName NVARCHAR( 18)
      SET @cUserName = SUSER_SNAME()
      
      EXEC dbo.isp_ScanInPickslip
         @c_PickSlipNo  = @cPickSlipNo,
         @c_PickerID    = @cUserName,
         @n_err         = @nErrNo      OUTPUT,
         @c_errmsg      = @cErrMsg     OUTPUT
      
      IF @nErrNo <> 0
      BEGIN
         SET @nErrNo = 143753
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan In Fail
         GOTO RollBackTran
      END
   END

   -- Create PackHeader
   IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
   BEGIN
      DECLARE @cRoute         NVARCHAR( 30)
      DECLARE @cOrderRefNo    NVARCHAR( 18)
      DECLARE @cConsigneekey  NVARCHAR( 18)

      -- Get order info
      SELECT 
         @cRoute = [Route],
         @cOrderRefNo = SUBSTRING(ExternOrderKey, 1, 18),
         @cConsigneekey = ConsigneeKey
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      INSERT INTO dbo.PackHeader
         (Route, OrderKey, OrderRefNo, Consigneekey, StorerKey, PickSlipNo, AddWho)
      VALUES
         (@cRoute, @cOrderKey, @cOrderRefNo, @cConsigneekey, @cStorerKey, @cPickSlipNo, 'rdt.' + SUSER_SNAME())

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 143754
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackHdrFail
         GOTO RollBackTran
      END
   END

   -- Allow mix SKU on pallet
   IF @cAllowMixPallet = '1'
   BEGIN
      DECLARE @cUCC_SKU NVARCHAR( 20)
      DECLARE @nUCC_QTY INT
      DECLARE @cUCCNo   NVARCHAR( 20)
      
      -- pallet id = pickdetail.id, get uccno = pickdetail.dropid
      SET @curPack = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT PickDetailKey, DropID, SKU, Qty
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
            AND ID = @cID
            AND Status <= '3'
            AND QTY > 0
         ORDER BY 1
      OPEN @curPack
      FETCH NEXT FROM @curPack INTO @cPickDetailKey, @cUCCNo, @cUCC_SKU, @nUCC_QTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Insert PackDetail
         IF NOT EXISTS( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND StorerKey = @cStorerKey  -- Include just to make use of index
               AND RefNo2 = @cUCCNo)
         BEGIN
            SET @nCartonNo = 0
            SET @cLabelNo = @cID

            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, RefNo2)
            VALUES
               (@cPickSlipNo, @nCartonNo, @cLabelNo, '00000', @cStorerKey, @cUCC_SKU, @nUCC_QTY,
               @cNewPalletID, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cPickDetailKey, @cUCCNo)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 143755
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackDtlFail
               GOTO RollBackTran
            END
         END

         -- Update UCC
         IF EXISTS( SELECT 1 FROM UCC WITH (NOLOCK) WHERE UCCNo = @cUCCNo AND StorerKey = @cStorerKey AND Status = '1')
         BEGIN
            UPDATE dbo.UCC SET
               Status = '6', 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME()
            WHERE UCCNo = @cUCCNo
               AND StorerKey = @cStorerKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 143756
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
               GOTO RollBackTran
            END
         END

         FETCH NEXT FROM @curPack INTO @cPickDetailKey, @cUCCNo, @cUCC_SKU, @nUCC_QTY
      END
   END
   ELSE
   BEGIN
      SET @curPack = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT PickDetailKey, SKU, QTY
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
            AND ID = @cID
            AND Status <= '3'
            AND QTY > 0
      OPEN @curPack
      FETCH NEXT FROM @curPack INTO @cPickDetailKey, @cSKU, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Check same sku + id (1 pallet = 1 carton no)
         IF NOT EXISTS ( SELECT 1 
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND SKU = @cSKU
               AND LabelNo = @cID)
         BEGIN
            SET @nCartonNo = 0
            SET @cLabelNo = @cID

            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, RefNo, DropID, RefNo2, 
               AddWho, AddDate, EditWho, EditDate)
            VALUES
               (@cPickSlipNo, @nCartonNo, @cLabelNo, '00000', @cStorerKey, @cSKU, @nQTY, @cNewPalletID, @cPickDetailKey, '', 
               'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 143757
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackDtlFail
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            -- check same sku + id + lot. different lot split into different labelline
            IF NOT EXISTS( SELECT 1 
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
                  AND SKU = @cSKU
                  AND LabelNo = @cID
                  AND DropID = @cPickDetailKey)
            BEGIN
               SET @nCartonNo = 0
               SET @cLabelNo = @cID
               SET @cLabelLine = ''

               SELECT @nCartonNo = CartonNo
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
                  AND SKU = @cSKU
                  AND LabelNo = @cID

               SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE Pickslipno = @cPickSlipNo
                  AND CartonNo = @nCartonNo
                  AND @cLabelNo = @cID

               INSERT INTO dbo.PackDetail
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, DropID, RefNo2, 
                  AddWho, AddDate, EditWho, EditDate)
               VALUES
                  (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cNewPalletID, @cPickDetailKey, '', 
                  'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 143758
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackDtlFail
                  GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               UPDATE dbo.PackDetail SET
                  QTY = QTY + @nQTY, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  ArchiveCop = NULL
               WHERE StorerKey = @cStorerKey
                  AND PickSlipNo = @cPickSlipNo
                  AND SKU = @cSKU
                  AND LabelNo = @cID
                  AND DropID = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 143759
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackDtlFail
                  GOTO RollBackTran
               END
            END
         END
         FETCH NEXT FROM @curPack INTO @cPickDetailKey, @cSKU, @nQTY
      END
   END

   -- Update PickDetail
   DECLARE @curPD CURSOR 
   SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT PickDetailKey
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE Orderkey = @cOrderKey
         AND ID = @cID
         AND Status <= '3'
         AND QTY > 0
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cPickDetailKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE dbo.PickDetail SET
         PickSlipNo = @cPickSlipNo,
         Status = '5', 
         EditDate = GETDATE(), 
         EditWho = SUSER_SNAME()
      WHERE PickDetailKey = @cPickDetailKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 143760
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PickCfm Fail
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
   END

   -- Auto pack confirm
   IF EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status < '9')
   BEGIN
      DECLARE @nExpectedQTY INT = 0
      DECLARE @nPackedQTY   INT = 0

      SELECT @nExpectedQTY = SUM( QTY) FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey
      SELECT @nPackedQTY = SUM(QTY) FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo

      IF @nExpectedQTY = @nPackedQTY
      BEGIN
         UPDATE dbo.PackHeader SET
            Status = '9', 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE PickSlipNo = @cPickSlipNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 143761
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail
            GOTO RollBackTran
         END
      END
   END

   COMMIT TRAN rdt_593Print24_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_593Print24_Confirm
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_593Print24_Confirm
END

GO