SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593PrintUA01                                       */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2017-09-20 1.0  ChewKP   WMS-4692 Created                               */
/* 2019-05-09 1.1  ChewKP   Bug Fixes - (ChewKP01)                         */
/* 2019-09-10 1.2  James    WMS-10521 Add insert packinfo (james01)        */
/* 2020-01-03 1.3  James    WMS-11661 Stamp pickdtl.dropid=labelno(james02)*/
/* 2022-09-15 1.4  yeekung  WMS-20794 Add reporttype (yeekung01)           */
/* 2022-11-23 1.5  yeekung  WMS-21213 Add Shiplabel (yeekung02)            */
/* 2023-08-09 1.6  yeekung  WMS-23130 Add Carton content lbl (yeekung03)   */
/***************************************************************************/

CREATE    PROC [RDT].[rdt_593PrintUA01] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- OrderKey
   @cParam2    NVARCHAR(20),
   @cParam3    NVARCHAR(20),
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success     INT

   DECLARE @cDataWindow   NVARCHAR( 50)
         , @cManifestDataWindow NVARCHAR( 50)

   DECLARE @cTargetDB     NVARCHAR( 20)
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)
   DECLARE @cUserName     NVARCHAR( 18)
   DECLARE @cLabelType    NVARCHAR( 20)

   DECLARE
           @cPickSlipNo       NVARCHAR(10)
          ,@cUCCNo            NVARCHAR(20)
          ,@nCartonStart      INT
          ,@nCartonEnd        INT
          ,@cVASType          NVARCHAR(10)
          ,@cField01          NVARCHAR(10)
          ,@cTemplate         NVARCHAR(50)
          ,@nTranCount        INT
          ,@cPickDetailKey    NVARCHAR(10)
          ,@cOrderKey         NVARCHAR(10)
          ,@cLabelNo          NVARCHAR(20)
          ,@cSKU              NVARCHAR(20)
          ,@nCartonNo         INT
          ,@cLabelLine        NVARCHAR(5)
          ,@cGenLabelNoSP     NVARCHAR(30)
          ,@nQty              INT
          ,@cExecStatements   NVARCHAR(4000)
          ,@cExecArguments    NVARCHAR(4000)
          ,@cCodeTwo          NVARCHAR(30)
          ,@cTemplateCode     NVARCHAR(60)
          ,@nFocusParam       INT
          ,@bsuccess          INT
          ,@nPackQTY          INT
          ,@nPickQTY          INT
          ,@nMaxCarton        INT
          ,@nIsUCC            INT
          ,@cPrintPackingList NVARCHAR(1)
          ,@cUOM              NVARCHAR(10)
          ,@cDeviceID         NVARCHAR(20)
          ,@cDeviceType       NVARCHAR(20)
          ,@cWCSStation       NVARCHAR(20)
          ,@cWCSKey           NVARCHAR(10)
          ,@cWCSSequence      NVARCHAR(2)
          ,@cWCSMessage       NVARCHAR(255)
          ,@cShipRouteLoc     NVARCHAR(10)
          ,@cPutawayZone      NVARCHAR(10)
          ,@cLoadKey          NVARCHAR(10)
          ,@nInputKey         INT
          ,@cFacility         NVARCHAR( 5)
          ,@cShipLbl          NVARCHAR( 20)
          ,@cOrdergroup       NVARCHAR( 20)
          ,@cUDF01            NVARCHAR( 20)
          ,@cChkOrderKey      NVARCHAR( 20)
          ,@cChkStatus        NVARCHAR( 20)
          ,@cChkSOStatus      NVARCHAR( 20)


   DECLARE @tOutBoundList AS VariableTable
   DECLARE @tOutBoundList2 AS VariableTable

   SET @cDeviceType = 'WCS'
   SET @cDeviceID   = 'WCS'

   SELECT @cLabelPrinter = Printer
         ,@cUserName     = UserName
         ,@cPaperPrinter   = Printer_Paper
         ,@cFacility       = Facility
         ,@nInputKey       = InputKey
   FROM rdt.rdtMobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check label printer blank
   IF ISNULL(RTRIM(@cLabelPrinter),'')  = ''
   BEGIN
      SET @nErrNo = 123151
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END

   -- Check label printer blank
   IF ISNULL(RTRIM(@cPaperPrinter),'')  = ''
   BEGIN
      SET @nErrNo = 123152
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PaperPrnterReq
      GOTO Quit
   END

   SET @cGenLabelNoSP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo', @cStorerkey)

   IF NOT EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = ISNULL(RTRIM(@cGenLabelNoSP),'') AND type = 'P')
   BEGIN
         SET @nErrNo = 123158
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'GenLblSPNotFound'
         GOTO Quit
   END


   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_593PrintUA01

   
   IF @cOption = '1'
   BEGIN

      -- Screen mapping
      SET @cOrderKey = @cParam1
      SET @cUDF01 = @cParam2

      -- james01
      IF ISNULL( @cUDF01 , '') <> ''
      BEGIN
         SELECT TOP 1 @cLabelNo = LabelNo
         FROM dbo.CartonTrack WITH (NOLOCK, INDEX =IX_CARTONTRACK_03)
         WHERE CarrierName='HTKY'
         AND   UDF01 = @cUDF01

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 123171
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Invalid UDF
            EXEC rdt.rdtSetFocusField @nMobile, 4 --Param1
            GOTO Quit
         END

         SET @cOrderKey = @cLabelNo
      END

      -- Check blank
      IF @cOrderKey = ''
      BEGIN
         SET @nErrNo = 123172
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Need OrderKey
         EXEC rdt.rdtSetFocusField @nMobile, 2 --Param1
         GOTO Quit
      END

      -- Get Order info
      SELECT
         @cChkOrderKey = OrderKey,
         @cChkStatus   = Status,
         @cChkSOStatus = SOStatus,
         @cOrdergroup = ordergroup
      FROM dbo.Orders WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      -- Check OrderKey valid
      IF @cChkOrderKey = ''
      BEGIN
         SET @nErrNo = 123173
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad OrderKey
         GOTO Quit
      END

      -- Check order shipped
      IF @cChkStatus = '9' AND @cUDF01 = ''
      BEGIN
         SET @nErrNo = 123174
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order shipped
         GOTO Quit
      END

      -- Check order cancel
      IF @cChkStatus = 'CANC'
      BEGIN
         SET @nErrNo = 123175
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order cancel
         GOTO Quit
      END

      -- Check order status
      IF @cChkSOStatus IN ('HOLD','PENDCANC','PENDGET','PENDPACK')
      BEGIN
         SET @nErrNo = 123176
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadOrderStatus
         GOTO Quit
      END
   /*
      -- Check order status
      IF @cChkSOStatus <> 'PENDPRINT'
      BEGIN
         DECLARE @cErrMsg1 NVARCHAR(20)
         SET @cErrMsg1 = @cChkSOStatus

         SET @nErrNo = 85256
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg, @cErrMsg1
         GOTO Quit
      END
   */
      -- Get LoadKey
      SELECT
         @cLoadKey = LoadKey
      FROM OrderDetail WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      -- Check LoadKey
      IF @cLoadKey = ''
      BEGIN
         SET @nErrNo = 123177
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') + @cChkSOStatus --OrdNotLoadPlan
         GOTO Quit
      END

      IF @cOrdergroup ='JITX'
         SET @cShipLbl ='SHPLBVIPUA'
      ELSE
         SET @cShipLbl='ShipLabel'

      SELECT @cUserName = UserName FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
      
      DECLARE @tShipLabel AS VariableTable  --(yeekung02)
      INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cStorerKey', @cStorerKey)    
      INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)          
      INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cLoadKey', @cLoadKey)       

         -- Print label  
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, '1', @cFacility, @cStorerkey, @cLabelPrinter, @cPaperPrinter,   
         @cShipLbl, -- Report type    SHIPPLABEL  / ShipLabel
         @tShipLabel, -- Report params  
         'rdt_593PrintUA01',   
         @nErrNo  OUTPUT,  
         @cErrMsg OUTPUT   
   END


   IF @cOption ='5'
   BEGIN
      SET @cUCCNo      = @cParam1

      -- Check blank
      IF ISNULL(RTRIM(@cUCCNo), '') = ''
      BEGIN
         SET @nErrNo = 123153
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UCCorDropIDReq
         GOTO RollBackTran
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND DropID = @cUCCNo
                      AND Status = '3' )
      BEGIN
         SET @nErrNo = 123154
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidValue
         GOTO RollBackTran
      END

      IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND UCCNo = @cUCCNo )
         SET @nIsUCC = 1
      ELSE
         SET @nIsUCC = 0



      BEGIN -- Packing


         DECLARE C_UADropID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

         SELECT PD.PickDetailKey
               ,PD.SKU
               ,PD.QTy
               ,PD.OrderKey
               ,PD.UOM
         FROM dbo.Pickdetail PD WITH (NOLOCK)
         --INNER JOIN dbo.PickHeader PH WITH (NOLOCK) ON PH.OrderKey = PD.OrderKey
         WHERE PD.StorerKey = @cStorerKey
         AND PD.Status = '3'
         AND PD.DropID = @cUCCNo
         AND PD.CaseID = ''
         AND PD.UOM    = CASE WHEN @nIsUCC = 1 THEN '2' ELSE PD.UOM END
         ORDER BY PD.OrderKey


         OPEN C_UADropID
         FETCH NEXT FROM C_UADropID INTO  @cPickDetailKey, @cSKU, @nQty, @cOrderKey, @cUOM
         WHILE (@@FETCH_STATUS <> -1)
         BEGIN

            IF EXISTS ( SELECT 1 FROM dbo.PickHeader WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND OrderKey = @cOrderKey )
            BEGIN
               SELECT @cPickSlipNo = PickHeaderKey
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND OrderKey = @cOrderKey

               IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND Orderkey = @cOrderKey )
               BEGIN
                   INSERT INTO dbo.PackHeader
                     (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
                   VALUES ( '' , @cOrderKey,  '', '', '', @cStorerKey, @cPickSlipNo )

                   IF @@ERROR <> 0
                   BEGIN
                      SET @nErrNo = 123155
                      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InsPackHdFail
                      GOTO RollBackTran
                   END
               END
            END
            ELSE
            BEGIN
               IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND Orderkey = @cOrderKey  )
               BEGIN
                   EXECUTE dbo.nspg_GetKey
                     'PICKSLIP',
                     9,
                     @cPickslipno OUTPUT,
                     @bsuccess   OUTPUT,
                     @nErrNo     OUTPUT,
                     @cErrMsg    OUTPUT

                   SET @cPickslipno = 'P' + @cPickslipno

                   INSERT INTO dbo.PICKHEADER (PickHeaderKey, Storerkey, Orderkey, PickType, Zone, TrafficCop, AddWho, AddDate, EditWho, EditDate)
                   VALUES (@cPickSlipNo, @cStorerkey, @cOrderKey, '0', 'D', '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE())

                   IF @@ERROR <> 0
                   BEGIN
                      SET @nErrNo = 123156
                      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickHdrFail'
                      GOTO RollBackTran
                   END

                   IF NOT EXISTS ( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK)
                                   WHERE PickSlipNo = @cPickSlipNo )
                   BEGIN

                     INSERT INTO dbo.PickingInfo (PickSlipNo , ScanInDate , AddWho  )
                     VALUES ( @cPickSlipNo , GetDATE() , @cUserName )

                     IF @@ERROR <> 0
                     BEGIN
                           SET @nErrNo = 123157
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPickInfoFail'
                           GOTO RollBackTran
                     END

                   END

                   INSERT INTO dbo.PackHeader
                     (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
                   VALUES ( '' , @cOrderKey,  '', '', '', @cStorerKey, @cPickSlipNo )

                   IF @@ERROR <> 0
                   BEGIN
                      SET @nErrNo = 123155
                      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InsPackHdFail
                      GOTO RollBackTran
                   END


                   --INSERT INTO dbo.PackHeader
                   --(Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, AddWho, AddDate, EditWho, EditDate)
                   --SELECT TOP 1  O.Route, O.OrderKey,'', O.LoadKey, O.ConsigneeKey, O.Storerkey,
                   --     @cPickSlipNo, sUser_sName(), GETDATE(), sUser_sName(), GETDATE()
                   --FROM  dbo.Orders O WITH (NOLOCK)
                   --WHERE O.Orderkey = @cOrderKey

                   --IF @@ERROR <> 0
                   --BEGIN
                   --   SET @nErrNo = 123158
                   --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CreatePHdrFail'
                   --   GOTO RollBackTran
                   --END


               END
               ELSE
               BEGIN
                  SELECT @cPickSlipNo = PickSlipNo
                  FROM dbo.PackHeader WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND Orderkey = @cOrderKey
               END
            END

            SET @cLabelNo = ''
            SET @nCartonNo = 0
            SET @cLabelLine = '00000'


            IF @cUOM = '7'
            BEGIN
               SET @cLabelNo = @cUCCNo
            END
            ELSE
            BEGIN
               IF EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                              WHERE StorerKey = @cStorerKey
                              AND PickSlipNo = @cPickSlipNo
                              AND DropID = @cUCCNo )  -- (ChewKP01)
               BEGIN

                  SELECT @cLabelNo = LabelNo
                  FROM dbo.PackDetail WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND DropID = @cUCCNo
                  AND PickSlipNo = @cPickSlipNo

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
               END
            END


            IF ISNULL(@cLabelNo,'')  = ''
            BEGIN
                  SET @nErrNo = 115256
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoLabelNoGen
                  GOTO RollBackTran
            END

            IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND PickSlipNo = @cPickSlipNo
                            AND LabelNo = @cLabelNo
                            AND DropID = @cUCCNo
                            AND SKU = @cSKU )
            BEGIN
