SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_841ExtUpdSP31                                   */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Ecomm Update SP                                             */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2022-10-24  1.0  James    WMS-21041. Created                         */
/* 2023-02-15  1.1  YeeKung  WMS-21774 Add shiplabel (yeekung01)        */
/* 2023-06-15  1.2  YeeKung   WMS-22632 Add ZPL shiplabel print(yeekung02)*/
/************************************************************************/

CREATE   PROC [RDT].[rdt_841ExtUpdSP31] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @cUserName   NVARCHAR( 15),
   @cFacility   NVARCHAR( 5),
   @cStorerKey  NVARCHAR( 15),
   @cDropID     NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @nStep       INT,
   @cPickslipNo NVARCHAR( 10),
   @cPrevOrderkey NVARCHAR(10),
   @cTrackNo     NVARCHAR( 20),
   @cTrackNoFlag NVARCHAR(1)   OUTPUT,
   @cOrderKeyOut NVARCHAR(10)  OUTPUT,
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT,
   @cCartonType  NVARCHAR( 20) ='',  
   @cSerialNo    NVARCHAR( 30),
   @nSerialQTY   INT,
   @tExtUpd      VariableTable READONLY  
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT
          ,@nSUM_PackQTY      INT
          ,@nSUM_PickQTY      INT
          ,@cOrderKey         NVARCHAR(10)
          ,@bsuccess          INT
          ,@nCartonNo         INT
          ,@cLabelLine        NVARCHAR( 5)
          ,@cLabelNo          NVARCHAR(20)
          ,@cPackSku          NVARCHAR(20)
          ,@nPackQty          INT
          ,@nTotalPackQty     INT
          ,@nTotalPickQty     INT
          ,@nTTL_PickedQty    INT
          ,@nTTL_PackedQty    INT
          ,@cDropIDType       NVARCHAR(10)
          ,@cGenTrackNoSP     NVARCHAR(30)
          ,@cGenLabelNoSP     NVARCHAR(30)
          ,@cExecStatements   NVARCHAR(4000)
          ,@cExecArguments    NVARCHAR(4000)
          ,@cRDTBartenderSP   NVARCHAR(30)
          ,@cLabelPrinter     NVARCHAR(10)
          ,@cLoadKey          NVARCHAR(10)
          ,@cPaperPrinter     NVARCHAR(10)
          ,@cDataWindow       NVARCHAR(50)
          ,@cTargetDB         NVARCHAR(20)
          ,@cOrderType        NVARCHAR(10)
          ,@cShipperKey       NVARCHAR(10)
          ,@cWCS              NVARCHAR(1)
          ,@cPrinter02        NVARCHAR(10)
          ,@cBrand01          NVARCHAR(10)
          ,@cBrand02          NVARCHAR(10)
          ,@cPrinter01        NVARCHAR(10)
          ,@cSectionKey       NVARCHAR(10)
          ,@cSOStatus         NVARCHAR(10)
          ,@cGenPackDetail    NVARCHAR(1)
          ,@b_success         INT
          ,@cShowTrackNoScn   NVARCHAR(1)
          ,@nRowRef           INT
          ,@cPickDetailKey    NVARCHAR(10)
          ,@cSHIPZPLLBL       NVARCHAR(20)

   DECLARE @tSHIPZPLLBL    VariableTable


   SET @nErrNo   = 0
   SET @cErrMsg  = ''
   SET @cWCS     = ''
   SET @cTrackNoFlag = '0'
   SET @cOrderKeyOut = ''
   SET @cBrand01     = ''
   SET @cBrand02     = ''
   SET @cPrinter02   = ''
   SET @cPrinter01   = ''
   SET @cSectionKey  = ''
   SET @cShowTrackNoScn = ''




   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_841ExtUpdSP31


   SELECT @cLabelPrinter = Printer
         ,@cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cGenPackDetail  = ''
   SET @cGenPackDetail = rdt.RDTGetConfig( @nFunc, 'GenPackDetail', @cStorerkey)

   IF @nStep = 2
   BEGIN
      SET @cGenLabelNoSP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo', @cStorerkey)

      -- check if sku exists in tote
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
                      WHERE ToteNo = @cDropID
                      AND SKU = @cSKU
                      AND AddWho = @cUserName
                      AND Status IN ('0', '1') )
      BEGIN
          SET @nErrNo = 193301
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKuNotIntote
          GOTO RollBackTran
      END

      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
                      WHERE ToteNo = @cDropID
                      AND ExpectedQty > ScannedQty
                      AND Status < '5'
                      AND Orderkey = @cPrevOrderkey
                      AND AddWho = @cUserName)
      BEGIN
          SET @cOrderkey = ''
      END
      ELSE
      BEGIN
          SET @cOrderkey = @cPrevOrderkey
      END

      IF ISNULL(RTRIM(@cOrderkey),'') = ''
      BEGIN
         -- processing new order
         SELECT @cOrderkey   = MIN(RTRIM(ISNULL(Orderkey,'')))
         FROM rdt.rdtECOMMLog WITH (NOLOCK)
         WHERE ToteNo = @cDropID
         AND   Status IN ('0', '1')
         AND   Sku = @cSKU
         AND   AddWho = @cUserName
      END
      ELSE
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
                        WHERE ToteNo = @cDropID
                        AND Orderkey = @cOrderkey
                        AND SKU = @cSKU
                        AND Status < '5'
                        AND AddWho = @cUserName)
         BEGIN
            SET @nErrNo = 193302
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUNotInOrder
            GOTO RollBackTran
         END
      END

      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
                     WHERE ToteNo = @cDropID
                     AND Orderkey = @cOrderkey
                     AND SKU = @cSKU
                     AND ExpectedQty > ScannedQty
                     AND Status < '5'
                     AND AddWho = @cUserName)
      BEGIN
         SET @nErrNo = 193303
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QtyExceeded
         GOTO RollBackTran
      END

      DECLARE C_ECOMMLOG1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RowRef
      FROM rdt.rdtEcommLog WITH (NOLOCK)
      WHERE ToteNo      = @cDropID
      AND   Orderkey    = @cOrderkey
      AND   Sku         = @cSku
      AND   Status      < '5'
      AND   AddWho = @cUserName
      ORDER BY RowRef

      OPEN C_ECOMMLOG1
      FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef
      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         /***************************
         UPDATE rdtECOMMLog
         ****************************/
         UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)
         SET   ScannedQty  = ScannedQty + 1,
               Status      = '1'    -- in progress
         WHERE RowRef = @nRowRef

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 193304
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'
            GOTO RollBackTran
         END

         FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef
      END
      CLOSE C_ECOMMLOG1
      DEALLOCATE C_ECOMMLOG1

      IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Orderkey = @cOrderkey)
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.PickHeader WITH (NOLOCK) WHERE Orderkey = @cOrderkey)
        BEGIN

            IF ISNULL(RTRIM(@cPickSlipno) ,'')=''
            BEGIN
                EXECUTE dbo.nspg_GetKey
                'PICKSLIP',
                9,
                @cPickslipno OUTPUT,
                @b_success OUTPUT,
                @nErrNo OUTPUT,
                @cErrMsg OUTPUT

                IF @nErrNo<>0
                BEGIN
                    SET @nErrNo = 193305
                    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GetDetKeyFail'
                    GOTO RollBackTran
                END

                SELECT @cPickslipno = 'P'+@cPickslipno

                INSERT INTO dbo.PICKHEADER
                  (
                    PickHeaderKey
                   ,ExternOrderKey
                   ,Orderkey
                   ,PickType
                   ,Zone
                   ,TrafficCop
                  )
                VALUES
                  (
                    @cPickslipno
                   ,''
                   ,@cOrderKey
                   ,'0'
                   ,'D'
                   ,''
                  )

                IF @@ERROR<>0
                BEGIN
                    SET @nErrNo = 193306
                    SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InstPKHdrFail '
                    GOTO RollBackTran

                END
            END --ISNULL(@cPickSlipno, '') = ''
         END
      END

      IF NOT EXISTS ( SELECT 1
                      FROM   dbo.PickingInfo WITH (NOLOCK)
                      WHERE  PickSlipNo = @cPickSlipNo          )
      BEGIN
          INSERT INTO dbo.PickingInfo
            (
              PickSlipNo
             ,ScanInDate
             ,PickerID
             ,ScanOutDate
             ,AddWho
             ,TrafficCop
            )
          VALUES
            (
              @cPickSlipNo
             ,GETDATE()
             ,@cUserName
             ,NULL
             ,@cUserName
             ,'U'
            )

          IF @@ERROR<>0
          BEGIN
               SET @nErrNo = 193307
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ScanInFail'
               GOTO RollBackTran
          END
      END

      SET @nTotalPickQty = 0
      SELECT @nTotalPickQty = SUM(PD.QTY)
      FROM PICKDETAIL PD WITH (NOLOCK)
      WHERE PD.ORDERKEY = @cOrderKey
      AND PD.Storerkey = @cStorerkey

      SET @nTotalPackQty = 0
      SELECT @nTotalPackQty = SUM(ScannedQty)
      FROM rdt.rdtEcommLog WITH (NOLOCK)
      WHERE OrderKey = @cORderKey

      IF @nTotalPickQty = @nTotalPackQty
      BEGIN
           SET @cTrackNoFlag = '1'
           SET @cOrderKeyOut = @cOrderkey
      END

      IF @cGenPackDetail = '1'
      BEGIN
         SET @cTrackNoFlag = ''

         /****************************
          CREATE PACK DETAILS
         ****************************/
         -- check is order fully despatched for this tote
         IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
                        WHERE ToteNo = @cDropID
                        AND Orderkey = @cOrderkey
                        AND ExpectedQty > ScannedQty
                        AND Status < '5'
                        AND AddWho = @cUserName)
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Orderkey = @cOrderkey)
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM dbo.PickHeader WITH (NOLOCK) WHERE Orderkey = @cOrderkey)
               BEGIN
                  /****************************
                   PICKHEADER
                  ****************************/
                  IF ISNULL(@cPickSlipNo,'') = ''
                  BEGIN
                     EXECUTE dbo.nspg_GetKey
                     'PICKSLIP',
                     9,
                     @cPickslipno OUTPUT,
                     @bsuccess   OUTPUT,
                     @nerrNo     OUTPUT,
                     @cerrmsg    OUTPUT

                     SET @cPickslipno = 'P' + @cPickslipno
                  END

                  INSERT INTO dbo.PICKHEADER (PickHeaderKey, Storerkey, Orderkey, PickType, Zone, TrafficCop, AddWho, AddDate, EditWho, EditDate)
                  VALUES (@cPickSlipNo, @cStorerkey, @cOrderKey, '0', 'D', '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE())
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 193308
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickHdrFail'
                     GOTO RollBackTran
                  END
                  ELSE
                  BEGIN
                     UPDATE dbo.PICKDETAIL WITH (ROWLOCK)
                     SET  PICKSLIPNO = @cPickslipno,
                          Trafficcop = NULL,
                          EditDate = GETDATE(),
                          EditWho = SUSER_SNAME()
                     WHERE StorerKey = @cStorerKey
                     AND   Orderkey = @cOrderKey
                     AND   (Status IN ('3', '5') OR ShipFlag = 'P')
                     AND   ISNULL(RTrim(Pickslipno),'') = ''

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 193309
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDetFail'
                        GOTO RollBackTran
                     END
                  END
               END -- pickheader does not exist

               /****************************
                PACKHEADER
               ****************************/
               INSERT INTO dbo.PackHeader
               (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, AddWho, AddDate, EditWho, EditDate)
               SELECT O.Route, O.OrderKey,SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey,
                     PH.PickHeaderkey, sUser_sName(), GETDATE(), sUser_sName(), GETDATE()
               FROM  dbo.PickHeader PH WITH (NOLOCK)
               JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
               WHERE PH.Orderkey = @cOrderkey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 193310
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CreatePHdrFail'
                  GOTO RollBackTran
               END

               SELECT @cPickSlipNo = MIN(RTRIM(ISNULL(PickHeaderKey,'')))
               FROM   dbo.PickHeader PH WITH (NOLOCK)
               WHERE  Orderkey = @cOrderkey
            END -- packheader does not exist
            ELSE
            BEGIN
               SELECT @cPickSlipNo = MIN(RTRIM(ISNULL(PickHeaderKey,'')))
               FROM   dbo.PickHeader PH WITH (NOLOCK)
               WHERE  Orderkey = @cOrderkey
            END

            SELECT @cLoadKey  = LoadKey
                  ,@cOrderKey = OrderKey
            FROM dbo.PackHeader WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            SELECT @nSUM_PackQTY = 0, @nSUM_PickQTY = 0

            IF ISNULL(RTRIM(@cDropID),'')  <> ''
            BEGIN
               SELECT @nSUM_PackQTY = ISNULL(SUM(PD.QTY), 0)
               FROM dbo.PackDetail PD WITH (NOLOCK)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.DropID = @cDropID
                  AND PD.PickSlipNo = @cPickSlipNo

               SELECT @nSUM_PickQTY = ISNULL(SUM(Qty), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey
               WHERE PD.StorerKey = @cStorerKey
                 AND PD.DropID = @cDropID
                 AND (PD.Status IN ('3', '5') OR PD.ShipFlag = 'P')
                 AND PH.PickHeaderKey = @cPickSlipNo
            END
            ELSE
            BEGIN
               SELECT @nSUM_PackQTY = ISNULL(SUM(PD.QTY), 0)
               FROM dbo.PackDetail PD WITH (NOLOCK)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.PickSlipNo = @cPickSlipNo

              SELECT @nSUM_PickQTY = ISNULL(SUM(Qty), 0)
              FROM dbo.PickDetail PD WITH (NOLOCK)
              INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey
              WHERE PD.StorerKey = @cStorerKey
                 AND PH.PickHeaderKey = @cPickSlipNo
            END

            IF @nSUM_PackQTY = @nSUM_PickQTY
            BEGIN
               SET @nErrNo = 193311
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ToteCompleted
               GOTO RollBackTran
            END

            /****************************
             PACKDETAIL
            ****************************/
            SET @cLabelNo = 0
            SET @nCartonNo = 0

            IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                                   WHERE PickSlipNo = @cPickSlipNo )
            BEGIN
               SELECT @cShipperKey = ShipperKey
               FROM dbo.ORDERS WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey

               IF EXISTS ( SELECT 1
                     FROM dbo.CODELKUP CLK WITH (NOLOCK)
                     WHERE CLK.LISTNAME = 'CARTNTRACK'
                     AND   CLK.Code = @cShipperKey
                     AND   CLK.Storerkey = @cStorerkey)
               BEGIN
                  SELECT @cTrackNo = TrackingNo
                  FROM dbo.Orders WITH (NOLOCK)
                  WHERE OrderKey = @cOrderkey

                  SET @cLabelNo = ISNULL(@cTrackNo ,'')
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
                     SET @nErrNo = 193312
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GET LABEL Fail'
                     GOTO RollBackTran
                  END
               END

               IF ISNULL(@cLabelNo,'')  = ''
               BEGIN
                     SET @nErrNo = 193313
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoLabelNoGen
                     GOTO RollBackTran
               END
            END
            ELSE
            BEGIN
               SELECT @cTrackNo = TrackingNo
               FROM dbo.Orders WITH (NOLOCK)
               WHERE OrderKey = @cOrderkey

               SELECT @cLabelNo = LabelNo
                     ,@cTrackNo = UPC
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo

               SELECT @cLoadKey = LoadKey
               FROM dbo.PackHeader WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo

            END

            SELECT @nPackQty = ISNULL(SUM(ECOMM.ScannedQTY), 0)
            FROM   rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
            WHERE  ToTeNo = @cDropID
            AND    Orderkey = @cOrderkey
            AND    Status < '5'
            AND    AddWho = @cUserName

            IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND DropID = @cDropID
                            AND ISNULL(CaseID,'')  = ''
                            AND (Status IN ('3', '5') OR ShipFlag = 'P'))
            BEGIN
               UPDATE dbo.PickDetail WITH (ROWLOCK)
               SET CASEID     = @cLabelNo
                  ,TrafficCop = NULL
                  ,EditDate = GETDATE()
                  ,EditWho = SUSER_SNAME()
               WHERE StorerKey = @cStorerKey
               AND DropID = @cDropID
               AND OrderKey = @cOrderKey

               IF @@ERROR <> 0
               BEGIN
                     SET @nErrNo = 193314
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFull
                     GOTO RollBackTran
               END
            END

            DECLARE C_TOTE_DETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT ECOMM.SKU, ECOMM.ScannedQTY
            FROM   rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
            WHERE  ToTeNo = @cDropID
            AND    Orderkey = @cOrderkey
            AND    Status < '5'
            AND    AddWho = @cUserName
            ORDER BY SKU

            OPEN C_TOTE_DETAIL
            FETCH NEXT FROM C_TOTE_DETAIL INTO  @cPackSku , @nPackQty
            WHILE (@@FETCH_STATUS <> -1)
            BEGIN
               SET @cLabelLine = '00000'

               IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                              WHERE PickSlipNo = @cPickSlipNo
                                 AND SKU = @cPackSku
                                 AND DropID = @cDropID)
               BEGIN
                  -- update the existing packdetail labelno
                  UPDATE dbo.Packdetail WITH (ROWLOCK)
                  SET   LabelNo  = @cLabelNo,
                        RefNo    = @cLabelNo,
                        UPC      = @cTrackNo,
                        EditDate = GETDATE(),
                        EditWho  = SUSER_SNAME(),
                        ArchiveCop = NULL
                  WHERE PickSlipNo = @cPickSlipNo

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 193315
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'
                     GOTO RollBackTran
                  END

                  -- Check if sku overpacked 
                  IF ISNULL(RTRIM(@cDropID),'') <> ''
                  BEGIN
                     SELECT @nTTL_PickedQty = ISNULL(SUM(PD.QTY), 0)
                     FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.PickHeader PH WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey
                     WHERE PD.StorerKey = @cStorerKey
                        AND (PD.Status IN ('3', '5') OR PD.ShipFlag = 'P')  
                        AND PD.SKU = @cPackSku
                        AND PH.PickHeaderKey = @cPickSlipNo
                  END
                  ELSE
                  BEGIN
                     SELECT @nTTL_PickedQty = ISNULL(SUM(PD.QTY), 0)
                     FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.PickHeader PH WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey
                     WHERE PD.StorerKey = @cStorerKey
                        AND PD.SKU = @cPackSku
                        AND PH.PickHeaderKey = @cPickSlipNo
                  END

                  SELECT @nTTL_PackedQty = ISNULL(SUM(QTY), 0)
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND PickSlipNo = @cPickSlipNo
                     AND SKU = @cPackSku

                  IF @nTTL_PickedQty < (@nTTL_PackedQty + @nPackQty)
                  BEGIN
                     SET @nErrNo = 193316
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OVER PACKED'
                     GOTO RollBackTran
                  END

                  -- Insert PackDetail
                  INSERT INTO dbo.PackDetail
                  (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, DropID, UPC, AddWho, AddDate, EditWho, EditDate)
                  VALUES
                     (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cPackSku, @nPackQty,
                     @cLabelNo, @cDropID, @cTrackNo, sUser_sName(), GETDATE(), sUser_sName(), GETDATE())

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 193317
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDetFail'
                     GOTO RollBackTran
                  END
                  ELSE
                  BEGIN
                    EXEC RDT.rdt_STD_EventLog
                       @cActionType = '8', -- Packing
                       @cUserID     = @cUserName,
                       @nMobileNo   = @nMobile,
                       @nFunctionID = @nFunc,
                       @cFacility   = @cFacility,
                       @cStorerKey  = @cStorerkey,
                       @cSKU        = @cPackSku,
                       @nQty        = @nPackQty,
                       @cRefNo1     = @cDropID,
                       @cRefNo2     = @cLabelNo,
                       @cRefNo3     = @cPickSlipNo
                  END
               END --packdetail for sku/order does not exists
               ELSE
               BEGIN
                  UPDATE dbo.Packdetail WITH (ROWLOCK)
                  SET   QTY      = QTY + @nPackQty,
                        LabelNo  = @cLabelNo,
                        RefNo    = @cLabelNo,
                        UPC = @cTrackNo,
                        EditDate = GETDATE(),
                        EditWho  = SUSER_SNAME()
                  WHERE PickSlipNo = @cPickSlipNo AND SKU = @cPackSku AND DropID = @cDropID

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 193318        
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'
                     GOTO RollBackTran
                  END

                  ELSE
                  BEGIN
                     EXEC RDT.rdt_STD_EventLog
                       @cActionType = '8', -- Packing
                       @cUserID     = @cUserName,
                       @nMobileNo   = @nMobile,
                       @nFunctionID = @nFunc,
                       @cFacility   = @cFacility,
                       @cStorerKey  = @cStorerkey,
                       @cSKU        = @cPackSku,
                       @nQty        = @nPackQty,
                       @cRefNo1     = @cDropID,
                       @cRefNo2     = @cLabelNo,
                       @cRefNo3     = @cPickSlipNo
                  END

               END -- packdetail for sku/order exists
               FETCH NEXT FROM C_TOTE_DETAIL INTO  @cPackSku , @nPackQty
            END --while
            CLOSE C_TOTE_DETAIL
            DEALLOCATE C_TOTE_DETAIL

            /****************************
             PACKINFO
            ****************************/
            IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)
            BEGIN
               INSERT INTO dbo.PackInfo(PickslipNo, CartonNo, CartonType, Refno, AddWho, AddDate, EditWho, EditDate)
               SELECT DISTINCT PD.PickSlipNo, PD.CartonNo, @cDropIDType, RefNo, sUser_sName(), GETDATE(), sUser_sName(), GETDATE()
               FROM PACKHEADER PH WITH (NOLOCK)
               JOIN   PACKDETAIL PD WITH (NOLOCK) ON (PH.PickslipNo = PD.PickSlipNo)
               WHERE  PH.Orderkey = @cOrderkey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 193319
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPInfoFail'
                  GOTO RollBackTran
               END
            END

            /***************************
            UPDATE rdtECOMMLog
            ****************************/
            DECLARE C_ECOMMLOG2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef
            FROM rdt.rdtEcommLog WITH (NOLOCK)
            WHERE ToteNo      = @cDropID
            AND   Orderkey    = @cOrderkey
            AND   AddWho      = @cUserName
            AND   Status      < '5'
            ORDER BY RowRef

            OPEN C_ECOMMLOG2
            FETCH NEXT FROM C_ECOMMLOG2 INTO  @nRowRef
            WHILE (@@FETCH_STATUS <> -1)
            BEGIN
               UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)
               SET   Status      = '9'    -- completed
               WHERE RowRef      = @nRowRef

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 193320
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'
                  GOTO RollBackTran
               END

               FETCH NEXT FROM C_ECOMMLOG2 INTO  @nRowRef

            END
            CLOSE C_ECOMMLOG2
            DEALLOCATE C_ECOMMLOG2

            -- check if total order fully despatched
            SELECT @nTotalPickQty = SUM(ISNULL(PK.Qty,0))
            FROM  dbo.PICKDETAIL PK WITH (nolock)
            WHERE PK.Orderkey = @cOrderkey
            AND PK.Status NOT IN ( '4' , '9' )

            SELECT @nTotalPackQty = SUM(ISNULL(PD.Qty,0))
            FROM  dbo.PACKDETAIL PD WITH (NOLOCK)
            JOIN  dbo.PACKHEADER PH WITH (NOLOCK) ON (PD.PickslipNo = PH.PickSlipNo )
            WHERE PD.StorerKey = @cStorerKey
            AND   PH.Orderkey = @cOrderkey

            -- Print Label
            IF @nTotalPickQty = @nTotalPackQty
            BEGIN
               SELECT @cPickSlipNo = PickHeaderKey
               FROM dbo.PickHeader (NOLOCK)
               WHERE OrderKey = @cOrderKey

               UPDATE dbo.PackHeader WITH (ROWLOCK)
               SET Status = '9'
                   ,Editdate   = GETDATE()
                   ,EditWho    = SUSER_SNAME()
               WHERE PickSlipNo = @cPickSlipNo
               AND StorerKey = @cStorerKey

               IF @@ERROR <> 0
               BEGIN
                   SET @nErrNo = 193321
                   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPackHdrFail
                   GOTO RollBackTran
               END

               -- Print Label via BarTender --
               SET @cRDTBartenderSP = ''
               SET @cRDTBartenderSP = rdt.RDTGetConfig( @nFunc, 'RDTBartenderSP', @cStorerkey)
               IF @cRDTBartenderSP = '0'
                  SET @cRDTBartenderSP = ''

               IF @cRDTBartenderSP <> ''
               BEGIN

                     IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRDTBartenderSP AND type = 'P')
                     BEGIN

                        SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cRDTBartenderSP) +
                                                '   @nMobile               ' +
                                                ' , @nFunc                 ' +
                                                ' , @cLangCode             ' +
                                                ' , @cFacility             ' +
                                                ' , @cStorerKey            ' +
                                                ' , @cLabelPrinter         ' +
                                                ' , @cDropID               ' +
                                                ' , @cLoadKey              ' +
                                                ' , @cLabelNo              ' +
                                                ' , @cUserName             ' +
                                                ' , @nErrNo       OUTPUT   ' +
                                                ' , @cErrMSG      OUTPUT   '


                        SET @cExecArguments =
                                   N'@nMobile     int,                   ' +
                                   '@nFunc       int,                    ' +
                                   '@cLangCode   nvarchar(3),            ' +
                                   '@cFacility   nvarchar(5),            ' +
                                   '@cStorerKey  nvarchar(15),           ' +
                                   '@cLabelPrinter     nvarchar(10),     ' +
                                   '@cDropID     nvarchar(20),           ' +
                                   '@cLoadKey    nvarchar(10),           ' +
                                   '@cLabelNo    nvarchar(20),           ' +
                                   '@cUserName   nvarchar(18),           ' +
                                   '@nErrNo      int  OUTPUT,            ' +
                                   '@cErrMsg     nvarchar(1024) OUTPUT   '



                        EXEC sp_executesql @cExecStatements, @cExecArguments,
                                              @nMobile
                                            , @nFunc
                                            , @cLangCode
                                            , @cFacility
                                            , @cStorerKey
                                            , @cLabelPrinter
                                            , @cDropID
                                            , @cLoadKey
                                            , @cLabelNo
                                            , @cUserName
                                            , @nErrNo       OUTPUT
                                            , @cErrMSG      OUTPUT

                         IF @nErrNo <> 0
                         BEGIN
                            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidCarton'
                            GOTO RollBackTran
                         END
                     END
               END
               ELSE
               BEGIN
                  -- Common params ofr printing
                  DECLARE @tSHIPPLABEL       VariableTable
                  DECLARE @tDelNotes         VariableTable
                  DECLARE @tDelNotesN        VariableTable
                  DECLARE @tRtnNotes         VariableTable
                  DECLARE @tRtnNotesN         VariableTable
                  DECLARE @cShipLabel        NVARCHAR( 10)
                  DECLARE @cDelNotes         NVARCHAR( 10)
                  DECLARE @cDelNotesN        NVARCHAR( 10)
                  DECLARE @cRtnNotes         NVARCHAR( 10)
                  DECLARE @cRtnNotesN        NVARCHAR( 10)
                  DECLARE @cOrdType          NVARCHAR( 1)
                  DECLARE @cPlatform         NVARCHAR( 20)
                  DECLARE @cC_ISOCntryCode   NVARCHAR( 10)

                  SELECT @cOrdType = DocType,
                         @cC_ISOCntryCode = C_ISOCntryCode,
                         @cFacility = Facility,
                         @cShipperKey = ShipperKey
                  FROM dbo.Orders WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey

                  SELECT @cPlatform = [Platform]
                  FROM dbo.OrderInfo WITH (NOLOCK)
                  WHERE OrderKey = @cOrderKey
                  

                  --(yeekung01)
                  SELECT @cShipLabel=notes2
                  FROM codelkup (nolock)
                  where listname='AsgnTNo'
                  AND storerkey=@cStorerkey
                  AND short =@cShipperKey
                  AND notes = @cfacility

                  IF ISNULL(@cShipLabel,'') =''
                  BEGIN
                     SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
                     IF @cShipLabel = '0'
                        SET @cShipLabel = ''
                  END

                  IF @cOrdType = 'E' AND EXISTS (
                     SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                     WHERE LISTNAME = 'CartnTrack'
                     AND   Code = @cShipperKey
                     AND   Storerkey = @cStorerkey)
                  BEGIN
                     IF @cShipLabel <> ''
                     BEGIN
                        SELECT TOP 1 @nCartonNo = CartonNo
                        FROM dbo.PackDetail WITH (NOLOCK)
                        WHERE PickSlipNo = @cPickSlipNo
                        AND   DropID = @cDropID
                        ORDER BY 1

                        SET @nErrNo = 0
                        INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderKey',       @cOrderKey)
                        INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nFromCartonNo',   @nCartonNo)
                        INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nToCartonNo',     @nCartonNo)

                        -- Print label
                        EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerkey, @cLabelPrinter, '',
                           @cShipLabel, -- Report type
                           @tSHIPPLABEL, -- Report params
                           'rdt_841ExtUpdSP31',
                           @nErrNo  OUTPUT,
                           @cErrMsg OUTPUT

                        IF @nErrNo <> 0
                        BEGIN
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                           GOTO RollBackTran
                        END
                     END
                  END

                  IF @cOrdType = 'E' AND @cPlatform <> 'FF'
                  BEGIN
                     SELECT @cPaperPrinter = Printer_Paper
                     FROM rdt.RDTMOBREC WITH (NOLOCK)
                     WHERE Mobile = @nMobile

                     IF @cC_ISOCntryCode = 'OTHERS'
                     BEGIN
                        SET @cDelNotes = rdt.RDTGetConfig( @nFunc, 'DelNotes', @cStorerKey)
                        IF @cDelNotes = '0'
                        SET @cDelNotes = ''

                        SET @cRtnNotes = rdt.RDTGetConfig( @nFunc, 'RtnNotes', @cStorerKey)
                        IF @cRtnNotes = '0'
                        SET @cRtnNotes = ''

                        IF @cDelNotes <> ''
                        BEGIN
                           INSERT INTO @tDelNotes (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)
                           INSERT INTO @tDelNotes (Variable, Value) VALUES ( '@cC_ISOCntryCode', @cC_ISOCntryCode)
                           INSERT INTO @tDelNotes (Variable, Value) VALUES ( '@cFacility', @cFacility)

                          -- Print label
                          EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,
                             @cDelNotes, -- Report type
                             @tDelNotes, -- Report params
                             'rdt_841ExtUpdSP31',
                             @nErrNo  OUTPUT,
                             @cErrMsg OUTPUT
                        END

                        IF @cRtnNotes <> ''
                        BEGIN
                           INSERT INTO @tRtnNotes (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)
                           INSERT INTO @tRtnNotes (Variable, Value) VALUES ( '@cC_ISOCntryCode', @cC_ISOCntryCode)
                           INSERT INTO @tRtnNotes (Variable, Value) VALUES ( '@cFacility', @cFacility)

                          -- Print label
                          EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,
                             @cRtnNotes, -- Report type
                             @tRtnNotes, -- Report params
                             'rdt_841ExtUpdSP31',
                             @nErrNo  OUTPUT,
                             @cErrMsg OUTPUT
                        END
                     END
                     ELSE
                     BEGIN
                        SET @cDelNotesN = rdt.RDTGetConfig( @nFunc, 'DelNotesN', @cStorerKey)
                        IF @cDelNotesN = '0'
                        SET @cDelNotesN = ''

                        SET @cRtnNotesN = rdt.RDTGetConfig( @nFunc, 'RtnNotesN', @cStorerKey)
                        IF @cRtnNotesN = '0'
                        SET @cRtnNotesN = ''

                        IF @cDelNotesN <> ''
                        BEGIN
                           INSERT INTO @tDelNotesN (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)
                           INSERT INTO @tDelNotesN (Variable, Value) VALUES ( '@cC_ISOCntryCode', @cC_ISOCntryCode)
                           INSERT INTO @tDelNotesN (Variable, Value) VALUES ( '@cFacility', @cFacility)

                          -- Print label
                          EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,
                             @cDelNotesN, -- Report type
                             @tDelNotesN, -- Report params
                             'rdt_841ExtUpdSP31',
                             @nErrNo  OUTPUT,
                             @cErrMsg OUTPUT
                        END

                        IF @cRtnNotesN <> ''
                        BEGIN
                           INSERT INTO @tRtnNotesN (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)
                           INSERT INTO @tRtnNotesN (Variable, Value) VALUES ( '@cC_ISOCntryCode', @cC_ISOCntryCode)
                           INSERT INTO @tRtnNotesN (Variable, Value) VALUES ( '@cFacility', @cFacility)

                          -- Print label
                          EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,
                             @cRtnNotesN, -- Report type
                             @tRtnNotesN, -- Report params
                             'rdt_841ExtUpdSP31',
                             @nErrNo  OUTPUT,
                             @cErrMsg OUTPUT
                        END
                     END
                  END
               END

               SELECT @cDataWindow = DataWindow,
                     @cTargetDB = TargetDB
               FROM rdt.rdtReport WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   ReportType = 'BAGMANFEST'

               SET @cShipperKey = ''
               SET @cOrderType = ''

               SELECT @cShipperKey = ShipperKey
                     ,@cOrderType  = Type
                     ,@cSectionKey = RTRIM(SectionKey)
               FROM dbo.Orders WITH (NOLOCK)
               WHERE OrderKey = @cOrderkey
               AND StorerKey = @cStorerKey

               -- Build PrintJob for RDT Spooler --
               IF @cOrderType = 'TMALL'
               BEGIN
                  -- Trigger WebService --
                  EXEC  [isp_WS_UpdPackOrdSts]
                    @cOrderKey
                  , @cStorerKey
                  , @bSuccess OUTPUT
                  , @nErrNo    OUTPUT
                  , @cErrMsg   OUTPUT
               END
               ELSE
               BEGIN
                  SET @cSOStatus = ''
                  SELECT @cSOStatus = SOStatus
                  FROM dbo.Orders WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND OrderKey = @cOrderkey

                  UPDATE dbo.Orders WITH (ROWLOCK)
                  SET SOStatus= '0'
                     ,TrafficCop = NULL
                     ,Editdate   = GETDATE()
                     ,EditWho    = SUSER_SNAME()
                  WHERE OrderKey = @cOrderkey
                  AND StorerKey = @cStorerKey

                  IF  @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 193322
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdOrdFail'
                     GOTO RollBackTran
                  END
               END

               IF EXISTS ( SELECT 1 FROM dbo.CodeLkup WITH (NOLOCK)
                   WHERE ListName = 'DTCPrinter' )
               BEGIN
                  -- Get Printer Information
                  SELECT @cPrinter01 = RTRIM(Code)
                        ,@cBrand01   = RTRIM(Short)
                        ,@cPrinter02 = RTRIM(UDF01)
                        ,@cBrand02   = RTRIM(UDF02)
                  FROM dbo.CodeLkup WITH (NOLOCK)
                  WHERE ListName = 'DTCPrinter'
                  AND RTRIM(Code) = ISNULL(RTRIM(@cPaperPrinter),'')

                  IF @cSectionKey = @cBrand01
                  BEGIN
                     SET @cPaperPrinter = @cPrinter01
                  END
                  ELSE IF @cSectionKey = @cBrand02
                  BEGIN
                     SET @cPaperPrinter = @cPrinter02
                  END
               END

               IF @cPaperPrinter <> 'PDF' AND @cPaperPrinter <> ''
               BEGIN
                  EXEC RDT.rdt_BuiltPrintJob
                   @nMobile,
                   @cStorerKey,
                   'BAGMANFEST',              -- ReportType
                   'ANF_CUSTOMERMANIFEST',    -- PrintJobName
                   @cDataWindow,
                   @cPaperPrinter,
                   @cTargetDB,
                   @cLangCode,
                   @nErrNo  OUTPUT,
                   @cErrMsg OUTPUT,
                   @cOrderkey,
                   @cLabelNo
               END

               IF @cShipperKey = 'FEDEX'
               BEGIN
                  SET @cSHIPZPLLBL = rdt.RDTGetConfig( @nFunc, 'SHIPZPLLBL', @cStorerKey)  
                  IF @cSHIPZPLLBL = '0'  
                     SET @cSHIPZPLLBL = ''  
         	
         	      IF @cSHIPZPLLBL <> ''
         	      BEGIN
                     INSERT INTO @tSHIPZPLLBL (Variable, Value) VALUES ( '@cOrderKey',   @cOrderkey)
               
                     -- Print label
                     EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerkey, @cLabelPrinter, '',
                        @cSHIPZPLLBL, -- Report type
                        @tSHIPZPLLBL, -- Report params
                        'rdt_841ExtUpdSP31',
                        @nErrNo  OUTPUT,
                        @cErrMsg OUTPUT

                     IF @nErrNo <> 0
                        GOTO Quit
                  END
               END

               SET @nTotalPickQty = 0
               SET @cOrderKeyOut = @cOrderkey

               SET @cTrackNoFlag = '1'
            END
         END
      END
      ELSE
      BEGIN
            SET @cShowTrackNoScn = rdt.RDTGetConfig( @nFunc, 'ShowTrackNoScn', @cStorerKey)

            IF @cShowTrackNoScn <> '1'
            BEGIN
               SET @nTotalPickQty = 0
               SELECT @nTotalPickQty = SUM(PD.QTY)
               FROM PICKDETAIL PD WITH (NOLOCK)
               WHERE PD.ORDERKEY = @cOrderKey
               AND PD.Storerkey = @cStorerkey
               AND PD.Status NOT IN ( '4' , '9' )

               SET @nTotalPackQty = 0
               SELECT @nTotalPackQty = SUM(ScannedQty)
               FROM rdt.rdtEcommLog WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey

               IF @nTotalPickQty = @nTotalPackQty
               BEGIN
                  SELECT @cPickSlipNo = PickHeaderKey
                  FROM dbo.PickHeader (NOLOCK)
                  WHERE OrderKey = @cOrderKey

                  SET @nErrNo = 0
                  EXEC isp_ScanOutPickSlip
                     @c_PickSlipNo = @cPickSlipNo,
                     @n_err = @nErrNo OUTPUT,
                     @c_errmsg = @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     SET @nErrNo = 193323
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickInfoFail
                     GOTO RollBackTran
                  END

               END

               SELECT @cTrackNo = TrackingNo
               FROM dbo.Orders WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey

               SET @cPickDetailKey = ''

               IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                           WHERE StorerKey = @cStorerKey
                           AND OrderKey = @cOrderkey
                           GROUP BY StorerKey, OrderKey
                           HAVING Count (DISTINCT PickDetailKey) = 1  )
               BEGIN
                    SELECT TOP 1 @cPickDetailKey = PickDetailKey
                    FROM dbo.PickDetail WITH (NOLOCK)
                    WHERE StorerKey = @cStorerKey
                    AND OrderKey    = @cOrderkey
                    AND SKU         = @cSKU

                    -- PickDetail.CaseID = TrackNo
                    UPDATE dbo.PickDetail WITH (ROWLOCK)
                    SET CaseID     = @cTrackNo
                       ,TrafficCop = NULL
                       ,Editdate   = GETDATE()
                       ,EditWho    = SUSER_SNAME()
                    WHERE StorerKey = @cStorerKey
                    AND PickDetailKey = @cPickDetailKey

                    IF @@ERROR <> 0
                    BEGIN
                       SET @nErrNo = 193324
                       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetailFail
                       GOTO RollBackTran
                    END
               END
               ELSE
               BEGIN
                  DECLARE C_ECOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                  SELECT PickDetailKey
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND OrderKey = @cOrderkey
                  AND SKU      = @cSKU
                  ORDER BY PickDetailKey
                  OPEN C_ECOM
                  FETCH NEXT FROM C_ECOM INTO  @cPickDetailKey
                  WHILE (@@FETCH_STATUS <> -1)
                  BEGIN
                     -- PickDetail.CaseID = TrackNo
                     UPDATE dbo.PickDetail WITH (ROWLOCK)
                     SET CaseID     = @cTrackNo
                        ,TrafficCop = NULL
                        ,Editdate   = GETDATE()
                        ,EditWho = SUSER_SNAME()
                     WHERE StorerKey = @cStorerKey
                     AND PickDetailKey = @cPickDetailKey

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 193325
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetailFail
                        GOTO RollBackTran
                     END

                     FETCH NEXT FROM C_ECOM INTO  @cPickDetailKey
                  END
                  CLOSE C_ECOM
                  DEALLOCATE C_ECOM
               END

               SET @cLabelNo = @cTrackNo

               -- Print Label
               IF @nTotalPickQty = @nTotalPackQty
               BEGIN
                  SET @nTotalPickQty = 0
                  SET @cOrderKeyOut = @cOrderkey

                  -- Print Label via BarTender --
                  SET @cRDTBartenderSP = ''
                  SET @cRDTBartenderSP = rdt.RDTGetConfig( @nFunc, 'RDTBartenderSP', @cStorerkey)

                  IF @cRDTBartenderSP <> ''
                  BEGIN
                     IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cRDTBartenderSP AND type = 'P')
                     BEGIN

                        SET @cExecStatements = N'EXEC rdt.' + RTRIM( @cRDTBartenderSP) +
                                                '   @nMobile               ' +
                                                ' , @nFunc                 ' +
                                                ' , @cLangCode             ' +
                                                ' , @cFacility             ' +
                                                ' , @cStorerKey            ' +
                                                ' , @cLabelPrinter         ' +
                                                ' , @cDropID               ' +
                                                ' , @cLoadKey              ' +
                                                ' , @cLabelNo              ' +
                                                ' , @cUserName             ' +
                                                ' , @nErrNo       OUTPUT   ' +
                                                ' , @cErrMSG      OUTPUT   '


                        SET @cExecArguments =
                                    N'@nMobile     int,                   ' +
                                    '@nFunc       int,                    ' +
                                    '@cLangCode   nvarchar(3),            ' +
                                    '@cFacility   nvarchar(5),            ' +
                                    '@cStorerKey  nvarchar(15),           ' +
                                    '@cLabelPrinter     nvarchar(10),     ' +
                                    '@cDropID     nvarchar(20),           ' +
                                    '@cLoadKey    nvarchar(10),           ' +
                                    '@cLabelNo    nvarchar(20),           ' +
                                    '@cUserName   nvarchar(18),           ' +
                                    '@nErrNo      int  OUTPUT,            ' +
                                    '@cErrMsg     nvarchar(1024) OUTPUT   '



                        EXEC sp_executesql @cExecStatements, @cExecArguments,
                                                @nMobile
                                             , @nFunc
                                             , @cLangCode
                                             , @cFacility
                                             , @cStorerKey
                                             , @cLabelPrinter
                                             , @cDropID
                                             , @cLoadKey
                                             , @cLabelNo
                                             , @cUserName
                                             , @nErrNo       OUTPUT
                                             , @cErrMSG      OUTPUT

                           IF @nErrNo <> 0
                           BEGIN
                              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidCarton'
                              GOTO RollBackTran
                           END
                     END
                  END

                  SELECT @cDataWindow = DataWindow,
                        @cTargetDB = TargetDB
                  FROM rdt.rdtReport WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   ReportType = 'BAGMANFEST'

                  SET @cShipperKey = ''
                  SET @cOrderType = ''

                  SELECT @cShipperKey = ShipperKey
                        ,@cOrderType  = Type
                        ,@cSectionKey = RTRIM(SectionKey)
                  FROM dbo.Orders WITH (NOLOCK)
                  WHERE OrderKey = @cOrderkey
                  AND StorerKey = @cStorerKey

                  -- Build PrintJob for RDT Spooler --
                  IF @cOrderType = 'TMALL'
                  BEGIN
                     -- Trigger WebService --
                     EXEC  [isp_WS_UpdPackOrdSts]
                       @cOrderKey
                     , @cStorerKey
                     , @bSuccess OUTPUT
                     , @nErrNo    OUTPUT
                     , @cErrMsg   OUTPUT

                  END
                  ELSE
                  BEGIN
                     SET @cSOStatus = ''
                     SELECT @cSOStatus = SOStatus
                     FROM dbo.Orders WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND OrderKey = @cOrderkey

                     UPDATE dbo.Orders WITH (ROWLOCK)
                     SET SOStatus= '0'
                        ,TrafficCop = NULL
                        ,Editdate   = GETDATE()
                        ,EditWho    = SUSER_SNAME()
                     WHERE OrderKey = @cOrderkey
                     AND StorerKey = @cStorerKey

                     IF  @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 193326
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdOrdFail'
                        GOTO RollBackTran
                     END
                  END

                  IF EXISTS ( SELECT 1 FROM dbo.CodeLkup WITH (NOLOCK)
                              WHERE ListName = 'DTCPrinter' )
                  BEGIN
                     -- Get Printer Information
                     SELECT @cPrinter01 = RTRIM(Code)
                           ,@cBrand01   = RTRIM(Short)
                           ,@cPrinter02 = RTRIM(UDF01)
                           ,@cBrand02   = RTRIM(UDF02)
                     FROM dbo.CodeLkup WITH (NOLOCK)
                     WHERE ListName = 'DTCPrinter'
                     AND RTRIM(Code) = ISNULL(RTRIM(@cPaperPrinter),'')

                     IF @cSectionKey = @cBrand01
                     BEGIN
                        SET @cPaperPrinter = @cPrinter01
                     END
                     ELSE IF @cSectionKey = @cBrand02
                     BEGIN
                        SET @cPaperPrinter = @cPrinter02
                     END
                  END

                  IF @cPaperPrinter <> 'PDF' AND @cPaperPrinter <> ''
                  BEGIN
                     EXEC RDT.rdt_BuiltPrintJob
                      @nMobile,
                      @cStorerKey,
                      'BAGMANFEST',              -- ReportType
                      'ANF_CUSTOMERMANIFEST',    -- PrintJobName
                      @cDataWindow,
                      @cPaperPrinter,
                      @cTargetDB,
                      @cLangCode,
                      @nErrNo  OUTPUT,
                      @cErrMsg OUTPUT,
                      @cOrderkey,
                      @cLabelNo
                  END

                  IF @cShipperKey = 'FEDEX'
                  BEGIN
                     SET @cSHIPZPLLBL = rdt.RDTGetConfig( @nFunc, 'SHIPZPLLBL', @cStorerKey)  
                     IF @cSHIPZPLLBL = '0'  
                        SET @cSHIPZPLLBL = ''  
         	
         	         IF @cSHIPZPLLBL <> ''
         	         BEGIN
                        INSERT INTO @tSHIPZPLLBL (Variable, Value) VALUES ( '@cOrderKey',   @cOrderkey)
               
                        -- Print label
                        EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerkey, @cLabelPrinter, '',
                           @cSHIPZPLLBL, -- Report type
                           @tSHIPZPLLBL, -- Report params
                           'rdt_841ExtUpdSP31',
                           @nErrNo  OUTPUT,
                           @cErrMsg OUTPUT

                        IF @nErrNo <> 0
                           GOTO Quit
                     END
                  END
               END
            END

            DECLARE C_ECOMMLOG1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT RowRef
            FROM rdt.rdtEcommLog WITH (NOLOCK)
            WHERE ToteNo      = @cDropID
            AND   SKU         = @cSKU
            AND   Orderkey    = @cOrderkey
            AND   AddWho      = @cUserName
            AND   Status      < '5'
            AND   ScannedQty  >= ExpectedQty

            OPEN C_ECOMMLOG1
            FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef
            WHILE (@@FETCH_STATUS <> -1)
            BEGIN

               /****************************
                rdtECOMMLog
               ****************************/
               --update rdtECOMMLog
               UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)
               SET   Status      = '9'    -- completed
               WHERE RowRef = @nRowRef

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 193327
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'
                  GOTO RollBackTran
               END

               FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef

            END
            CLOSE C_ECOMMLOG1
            DEALLOCATE C_ECOMMLOG1
         END
      END


   GOTO QUIT

RollBackTran:
   ROLLBACK TRAN rdt_841ExtUpdSP31 -- Only rollback change made here

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_841ExtUpdSP31


END

GO