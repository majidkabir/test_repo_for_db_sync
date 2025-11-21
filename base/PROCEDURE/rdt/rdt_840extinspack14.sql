SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: rdt_840ExtInsPack14                                */
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
/* 2021-01-28   James     1.0   WMS-16145. Created                      */
/* 2021-04-01   YeeKung   1.1   WMS-16717 Add serialno and serialqty    */
/*                              Params (yeekung01)                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtInsPack14] (
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
           @cPickDetailKey    NVARCHAR( 10), 
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
           @cBarcode          NVARCHAR( 40),
           @cLottable02       NVARCHAR( 18),
           @cExtendedLabelNoSP   NVARCHAR( 20),
           @cSQL              NVARCHAR( MAX),
           @cSQLParam         NVARCHAR( MAX),
           @cDropID           NVARCHAR( 20),
           @cNewDropID        NVARCHAR( 20),
           @bsuccess          INT,
           @nPack_QTY         INT,
           @nNewCarton        INT,
           @nPD_QTY           INT

   DECLARE @b_success         INT,
           @n_err             INT,
           @c_errmsg          NVARCHAR( 20)

   SET @nTranCount = @@TRANCOUNT    

   BEGIN TRAN    
   SAVE TRAN rdt_840ExtInsPack14    

   SELECT @cUserName = UserName, 
          @cFacility = Facility,
          @cBarcode = I_Field06
   FROM rdt.rdtMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Piece scanning
   SET @nQty = 1
   SET @cLabelNo = ''

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
         SET @nErrNo = 162701
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
         SET @nErrNo = 162702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsLog Failed'
         GOTO RollBackTran
      END
   END

   -- Create PackHeader if not yet created
   IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
   BEGIN
      SELECT @cLoadKey = ISNULL(RTRIM(LoadKey),'')
            , @cRoute = ISNULL(RTRIM(Route),'')
            , @cConsigneeKey = ISNULL(RTRIM(ConsigneeKey),'')
      FROM dbo.Orders WITH (NOLOCK)
      WHERE Orderkey = @cOrderkey

      INSERT INTO dbo.PACKHEADER
      (PickSlipNo, StorerKey, OrderKey, LoadKey, Route, ConsigneeKey, OrderRefNo, TtlCnts, [STATUS])
      VALUES
      (@cPickSlipNo, @cStorerkey, @cOrderkey, @cLoadKey, @cRoute, @cConsigneeKey, '', 0, '0')

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 162703
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPKHDR Failed'
         GOTO RollBackTran
      END
   END

   SET @cLottable02 = SUBSTRING( RTRIM( @cBarcode), 16, 12) -- Lottable02    
   SET @cLottable02 = RTRIM( @cBarcode) + '-' -- Lottable02    
   SET @cLottable02 = RTRIM( @cBarcode) + SUBSTRING( RTRIM( @cLabelNo), 28, 2) -- Lottable02    

   -- (james07)
   SELECT TOP 1 @cPickDetailKey = PID.PickDetailKey
   FROM dbo.PickDetail PID WITH (NOLOCK)
   JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PID.LOT = LA.LOT
   WHERE PID.Orderkey = @cOrderKey
   AND   PID.Storerkey = @cStorerKey
   AND   PID.Status < '9'
   AND   PID.SKU = @cSKU
   AND   LA.Lottable02 = @cLottable02
   AND   QtyMoved = 0

   UPDATE PickDetail WITH (ROWLOCK) SET
      QtyMoved = 1, Trafficcop = NULL
   WHERE PickDetailKey = @cPickDetailKey

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 162704
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKDET Failed'
      GOTO RollBackTran
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
         SET @nErrNo = 162705
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKDET Failed'
         GOTO RollBackTran
      END

      SELECT TOP 1 @cCurLabelNo = LabelNo 
      FROM dbo.PackDetail WITH (NOLOCK)     
      WHERE StorerKey = @cStorerkey    
      AND PickSlipNo = @cPickSlipNo    
      AND CartonNo = @nCartonNo  
      ORDER BY 1
   END
   ELSE     -- Insert new PackDetail
   BEGIN
      -- Check if same carton exists before. Diff sku can scan into same carton
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerkey
                  AND PickSlipNo = @cPickSlipNo
                  AND CartonNo = @nCartonNo)
      BEGIN
         SET @cExtendedLabelNoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedLabelNoSP', @cStorerKey)
         IF @cExtendedLabelNoSP NOT IN ('0', '') AND 
            EXISTS( SELECT 1 FROM sys.sysobjects WHERE name = @cExtendedLabelNoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedLabelNoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo, @cLabelNo OUTPUT,' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
               '@nMobile                   INT,           ' +
               '@nFunc                     INT,           ' +
               '@cLangCode                 NVARCHAR( 3),  ' +
               '@nStep                     INT,           ' +
               '@nInputKey                 INT,           ' +
               '@cStorerkey                NVARCHAR( 15), ' +
               '@cOrderKey                 NVARCHAR( 10), ' +
               '@cPickSlipNo               NVARCHAR( 10), ' +
               '@cTrackNo                  NVARCHAR( 20), ' +
               '@cSKU                      NVARCHAR( 20), ' +
               '@nCartonNo                 INT,           ' +
               '@cLabelNo                  NVARCHAR( 20) OUTPUT,  ' +                     
               '@nErrNo                    INT           OUTPUT,  ' +
               '@cErrMsg                   NVARCHAR( 20) OUTPUT   '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @nCartonNo, @cLabelNo OUTPUT,
                  @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 162706
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            -- Get new LabelNo
            EXECUTE isp_GenUCCLabelNo
                     @cStorerKey,
                     @cLabelNo     OUTPUT,
                     @bSuccess     OUTPUT,
                     @nErrNo       OUTPUT,
                     @cErrMsg      OUTPUT

            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 162707
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'
               GOTO RollBackTran
            END
         END

         IF ISNULL( @cLabelNo, '') = ''
         BEGIN
            SET @nErrNo = 162708
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'
            GOTO RollBackTran
         END

         -- CartonNo = 0 & LabelLine = '0000', trigger will auto assign
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, UPC)
         VALUES
            (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nQty,
            '', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '', @cBarcode)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 162709
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
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID, UPC)
         VALUES
            (@cPickSlipNo, @nCartonNo, @cCurLabelNo, @cCurLabelLine, @cStorerKey, @cSku, @nQty,
            '', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), '', @cBarcode)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 162710
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS PACK Fail'
            GOTO RollBackTran
         END
      END
   END
 
   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_840ExtInsPack14  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  

END

GO