--               IF @cUOM = '7'
--               BEGIN
                  INSERT INTO dbo.PackDetail
                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, DropID, UPC, AddWho, AddDate, EditWho, EditDate)
                  VALUES
                     (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nQty,
                     '1', @cUCCNo, '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE())
--               END
--               ELSE
--               BEGIN
--                   INSERT INTO dbo.PackDetail
--                     (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, DropID, UPC, AddWho, AddDate, EditWho, EditDate)
--                  VALUES
--                     (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nQty,
--         '1', @cLabelNo, '', sUser_sName(), GETDATE(), sUser_sName(), GETDATE())
--
--
--               END

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 115257
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDetFail'
                  GOTO RollBackTran
               END

               -- (james01)
               SELECT TOP 1 @nCartonNo = CartonNo
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               AND   LabelNo = @cLabelNo
               ORDER BY 1

               IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
                           WHERE PickSlipNo = @cPickSlipNo
                           AND CartonNo = @nCartonNo)
               BEGIN
                  INSERT INTO dbo.PACKINFO
                  (PickSlipNo, CartonNo, CartonType, Cube, Weight, RefNo)
                  VALUES
                  (@cPickSlipNo, @nCartonNo, '', 0, 0, '')

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 123170
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INS PACKInf Fail'
                     GOTO RollBackTran
                  END
               END
            END
            ELSE
            BEGIN
              -- IF @cUOM = '7'
                  UPDATE dbo.PackDetail WITH (ROWLOCK)
                  SET Qty = Qty + @nQty
                  WHERE StorerKey = @cStorerKey
                  AND PickSlipNo  = @cPickSlipNo
                  AND LabelNo     = @cLabelNo
                  AND DropID      = @cUCCNo
                  AND SKU         = @cSKU
