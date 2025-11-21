SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/****************************************************************************/
/* Stored Procedure: rdt_840ExtInsPack06                                    */
/*                                                                          */
/* Purpose: Insert/Update packdetail.                                       */
/*          Retrieve tracking no and used as packdetail.labelno             */
/*          Update pickdetail.dropid = tracking no                          */
/*                                                                          */
/* Called By: RDT Pack By Track No                                          */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date        Author  Ver.  Purposes                                       */
/* 2019-03-11  James   1.0   WMS8234-Created                                */
/* 2020-01-03  James   1.1   WMS-11661 Stamp pickdtl.dropid=labelno(james01)*/
/* 2021-04-16  James   1.2   WMS-16024 Standarized use of TrackingNo        */
/*                           (james02)                                      */
/* 2021-04-01  YeeKung 1.3   WMS-16717 Add serialno and serialqty           */
/*                              Params (yeekung01)                          */
/* 03-08-2022  YeeKung 1.4   WMS-20495 remove label print     (yeekung02)   */  
/* 19-12-2022  James   1.5   WMS-21358 Add VMI ordergroup process (james03) */
/****************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtInsPack06] (
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
           @nPack_QTY         INT,
           @nPickQty          INT,
           @nPackQty          INT,
           @nNewCarton        INT,
           @nPD_CartonNo      INT,
           @nFromCartonNo     INT,
           @nToCartonNo       INT,
           @cOrderGroup       NVARCHAR(20)

   DECLARE @b_success         INT,
           @n_err             INT,
           @c_errmsg          NVARCHAR( 20),
           @bsuccess          INT
           
   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_840ExtInsPack06

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
         SET @nErrNo = 135801
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
         SET @nErrNo = 135802
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsLog Failed'
         GOTO RollBackTran
      END
   END

   SELECT @cLoadKey = ISNULL(RTRIM(LoadKey),'')
         , @cRoute = ISNULL(RTRIM(Route),'')
         , @cConsigneeKey = ISNULL(RTRIM(ConsigneeKey),'')
         --, @cTrackNo = UserDefine04
         , @cTrackNo = TrackingNo   -- (james02)
         , @cOrderGroup = ordergroup
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
         SET @nErrNo = 135803
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
         SET @nErrNo = 135804
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
      	-- (james03)
      	IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)
      	            WHERE OrderKey = @cOrderKey
      	            AND   OrderGroup = 'VMI' 
      	            AND   ShipperKey = 'JD') AND @nCartonNo > 1
         BEGIN
         	SET @cLabelNo = RTRIM( @cTrackNo) + '-' + CAST( @nCartonNo AS NVARCHAR( 3))
         	
         	--INSERT INTO dbo.CartonTrack 
         	--( TrackingNo, CarrierName, KeyName, LabelNo, CarrierRef2) VALUES 
         	--( @cLabelNo, 'VMI', 'VMI', @cOrderKey, 'GET')
         	
         	--IF @@ERROR <> 0
          --  BEGIN
          --     SET @nErrNo = 135809
          --     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS CTNTRK ERR'
          --     GOTO RollBackTran
          --  END
         END
         ELSE
         BEGIN
         	IF @nCartonNo = 1
               SET @cLabelNo = @cTrackNo
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
                  SET @nErrNo = 135810
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL FAIL'
                  GOTO RollBackTran
               END
            END
         END
         
         IF ISNULL( @cLabelNo, '') = ''
         BEGIN
            SET @nErrNo = 135805
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
            SET @nErrNo = 135806
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
            SET @nErrNo = 135807
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS PACK Fail'
            GOTO RollBackTran
         END
      END
   END

   -- Stamp pickdetail.dropid = orders.userdefine04
   DECLARE curPICKD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PickDetailKey
   FROM dbo.PickDetail PD WITH (NOLOCK)
   JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
   JOIN dbo.Orders O WITH (NOLOCK) ON ( OD.OrderKey = O.OrderKey)
   WHERE PD.OrderKey  = @cOrderKey
   AND   PD.StorerKey  = @cStorerKey
   AND   PD.Status < '9'
   AND   ( ISNULL( PD.DropID, '') = '' OR PD.DropID <> @cTrackNo)
   ORDER BY PickDetailKey
   OPEN curPICKD
   FETCH NEXT FROM curPICKD INTO @cPickDetailKey
   WHILE @@FETCH_STATUS = 0
   BEGIN

      UPDATE dbo.PICKDETAIL WITH (ROWLOCK) SET
         DropID = @cTrackNo,
         TrafficCop = NULL
      WHERE PickDetailKey = @cPickDetailKey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 135808
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UPD DROPID Err'
         GOTO RollBackTran
      END

      FETCH NEXT FROM curPICKD INTO @cPickDetailKey
   END
   CLOSE curPICKD
   DEALLOCATE curPICKD

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_840ExtInsPack06
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

   --SELECT @nPickQty = ISNULL( SUM( QTY), 0)
   --FROM dbo.PickDetail WITH (NOLOCK)
   --WHERE OrderKey = @cOrderKey
   --AND   StorerKey = @cStorerkey

   --SELECT @nPackQty = ISNULL( SUM( QTY), 0)
   --FROM dbo.PackDetail WITH (NOLOCK)
   --WHERE StorerKey = @cStorerkey
   --AND   PickSlipNo = @cPickSlipNo

   ---- Delivery notes only print when all items pick n pack
   --IF @nPickQty = @nPackQty
   --BEGIN

   --   -- (james01)
   --   -- Get storer config
   --   DECLARE @cAssignPackLabelToOrdCfg NVARCHAR(1)
   --   DECLARE @bsuccess INT
   --   EXECUTE nspGetRight
   --      @cFacility,
   --      @cStorerKey,
   --      '', --@c_sku
   --      'AssignPackLabelToOrdCfg',
   --      @bSuccess                 OUTPUT,
   --      @cAssignPackLabelToOrdCfg OUTPUT,
   --      @nErrNo                   OUTPUT,
   --      @cErrMsg                  OUTPUT
   --   IF @nErrNo <> 0
   --      GOTO Fail

   --   -- Assign
   --   IF @cAssignPackLabelToOrdCfg = '1'
   --   BEGIN
   --      -- Update PickDetail, base on PackDetail.DropID
   --      EXEC isp_AssignPackLabelToOrderByLoad
   --          @cPickSlipNo
   --         ,@bSuccess OUTPUT
   --         ,@nErrNo   OUTPUT
   --         ,@cErrMsg  OUTPUT
   --      IF @nErrNo <> 0
   --         GOTO Fail
   --   END

   --   SELECT
   --      @cLabelPrinter = Printer,
   --      @cPaperPrinter = Printer_Paper
   --   FROM rdt.rdtMobRec WITH (NOLOCK)
   --   WHERE Mobile = @nMobile

   --   SET @cDelNotes = rdt.RDTGetConfig( @nFunc, 'DelNotes', @cStorerKey)
   --   IF @cDelNotes = '0'
   --      SET @cDelNotes = ''

   --   IF @cDelNotes <> ''
   --   BEGIN
   --      DECLARE @tDELNOTES AS VariableTable
   --      INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLoadKey',     @cLoadKey)
   --      INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cOrderKey',    @cOrderKey)
   --      INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
   --      INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cTrackNo',     @cTrackNo)
   --      INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@nCartonNo',    @nCartonNo)
   --      INSERT INTO @tDELNOTES (Variable, Value) VALUES ( '@cLabelNo',     @cLabelNo)

   --      -- Print label
   --      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter,
   --         @cDelNotes, -- Report type
   --         @tDELNOTES, -- Report params
   --         'rdt_840ExtInsPack06',
   --         @nErrNo  OUTPUT,
   --         @cErrMsg OUTPUT

   --      IF @nErrNo <> 0
   --         GOTO Fail
   --   END

   --   IF EXISTS (SELECT 1 FROM Codelkup (nolock) 
   --               where listname='VIPORDTYPE' 
   --                  and storerkey=@cstorerkey
   --                  and code = @cOrdergroup
   --                  and short =@nFunc) --yeekung02
   --   BEGIN
   --      SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabels', @cStorerKey)      
   --      IF @cShipLabel = '0'      
   --         SET @cShipLabel = ''   
   --   END
   --   ELSE
   --   BEGIN
   --      SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShippLabel', @cStorerKey)      
   --      IF @cShipLabel = '0'      
   --         SET @cShipLabel = ''   
   --   END

   --   IF @cShipLabel <> ''
   --   BEGIN

   --      SELECT @nFromCartonNo = MIN( CartonNo),
   --               @nToCartonNo = MAX( CartonNo)
   --      FROM dbo.PackDetail WITH (NOLOCK)
   --      WHERE PickSlipNo = @cPickSlipNo

   --      DECLARE @tSHIPPLABEL AS VariableTable
   --      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',       @cOrderKey)
   --      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nFromCartonNo',   @nFromCartonNo)
   --      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nToCartonNo',     @nToCartonNo)
   --      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cLoadKey',        @cLoadKey)

   --      -- Print label
   --      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '',
   --         @cShipLabel,  -- Report type
   --         @tSHIPPLABEL, -- Report params
   --         'rdt_840ExtInsPack06',
   --         @nErrNo  OUTPUT,
   --         @cErrMsg OUTPUT

   --      IF @nErrNo <> 0
   --         GOTO Fail
   --   END
   --END

   Fail:
END

GO