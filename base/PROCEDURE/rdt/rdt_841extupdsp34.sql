SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_841ExtUpdSP34                                   */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: Ecomm Update SP                                             */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2023-04-05  1.0  yeekung   WMS-22157 Created                         */
/************************************************************************/

CREATE   PROC [RDT].[rdt_841ExtUpdSP34] (
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR( 3),  
   @cUserName     NVARCHAR( 15),  
   @cFacility     NVARCHAR( 5),  
   @cStorerKey    NVARCHAR( 15),  
   @cDropID       NVARCHAR( 20),  
   @cSKU          NVARCHAR( 20),  
   @nStep         INT,  
   @cPickslipNo   NVARCHAR( 10),  
   @cPrevOrderkey NVARCHAR(10),  
   @cTrackNo      NVARCHAR( 20),  
   @cTrackNoFlag  NVARCHAR(1)   OUTPUT,  
   @cOrderKeyOut  NVARCHAR(10)  OUTPUT,  
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR( 20) OUTPUT,  -- screen limitation, 20 char max  
   @cCartonType   NVARCHAR( 20) ='',  --(yeekung01) 
   @cSerialNo     NVARCHAR( 30), 
   @nSerialQTY    INT,
   @tExtUpd       VariableTable READONLY     
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
          ,@cAutoMBOLPack     NVARCHAR( 1)   -- (james03)

   DECLARE @curPD CURSOR

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
   SAVE TRAN rdt_841ExtUpdSP34

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
          SET @nErrNo = 199055
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
            SET @nErrNo = 199056
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
         SET @nErrNo = 199057
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
            SET @nErrNo = 199058
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'
            GOTO RollBackTran
         END

         FETCH NEXT FROM C_ECOMMLOG1 INTO  @nRowRef

      END
      CLOSE C_ECOMMLOG1
      DEALLOCATE C_ECOMMLOG1

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
              SET @nErrNo = 199079
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
              SET @nErrNo = 199080
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InstPKHdrFail '
              GOTO RollBackTran

          END
      END --ISNULL(@cPickSlipno, '') = ''

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
               SET @nErrNo = 199081
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ScanInFail'
               GOTO RollBackTran
          END
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
                     SET @nErrNo = 199059
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickHdrFail'
                     GOTO RollBackTran
                  END
                  ELSE
                  BEGIN
                     SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                        SELECT PickDetailKey
                        FROM PickDetail WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                           AND Orderkey = @cOrderKey
                           AND (Status IN ('3', '5') OR ShipFlag = 'P')
                           AND ISNULL(RTrim(Pickslipno),'') = ''
                     OPEN @curPD
                     FETCH NEXT FROM @curPD INTO @cPickDetailKey
                     WHILE @@FETCH_STATUS = 0
                     BEGIN
                        UPDATE dbo.PickDetail SET
                           PickSlipNo = @cPickslipno,
                           Trafficcop = NULL,
                           EditDate = GETDATE(),
                           EditWho = SUSER_SNAME()
                        WHERE PickDetailKey = @cPickDetailKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 199060
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDetFail'
                           GOTO RollBackTran
                        END
                     
                        FETCH NEXT FROM @curPD INTO @cPickDetailKey
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
                  SET @nErrNo = 199061
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
                 AND (PD.Status IN ('3', '5')  OR PD.ShipFlag = 'P')
                 AND PH.PickHeaderKey = @cPickSlipNo

               --SELECT @cPickSlipno '@cPickSlipno' , @cOrderKey '@cOrderKey' , @nSUM_PackQTY '@nSUM_PackQTY' , @nSUM_PickQTY '@nSUM_PickQTY'
            END
            ELSE
            BEGIN
               SELECT @nSUM_PackQTY = ISNULL(SUM(PD.QTY), 0)
               FROM dbo.PackDetail PD WITH (NOLOCK)
               WHERE PD.StorerKey = @cStorerKey
                  --AND PD.DropID = @cDropID  --NoTote  
                  AND PD.PickSlipNo = @cPickSlipNo

               SELECT @nSUM_PickQTY = ISNULL(SUM(Qty), 0)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey
               WHERE PD.StorerKey = @cStorerKey
                  --AND PD.DropID = @cDropID  --NoTote  
                  --AND PD.Status = '5'
                  AND PH.PickHeaderKey = @cPickSlipNo
            END

            IF @nSUM_PackQTY = @nSUM_PickQTY
            BEGIN
               SET @nErrNo = 199051
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ToteCompleted
               GOTO RollBackTran
            END

            /****************************
             PACKDETAIL
            ****************************/
            SET @cLabelNo = 0
            SET @nCartonNo = 0
            BEGIN

               SELECT @cTrackNo = TrackingNo -- (james04)
               FROM dbo.Orders WITH (NOLOCK)
               WHERE OrderKey = @cOrderkey

               SET @cLabelNo = @cTrackNo
            END

            SELECT @nPackQty = ISNULL(SUM(ECOMM.ScannedQTY), 0)
            FROM   rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
            WHERE  ToTeNo = @cDropID
            AND    Orderkey = @cOrderkey
            AND    Status < '5'
            AND    AddWho = @cUserName

            IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                                  WHERE StorerKey = @cStorerKey
                                  AND OrderKey = @cOrderKey
                                  AND ISNULL(UserDefine04,'')  = '' )
            BEGIN
               UPDATE dbo.Orders WITH (ROWLOCK)
               SET UserDefine04 = @cTrackNo
                  ,Trafficcop   = NULL -- (ChewKP02)
                  ,EditDate = GETDATE()
                  ,EditWho = SUSER_SNAME()
               WHERE Orderkey = @cOrderKey
               AND Storerkey = @cStorerKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 199075
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdOrderFail
                  GOTO RollBackTran
               END
            END

            IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND OrderKey = @cOrderKey
                            AND DropID = @cDropID
                            AND CaseID = ''
                            --AND Status = '5' ) -- (ChewKP01)
                            AND (Status IN ('3', '5') OR ShipFlag = 'P')) -- (ChewKP01)
            BEGIN
               SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT PickDetailKey
                  FROM PickDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND DropID = @cDropID
                     AND OrderKey = @cOrderKey
               OPEN @curPD
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  UPDATE dbo.PickDetail SET 
                     CASEID = @cLabelNo
                     ,TrafficCop = NULL
                     ,EditDate = GETDATE()
                     ,EditWho = SUSER_SNAME()
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 199076
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFull
                     GOTO RollBackTran
                  END
                  FETCH NEXT FROM @curPD INTO @cPickDetailKey
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
                            AND SKU = @cPackSku)    
                                 --AND DropID = @cDropID)  --NoNeedCHeckTote  
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
                     SET @nErrNo = 199062
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'
                     GOTO RollBackTran
                  END

                  -- Check if sku overpacked (james03)
                  IF ISNULL(RTRIM(@cDropID),'') <> ''
                  BEGIN
                     SELECT @nTTL_PickedQty = ISNULL(SUM(PD.QTY), 0)
                     FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.PickHeader PH WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey
                     WHERE PD.StorerKey = @cStorerKey
                        AND (PD.Status IN ('3' , '5') OR PD.ShipFlag = 'P')
                        AND PD.SKU = @cPackSku
                        AND PH.PickHeaderKey = @cPickSlipNo
                  END
                  ELSE
                  BEGIN
                     SELECT @nTTL_PickedQty = ISNULL(SUM(PD.QTY), 0)
                     FROM dbo.PickDetail PD WITH (NOLOCK)
                     JOIN dbo.PickHeader PH WITH (NOLOCK) ON PD.OrderKey = PH.OrderKey
                     WHERE PD.StorerKey = @cStorerKey
                        --AND PD.Status = '5'
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
                     SET @nErrNo = 199063
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
                     SET @nErrNo = 199064
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
                  WHERE PickSlipNo = @cPickSlipNo AND SKU = @cPackSku --AND DropID = @cDropID  --NoNeedCHeckTote  

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 69907        --(Kc07)
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
               FROM   PACKHEADER PH WITH (NOLOCK)
               JOIN   PACKDETAIL PD WITH (NOLOCK) ON (PH.PickslipNo = PD.PickSlipNo)
               WHERE  PH.Orderkey = @cOrderkey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 199065
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
                  SET @nErrNo = 199066
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
            JOIN  dbo.PACKHEADER PH WITH (NOLOCK) ON (PD.PickslipNo = PH.PickSlipNo AND PH.Orderkey = @cOrderkey)

            -- Print Label
            IF @nTotalPickQty = @nTotalPackQty
            BEGIN
               -- (james03)
               SET @nErrNo = 0
               EXEC nspGetRight
                     @c_Facility   = @cFacility
                  ,  @c_StorerKey  = @cStorerKey
                  ,  @c_sku        = ''
                  ,  @c_ConfigKey  = 'AutoMBOLPack'
                  ,  @b_Success    = @bSuccess             OUTPUT
                  ,  @c_authority  = @cAutoMBOLPack        OUTPUT
                  ,  @n_err        = @nErrNo               OUTPUT
                  ,  @c_errmsg     = @cErrMsg              OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 199089
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetRightFail
                  GOTO RollBackTran
               END

               IF @cAutoMBOLPack = '1'
               BEGIN
                  SET @nErrNo = 0
                  EXEC dbo.isp_QCmd_SubmitAutoMbolPack
                    @c_PickSlipNo= @cPickSlipNo
                  , @b_Success   = @bSuccess    OUTPUT
                  , @n_Err       = @nErrNo      OUTPUT
                  , @c_ErrMsg    = @cErrMsg     OUTPUT

                  IF @nErrNo <> 0
                  BEGIN
                     SET @nErrNo = 199090
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- AutoMBOLPack
                     GOTO RollBackTran
                  END
               END

               UPDATE dbo.PackHeader WITH (ROWLOCK)
                  SET Status = '9'
                  ,Editdate   = GETDATE()
                  ,EditWho    = SUSER_SNAME()
               WHERE PickSlipNo = @cPickSlipNo
               AND StorerKey = @cStorerKey

               IF @@ERROR <> 0
                  GOTO RollBackTran

               -- (james02)
               -- Get storer config
               DECLARE @cAssignPackLabelToOrdCfg NVARCHAR(1)
               EXECUTE nspGetRight
                  @cFacility,
                  @cStorerKey,
                  '', --@c_sku
                  'AssignPackLabelToOrdCfg',
                  @bSuccess                 OUTPUT,
                  @cAssignPackLabelToOrdCfg OUTPUT,
                  @nErrNo                   OUTPUT,
                  @cErrMsg                  OUTPUT
               IF @nErrNo <> 0
                  GOTO RollBackTran

               -- Assign
               IF @cAssignPackLabelToOrdCfg = '1'
               BEGIN
                  -- Update PickDetail, base on PackDetail.DropID
                  EXEC isp_AssignPackLabelToOrderByLoad
                      @cPickSlipNo
                     ,@bSuccess OUTPUT
                     ,@nErrNo   OUTPUT
                     ,@cErrMsg  OUTPUT
                  IF @nErrNo <> 0
                     GOTO RollBackTran
               END

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

                  -- (james01)
                  -- Order might get cancenlled during packing
                  -- after key in tote, all orders get inserted into rdtecommlog
                  -- need prompt error here
                  IF @cSOStatus = 'PENDCANC'
                  BEGIN
                     SET @nErrNo = 199088
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ORD PENDCANC'
                     GOTO RollBackTran
                  END

                  UPDATE dbo.Orders WITH (ROWLOCK)
                  SET SOStatus= '0'
                     ,TrafficCop = NULL
                     ,Editdate   = GETDATE()
                     ,EditWho    = SUSER_SNAME()
                  WHERE OrderKey = @cOrderkey
                  AND StorerKey = @cStorerKey

                  IF  @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 199087
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

               IF @cPaperPrinter <> 'PDF' AND @cPaperPrinter <> '' --JYHBIN
               BEGIN
                  EXEC RDT.rdt_BuiltPrintJob
                   @nMobile,
                   @cStorerKey,
                   'BAGMANFEST',              -- ReportType
                   'HONMA_CUSTOMERMANIFEST',    -- PrintJobName
                   @cDataWindow,
                   @cPaperPrinter,
                   @cTargetDB,
                   @cLangCode,
                   @nErrNo  OUTPUT,
                   @cErrMsg OUTPUT,
                   @cStorerkey,
                   @cOrderkey
               END
            END
         END
      END
   END

   GOTO QUIT

RollBackTran:
   ROLLBACK TRAN rdt_841ExtUpdSP34 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_841ExtUpdSP34
END

GO