--               ELSE
--                  UPDATE dbo.PackDetail WITH (ROWLOCK)
--                  SET Qty = Qty + @nQty
--                  WHERE StorerKey = @cStorerKey
--  AND PickSlipNo  = @cPickSlipNo
--                  AND LabelNo     = @cLabelNo
--                  AND DropID      = @cLabelNo
--                  AND SKU         = @cSKU


               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 115258
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDetFail'
                  GOTO RollBackTran
               END

            END

--            IF @cUOM = '7'
               UPDATE dbo.PickDetail WITH (ROWLOCK)
               SET CaseID = @cLabelNo
                  ,EditWho = @cUserName
                  ,EditDate = GetDATE()
                  ,Status = '5'
                  --,TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
--            ELSE
--               UPDATE dbo.PickDetail WITH (ROWLOCK)
--               SET CaseID = @cLabelNo
--                  ,DropID = @cLabelNo
--                  ,EditWho = @cUserName
--                  ,EditDate = GetDATE()
--                  ,Status = '5'
--                  --,TrafficCop = NULL
--               WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
                  SET @nErrNo = 115259
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDetFail'
                  GOTO RollBackTran
            END

            FETCH NEXT FROM C_UADropID INTO  @cPickDetailKey, @cSKU, @nQty, @cOrderKey, @cUOM

         END
         CLOSE C_UADropID
         DEALLOCATE C_UADropID



         SELECT @nCartonNo = CartonNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
         AND StorerKey = @cStorerKey
         AND DropID = @cUCCNo

