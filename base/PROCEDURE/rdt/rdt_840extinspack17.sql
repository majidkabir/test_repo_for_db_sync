SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: rdt_840ExtInsPack17                                */
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
/* 2022-03-18   James     1.0   WMS-19123. Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtInsPack17] (
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
           @nPD_QTY           INT,
           @cData1            NVARCHAR( 60) = '',
           @cData2            NVARCHAR( 60) = '',
           @cData3            NVARCHAR( 60) = '',
           @cData4            NVARCHAR( 60) = '',
           @cData5            NVARCHAR( 60) = '',
           @cLabelLine        NVARCHAR( 5) = ''
           
   DECLARE @b_success         INT,
           @n_err             INT,
           @c_errmsg          NVARCHAR( 20)

   SET @nTranCount = @@TRANCOUNT    

   BEGIN TRAN    
   SAVE TRAN rdt_840ExtInsPack17    

   SELECT @cUserName = UserName, 
          @cFacility = Facility,
          @cBarcode = I_Field06, 
          @cData1 = V_String44,
          @cData2 = V_String45,
          @cData3 = V_String46,
          @cData4 = V_String47,
          @cData5 = V_String48
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
         SET @nErrNo = 184401
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
         SET @nErrNo = 184402
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
         SET @nErrNo = 184403
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPKHDR Err'
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
         SET @nErrNo = 184404
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPDPKDET Failed'
         GOTO RollBackTran
      END

      SELECT TOP 1 
         @cLabelNo = LabelNo, 
         @cLabelLine = LabelLine 
      FROM dbo.PackDetail WITH (NOLOCK)     
      WHERE StorerKey = @cStorerkey    
      AND PickSlipNo = @cPickSlipNo    
      AND CartonNo = @nCartonNo  
      AND SKU = @cSKU
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
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @cLabelNo OUTPUT, @nCartonNo OUTPUT,' +
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
               '@cLabelNo                  NVARCHAR( 20) OUTPUT,  ' +
               '@nCartonNo                 INT           OUTPUT,  ' +
               '@nErrNo                    INT           OUTPUT,  ' +
               '@cErrMsg                   NVARCHAR( 20) OUTPUT   '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cOrderKey, @cPickSlipNo, @cTrackNo, @cSKU, @cLabelNo OUTPUT, @nCartonNo OUTPUT,
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
            BEGIN
               SET @nErrNo = 184405
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Err'
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
               SET @nErrNo = 184406
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Err'
               GOTO RollBackTran
            END
         END

         IF ISNULL( @cLabelNo, '') = ''
         BEGIN
            SET @nErrNo = 184407
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
            SET @nErrNo = 184408
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS PACK Fail'
            GOTO RollBackTran
         END
         ELSE
            SELECT TOP 1 
               @nCartonNo = CartonNo,
               @cLabelLine = LabelLine 
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo
            AND   LabelNo = @cLabelNo
            AND   StorerKey = @cStorerKey
            ORDER BY 1
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
            SET @nErrNo = 184409
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS PACK Fail'
            GOTO RollBackTran
         END
         
         SET @cLabelNo = @cCurLabelNo
         SET @cLabelLine = @cCurLabelLine
      END
   END

   -- Ctn type, cube, weight will be updated in carton type screen
   -- Here just insert tracking no
   IF NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) 
                   WHERE PickSlipNo = @cPickSlipNo 
                   AND CartonNo = @nCartonNo)
   BEGIN
      INSERT INTO dbo.PACKINFO  
      (PickSlipNo, CartonNo, CartonType, Qty, Cube, WEIGHT, TrackingNo)  
      VALUES  
      (@cPickSlipNo, @nCartonNo, '', 0, 0, 0, @cLabelNo) 

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 184410
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS PACK Fail'
         GOTO RollBackTran
      END
   END
   
   -- Serial no
   IF @cSerialNo <> ''
   BEGIN
      -- Get serial no info
      DECLARE @nRowCount INT
      DECLARE @nPackSerialNoKey  INT
      DECLARE @cChkSerialSKU NVARCHAR( 20)
      DECLARE @nChkSerialQTY INT
      
      SELECT 
         @nPackSerialNoKey = PackSerialNoKey, 
         @cChkSerialSKU = SKU, 
         @nChkSerialQTY = QTY
      FROM PackSerialNo WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND SerialNo = @cSerialNo
      SET @nRowCount = @@ROWCOUNT
      
      -- New serial no
      IF @nRowCount = 0
      BEGIN
         -- Insert PackSerialNo 
         INSERT INTO PackSerialNo (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, SerialNo, QTY)
         VALUES (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @cSerialNo, @nSerialQTY)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 184411
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RDSNo Err
            GOTO RollBackTran
         END
      END
      
      -- Check serial no scanned
      ELSE
      BEGIN
         SET @nErrNo = 184412
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SNO ady scan
         GOTO RollBackTran
      END
   END
   
   -- Pack data
   IF @cData1 <> '' 
   BEGIN
   	IF EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK)
   	            WHERE StorerKey = @cStorerkey
   	            AND   Sku = @cSKU
   	            AND   DataCapture = '1')
      BEGIN
         DECLARE @nPackDetailInfoKey BIGINT
      
         -- Get PackDetailInfo
         SET @nPackDetailInfoKey = 0
         SELECT @nPackDetailInfoKey = PackDetailInfoKey
         FROM dbo.PackDetailInfo WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo 
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo 
            AND SKU = @cSKU
            AND UserDefine01 = @cData1
            AND UserDefine02 = @cData2
      
         IF @nPackDetailInfoKey = ''
         BEGIN
            -- Insert PackDetailInfo
            INSERT INTO dbo.PackDetailInfo (
               PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, UserDefine01, UserDefine02, UserDefine03, 
               AddWho, AddDate, EditWho, EditDate)
            VALUES (
               @cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, @cData1, @cSerialNo, '', 
               'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE())
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 184413
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PDInfoErr
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            -- Update PackDetailInfo
            UPDATE dbo.PackDetailInfo SET   
               QTY = QTY + @nQTY, 
               EditWho = 'rdt.' + SUSER_SNAME(), 
               EditDate = GETDATE(), 
               ArchiveCop = NULL
            WHERE PackDetailInfoKey = @nPackDetailInfoKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 184414
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PDInfoErr
               GOTO RollBackTran
            END
         END
      END
   END   
   
   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_840ExtInsPack17  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  

END

GO