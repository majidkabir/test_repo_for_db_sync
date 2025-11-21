SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Store procedure: rdt_842ExtUpdSP08                                    */
/* Copyright      : Maersk                                               */
/*                                                                       */
/* Purpose: AEO DTC Logic                                                */
/*                                                                       */
/* Modifications log:                                                    */
/* Date        Rev   Author   Purposes                                   */
/* 2020-04-22  1.0   James    WMS-13002 Created                          */
/* 2020-06-04  1.1   James    Add Hoc fix carton no blank (james01)      */
/* 2020-08-13  1.2   CheeMun  INC1251022-Retrieve TrackingNo from Udf04  */
/* 2020-11-18  1.3   YeeKung  Add Break to loop two time (yeekung01)     */
/* 2021-04-16  1.4   James    WMS-16024 Standarized use of TrackingNo    */
/*                            (james02)                                  */
/* 2021-11-24  1.5   LZG      JSM-35243 - Removed hardcoded value and let*/
/*                             rdt_Print defaults the NoOfCopy (ZG01)    */
/* 2024-12-17  1.6.0 Dennis   FCR-1446 Insert Trans Log if fully packed  */
/* 2025-01-06  1.7.0 NLT013  FCR-1445 Print PDF once an order is finished*/
/* 2025-01-29  1.7.1 Dennis  FCR-1445 Move Printing Label behind commit */
/* 2025-02-12  1.8.0 NLT013  UWP-30206 Exclude the shipped orders       */
/* 2025-02-12  1.8.1 NLT013  UWP-30206 Exclude the orders not from same wave*/
/* 2025-02-14  1.8.2 NLT013  UWP-30206 Endless printing                 */
/************************************************************************/
CREATE   PROC [RDT].[rdt_842ExtUpdSP08] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR(3),
   @nStep          INT,
   @cUserName      NVARCHAR( 18),
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cDropID        NVARCHAR( 20),
   @cSKU           NVARCHAR( 20),
   @cOption        NVARCHAR( 1),
   @cOrderKey      NVARCHAR( 10) OUTPUT,
   @cTrackNo       NVARCHAR( 20) OUTPUT,
   @cCartonType    NVARCHAR( 10) OUTPUT,
   @cWeight        NVARCHAR( 20) OUTPUT,
   @cTaskStatus    NVARCHAR( 20) OUTPUT,
   @cTTLPickedQty  NVARCHAR( 10) OUTPUT,
   @cTTLScannedQty NVARCHAR( 10) OUTPUT,
   @nErrNo         INT OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT
          ,@nSUM_PackQTY      INT
          ,@nSUM_PickQTY      INT
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
          ,@cPaperPrinter     NVARCHAR(10)
          ,@cDataWindow       NVARCHAR(50)
          ,@cTargetDB         NVARCHAR(20)
          ,@cOrderType        NVARCHAR(10)
          ,@cShipperKey       NVARCHAR(10)
          ,@cPrinter02        NVARCHAR(10)
          ,@cBrand01          NVARCHAR(10)
          ,@cBrand02          NVARCHAR(10)
          ,@cPrinter01        NVARCHAR(10)
          ,@cSectionKey       NVARCHAR(10)
          ,@cSOStatus         NVARCHAR(10)
          ,@cPickSlipNo       NVARCHAR(10)
          ,@cLoadKey          NVARCHAR(10)
          ,@nTotalScannedQty  INT
          ,@nTotalPickedQty   INT
          ,@nRowRef           INT
          ,@cPostDataCapture  NVARCHAR(5)
          --,@nTotalPickedQty   INT
          --,@nTTLScannedQty    INT
          ,@cBatchKey         NVARCHAR(10)
          ,@cToteOrderKey     NVARCHAR(10)
          ,@nDropIDCount      INT
          ,@cPickDetailKey    NVARCHAR(10)
          ,@nQTYBal           INT
          ,@nPickedQty        INT

   DECLARE  @fCartonWeight       FLOAT
           ,@fCartonLength       FLOAT
           ,@fCartonHeight       FLOAT
           ,@fCartonWidth        FLOAT
           ,@fStdGrossWeight     FLOAT
           ,@fCartonTotalWeight  FLOAT
           ,@fCartonCube         FLOAT
           ,@nTotalPackedQty     INT
           ,@cManifestDataWindow NVARCHAR(50)
           ,@nMaxCartonNo        INT
           ,@nMinCartonNo        INT
           ,@fTTLWeight          FLOAT
           --,@nPackQTY            INT
           ,@nPickQty            INT
           ,@cDropOrderKey       NVARCHAR(10)
           ,@nInsertedCartonNo   INT
           ,@nInsertedLabelLine  INT
           ,@cTrackingNo         NVARCHAR(20)
           ,@cCarriername        NVARCHAR(30)
           ,@cKeyName            NVARCHAR(30)
           ,@cFilePath           NVARCHAR(100)
           ,@cProcessType        NVARCHAR( 15)
           ,@cWinPrinter         NVARCHAR(128)
           ,@cPrinterName        NVARCHAR(100)
           ,@cPrintFilePath      NVARCHAR(100)
           ,@cPrinterInGroup     NVARCHAR( 10)
           ,@cReportType         NVARCHAR( 10)
           ,@cFileName           NVARCHAR( 50)
           ,@cWinPrinterName     NVARCHAR(100)
           ,@cPrintCommand       NVARCHAR(MAX)
           ,@cPaperType          NVARCHAR( 10)
           ,@cFilePrefix         NVARCHAR( 30)
           ,@tCartonLabel        VariableTable
           ,@tRDTPrintJob        VariableTable
           ,@tDatawindow         VariableTable
           ,@tSHIPLabel          VariableTable
           ,@cTempOrderKey       NVARCHAR( 10)
           ,@cTempLabelNo        NVARCHAR( 20)
           ,@cDelayLength        NVARCHAR( 20)
           ,@nDelayLength        INT
           ,@cWaveKey            NVARCHAR( 10)
           ,@cCurrentOrderKey    NVARCHAR( 10)

   DECLARE @cCartonLabel         NVARCHAR( 10)
   DECLARE @cPackList            NVARCHAR( 10)
   DECLARE @tOrders TABLE
         (
            ID    INT IDENTITY(1,1),
            OrderKey NVARCHAR(10),
            LabelNo  NVARCHAR(20)
         )
   DECLARE @nLoopIndex INT = -1,
   @nRowCount INT = 0

   SET @nErrNo   = 0
   SET @cErrMsg  = ''

   SELECT @cCurrentOrderKey = V_OrderKey
   FROM rdt.RDTMOBREC WITH(NOLOCK)
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_842ExtUpdSP08

   IF @nStep = 1
   BEGIN

      SELECT   @cPickSlipNo = PickSlipNo
             , @cDropIDType = DropIDType
             , @cLoadKey    = LoadKey
      FROM dbo.DropID WITH (NOLOCK)
      WHERE DropID = @cDropID
      AND Status = '5'

      EXECUTE dbo.nspg_GetKey
               'RDTECOMM',
               10,
               @cBatchKey  OUTPUT,
               @bsuccess   OUTPUT,
               @nerrNo     OUTPUT,
               @cerrmsg    OUTPUT


      IF NOT EXISTS (SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND DropID = @cDropID
                     AND CASEID = ''
                     AND Status = '5' )
      BEGIN
         SET @nErrNo = 151151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'InvDropID'
         GOTO ROLLBACKTRAN
      END


      UPDATE rdt.rdtECOMMLOG WITH (ROWLOCK)
      SET Status = '9'
      , ErrMsg = 'CLEAN UP PACK'
      WHERE ToteNo = @cDropID
      AND Status < '9'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 151152
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UpdEcommFail'
         GOTO ROLLBACKTRAN
      END

      IF @cDropIDType = 'MULTIS'
      BEGIN
         SET @cDropOrderKey = ''

         SELECT Top 1 @cDropOrderKey = PD.OrderKey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
         WHERE PD.StorerKey =  @cStorerKey
         AND PD.DropID = @cDropID
         AND PD.Status < '9'
         AND O.LoadKey = @cLoadKey
         Order by PD.Editdate Desc

         IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND OrderKey = @cDropOrderKey
                     AND Status < '5' )
         BEGIN
            SET @nErrNo = 151153
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'PickNotComplete'
            GOTO ROLLBACKTRAN
         END

         SET @nDropIDCount = 0

         SELECT Top 1 @cToteOrderKey = OrderKey
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND DropID = @cDropID
         AND CASEID = ''
         AND Status = '5'

         SELECT @nDropIDCount = Count(DISTINCT DropID )
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND OrderKey = @cToteOrderKey
         AND CASEID = ''
         AND Status = '5'


      END
      ELSE
      BEGIN
         SET @nDropIDCount = 1
      END

      IF @nDropIDCount = 1
      BEGIN


          /****************************
          INSERT INTO rdtECOMMLog
         ****************************/
         INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate, BatchKey)
         SELECT @nMobile, @cDropID, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE(), @cBatchKey
         FROM dbo.PICKDETAIL PK WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey
         WHERE PK.DROPID = @cDropID
           AND (PK.Status IN ('3', '5') OR PK.ShipFlag = 'P')
           AND PK.CaseID = ''
           AND O.Type IN  ( SELECT CL.Code FROM dbo.CodeLKUP CL WITH (NOLOCK)
                           WHERE CL.ListName = 'ECOMTYPE'
                           AND CL.StorerKey = CASE WHEN CL.StorerKey = '' THEN '' ELSE O.StorerKey END)
           AND PK.Qty > 0
           AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' )
         GROUP BY PK.OrderKey, PK.SKU

         IF @@ROWCOUNT = 0 -- No data inserted
         BEGIN
            SET @nErrNo = 151154
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'
            GOTO ROLLBACKTRAN
         END
      END
      SET @nTotalScannedQty = 0

      SELECT @nTotalPickedQty  = SUM(ExpectedQty)
      FROM rdt.rdtECOMMLog WITH (NOLOCK)
      WHERE ToteNo = @cDropID
      AND Status = '0'
      AND OrderKey = CASE WHEN ISNULL(@cOrderKey,'')  = '' THEN OrderKey ELSE @cOrderKey END
      AND AddWho = @cUserName
      AND Mobile = @nMobile

      SELECT @cOrderKey = OrderKey
      FROM rdt.rdtEcommLog WITH (NOLOCK)
      WHERE ToteNo = @cDropID
      AND Status = '0'
      AND AddWho = @cUserName
      AND Mobile = @nMobile



      SET @cOrderKey      = CASE WHEN @cDropIDType = 'MULTIS' THEN @cOrderKey ELSE '' END
      SET @cTrackNo       = ''
      SET @cCartonType    = ''
      SET @cWeight        = ''
      SET @cTaskStatus    = CASE WHEN @nDropIDCount > 1 THEN '1' ELSE '9' END
      SET @cTTLPickedQty  = @nTotalPickedQty
      SET @cTTLScannedQty = '0'


   END

   IF @nStep = 2
   BEGIN

      SET @cOrderKey      = ''
      SET @cTrackNo       = ''
      SET @cCartonType    = ''
      SET @cWeight        = ''
      SET @cTaskStatus    = ''
      SET @cTTLPickedQty  = ''
      SET @cTTLScannedQty = ''


      SET @cGenLabelNoSP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo', @cStorerkey)

      SELECT @cLabelPrinter = Printer
           , @cPaperPrinter = Printer_Paper
      FROM rdt.rdtMobrec WITH (NOLOCK)
      WHERE Mobile = @nMobile

      IF ISNULL(@cLabelPrinter,'' ) = ''
      BEGIN
          SET @nErrNo = 151187
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrinterReq
          GOTO RollBackTran
      END

      IF ISNULL(@cPaperPrinter,'' ) = ''
      BEGIN
          SET @nErrNo = 151188
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrinterReq
          GOTO RollBackTran
      END

      -- check if sku exists in tote
      IF NOT EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
                      WHERE ToteNo = @cDropID
                      AND SKU = @cSKU
                      AND AddWho = @cUserName
                      AND Status IN ('0', '1') )
      BEGIN
          SET @nErrNo = 151155
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKuNotIntote
          GOTO RollBackTran
      END

      IF EXISTS (SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
                 GROUP BY ToteNo, SKU , Status , AddWho
                     HAVING ToteNo = @cDropID
                     AND SKU = @cSKU
                     AND SUM(ExpectedQty) < SUM(ScannedQty) + 1
                     AND Status < '5'
                     AND AddWho = @cUserName)
      BEGIN
         SET @nErrNo = 151156
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QtyExceeded
         GOTO RollBackTran
      END



      /****************************
       CREATE PACK DETAILS
      ****************************/
      -- check is order fully despatched for this tote

      SELECT TOP 1 @cOrderkey   = RTRIM(ISNULL(Orderkey,''))
      FROM rdt.rdtECOMMLog WITH (NOLOCK)
      GROUP BY ToteNo, SKU , Status , AddWho, OrderKey
                     HAVING ToteNo = @cDropID
                     --AND Orderkey = @cOrderkey
                     AND SKU = @cSKU
                     AND SUM(ExpectedQty) > SUM(ScannedQty) --+ 1
                     AND Status < '5'
                     AND AddWho = @cUserName
      ORDER BY Status Desc

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
               SET @nErrNo = 151157
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickHdrFail'
               GOTO RollBackTran
            END
            ELSE
            BEGIN

               UPDATE dbo.PICKDETAIL WITH (ROWLOCK)
               SET  PICKSLIPNO = @cPickslipno,
                    Trafficcop = NULL
             WHERE StorerKey = @cStorerKey
               AND   Orderkey = @cOrderKey
               AND   (Status = '5' OR ShipFlag = 'P')
               AND   ISNULL(RTrim(Pickslipno),'') = ''

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 151158
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDetFail'
                  GOTO RollBackTran
               END
            END

            INSERT INTO dbo.PickingInfo (PickslipNo , ScanInDate )
            VALUES ( @cPickSlipNo , GetDate() )

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 151159
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickInfoFail'
               GOTO RollBackTran
            END
         END -- pickheader does not exist
         ELSE
         BEGIN

            SELECT @cPickSlipNo = PickHeaderKey
            FROM dbo.PickHeader WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey


         END

         /****************************
          PACKHEADER
         ****************************/


         INSERT INTO dbo.PackHeader
         (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, AddWho, AddDate, EditWho, EditDate)
         SELECT O.Route, O.OrderKey, O.LoadKey, O.LoadKey, O.ConsigneeKey, O.Storerkey,
               PH.PickHeaderkey, sUser_sName(), GETDATE(), sUser_sName(), GETDATE()
         FROM  dbo.PickHeader PH WITH (NOLOCK)
         JOIN  dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey)
         WHERE PH.Orderkey = @cOrderkey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 151160
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CreatePHdrFail'
            GOTO RollBackTran
         END

         SELECT @cLoadKey = LoadKey
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo

      END -- packheader does not exist
      ELSE
      BEGIN


            SELECT @cPickSlipNo = RTRIM(ISNULL(PickSlipNo,''))
                  ,@cLoadKey    = RTRIM(ISNULL(@cLoadKey,''))
            FROM   dbo.PackHeader PH WITH (NOLOCK)
            WHERE  Orderkey = @cOrderkey

      END

      /****************************
       PACKDETAIL
      ****************************/
      SET @cLabelNo = 0
      SET @nCartonNo = 0


      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                      WHERE PickSlipNo = @cPickSlipNo )
                      --AND DropID = @cDropID )
      BEGIN

         SET @cExecStatements = N'EXEC dbo.' + RTRIM( @cGenLabelNoSP) +
                       '   @cPickslipNo           ' +
                                 ' , @nCartonNo             ' +
                                 ' , @cLabelNo     OUTPUT   '


         SET @cExecArguments =
                   N'@cPickslipNo  nvarchar(10),       ' +
                    '@nCartonNo    int,                ' +
                    '@cLabelNo     nvarchar(20) OUTPUT '



         EXEC sp_executesql @cExecStatements, @cExecArguments,
                              @cPickslipNo
                            , @nCartonNo
                            , @cLabelNo      OUTPUT



         IF ISNULL(@cLabelNo,'')  = ''
         BEGIN
               SET @nErrNo = 151161
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoLabelNoGen
               GOTO RollBackTran
         END

      END
      ELSE
      BEGIN

         IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                     WHERE PickSlipNo = @cPickSlipNo
                     AND RefNo2 = '' )
         BEGIN
            SELECT TOP 1 @cLabelNo = LabelNo
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND RefNo2 = ''
            ORDER BY CartonNo Desc
         END
         ELSE
         BEGIN
            SET @cExecStatements = N'EXEC dbo.' + RTRIM( @cGenLabelNoSP) +
                                    '   @cPickslipNo           ' +
                                    ' , @nCartonNo             ' +
                                    ' , @cLabelNo     OUTPUT   '


            SET @cExecArguments =
                      N'@cPickslipNo  nvarchar(10),       ' +
                       '@nCartonNo    int,                ' +
                       '@cLabelNo     nvarchar(20) OUTPUT '



            EXEC sp_executesql @cExecStatements, @cExecArguments,
                                 @cPickslipNo
                               , @nCartonNo
                               , @cLabelNo      OUTPUT



            IF ISNULL(@cLabelNo,'') = ''
            BEGIN
                  SET @nErrNo = 151162
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoLabelNoGen
                  GOTO RollBackTran
            END
         END


      END

      --(yeekung01) Remove the cursor

      SELECT @nRowRef=RowRef , @nPackQty=ScannedQTY
      FROM   rdt.rdtECOMMLog ECOMM WITH (NOLOCK)
      WHERE  ToTeNo = @cDropID
      AND    Orderkey = @cOrderkey
      AND    SKU    = @cSKU
      AND    Status < '5'
      AND    AddWho = @cUserName
      ORDER BY SKU

      SET @cLabelLine = '00000'


      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                     WHERE PickSlipNo = @cPickSlipNo
                     AND SKU = @cSku
                     AND LabelNo = @cLabelNo  )
      BEGIN
         -- Insert PackDetail
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, DropID, UPC, AddWho, AddDate, EditWho, EditDate, RefNo2)
         VALUES
            (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, 1 ,
            @cDropID, @cDropID, '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), '')

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 151163
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDetFail'
            GOTO RollBackTran
         END

         -- (james01)
         SELECT TOP 1 @nCartonNo = CartonNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND   LabelNo = @cLabelNo
         ORDER BY 1

         SELECT
            @cOrderType  = Type
            ,@cCarriername = ShipperKey
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         AND StorerKey = @cStorerKey

         SELECT @cKeyname     = Long
         FROM dbo.Codelkup WITH (NOLOCK)
         WHERE Listname = 'AsgnTNo'
         AND Storerkey = @cStorerkey
         AND UDF03 = @cOrderType
         AND Short = @cCarriername

         IF ISNULL(@cKeyName ,'' ) <> ''
         BEGIN

            SELECT @nInsertedCartonNo = CartonNo
                  ,@nInsertedLabelLine = LabelLine
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND StorerKey    = @cStorerKey
            AND LabelNo      = @cLabelNo
            AND SKU          = @cSKU
            AND RefNo        = @cDropID
            AND DropID       = @cDropID
            ORDER BY AddDate DESC

            IF @nInsertedCartonNo = 1
            BEGIN
               --SELECT @cTrackingNo = UserDefine04
               SELECT @cTrackingNo = TrackingNo -- (james02)
               FROM dbo.Orders WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey
            END
            ELSE
            BEGIN

               IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                           WHERE PickSlipNo = @cPickSlipNo
                           AND StorerKey    = @cStorerKey
                           AND LabelNo      = @cLabelNo
                           AND ISNULL(UPC,'')  <> '' )
               BEGIN
                  SELECT TOP 1 @cTrackingNo = UPC
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                  AND StorerKey    = @cStorerKey
                  AND LabelNo      = @cLabelNo
                  AND ISNULL(UPC,'') <> ''

               END
               ELSE
               BEGIN
                  SELECT @cTrackingNo = MIN(TrackingNo)
                  FROM dbo.CartonTrack WITH (NOLOCK)
                  WHERE  CarrierName = @cCarriername
                  AND Keyname        = @cKeyname
                  AND CarrierRef2    = ''
                  AND LabelNo        = ''

                  DELETE FROM dbo.CartonTrack WITH (ROWLOCK)
                  WHERE TrackingNo = @cTrackingNo
                  AND CarrierName  = @cCarriername
                  AND KeyName      = @cKeyname


                  /**update cartontrack **/
                  IF NOT EXISTS ( SELECT 1 FROM dbo.CartonTrack WITH (NOLOCK)
                                 WHERE  CarrierName = @cCarriername
                                 AND Keyname        = @cKeyname
                                 AND CarrierRef2    = ''
                                 AND TrackingNo     = @cTrackingNo  )
                  BEGIN
                     INSERT INTO dbo.CartonTrack ( TrackingNo, CarrierName, KeyName, LabelNo, CarrierRef2 )
                     VALUES ( @cTrackingNo, @cCarriername, @cKeyname, @cOrderKey, 'GET' )

                     IF @@ERROR <> 0
                     BEGIN
                    SET @nErrNo = 151164
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsCartonTrackFail'
                     GOTO RollBackTran
                     END

                  END
                  ELSE
                  BEGIN
                     SET @nErrNo = 151165
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TrackNoInUsed'
                     GOTO RollBackTran
                  END
               END
            END

            /**Update packdetail**/
            UPDATE dbo.Packdetail
            SET UPC = @cTrackingNo
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND StorerKey    = @cStorerKey
            AND LabelNo      = @cLabelNo
            AND SKU          = @cSKU
            AND RefNo        = @cDropID
            AND DropID       = @cDropID
            AND CartonNo     = @nInsertedCartonNo
            AND LabelLine    = @nInsertedLabelLine

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 151166
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'
               GOTO RollBackTran
            END
            END

            EXEC RDT.rdt_STD_EventLog
              @cActionType = '8', -- Packing
              @cUserID     = @cUserName,
              @nMobileNo   = @nMobile,
              @nFunctionID = @nFunc,
              @cFacility   = @cFacility,
              @cStorerKey  = @cStorerkey,
              @cSKU        = @cSku,
              @nQty        = @nPackQty ,
              @cRefNo1     = @cDropID,
              @cRefNo2     = @cLabelNo,
              @cRefNo3     = @cPickSlipNo
            --END
         END --packdetail for sku/order does not exists
      ELSE
      BEGIN
         UPDATE dbo.Packdetail WITH (ROWLOCK)
         SET   QTY      = QTY + 1
         WHERE PickSlipNo = @cPickSlipNo
         AND SKU = @cSku

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 151167
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'
            GOTO RollBackTran
         END

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


      END -- packdetail for sku/order exists


      /***************************
      UPDATE rdtECOMMLog
      ****************************/
      UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)
      SET   ScannedQty  = ScannedQty + 1,
            Status      = '1'    -- in progress
      WHERE RowRef = @nRowRef

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 151168
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'
         GOTO RollBackTran
      END

      IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                       WHERE StorerKey = @cStorerKey
                       AND DropID = @cDropID
                       AND OrderKey = @cOrderKey
                       AND ISNULL(CaseID,'')  = ''
                       AND (Status = '5' OR Status = '3' OR ShipFlag = 'P')
                       AND SKU = @cSKU )
      BEGIN
         -- Piece Scanning Balance always = 1
         SET @nQTYBal = 1

         -- Loop PickDetail to Split and Update by Quantity
         DECLARE C_TOTE_PICKDETAIL  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey, Qty
         FROM   PickDetail PD WITH (NOLOCK)
         WHERE  PD.DropID = @cDropID
         AND    PD.Orderkey = @cOrderkey
         AND    PD.SKU    = @cSKU
         AND    Status = '5'
         ORDER BY PickDetailKey

         OPEN C_TOTE_PICKDETAIL
         FETCH NEXT FROM C_TOTE_PICKDETAIL INTO  @cPickDetailKey , @nPickedQty
         WHILE (@@FETCH_STATUS <> -1)
         BEGIN



             -- Exact match
            IF @nPickedQty =  @nQTYBal
            BEGIN

               UPDATE dbo.PickDetail WITH (ROWLOCK)
               SET CASEID     = @cLabelNo
                  ,DropID     = @cLabelNo
                  ,TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                     SET @nErrNo = 151169
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFull
                     GOTO RollBackTran
               END

               SET @nQTYBal = 0 -- Reduce balance
            END
            -- PickDetail have less
            ELSE IF @nPickedQty <  @nQTYBal
            BEGIN
               UPDATE dbo.PickDetail WITH (ROWLOCK)
               SET CASEID     = @cLabelNo
                  ,DropID     = @cLabelNo
                  ,TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 151170
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFull
                  GOTO RollBackTran
               END


               SET @nQTYBal = 0 -- Reduce balance
            END
            -- PickDetail have more
            ELSE IF @nPickedQty >  @nQTYBal
            BEGIN


       -- Get new PickDetailkey
                  DECLARE @cNewPickDetailKey NVARCHAR( 10)
                  EXECUTE dbo.nspg_GetKey
                     'PICKDETAILKEY',
                     10 ,
                     @cNewPickDetailKey OUTPUT,
                     @bSuccess          OUTPUT,
                     @nErrNo            OUTPUT,
                     @cErrMsg           OUTPUT
                  IF @bSuccess <> 1
                  BEGIN
                     SET @nErrNo = 151171
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
                     GOTO RollBackTran
                  END

                  -- Create new a PickDetail to hold the balance
                  INSERT INTO dbo.PickDetail (
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
                     UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                     ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                     EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                     PickDetailKey,
                     QTY,
                     TrafficCop,
                     OptimizeCop)
                  SELECT
                     CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
                     UOMQTY, QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
                     CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                     EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                     @cNewPickDetailKey,
                     @nPickedQty - @nQTYBal, -- QTY
                     NULL, -- TrafficCop
                     '1'   -- OptimizeCop
                  FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE PickDetailKey = @cPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 151172
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
                     GOTO RollBackTran
                  END

                  -- Change orginal PickDetail with exact QTY (with TrafficCop)
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                     QTY = @nQTYBal,
                     CaseID = @cLabelNo,
                     DropID = @cLabelNo,
                     EditDate = GETDATE(),
                     EditWho  = SUSER_SNAME(),
                     Trafficcop = NULL                        WHERE PickDetailKey = @cPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 151173
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UpdPickDetFaill
                     GOTO RollBackTran
                  END


                  SET @nQTYBal = 0 -- Reduce balance

            END

            IF @nQTYBal <= 0
            BREAK

            FETCH NEXT FROM C_TOTE_PICKDETAIL INTO  @cPickDetailKey , @nPickedQty


         END
         CLOSE C_TOTE_PICKDETAIL
         DEALLOCATE C_TOTE_PICKDETAIL

      END



      -- check if total order fully despatched
      SELECT @nTotalPickQty = SUM(ISNULL(PK.Qty,0))
      FROM  dbo.PICKDETAIL PK WITH (nolock)
      WHERE PK.StorerKey = @cStorerKey
      AND PK.Orderkey = @cOrderkey


      SELECT @nTotalPackQty = SUM(ISNULL(PD.Qty,0))
      FROM  dbo.PACKDETAIL PD WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND PickSlipNo = @cPickSlipNo

      SELECT @cShipperKey = ShipperKey
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      -- Prepare for TaskStatus
      IF @nTotalPickQty = @nTotalPackQty
      BEGIN
         UPDATE dbo.PackHeader WITH (ROWLOCK)
         SET Status = '9'
         WHERE PickSlipNo = @cPickSlipNo
         AND StorerKey = @cStorerKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 151189
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PackCfm Fail'
            GOTO RollBackTran
         END

         UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)
         SET   Status      = '9'    -- completed
         WHERE ToteNo      = @cDropID
         AND   Orderkey    = @cOrderkey
         AND   AddWho      = @cUserName
         AND   Status      = '1'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 151174
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'
            GOTO RollBackTran
         END

         --INC1251022(START)
         SELECT TOP 1 @nCartonNo = CartonNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND   LabelNo = @cLabelNo
         ORDER BY 1

         IF EXISTS(SELECT 1 FROM dbo.Orders WITH (NOLOCK)WHERE StorerKey = @cStorerKey
                   AND OrderKey = @cOrderKey
                   --AND ISNULL(UserDefine04,'') <> '')
                   AND ISNULL(TrackingNo,'') <> '')      -- (james02)
         BEGIN
            --SELECT @cTrackingNo = UserDefine04
            SELECT @cTrackingNo = TrackingNo -- (james02)
            FROM dbo.Orders WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey  AND OrderKey = @cOrderKey
         END
         --INC1251022(END)


         SET @cPostDataCapture = rdt.RDTGetConfig( @nFunc, 'PostDataCapture', @cStorerKey)
         IF @cPostDataCapture = '0'
            SET @cPostDataCapture = ''

         -- Need capture carton, print later
         IF @cPostDataCapture = ''
         BEGIN
            SET @cCartonLabel = rdt.RDTGetConfig( @nFunc, 'CartonLbl', @cStorerkey)
            IF @cCartonLabel = '0'
               SET @cCartonLabel = ''

            IF @cCartonLabel <> ''
            BEGIN
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nToCartonNo', @nCartonNo)
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cFromLabelNo', @cLabelNo)
               INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cToLabelNo', @cLabelNo)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
                  @cCartonLabel, -- Report type
                  @tCartonLabel, -- Report params
                  'rdt_842ExtUpdSP08',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO RollBackTran
            END

            DECLARE Cur_Print CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT Long, Notes, Code2, UDF01
            FROM dbo.CODELKUP WITH (NOLOCK)
            WHERE LISTNAME = 'PrtbyShipK'
            AND   Code = @cShipperKey
            AND   StorerKey = @cStorerKey
            OPEN CUR_Print
            FETCH NEXT FROM CUR_Print INTO @cFilePath, @cPrintFilePath, @cReportType, @cFilePrefix
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Make sure we have setup the printer id
               -- Record searched based on func + storer + reporttype + printergroup (shipperkey)
               SELECT @cPrinterInGroup = PrinterID
               FROM rdt.rdtReportToPrinter WITH (NOLOCK)
               WHERE Function_ID = @nFunc
               AND   StorerKey = @cStorerKey
               AND   ReportType = @cReportType
               AND   PrinterGroup = @cLabelPrinter

               -- Determine print type (command/bartender)
               SELECT @cProcessType = ProcessType,
                      @cPaperType = PaperType
               FROM rdt.RDTREPORT WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   ReportType = @cReportType
               AND  (Function_ID = @nFunc OR Function_ID = 0)
               ORDER BY Function_ID DESC

               -- PDF use foxit then need use the winspool printer name
               IF @cReportType LIKE 'PDFWBILL%'
               BEGIN
                  SELECT @cWinPrinter = WinPrinter
                  FROM rdt.rdtPrinter WITH (NOLOCK)
                  WHERE PrinterID = CASE WHEN ISNULL( @cPrinterInGroup, '') <> '' THEN @cPrinterInGroup ELSE @cLabelPrinter END

                  IF CHARINDEX(',' , @cWinPrinter) > 0
                  BEGIN
                     SET @cPrinterName = @cPrinterInGroup
                     SET @cWinPrinterName = LEFT( @cWinPrinter , (CHARINDEX(',' , @cWinPrinter) - 1) )
                  END
                  ELSE
                  BEGIN
                     SET @cPrinterName =  @cPrinterInGroup
                     SET @cWinPrinterName = @cWinPrinter
                  END
               END
               ELSE
               BEGIN
                  IF @cPaperType = 'LABEL'
                     SET @cPrinterName = @cLabelPrinter
                  ELSE
                     SET @cPrinterName = @cPaperPrinter
               END

               IF @cProcessType = 'QCOMMANDER'
               BEGIN
                  IF ISNULL( @cFilePath, '') <> ''
                  BEGIN
                     SET @cFilePrefix = @cFilePrefix + CASE WHEN ISNULL( @cFilePrefix, '') <> '' THEN '_' ELSE '' END
                     SET @cFileName = @cFilePrefix + RTRIM( @cOrderKey) + '.pdf'
                     SET @cPrintCommand = '"' + @cPrintFilePath + '" /t "' + @cFilePath + '\' + @cFileName + '" "' + @cWinPrinterName + '"'

                     -- Print label (pass in shipperkey as label printer. then rdt_print will look for correct printer id)
                     EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '',
                        @cReportType,     -- Report type
                        @tRDTPrintJob,    -- Report params
                        'rdt_842ExtUpdSP08',
                        @nErrNo  OUTPUT,
                        @cErrMsg OUTPUT,
                        --1,              -- ZG01
                        NULL,             -- ZG01
                        @cPrintCommand

                        --IF @nErrNo <> 0 SET @cErrMsg = @cPrinterName
                  END
               END
               ELSE
               BEGIN
                  IF @cProcessType = 'TCPSPOOLER'  -- For datawindow printing  -- For datawindow printing
                  BEGIN
                     DELETE FROM @tDatawindow
                     INSERT INTO @tDatawindow (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)
                     INSERT INTO @tDatawindow (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)
                     INSERT INTO @tDatawindow (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)
                     INSERT INTO @tDatawindow (Variable, Value) VALUES ( '@nToCartonNo', @nCartonNo)

                     -- Print label
                     EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPrinterName,
                        @cReportType, -- Report type
                        @tDatawindow, -- Report params
                        'rdt_842ExtUpdSP08',
                        @nErrNo  OUTPUT,
                        @cErrMsg OUTPUT
                  END
     ELSE
                  BEGIN
                     -- Common params
                     DELETE FROM @tSHIPLabel
                     INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)
                     INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)
                     INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cTrackingNo', @cTrackingNo)
                     INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cLabelNo', @cLabelNo)
                     INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@nCartonNo', @nCartonNo)

                     -- Print label
                     EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '',
                        @cReportType, -- Report type
                        @tSHIPLabel, -- Report params
                        'rdt_842ExtUpdSP08',
                        @nErrNo  OUTPUT,
                        @cErrMsg OUTPUT
                  END
               END

               IF @nErrNo <> 0
                  GOTO RollBackTran

               FETCH NEXT FROM CUR_Print INTO @cFilePath, @cPrintFilePath, @cReportType, @cFilePrefix
            END
            CLOSE Cur_Print
            DEALLOCATE Cur_Print
         END

         IF @cPostDataCapture <> ''
            SET @cTaskStatus = '9'
         ELSE
         BEGIN
            IF EXISTS ( SELECT 1 FROM rdt.rdtECOMMLOG WITH (NOLOCK)
                            WHERE ToteNo = @cDropID
                            AND Status IN (  '0' ,'1' )
                            AND ExpectedQty <>  ScannedQty
                            AND AddWho = @cUserName )
            BEGIN
               SELECT TOP 1 @cBatchKey = BatchKey
               FROM rdt.rdtECOMMLog WITH (NOLOCK)
               WHERE ToteNo = @cDropID
               AND Status IN ( '0', '1' )
               AND AddWho = @cUserName
               AND Mobile = @nMobile

               SELECT @nTotalPickedQty  = SUM(ExpectedQty)
               FROM rdt.rdtECOMMLog WITH (NOLOCK)
               WHERE ToteNo = @cDropID
               AND Status IN ('0' , '1', '9' )
               AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
               AND AddWho = @cUserName
               AND Mobile = @nMobile
               AND BatchKey = @cBatchKey
               AND ISNULL(ErrMSG,'')  = ''

               SELECT @nTotalScannedQty = SUM(ScannedQty)
               FROM rdt.rdtECOMMLog WITH (NOLOCK)
               WHERE ToteNo = @cDropID
               AND Status IN ( '1', '9' )
               AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
               AND AddWho = @cUserName
               AND ISNULL(ErrMSG,'')  = ''
               AND Mobile = @nMobile
               AND BatchKey = @cBatchKey



               SET @cOrderKey      = CASE WHEN @cDropIDType = 'SINGLES' THEN '' ELSE @cOrderKey END
               SET @cTrackNo       = ''
               SET @cCartonType    = ''
               SET @cWeight        = ''
               SET @cTaskStatus    = '1'
               SET @cTTLPickedQty  = @nTotalPickedQty
               SET @cTTLScannedQty = @nTotalScannedQty
            END
            ELSE
            BEGIN
               UPDATE dbo.DROPID WITH (Rowlock)
               SET   Status = '9'
                    ,Editdate = GetDate()
               WHERE DropID = @cDropID
               AND   Status < '9'

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 151175
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDFail'
                  GOTO ROLLBACKTRAN
               END

               SET @cOrderKey      = CASE WHEN @cDropIDType = 'SINGLES' THEN '' ELSE @cOrderKey END
               SET @cTrackNo       = ''
               SET @cCartonType    = ''
               SET @cWeight        = ''
               SET @cTaskStatus    = '5'
               SET @cTTLPickedQty  = 0
               SET @cTTLScannedQty = 0
            END
         END
      END
      ELSE
      BEGIN

         IF EXISTS ( SELECT 1 FROM rdt.rdtECOMMLOG WITH (NOLOCK)
                         WHERE ToteNo = @cDropID
                         AND Status IN (  '0' ,'1' )
                         AND ExpectedQty <>  ScannedQty
                         AND AddWho = @cUserName )
         BEGIN
            SELECT TOP 1 @cBatchKey = BatchKey
            FROM rdt.rdtECOMMLog WITH (NOLOCK)
            WHERE ToteNo = @cDropID
            AND Status IN ( '0', '1' )
            AND AddWho = @cUserName
            AND Mobile = @nMobile

            SELECT @nTotalPickedQty  = SUM(ExpectedQty)
            FROM rdt.rdtECOMMLog WITH (NOLOCK)
            WHERE ToteNo = @cDropID
            AND Status IN ('0' , '1', '9' )
            AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
            AND AddWho = @cUserName
            AND Mobile = @nMobile
            AND BatchKey = @cBatchKey
            AND ISNULL(ErrMSG,'')  = ''

            SELECT @nTotalScannedQty = SUM(ScannedQty)
            FROM rdt.rdtECOMMLog WITH (NOLOCK)
            WHERE ToteNo = @cDropID
            AND Status IN ( '1', '9' )
            AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
            AND AddWho = @cUserName
            AND ISNULL(ErrMSG,'')  = ''
            AND Mobile = @nMobile
            AND BatchKey = @cBatchKey



    SET @cOrderKey      = CASE WHEN @cDropIDType = 'SINGLES' THEN '' ELSE @cOrderKey END
            SET @cTrackNo       = ''
            SET @cCartonType    = ''
            SET @cWeight        = ''
            SET @cTaskStatus    = '1'
            SET @cTTLPickedQty  = @nTotalPickedQty
            SET @cTTLScannedQty = @nTotalScannedQty
         END
         ELSE
         BEGIN
            UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)
            SET   Status      = '9'    -- completed
            WHERE ToteNo      = @cDropID
            AND   Orderkey    = @cOrderkey
            AND   AddWho      = @cUserName
            AND   Status      = '1'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 151174
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'
               GOTO RollBackTran
            END

            UPDATE dbo.DROPID WITH (Rowlock)
            SET   Status = '9'
                 ,Editdate = GetDate()
            WHERE DropID = @cDropID
            AND   Status < '9'

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 151175
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdDropIDFail'
               GOTO ROLLBACKTRAN
            END



            SET @cOrderKey      = CASE WHEN @cDropIDType = 'SINGLES' THEN '' ELSE @cOrderKey END
            SET @cTrackNo       = ''
            SET @cCartonType    = ''
            SET @cWeight        = ''
            SET @cTaskStatus    = '5'
            SET @cTTLPickedQty  = 0
            SET @cTTLScannedQty = 0
         END

      END


   END

   IF @nStep = 3
   BEGIN
       SELECT @cLabelPrinter = Printer
            , @cPaperPrinter = Printer_Paper
       FROM rdt.rdtMobrec WITH (NOLOCK)
       WHERE Mobile = @nMobile

       SELECT @cDropIDType = DropIDType
       FROM dbo.DropID WITH (NOLOCK)
       WHERE DropID = @cDropID
       AND Status = '5'

      /****************************
       PACKINFO
      ****************************/
      SELECT
         @fCartonHeight = CZ.CartonHeight,
         @fCartonLength = CartonLength,
         @fCartonWidth = CartonWidth,
         @fCartonWeight = CartonWeight
      FROM dbo.CARTONIZATION CZ WITH (NOLOCK)
      JOIN dbo.STORER ST WITH (NOLOCK) ON ( ST.CartonGroup = CZ.CartonizationGroup)
      WHERE ST.StorerKey = @cStorerKey
      AND   CZ.CartonType = @cCartonType

      SELECT @cPickSlipNo = PickSlipNo
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      SELECT TOP 1 @nCartonNo  = CartonNo,
                   @cLabelNo = LabelNo,
                   @cTrackingNo = UPC
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND PickSlipNo = @cPickSlipNo
      AND RefNo2 = ''
      ORDER BY CartonNo Desc

      IF @nCartonNo = 1
         --SELECT @cTrackingNo = UserDefine04
         SELECT @cTrackingNo = TrackingNo -- (james02)
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderkey

      SELECT @nTotalPackedQty = SUM(Qty)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND PickSlipNo = @cPickSlipNo
      AND CartonNo = @nCartonNo
      GROUP BY CartonNo

      --SET @fCartonTotalWeight = @cWeight
      SELECT @fCartonTotalWeight = SUM(PD.QTY * ISNULL(SKU.STDGROSSWGT,0)) + ISNULL(@fCartonWeight,0)
      FROM dbo.PackDetail PD WITH (NOLOCK)
      INNER JOIN dbo.SKU WITH (NOLOCK) ON SKU.SKU = PD.SKU AND SKU.StorerKey = PD.StorerKey
      WHERE PD.StorerKey = @cStorerKey
      AND PD.PickSlipNo = @cPickSlipNo

      IF NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
                      WHERE PickSlipNo = @cPickSlipNo
                      AND CartonNo = @nCartonNo )
      BEGIN
         INSERT INTO dbo.PackInfo(
            PickslipNo, CartonNo, CartonType, Qty,
            Length, Width, Height, [Weight],
            AddWho, AddDate, EditWho, EditDate)
         VALUES
         ( @cPickSlipNo , @nCartonNo, @cCartonType, @nTotalPackedQty,
         @fCartonLength, @fCartonWidth, @fCartonHeight, @fCartonTotalWeight,
         'rdt' + sUser_sName(), GetDate(), 'rdt' + sUser_sName(), GetDate())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 151176
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackInfoFail'
            GOTO RollBackTran
         END

      END

      -- UPDATE PACKDETAIL WITH * Indicate Carton Change
      UPDATE dbo.PackDetail WITH (ROWLOCK)
      SET RefNo2 = RefNo2 + '*'
      WHERE PickSlipNo = @cPickSlipNo
      AND CartonNo = @nCartonNo
      AND ISNULL(RefNo2,'') = ''

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 151177
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'
         GOTO RollBackTran
      END

      /****************************
      rdtECOMMLog
      ****************************/
      --update rdtECOMMLog

      UPDATE RDT.rdtECOMMLog WITH (ROWLOCK)
      SET   Status      = '9'    -- completed
      WHERE ToteNo      = @cDropID
      AND   Orderkey    = @cOrderkey
      AND   AddWho      = @cUserName
      AND   Status      = '1'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 151178
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'
         GOTO RollBackTran
      END

      SELECT @cShipperKey = ShipperKey
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      SET @cCartonLabel = rdt.RDTGetConfig( @nFunc, 'CartonLbl', @cStorerkey)
      IF @cCartonLabel = '0'
         SET @cCartonLabel = ''

      IF @cCartonLabel <> ''
      BEGIN
         INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)
         INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)
         INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)
         INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@nToCartonNo', @nCartonNo)
         INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cFromLabelNo', @cLabelNo)
         INSERT INTO @tCartonLabel (Variable, Value) VALUES ( '@cToLabelNo', @cLabelNo)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
            @cCartonLabel, -- Report type
            @tCartonLabel, -- Report params
            'rdt_842ExtUpdSP08',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      DECLARE Cur_Print CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT Long, Notes, Code2, UDF01
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = 'PrtbyShipK'
      AND   Code = @cShipperKey
      AND   StorerKey = @cStorerKey
      OPEN CUR_Print
      FETCH NEXT FROM CUR_Print INTO @cFilePath, @cPrintFilePath, @cReportType, @cFilePrefix
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Make sure we have setup the printer id
         -- Record searched based on func + storer + reporttype + printergroup (shipperkey)
         SELECT @cPrinterInGroup = PrinterID
         FROM rdt.rdtReportToPrinter WITH (NOLOCK)
         WHERE Function_ID = @nFunc
         AND   StorerKey = @cStorerKey
         AND   ReportType = @cReportType
         AND   PrinterGroup = @cLabelPrinter

         -- Determine print type (command/bartender)
         SELECT @cProcessType = ProcessType,
                @cPaperType = PaperType
         FROM rdt.RDTREPORT WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReportType = @cReportType
         AND  (Function_ID = @nFunc OR Function_ID = 0)
         ORDER BY Function_ID DESC

         -- PDF use foxit then need use the winspool printer name
         IF @cReportType LIKE 'PDFWBILL%'
         BEGIN
            SELECT @cWinPrinter = WinPrinter
            FROM rdt.rdtPrinter WITH (NOLOCK)
            WHERE PrinterID = CASE WHEN ISNULL( @cPrinterInGroup, '') <> '' THEN @cPrinterInGroup ELSE @cLabelPrinter END

            IF CHARINDEX(',' , @cWinPrinter) > 0
            BEGIN
               SET @cPrinterName = @cPrinterInGroup
               SET @cWinPrinterName = LEFT( @cWinPrinter , (CHARINDEX(',' , @cWinPrinter) - 1) )
            END
            ELSE
           BEGIN
               SET @cPrinterName =  @cPrinterInGroup
               SET @cWinPrinterName = @cWinPrinter
            END
         END
         ELSE
         BEGIN
            IF @cPaperType = 'LABEL'
               SET @cPrinterName = @cLabelPrinter
            ELSE
               SET @cPrinterName = @cPaperPrinter
         END

         IF ISNULL( @cFilePath, '') <> ''
         BEGIN
            SET @cFilePrefix = @cFilePrefix + CASE WHEN ISNULL( @cFilePrefix, '') <> '' THEN '_' ELSE '' END
            SET @cFileName = @cFilePrefix + RTRIM( @cOrderKey) + '.pdf'
            SET @cPrintCommand = '"' + @cPrintFilePath + '" /t "' + @cFilePath + '\' + @cFileName + '" "' + @cWinPrinterName + '"'

            -- Print label (pass in shipperkey as label printer. then rdt_print will look for correct printer id)
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '',
               @cReportType,     -- Report type
               @tRDTPrintJob,    -- Report params
               'rdt_842ExtUpdSP08',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT,
               --1,              -- ZG01
               NULL,             -- ZG01
               @cPrintCommand

               --IF @nErrNo <> 0 SET @cErrMsg = @cPrinterName
         END
         ELSE
         BEGIN
            -- Common params
            DELETE FROM @tSHIPLabel
            INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)
            INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)
            INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cTrackingNo', @cTrackingNo)
            INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cLabelNo', @cLabelNo)
            INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@nCartonNo', @nCartonNo)
            INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)
            INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@nFromCartonNo', @nCartonNo)
            INSERT INTO @tSHIPLabel (Variable, Value) VALUES ( '@nToCartonNo', @nCartonNo)

            -- Print label
            IF @cPaperType = 'LABEL'
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterName, '',
                  @cReportType, -- Report type
                  @tSHIPLabel, -- Report params
                  'rdt_842ExtUpdSP08',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
            ELSE
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPrinterName,
                  @cReportType, -- Report type
                 @tSHIPLabel, -- Report params
                  'rdt_842ExtUpdSP08',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT
         END

         IF @nErrNo <> 0
            GOTO RollBackTran

         FETCH NEXT FROM CUR_Print INTO @cFilePath, @cPrintFilePath, @cReportType, @cFilePrefix
      END
      CLOSE Cur_Print
      DEALLOCATE Cur_Print

      SET @nPackQTY = 0
      SET @nPickQTY = 0
      SELECT @nPackQTY = ISNULL( SUM( QTY), 0) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
      SELECT @nPickQTY = ISNULL( SUM( QTY), 0) FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey

      IF @nPackQty = @nPickQty
      BEGIN
         -- Print Label
         UPDATE dbo.PackHeader WITH (ROWLOCK)
         SET Status = '9'
         WHERE PickSlipNo = @cPickSlipNo
         AND StorerKey = @cStorerKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 151190
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PackCfm Fail'
            GOTO RollBackTran
         END

         SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerkey)
         IF @cPackList = '0'
            SET @cPackList = ''

         IF @cPackList <> ''
         BEGIN
            DECLARE @tPackList AS VariableTable
            INSERT INTO @tPackList (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)
            INSERT INTO @tPackList (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)
            INSERT INTO @tPackList (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
               @cPackList, -- Report type
               @tPackList, -- Report params
               'rdt_842ExtUpdSP08',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO RollBackTran
         END
      END

      IF EXISTS ( SELECT 1 FROM rdt.rdtECOMMLog ECOMM WITH (NOLOCK) WHERE ToteNo = @cDropID
                  AND Mobile = @nMobile AND Status < '5' )
      BEGIN

         SELECT TOP 1 @cBatchKey = BatchKey
         FROM rdt.rdtECOMMLog WITH (NOLOCK)
         WHERE ToteNo = @cDropID
         AND Status = '0'
         AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
         AND AddWho = @cUserName
         AND Mobile = @nMobile

         SELECT @nTotalPickedQty  = SUM(ExpectedQty)
         FROM rdt.rdtECOMMLog WITH (NOLOCK)
         WHERE ToteNo = @cDropID
         AND Status IN ('0' , '9' )
         AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
         AND AddWho = @cUserName
         AND Mobile = @nMobile
         AND BatchKey = @cBatchKey
         AND ISNULL(ErrMSG,'')  = ''

         SELECT @nTotalScannedQty = SUM(ScannedQty)
         FROM rdt.rdtECOMMLog WITH (NOLOCK)
         WHERE ToteNo = @cDropID
         AND Status = '9'
         AND OrderKey = CASE WHEN @cDropIDType = 'SINGLES' THEN OrderKey ELSE @cOrderKey END
         AND AddWho = @cUserName
         AND ISNULL(ErrMSG,'')  = ''
         AND Mobile = @nMobile
         AND BatchKey = @cBatchKey

         SET @cOrderKey      = ''
         SET @cTrackNo       = ''
         SET @cCartonType    = ''
         SET @cWeight        = ''
         SET @cTaskStatus    = '1'
         SET @cTTLPickedQty  = @nTotalPickedQty
         SET @cTTLScannedQty = @nTotalScannedQty

      END
      ELSE
      BEGIN

         UPDATE dbo.DROPID WITH (Rowlock)
         SET   Status = '9'
              ,Editdate = GetDate()
         WHERE DropID = @cDropID
         AND   Status < '9'

         IF @@ERROR <> 0
         BEGIN
               SET @nErrNo = 151179
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'
               GOTO ROLLBACKTRAN
         END

         SET @cOrderKey      = ''
         SET @cTrackNo       = ''
         SET @cCartonType    = ''
         SET @cWeight        = ''
         SET @cTaskStatus    = '9'
         SET @cTTLPickedQty  = ''
         SET @cTTLScannedQty = ''
      END

      IF @cTaskStatus = '9'
      BEGIN
         DECLARE 
            @cUDF02 NVARCHAR(30),
            @cUDF03 NVARCHAR(30)

         IF rdt.RDTGetConfig( @nFunc, 'GenTranLog2', @cStorerKey) = '1'
         BEGIN
            SELECT @cWaveKey = WaveKey 
            FROM dbo.WaveDetail WITH(NOLOCK)
            WHERE OrderKey = @cCurrentOrderKey

            DELETE FROM @tOrders
            INSERT INTO @tOrders(OrderKey,LabelNo)
            SELECT DISTINCT ECL.OrderKey,PD.LabelNo
            FROM RDT.rdtECOMMLog ECL WITH (NOLOCK)
            INNER JOIN PICKHEADER PH WITH (NOLOCK) ON PH.OrderKey = ECL.OrderKey
            INNER JOIN PackDetail PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickHeaderKey
            INNER JOIN dbo.ORDERS ORM WITH(NOLOCK) ON PH.OrderKey = ORM.OrderKey AND PH.StorerKey = ORM.StorerKey 
            INNER JOIN dbo.WaveDetail WD WITH(NOLOCK) ON WD.OrderKey = ORM.OrderKey
            WHERE ECL.STATUS = '9' AND ECL.ToTeNo = @cDropID AND ECL.Mobile = @nMobile
               AND ORM.StorerKey = @cStorerKey
               AND ORM.Status < '9'
               AND WD.WaveKey = @cWaveKey

            SET @nLoopIndex = -1
            WHILE 1 = 1
            BEGIN
               SELECT TOP 1 
                  @cTempOrderKey = OrderKey,
                  @cTempLabelNo = LabelNo,
                  @nLoopIndex = id
               FROM @tOrders
               WHERE id > @nLoopIndex
               ORDER BY id

               SELECT @nRowCount = @@ROWCOUNT

               IF @nRowCount = 0
                  BREAK

               EXEC dbo.ispGenTransmitLog2
               @c_TableName      = 'WSCRSOEDELIV',  
               @c_Key1           = @cTempOrderKey,  
               @c_Key2           = @cTempLabelNo ,  
               @c_Key3           = @cStorerKey,  
               @c_TransmitBatch  = '',  
               @b_success        = @bSuccess    OUTPUT,  
               @n_err            = @nErrNo      OUTPUT,  
               @c_errmsg         = @cErrMsg     OUTPUT  

               IF @bSuccess <> 1
               BEGIN
                  GOTO ROLLBACKTRAN
               END
            END
         END
      END
   END


   IF @nStep = 4
   BEGIN

      IF @cOption = '1'
      BEGIN
          SET @nErrNo = 151180
          SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidOption'
          GOTO RollBackTran
      END

      IF @cOption = '5'
      BEGIN

        IF @cOrderKey <> ''
         SET @cOrderKey      = @cOrderKey

         SET @cTrackNo       = ''
         SET @cCartonType    = ''
         SET @cWeight        = ''
         SET @cTaskStatus    = '5'
         SET @cTTLPickedQty  = ''
         SET @cTTLScannedQty = ''

         -- Split rdt.rdtEcommLog

         /****************************
          INSERT INTO rdtECOMMLog
         ****************************/

         IF EXISTS ( SELECT 1
                     FROM rdt.rdtEcommLog WITH (NOLOCK)
                     WHERE ToteNo      = @cDropID
                     AND   Orderkey    = @cOrderkey
                     AND   AddWho      = @cUserName
                     AND   Status      = '1'
                     AND   ExpectedQty - ScannedQty > 0 )
         BEGIN

            INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate, BatchKey)
            SELECT Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty - ScannedQty, 0, AddWho, GETDATE(), EditWho, GETDATE(), BatchKey
            FROM rdt.rdtEcommLog WITH (NOLOCK)
            WHERE ToteNo      = @cDropID
            AND   Orderkey    = @cOrderkey
            AND   AddWho      = @cUserName
            AND   Status      = '1'
            AND   ExpectedQty - ScannedQty > 0


            IF @@ROWCOUNT = 0 -- No data inserted
            BEGIN
               SET @nErrNo = 151181
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'InsEcommFail'
               GOTO ROLLBACKTRAN
            END

            UPDATE rdt.rdtECOMMlog WITH (ROWLOCK)
            SET ExpectedQty = ScannedQty
               ,ErrMsg = 'Close Pack'
            WHERE ToteNo     = @cDropID
            AND   Orderkey    = @cOrderkey
            AND   AddWho      = @cUserName
            AND   Status      = '1'
            AND   ExpectedQty - ScannedQty > 0

            IF @@ROWCOUNT = 0 -- No data inserted
            BEGIN
               SET @nErrNo = 151182
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UpdEcommFail'
               GOTO ROLLBACKTRAN
            END

         END


      END

      IF @cOption = '9'
      BEGIN

         SET @cOrderKey = ''

         DECLARE C_Tote_Short CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

         SELECT RowRef, OrderKey
         FROM rdt.rdtECOMMLog WITH (NOLOCK)
         WHERE ToteNo = @cDropID
         --AND SKU = CASE WHEN @cOption ='1' THEN @cSKU  ELSE SKU END
         --AND SUM(ExpectedQty) > SUM(ScannedQty) --+ 1
         AND Status < '5'
         --AND AddWho = @cUserName
         ORDER BY RowRef

         OPEN C_Tote_Short
         FETCH NEXT FROM C_Tote_Short INTO  @nRowRef, @cOrderKey
         WHILE (@@FETCH_STATUS <> -1)
         BEGIN

            UPDATE rdt.rdtEcommLog WITH (ROWLOCK)
            SET Status = CASE WHEN @cOption = '1' THEN '5' ELSE '9' END
              , ErrMsg = CASE WHEN @cOption = '1' THEN 'Short Pack' ELSE 'Exit Pack' END
            WHERE RowRef = @nRowRef

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 151183
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdEcommFail'
               GOTO RollBackTran
            END


            EXEC RDT.rdt_STD_EventLog
                 @cActionType = '8', -- Packing
                 @cUserID     = @cUserName,
                 @nMobileNo   = @nMobile,
                 @nFunctionID = @nFunc,
                 @cFacility   = @cFacility,
                 @cStorerKey  = @cStorerkey,
                 @cSKU        = @cSku,
                 @cRefNo1     = 'SHORT PACK',
                 @cOrderKey   = @cOrderKey

            FETCH NEXT FROM C_Tote_Short INTO  @nRowRef, @cOrderKey

         END
         CLOSE C_Tote_Short
         DEALLOCATE C_Tote_Short


         SET @cOrderKey      = ''
         SET @cTrackNo       = ''
         SET @cCartonType    = ''
         SET @cWeight        = ''
         SET @cTaskStatus    = '9'
         SET @cTTLPickedQty  = ''
         SET @cTTLScannedQty = ''
      END


      --END

      --IF @cOption = '9'
      --BEGIN
      --   SET @cOrderKey      = ''
      --   SET @cTrackNo       = ''
      --   SET @cCartonType    = ''
      --   SET @cWeight        = ''
      --   SET @cTaskStatus    = '9'
      --   SET @cTTLPickedQty  = ''
      --   SET @cTTLScannedQty = ''
      --END

   END

   IF @nStep = 5
   BEGIN

      IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND DropID = @cDropID
                  AND Status < '5' )
      BEGIN
            SET @nErrNo = 151184
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'PickNotDone'
            GOTO ROLLBACKTRAN
      END

      SELECT   @cPickSlipNo = PickSlipNo
             , @cDropIDType = DropIDType
             , @cLoadKey    = LoadKey
      FROM dbo.DropID WITH (NOLOCK)
      WHERE DropID = @cDropID
      AND Status = '5'

      IF @cDropIDType = 'MULTIS'
      BEGIN
         SET @cDropOrderKey = ''

         SELECT Top 1 @cDropOrderKey = PD.OrderKey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
         WHERE PD.StorerKey =  @cStorerKey
         AND PD.DropID = @cDropID
         AND PD.Status < '9'
         AND O.LoadKey = @cLoadKey
         Order by PD.Editdate Desc

         IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND OrderKey = @cDropOrderKey
                     AND Status < '5' )
         BEGIN
            SET @nErrNo = 151185
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'PickNotComplete'
            GOTO ROLLBACKTRAN
         END
      END

      EXECUTE dbo.nspg_GetKey
               'RDTECOMM',
               10,
               @cBatchKey  OUTPUT,
               @bsuccess   OUTPUT,
               @nerrNo     OUTPUT,
               @cerrmsg    OUTPUT


      IF @cDropIDType = 'MULTIS' AND @cOption = '1'
      BEGIN


          /****************************
          INSERT INTO rdtECOMMLog
         ****************************/
         INSERT INTO rdt.rdtECOMMLog(Mobile, ToteNo, Orderkey, Sku, DropIDType, ExpectedQty, ScannedQty, AddWho, AddDate, EditWho, EditDate, BatchKey)
         SELECT @nMobile, @cDropID, PK.Orderkey, PK.SKU, @cDropIDType, SUM(PK.Qty), 0, @cUserName, GETDATE(), @cUserName, GETDATE(), @cBatchKey
         FROM dbo.PICKDETAIL PK WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON O.Orderkey = PK.Orderkey
         WHERE PK.DROPID = @cDropID
           AND (PK.Status IN ('3', '5') OR PK.ShipFlag = 'P')
           AND PK.CaseID = ''
           AND O.Type IN  ( SELECT CL.Code FROM dbo.CodeLKUP CL WITH (NOLOCK)
                           WHERE CL.ListName = 'ECOMTYPE'
                           AND CL.StorerKey = CASE WHEN CL.StorerKey = '' THEN '' ELSE O.StorerKey END)
           AND PK.Qty > 0 -- SOS# 329265
           AND O.SOStatus NOT IN ( 'PENDPACK', 'HOLD', 'PENDCANC' )
         GROUP BY PK.OrderKey, PK.SKU

         IF @@ROWCOUNT = 0 -- No data inserted
         BEGIN
            SET @nErrNo = 151186
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoRecToProcess'
            GOTO ROLLBACKTRAN
         END

         SET @nTotalScannedQty = 0

         SELECT @nTotalPickedQty  = SUM(ExpectedQty)
         FROM rdt.rdtECOMMLog WITH (NOLOCK)
         WHERE ToteNo = @cDropID
         AND Status = '0'
         AND OrderKey = CASE WHEN ISNULL(@cOrderKey,'')  = '' THEN OrderKey ELSE @cOrderKey END
         AND AddWho = @cUserName
         AND Mobile = @nMobile

         SELECT @cOrderKey = OrderKey
         FROM rdt.rdtEcommLog WITH (NOLOCK)
         WHERE ToteNo = @cDropID
         AND Status = '0'
         AND AddWho = @cUserName
         AND Mobile = @nMobile



         SET @cOrderKey      = @cOrderKey
         SET @cTrackNo       = ''
         SET @cCartonType    = ''
         SET @cWeight        = ''
         SET @cTaskStatus    = '1'
         SET @cTTLPickedQty  = @nTotalPickedQty
         SET @cTTLScannedQty = '0'


      END
      ELSE
      BEGIN
         SET @cOrderKey      = ''
         SET @cTrackNo       = ''
         SET @cCartonType    = ''
         SET @cWeight        = ''
         SET @cTaskStatus    = '9'
         SET @cTTLPickedQty  = '0'
         SET @cTTLScannedQty = '0'
      END


   END

   GOTO QUIT