--         SELECT @nCartonEnd = MAX(CartonNo)
--         FROM dbo.PackDetail WITH (NOLOCK)
--         WHERE PickSlipNo = @cPickSlipNo
--         AND StorerKey = @cStorerKey
--         AND DropID = @cUCCNo

--         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cStorerKey',  @cStorerKey)
--         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
--         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonStart', @nCartonNo)
--         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonEnd',   @nCartonNo)
--
--         -- Print label
--         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
--            'SHIPLBLUA', -- Report type
--            @tOutBoundList, -- Report params
--            'rdt_593PrintUA01',
--            @nErrNo  OUTPUT,
--            @cErrMsg OUTPUT
--
--         IF @nErrNo <> 0
--            GOTO RollBackTran


      END

      SELECT Top 1 @cOrderKey = OrderKey
                  ,@cUOM      = UOM
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND DropID = @cUCCNo
      --AND Status = '5'
      --AND CaseID <> ''

      IF EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND OrderKey = @cOrderKey )
      BEGIN
         SELECT @cPickSlipNo = PickSlipNo
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey
      END
      ELSE
      BEGIN
         SET @nErrNo = 123160
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NoRecFound
         GOTO RollBackTran
      END

      -- Print UCC Label
      SELECT @nCartonStart = MIN(CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND StorerKey = @cStorerKey
      AND DropID = @cUCCNo

      SELECT @nCartonEnd = MAX(CartonNo)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
      AND StorerKey = @cStorerKey
      AND DropID = @cUCCNo

-- SELECT @nMaxCarton = MAX(CartonNo)
--      FROM dbo.PackDetail WITH (NOLOCK)
--      WHERE PickSlipNo = @cPickSlipNo
--      AND StorerKey = @cStorerKey

      SET @nPackQTY = 0
      SET @nPickQTY = 0
      SELECT @nPackQTY = SUM( QTY) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
      SELECT @nPickQTY = SUM( QTY) FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey

      SET @cPrintPackingList = '0'

      IF @nPackQty = @nPickQty
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND PickSlipNo = @cPickSlipNo
                            AND RefNo2 = '1'  )
         BEGIN
            SET @cPrintPackingList = '1'

            UPDATE dbo.PackDetail WITH (ROWLOCK)
            SET RefNo2 = '1'
            WHERE PickSlipNo = @cPickSlipNo
            AND DropID = @cUCCNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 123165
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --UpdPickDetFail
               GOTO RollBackTran
            END
         END
      END

      IF EXISTS (  SELECT 1
                FROM dbo.DocInfo WITH (NOLOCK)
                WHERE StorerKey = @cStorerKey
                AND TableName = 'ORDERDETAIL'
                AND Key1 = @cOrderKey
                AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L01'  )
      BEGIN

         DECLARE CursorLabel CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

         SELECT Rtrim(Substring(Docinfo.Data,31,30))
               ,Rtrim(Substring(Docinfo.Data,61,30))
         FROM dbo.DocInfo WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND TableName = 'ORDERDETAIL'
         AND Key1 = @cOrderKey
         AND Key2 = '00001'
         AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L01'

         OPEN CursorLabel

         FETCH NEXT FROM CursorLabel INTO @cVASType, @cField01


         WHILE @@FETCH_STATUS <> -1
         BEGIN

            SET @cTemplate = ''

            DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Notes, Code2
            FROM dbo.CodeLkup WITH (NOLOCK)
            WHERE ListName = 'UALabel'
            AND Code  = @cField01
            AND Short = @cVASType
            AND StorerKey = @cStorerKey

            OPEN CursorCodeLkup
            FETCH NEXT FROM CursorCodeLkup INTO @cTemplate, @cCodeTwo
            WHILE @@FETCH_STATUS<>-1
            BEGIN

      --         SELECT @cTemplate = ISNULL(RTRIM(Notes),'')
      --         FROM dbo.CodeLkup WITH (NOLOCK)
      --         WHERE ListName = 'UALabel'
      --         AND Code  = @cField01
      --         AND Short = @cVASType
      --         AND StorerKey = @cStorerKey

               SET @cTemplateCode = ''
               SET @cTemplateCode = ISNULL(RTRIM(@cField01),'')  + ISNULL(RTRIM(@cCodeTwo),'')

               IF @cTemplate = ''
               BEGIN
                  SET @nErrNo = 123161
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TemplateNotFound
                  GOTO Quit
               END

               DELETE FROM @tOutBoundList

               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonStart', @nCartonStart)
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonEnd',   @nCartonEnd)
               INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cTemplateCode',   @cTemplateCode)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
                  'SHIPLBLUA2', -- Report type
                  @tOutBoundList, -- Report params
                  'rdt_593PrintUA01',
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT

              IF @nErrNo <> 0
                  GOTO RollBackTran



               FETCH NEXT FROM CursorCodeLkup INTO @cTemplate, @cCodeTwo
            END
            CLOSE CursorCodeLkup
            DEALLOCATE CursorCodeLkup

            FETCH NEXT FROM CursorLabel INTO @cVASType, @cField01

         END
         CLOSE CursorLabel
         DEALLOCATE CursorLabel
      END

      --INSERT INTO TRACEINFO (TRaceName , TimeIN, Col1, Col2, Col3, Col4, Col5 )
      --VALUES ( 'UALABEL', Getdate() ,@cVASType ,@cLabelFlag, @nCartonNo ,@cLabelNo ,@cPickSlipNo  )
      IF ISNULL(@cUOM,'') NOT IN ('', '2')
      BEGIN
         IF EXISTS (  SELECT 1
                      FROM dbo.DocInfo WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND TableName = 'ORDERDETAIL'
                      AND Key1 = @cOrderKey
                      AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L02'  )
         BEGIN



            SELECT @cVASType = Rtrim(Substring(Docinfo.Data,31,30))
            FROM dbo.DocInfo WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND TableName = 'ORDERDETAIL'
            AND Key1 = @cOrderKey
            AND Key2 = '00001'
            AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L02'



            SET @cTemplate = ''

            DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Notes, Code2
            FROM dbo.CodeLkup WITH (NOLOCK)
            WHERE ListName = 'UACCLabel'
            AND Code  = @cVASType
            AND StorerKey = @cStorerKey

            OPEN CursorCodeLkup
            FETCH NEXT FROM CursorCodeLkup INTO @cTemplate, @cCodeTwo
            WHILE @@FETCH_STATUS<>-1
            BEGIN

               SET @cTemplateCode = ''
               SET @cTemplateCode = ISNULL(RTRIM(@cVASType),'')  + ISNULL(RTRIM(@cCodeTwo),'')

               IF @cTemplate = ''
               BEGIN
                  SET @nErrNo = 123162
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TemplateNotFound
                  GOTO Quit
               END

                  DELETE FROM @tOutBoundList

                  INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
                  INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonStart', @nCartonStart)
                  INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonEnd',   @nCartonEnd)
                  INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cTemplateCode',   @cTemplateCode)

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
                     'SHIPLBLUA2', -- Report type
                     @tOutBoundList, -- Report params
                     'rdt_593PrintUA01',
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO RollBackTran

               FETCH NEXT FROM CursorCodeLkup INTO @cTemplate, @cCodeTwo

            END
            CLOSE CursorCodeLkup
            DEALLOCATE CursorCodeLkup

         END
      END

      -- Sent WCS when UOM = 2
      IF ISNULL(@cUOM,'')  = '2'
      BEGIN

          -- To Shipping Route
          SET @cWCSStation   = ''
          SET @cPutawayZone  = ''
          SET @cShipRouteLoc = ''
          SET @cLoadKey      = ''

          SELECT @cLoadKey = LoadKey
          FROM dbo.LoadPlanDetail WITH (NOLOCK)
          WHERE OrderKey = @cOrderKey

          SELECT @cShipRouteLoc = Loc
          FROM dbo.LoadPlanLaneDetail WITH (NOLOCK)
          WHERE Loadkey = @cLoadKey

          SELECT @cPutawayZone = PutawayZone
          FROM dbo.Loc WITH (NOLOCK)
          WHERE Facility = @cFacility
          AND Loc = @cShipRouteLoc

          SELECT @cWCSStation = Short
          FROM dbo.Codelkup WITH (NOLOCK)
          WHERE ListName = 'WCSSTATION'
          AND StorerKey = @cStorerKey
          AND Code = @cPutawayZone

          EXECUTE dbo.nspg_GetKey
          'WCSKey',
          10 ,
          @cWCSKey           OUTPUT,
          @bSuccess          OUTPUT,
          @nErrNo            OUTPUT,
          @cErrMsg           OUTPUT

          IF @bSuccess <> 1
          BEGIN
             SET @nErrNo = 123169
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
             GOTO RollBackTran
          END

          SET @cWCSSequence =  '01' --RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)
          SET @cWCSMessage = CHAR(2) + @cWCSKey + '|' + @cWCSSequence + '|' + RTRIM(@cLabelNo) + '|' + @cOrderKey + '|' + @cWCSStation + '|' + CHAR(3)

          EXEC [RDT].[rdt_GenericSendMsg]
           @nMobile      = @nMobile
          ,@nFunc        = @nFunc
          ,@cLangCode    = @cLangCode
          ,@nStep        = @nStep
          ,@nInputKey    = @nInputKey
          ,@cFacility    = @cFacility
          ,@cStorerKey   = @cStorerKey
          ,@cType        = @cDeviceType
          ,@cDeviceID    = @cDeviceID
          ,@cMessage     = @cWCSMessage
          ,@nErrNo       = @nErrNo       OUTPUT
          ,@cErrMsg      = @cErrMsg      OUTPUT

          IF @nErrNo <> 0
          BEGIN
             SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
             GOTO RollBackTran
          END

      END

      IF EXISTS (select 1 from orders (nolock)
                 WHERE orderkey=@cOrderKey
                 AND ordergroup ='JIT')
      BEGIN
         DELETE FROM @tOutBoundList

         --INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
         --INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonStart', @nCartonStart)
         --INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@nCartonEnd',   @nCartonEnd)
         --INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cTemplateCode',   @cTemplateCode)
         
         
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cDropid',  @cParam1)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
            'CTNLBLUA', -- Report type
            @tOutBoundList, -- Report params
            'rdt_593PrintUA01',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT

         DELETE FROM @tOutBoundList
         
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickslipNo',  @cPickSlipNo)
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cUCCNO',  @cUCCNO)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
            'CTNRPTUA', -- Report type
            @tOutBoundList, -- Report params
            'rdt_593PrintUA01',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT


      END


      SET @nPackQTY = 0
      SET @nPickQTY = 0
      SELECT @nPackQTY = SUM( QTY) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
      SELECT @nPickQTY = SUM( QTY) FROM PickDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey

      IF (ISNULL(@nPackQty,0)  > 0 AND  ISNULL(@nPickQty,0)  > 0  )  AND @nPackQty = @nPickQty
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                            WHERE PickSlipNo = @cPickSlipNo
                            AND Status = '9')
         BEGIN


               UPDATE PackHeader SET
                  Status = '9'
               WHERE PickSlipNo = @cPickSlipNo
                  AND Status <> '9'

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 123160
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NoRecFound
                  GOTO RollBackTran
               END
         END




         IF @cPrintPackingList = '1'
         BEGIN



            -- Print Packing List Process --
            IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND PickSlipNo = @cPickSlipNo
                            AND ISNULL(RTRIM(RefNo),'')  <> '1' )
            BEGIN
               --IF @nMaxCarton = @nCartonEnd
               --BEGIN

                  SET @cTemplate = ''

                  IF EXISTS ( SELECT 1
                              FROM dbo.DocInfo WITH (NOLOCK)
                              WHERE StorerKey = @cStorerKey
                              AND TableName = 'ORDERDETAIL'
                              AND Key1 = @cOrderKey
                              AND Rtrim(Substring(Docinfo.Data,31,30)) = 'F01'  )
                  BEGIN

                     SELECT @cVASType = Rtrim(Substring(Docinfo.Data,31,30))
                     FROM dbo.DocInfo WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND TableName = 'ORDERDETAIL'
                     AND Key1 = @cOrderKey
                     AND Rtrim(Substring(Docinfo.Data,31,30)) = 'F01'

                     SELECT @cTemplate = ISNULL(RTRIM(Notes),'')
                     FROM dbo.CodeLkup WITH (NOLOCK)
                     WHERE ListName = 'UAPACKLIST'
                     AND Code  = @cVASType
                     AND UDF01 <> '1'
                     AND StorerKey = @cStorerKey

                     IF ISNULL(RTRIM(@cTemplate),'')  <> ''
                     BEGIN


                        DELETE @tOutBoundList
                        INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)

                        -- Print label
                        EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,
                           'PACKLIST', -- Report type
                           @tOutBoundList, -- Report params
                           'rdt_593PrintUA01',
                           @nErrNo  OUTPUT,
                           @cErrMsg OUTPUT

                        IF @nErrNo <> 0
                           GOTO RollBackTran

                     END
                  END

               --END


            END

         END

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

      END
   END

   GOTO QUIT



RollBackTran:
   ROLLBACK TRAN rdt_593PrintUA01 -- Only rollback change made here
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam


Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN rdt_593PrintUA01
   EXEC rdt.rdtSetFocusField @nMobile, @nFocusParam


GO