RollBackTran:
   ROLLBACK TRAN rdt_842ExtUpdSP08 -- Only rollback change made here

Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_842ExtUpdSP08
   IF @nStep = 3 AND @cTaskStatus = '9'
   BEGIN
      SET @cDelayLength = rdt.RDTGetConfig( @nFunc, 'PrintLabel', @cStorerKey)
      IF @cDelayLength = '0'
         SET @cDelayLength = ''
      IF @cDelayLength <> ''
      BEGIN
         SET @nDelayLength = TRY_CAST(@cDelayLength AS INT)
         IF @nDelayLength IS NOT NULL AND @nDelayLength > 0
         BEGIN
            DECLARE
               @nMin       INT,
               @nSec       INT,
               @nPrintedOrderQty INT

            --SET @nDelayLength = IIF( @nDelayLength > 5000, 5000, @nDelayLength)
            SET @nDelayLength = IIF( @nDelayLength > 20000, 20000, @nDelayLength)
            SET @nMin = @nDelayLength / 1000 / 60
            SET @nSec = (@nDelayLength - (@nMin * 60 * 1000)) / 1000
            SET @cDelayLength = '00:' + CAST(@nMin AS NVARCHAR(5)) + ':' + CAST(@nSec AS NVARCHAR(5))

            WAITFOR DELAY @cDelayLength

            SELECT @cOption = Code
            FROM dbo.CodeLkup WITH (NOLOCK)
            WHERE Listname = 'RDTLBLRPT'
               AND Storerkey = @cStorerKey
               AND Long = 'rdt_593PrintHK01'
               AND code2 = 'SHIPLABEL'

            SELECT @cWaveKey = WaveKey 
            FROM dbo.WaveDetail WITH(NOLOCK)
            WHERE OrderKey = @cCurrentOrderKey

            DELETE FROM @tOrders

            INSERT INTO @tOrders(OrderKey)
            SELECT DISTINCT ECL.OrderKey
            FROM RDT.rdtECOMMLog ECL WITH (NOLOCK)
            INNER JOIN dbo.ORDERS ORM WITH(NOLOCK) ON ECL.OrderKey = ORM.OrderKey AND ORM.StorerKey = @cStorerKey
            INNER JOIN dbo.WaveDetail WD WITH(NOLOCK) ON WD.OrderKey = ORM.OrderKey
            WHERE ECL.STATUS = '9' AND ECL.ToTeNo = @cDropID AND ECL.Mobile = @nMobile
              AND ORM.Status < '9'
              AND WD.WaveKey = @cWaveKey
            ORDER BY ECL.OrderKey

            INSERT INTO dbo.TraceInfo (TraceName, TimeIn, Col1, Col2, Col3, Col4, Col5)  
            VALUES('rdt_842ExtUpdSP08-0', GETDATE(), '', @cDelayLength, @cStorerKey, @cDropID, @nMobile) 

            SET @nPrintedOrderQty = 0
            SET @nLoopIndex = -1
            SET @cTempOrderKey = ''
            WHILE 1 = 1
            BEGIN
               SELECT TOP 1
                  @cTempOrderKey = OrderKey,
                  @nLoopIndex = id
               FROM @tOrders
               WHERE id > @nLoopIndex
                  AND OrderKey > @cTempOrderKey
               ORDER BY id

               SELECT @nRowCount = @@ROWCOUNT

               IF @nRowCount = 0
                  BREAK

               IF @nPrintedOrderQty > 200
                  BREAK

               SELECT @cUDF02 = ISNULL(UDF02, 'Empty UDF02'), @cUDF03 = ISNULL(UDF03, 'Empty UDF03')
               FROM dbo.CartonTrack WITH(NOLOCK)
               WHERE LABELNO = @cTempOrderKey

               INSERT INTO dbo.TraceInfo (TraceName, TimeIn, Step1, Col1, Col2, Col3, Col4, Col5)
               VALUES('rdt_842ExtUpdSP08', GetDate(), @nLoopIndex, @cTempOrderKey, @cUDF02, @cUDF03, @cDropID, CAST(@nMobile AS NVARCHAR(10)))

               IF EXISTS(SELECT 1 FROM dbo.CARTONTRACK WITH(NOLOCK) WHERE LABELNO = @cTempOrderKey AND ISNULL(UDF02, '') <> '' AND ISNULL(UDF03, '') <> '')
               BEGIN
                  IF EXISTS ( SELECT 1 FROM dbo.sysobjects WHERE name = 'rdt_593PrintHK01' AND type = 'P')
                  BEGIN
                     EXEC RDT.rdt_593PrintHK01
                        @nMobile,
                        @nFunc,
                        @nStep,
                        @cLangCode,
                        @cStorerKey,
                        @cOption,
                        @cTempOrderKey,
                        '',
                        '',
                        '',
                        '',
                        @nErrNo,
                        @cErrMsg

                     IF @nErrNo <>''
                     BEGIN
                        BREAK
                     END

                     SET @nPrintedOrderQty = @nPrintedOrderQty + 1
                  END
                  ELSE
                  BEGIN
                     SET @nErrNo = 151194
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --rdt_593PrintHK01 does not exist
                     BREAK
                  END
               END
               ELSE
               BEGIN
                  DECLARE
                     @cMsg01  NVARCHAR(125),
                     @cMsg02  NVARCHAR(125),
                     @cMsg03  NVARCHAR(125)
                  SELECT
                     @cMsg01 = rdt.rdtGetMessageLong( 151191, @cLangCode, 'DSP'),
                     @cMsg02 = rdt.rdtGetMessageLong( 151192, @cLangCode, 'DSP'),
                     @cMsg03 = rdt.rdtGetMessageLong( 151193, @cLangCode, 'DSP')

                  EXEC rdt.rdtInsertMsgQueue
                     @nMobile = @nMobile,
                     @nErrNo = @nErrNo,
                     @cErrMsg = @cErrMsg,
                     @cLine01 = @cMsg01,
                     @cLine02 = @cMsg02,
                     @cLine03 = @cMsg03,
                     @cLine04 = '',
                     @cLine05 = '',
                     @cLine06 = '',
                     @cLine07 = '',
                     @cLine08 = '',
                     @cLine09 = '',
                     @nDisplayMsg = 0
                  BREAK
               END
            END
         END
      END
   END


END

GO