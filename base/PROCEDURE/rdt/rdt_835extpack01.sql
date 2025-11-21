SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_835ExtPack01                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick and pack confirm                                       */
/*                                                                      */
/* Called from: rdtfnc_Pallet_Pack                                      */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 26-04-2019  1.0  James       WMS9039.Created                         */
/* 23-07-2019  1.1  James       Add scan in (james01)                   */  
/* 16-04-2021  1.2  James       WMS-16024 Standarized use of TrackingNo */
/*                              (james02)                               */
/************************************************************************/

CREATE PROC [RDT].[rdt_835ExtPack01] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5), 
   @tPackCfm      VariableTable READONLY, 
   @cPrintPackList NVARCHAR( 1)  OUTPUT,
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT
   DECLARE @cZone          NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @nQTY_PD        INT
   DECLARE @bSuccess       INT
   DECLARE @n_err          INT
   DECLARE @c_errmsg       NVARCHAR( 20)
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @cShipperKey    NVARCHAR( 15)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cRoute         NVARCHAR( 20)
   DECLARE @cOrderRefNo    NVARCHAR( 18)
   DECLARE @cConsigneekey  NVARCHAR( 15)
   DECLARE @cLot           NVARCHAR( 10)
   DECLARE @cLabelNo       NVARCHAR( 20)
   DECLARE @nCartonNo      INT
   DECLARE @cLabelLine     NVARCHAR( 5)
   DECLARE @cShipLabel     NVARCHAR( 10)
   DECLARE @cDelNotes      NVARCHAR( 10)
   DECLARE @cPaperPrinter  NVARCHAR( 10)
   DECLARE @cLabelPrinter  NVARCHAR( 10)
   DECLARE @cPalletID      NVARCHAR( 20)
   DECLARE @cCartonCount   NVARCHAR( 5)
   DECLARE @cPackByPickDetailDropID NVARCHAR( 1)
   DECLARE @cPackByPickDetailID     NVARCHAR( 1)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @nStep          INT
   DECLARE @nInputKey      INT
   DECLARE @nQty           INT
   DECLARE @nSum_Picked    INT
   DECLARE @nSum_Packed    INT
   DECLARE @nSum_PickDQty  INT
   DECLARE @nSum_PackDQty  INT
   DECLARE @cGenLabelNo_SP NVARCHAR( 20)
   DECLARE @cUpdatePickDetail NVARCHAR( 1)
   DECLARE @cGenPalletDetail  NVARCHAR( 1)
   DECLARE @cGenPackInfo   NVARCHAR( 1)
   DECLARE @cCartonType    NVARCHAR( 10)
   DECLARE @cPackConfirm   NVARCHAR(1)
   DECLARE @nPickQty       INT
   DECLARE @nCartonWeight  FLOAT
   DECLARE @nCartonCube    FLOAT
   DECLARE @tGenLabelNo    VARIABLETABLE
   DECLARE @cITF           NVARCHAR( 60)
   DECLARE @cTrackingNo    NVARCHAR( 20)
   DECLARE @cExternOrderKey   NVARCHAR( 20)
   DECLARE @cPrintShipLbl  NVARCHAR( 60)

   SET @nErrNo = 0
   SET @cPrintPackList = 'N'
   SET @cPackConfirm = ''

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerKey) 
   IF @cGenLabelNo_SP = '0'
      SET @cGenLabelNo_SP = ''  

   SET @cCartonType = rdt.RDTGetConfig( @nFunc, 'CartonType', @cStorerKey) 
   IF @cCartonType = '0'
      SET @cCartonType = ''  

   SET @cUpdatePickDetail = rdt.RDTGetConfig( @nFunc, 'UpdatePickDetail', @cStorerKey)
   SET @cGenPackInfo = rdt.RDTGetConfig( @nFunc, 'GenPackInfo', @cStorerKey)
   SET @cGenPalletDetail = rdt.RDTGetConfig( @nFunc, 'GenPalletDetail', @cStorerKey)

   -- Variable mapping
   SELECT @cPalletID = Value FROM @tPackCfm WHERE Variable = '@cPltValue'
   SELECT @cCartonCount = Value FROM @tPackCfm WHERE Variable = '@cCartonCount'
   SELECT @cPackByPickDetailDropID = Value FROM @tPackCfm WHERE Variable = '@cPackByPickDetailDropID'
   SELECT @cPackByPickDetailID = Value FROM @tPackCfm WHERE Variable = '@cPackByPickDetailID'

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_835ExtPack01

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   SELECT @nSum_PickDQty = ISNULL( SUM( Qty), 0)
   FROM dbo.PickDetail WITH (NOLOCK)     
   WHERE ( ( @cPackByPickDetailDropID = '1' AND DropID = @cPalletID) OR 
            ( @cPackByPickDetailID = '1' AND ID = @cPalletID))
   AND   Status <> '4'
   AND   StorerKey  = @cStorerKey

   SELECT @nSum_PackDQty = ISNULL( SUM( Qty), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
   WHERE PD.StorerKey = @cStorerKey
   AND   PD.DropID = @cPalletID
   AND   PH.OrderKey IN (
         SELECT DISTINCT OrderKey
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE ( ( @cPackByPickDetailDropID = '1' AND DropID = @cPalletID) OR 
                  ( @cPackByPickDetailID = '1' AND ID = @cPalletID))
         AND   PD.StorerKey  = @cStorerKey)

   IF ( @nSum_PickDQty < @nSum_PackDQty) AND @nSum_PackDQty > 0
   BEGIN
      SET @nErrNo = 140551
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Fully Packed'
      GOTO RollBackTran
   END

   SELECT @nPickQty = ISNULL( SUM( QTY  ), 0)
   FROM dbo.PickDetail PD (NOLOCK)     
   WHERE ( ( @cPackByPickDetailDropID = '1' AND DropID = @cPalletID) OR 
            ( @cPackByPickDetailID = '1' AND ID = @cPalletID))
   AND   PD.Status < @cPickConfirmStatus
   AND   PD.Status <> '4'
   AND   PD.QTY > 0
   AND   PD.StorerKey  = @cStorerKey

   DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PD.PickDetailKey, SKU, QTY, DropID
   FROM dbo.PickDetail PD (NOLOCK)     
   WHERE ( ( @cPackByPickDetailDropID = '1' AND DropID = @cPalletID) OR 
            ( @cPackByPickDetailID = '1' AND ID = @cPalletID))
   AND   PD.Status < @cPickConfirmStatus
   AND   PD.Status <> '4'
   AND   PD.QTY > 0
   AND   PD.StorerKey  = @cStorerKey
   ORDER BY PD.PickDetailKey

   OPEN curPD
   FETCH NEXT FROM curPD INTO @cPickDetailKey, @cSKU, @nQTY_PD, @cDropID
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Get PickDetail info  
      DECLARE @cPD_LoadKey      NVARCHAR( 10)  
      DECLARE @cPD_OrderKey     NVARCHAR( 10)  
      DECLARE @cOrderLineNumber NVARCHAR( 5)  
      SELECT 
         @cPD_Loadkey = O.LoadKey, 
         @cPD_OrderKey = OD.OrderKey, 
         @cOrderLineNumber = OD.OrderLineNumber,
         @cLot = PD.LOT
      FROM dbo.PickDetail PD WITH (NOLOCK) 
      INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)
      INNER JOIN dbo.Orders O WITH (NOLOCK) ON (OD.OrderKey = O.OrderKey)
      WHERE PD.PickDetailkey = @cPickDetailKey  

      -- Get PickSlipNo  
      DECLARE @cPickSlipNo NVARCHAR(10)  
      SET @cPickSlipNo = ''  
      SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cPD_OrderKey  

      IF @cPickSlipNo = '' AND ISNULL( @cPD_Loadkey, '') <> ''
         SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cPD_Loadkey  

      IF @cPickSlipNo = '' 
      BEGIN
         SET @nErrNo = 140573
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Pickslip'
         GOTO RollBackTran
      END 

      IF @cUpdatePickDetail = '1'
      BEGIN
         -- Exact match
         IF @nQTY_PD = @nPickQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               Status = @cPickConfirmStatus, 
               EditDate = GETDATE()
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 140556
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance -- SOS# 176144
         END
         -- PickDetail have less
         ELSE IF @nQTY_PD < @nPickQty
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               Status = @cPickConfirmStatus, 
               EditDate = GETDATE()
            WHERE PickDetailKey = @cPickDetailKey

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 140557
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
               GOTO RollBackTran
            END

            SET @nPickQty = @nPickQty - @nQTY_PD -- Reduce balance
         END
         -- PickDetail have more, need to split
         ELSE IF @nQTY_PD > @nPickQty
         BEGIN
            IF @nPickQty > 0 -- SOS# 176144
            BEGIN
               -- If Status = '5' (full pick), split line if neccessary
               -- If Status = '4' (short pick), no need to split line if already last RPL line to update,
               -- just have to update the pickdetail.qty = short pick qty
               -- Get new PickDetailkey
               DECLARE @cNewPickDetailKey NVARCHAR( 10)
               EXECUTE dbo.nspg_GetKey
                  @KeyName       = 'PICKDETAILKEY',
                  @fieldlength   = 10 ,
                  @keystring     = @cNewPickDetailKey OUTPUT,
                  @b_Success     = @bSuccess          OUTPUT,
                  @n_err         = @nErrNo            OUTPUT,
                  @c_errmsg      = @cErrMsg           OUTPUT

               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 140558
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GetDetKeyFail'
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
                  '0', DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                  DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
                  @nQTY_PD - @nPickQty, -- QTY
                  NULL, --TrafficCop,
                  '1'  --OptimizeCop
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 140559
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PDtl Fail'
                  GOTO RollBackTran
               END

               -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  QTY = @nPickQty,
                  Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 140560
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  Status = @cPickConfirmStatus, 
                  EditDate = GETDATE()
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 140561
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               SET @nPickQty = 0 -- Reduce balance
            END
         END
      END

      -- Insert PickingInfo
      IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickslipNo)
      BEGIN
         -- Scan in pickslip
         EXEC dbo.isp_ScanInPickslip
            @c_PickSlipNo  = @cPickSlipNo,
            @c_PickerID    = @cUserName,
            @n_err         = @nErrNo      OUTPUT,
            @c_errmsg      = @cErrMsg     OUTPUT

         IF @nErrNo <> 0
         BEGIN
            SET @nErrNo = 140574
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Fail scan-in
            GOTO RollBackTran
         END
      END

      SELECT @cZone = Zone,
               @cPD_OrderKey = OrderKey,
               @cPD_LoadKey = ExternOrderKey
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo

      SELECT @cRoute = [Route], 
             @cOrderRefNo = SUBSTRING(ExternOrderKey, 1, 18), 
             @cConsigneekey = ConsigneeKey,           
             --@cTrackingNo = UserDefine04,
             @cTrackingNo = TrackingNo,      -- (james02)
             @cExternOrderKey = ExternOrderKey
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE OrderKey = @cPD_OrderKey

      IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
      BEGIN
         INSERT INTO dbo.PackHeader
         (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
         VALUES
         (@cRoute, @cPD_OrderKey, @cOrderRefNo, @cPD_LoadKey, @cConsigneekey, @cStorerKey, @cPickSlipNo)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 140552
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPHdrFail'
            GOTO RollBackTran
         END 
      END

      -- Same DropID + PickSlipNo will group SKU into a carton. 1 carton could be multi sku
      IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
         AND   DropID = @cDropID)
      BEGIN
         SET @nCartonNo = 0

         SET @cLabelNo = ''

         IF @cGenLabelNo_SP <> '' AND 
            EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenLabelNo_SP AND type = 'P')
         BEGIN
            insert into TraceInfo (TraceName, TimeIn, col1, Col2) values ('835_1', getdate(), @cLabelNo, @cDropID)
            INSERT INTO @tGenLabelNo (Variable, Value) VALUES 
            ('@cPickSlipNo',     @cPickSlipNo),
            ('@cDropID',         @cDropID)

            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenLabelNo_SP) +     
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' + 
               ' @tGenLabelNo, @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

               SET @cSQLParam =    
                  '@nMobile                   INT,           ' +
                  '@nFunc                     INT,           ' +
                  '@cLangCode                 NVARCHAR( 3),  ' +
                  '@nStep                     INT,           ' +
                  '@nInputKey                 INT,           ' +
                  '@cFacility                 NVARCHAR( 5),  ' +
                  '@cStorerkey                NVARCHAR( 15), ' +
                  '@tGenLabelNo               VARIABLETABLE READONLY, ' +
                  '@cLabelNo                  NVARCHAR( 20) OUTPUT, ' +
                  '@nCartonNo                 INT           OUTPUT, ' +
                  '@nErrNo                    INT           OUTPUT, ' +
                  '@cErrMsg                   NVARCHAR( 20) OUTPUT  ' 
               
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                  @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
                  @tGenLabelNo, @cLabelNo OUTPUT, @nCartonNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 

               IF @nErrNo <> 0
                  GOTO RollBackTran
               insert into TraceInfo (TraceName, TimeIn, col1, Col2) values ('835_2', getdate(), @cLabelNo, @cDropID)
         END
         ELSE
         BEGIN
            EXECUTE dbo.nsp_GenLabelNo
               '',
               @cStorerKey,
               @c_labelno     = @cLabelNo  OUTPUT,
               @n_cartonno    = @nCartonNo OUTPUT,
               @c_button      = '',
               @b_success     = @bSuccess  OUTPUT,
               @n_err         = @n_err     OUTPUT,
               @c_errmsg      = @c_errmsg  OUTPUT

            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 140553
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenLabelFail'
               GOTO RollBackTran
            END
         END

         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)
         VALUES
            (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nQTY_PD,
            @cPalletID, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID)

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 140554
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
            GOTO RollBackTran
         END 

         SELECT TOP 1 @nCartonNo = CartonNo
         FROM dbo.PackDetail WITH (NOLOCK) 
         WHERE PickSlipNo = @cPickSlipNo
         AND   LabelNo = @cLabelNo
         ORDER BY 1 
      END
      ELSE  -- DropID not exists
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
                        WHERE PickSlipNo = @cPickSlipNo
                        AND   DropID = @cDropID
                        AND   SKU = @cSKU)
         BEGIN
            SET @nCartonNo = 0

            SET @cLabelNo = ''

            SELECT @nCartonNo = CartonNo, 
                   @cLabelNo = LabelNo 
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE Pickslipno = @cPickSlipNo
               AND StorerKey = @cStorerKey
               AND DropID = @cDropID

            SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE Pickslipno = @cPickSlipNo
               AND CartonNo = @nCartonNo
               AND DropID = @cDropID

            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)
            VALUES
               (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSku, @nQTY_PD,
               @cPalletID, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cDropID)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 140572
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
               GOTO RollBackTran
            END 
         END
         ELSE
         BEGIN
            SELECT TOP 1
                     @nCartonNo = CartonNo,
                     @cLabelNo = LabelNo,
                     @cLabelLine = @cLabelLine
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo
            AND   DropID = @cDropID
            AND   SKU = @cSKU
            ORDER BY 1

            UPDATE dbo.PackDetail WITH (ROWLOCK) SET
               QTY = QTY + @nQTY_PD,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nCartonNo
            AND   LabelNo = @cLabelNo
            AND   LabelLine = @cLabelLine

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 140555
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
               GOTO RollBackTran
            END
         END
      END   -- DropID exists and SKU exists (update qty only)

      IF @cGenPackInfo = '1'
      BEGIN
         SELECT @nQTY = ISNULL( SUM( PD.Qty), 0)
         FROM dbo.PackDetail PD WITH (NOLOCK)
         JOIN SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         WHERE PD.PickSlipNo = @cPickSlipNo
         AND PD.CartonNo = @nCartonNo

         DECLARE @cUDF01   NVARCHAR( 15)
         DECLARE @cUDF02   NVARCHAR( 15)
         SELECT @nCartonWeight = ISNULL( SUM( CAST( Userdefined02 AS float)), 0)
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UCCNo = @cDropID

         SELECT @cUDF01 = Userdefined01 -- carton type
         FROM dbo.UCC WITH (NOLOCK)
         WHERE @cStorerKey = @cStorerKey
         AND   UCCNo = @cDropID
         
         IF ISNULL( @cUDF01, '') = ''
         BEGIN
            SET @cCartonType = 'CTN'

            SELECT @nCartonCube = ISNULL( SUM( PD.QTY * SKU.STDCube), 0)
            FROM dbo.PackDetail PD WITH (NOLOCK)
            JOIN SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
            WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.CartonNo = @nCartonNo
         END
         ELSE
         BEGIN
            SET @cCartonType = @cUDF01

            SELECT @nCartonCube = Cube 
            FROM dbo.Cartonization CZ WITH (NOLOCK) 
            JOIN dbo.Storer ST WITH (NOLOCK) ON ( CZ.cartonizationgroup = ST.CartonGroup)
            WHERE ST.StorerKey = @cStorerKey
            AND   ST.Type = '1'
            AND   CZ.CartonType = @cCartonType
         END

         IF NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
                           WHERE PickSlipNo = @cPickSlipNo
                           AND   CartonNo = @nCartonNo)
         BEGIN
            -- Insert PackInfo
            INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, Weight, Cube, Qty, CartonType) VALUES
            (@cPickSlipNo, @nCartonNo, @nCartonWeight, @nCartonCube, @nQTY, @cCartonType)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 140562
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PInfo Fail'
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            -- Update PackInfo
            UPDATE dbo.PackInfo WITH (ROWLOCK) SET
               CartonType = @cCartonType,
               Weight = @nCartonWeight,
               Cube = @nCartonCube, 
               Qty = /*Qty +*/ @nQTY
            WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 140563
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PInfo Fail'
               GOTO RollBackTran
            END
         END
      END

      IF @cGenPalletDetail = '1'
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK) 
                           WHERE PalletKey = @cPalletID)
         BEGIN
            INSERT INTO dbo.Pallet (PalletKey, StorerKey, Status) VALUES 
            (@cPalletID, @cStorerKey, '0')

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 140564
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPltInfoFail'
               GOTO RollBackTran
            END

            INSERT INTO dbo.PalletDetail (PalletKey, PalletLineNumber, CaseId, Sku, Qty, StorerKey, Status) VALUES 
            (@cPalletID, '0', @cLabelNo, @cSku, @nQTY_PD, @cStorerKey, '0')

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 140565
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPldInfoFail'
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK) 
                  WHERE PalletKey = @cPalletID
                  AND   StorerKey = @cStorerKey
                  AND   CaseID = @cLabelNo
                  AND   SKU = @cSKU)
            BEGIN
               INSERT INTO dbo.PalletDetail (PalletKey, PalletLineNumber, CaseId, Sku, Qty, StorerKey, Status) VALUES 
               (@cPalletID, '0', @cLabelNo, @cSku, @nQTY_PD, @cStorerKey, '0')

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 140566
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPldInfoFail'
                  GOTO RollBackTran
               END
            END
         END
      END

      --insert into TraceInfo (tracename, TimeIn, col1, Col2, Col3, Col4, Col5) values ('835', getdate(), @cPickDetailKey, @cSKU, @nQTY_PD, @cDropID, @cLabelNo)
      FETCH NEXT FROM curPD INTO @cPickDetailKey, @cSKU, @nQTY_PD, @cDropID
   END
   CLOSE curPD
   DEALLOCATE curPD

   SET @nSum_Packed = 0
   SELECT @nSum_Packed = ISNULL( SUM( Qty), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK) 
   WHERE PickSlipNo = @cPickSlipNo

   SET @nSum_Picked = 0

   -- conso picklist   
   If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' 
   BEGIN    
      -- Check outstanding PickDetail
      IF EXISTS( SELECT TOP 1 1
                  FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                  WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND   PD.Status < '5'
                  AND    PD.QTY > 0
                  AND   (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
         SET @cPackConfirm = 'N'
      ELSE
         SET @cPackConfirm = 'Y'

      -- Check fully packed
      IF @cPackConfirm = 'Y'
      BEGIN
         SELECT @nSum_Picked = SUM( QTY) 
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
         WHERE RKL.PickSlipNo = @cPickSlipNo
         
         IF @nSum_Picked <> @nSum_Packed
            SET @cPackConfirm = 'N'
      END
   END
   -- Discrete PickSlip
   ELSE IF ISNULL(@cPD_OrderKey, '') <> '' 
   BEGIN
      -- Check outstanding PickDetail
      IF EXISTS( SELECT TOP 1 1
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  WHERE PD.OrderKey = @cPD_OrderKey
                  AND   PD.Status < '5'
                  AND   PD.QTY > 0
                  AND  (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
         SET @cPackConfirm = 'N'
      ELSE
         SET @cPackConfirm = 'Y'
      
      -- Check fully packed
      IF @cPackConfirm = 'Y'
      BEGIN
         SELECT @nSum_Picked = SUM( PD.QTY) 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         WHERE PD.OrderKey = @cPD_OrderKey
         
         IF @nSum_Picked <> @nSum_Packed
            SET @cPackConfirm = 'N'
      END
   END
   ELSE
   BEGIN
      -- Check outstanding PickDetail
      IF EXISTS( SELECT TOP 1 1 
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
                  WHERE LPD.LoadKey = @cLoadKey
                  AND   PD.Status < '5'
                  AND   PD.QTY > 0
                  AND  (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
         SET @cPackConfirm = 'N'
      ELSE
         SET @cPackConfirm = 'Y'
      
      -- Check fully packed
      IF @cPackConfirm = 'Y'
      BEGIN
         SELECT @nSum_Picked = SUM( PD.QTY) 
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
         WHERE LPD.LoadKey = @cLoadKey
         
         IF @nSum_Picked <> @nSum_Packed
            SET @cPackConfirm = 'N'
      END
   END

   -- Pack confirm
   IF @cPackConfirm = 'Y'
   BEGIN
      SET @cPrintPackList = 'Y'

      SET @cPrintShipLbl = ''
      SET @cITF = ''
      SELECT @cPrintShipLbl = UDF01, 
             @cITF = UDF04
      FROM dbo.CODELKUP WITH (NOLOCK) 
      WHERE ListName = 'BRCOURTYPE'
      AND   Code = @cShipperKey
      AND   StorerKey = @cStorerKey

      IF @cPrintShipLbl = 'N'
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.CartonTrack WITH (NOLOCK) WHERE TrackingNo = @cLabelNo AND CarrierName = @cTrackingNo)
         BEGIN
            INSERT INTO dbo.CartonTrack ( TrackingNo, CarrierName, KeyName, Labelno, Carrierref1, Carrierref2) VALUES
            (@cLabelNo, @cTrackingNo, @cStorerKey, @cLabelNo, @cPD_OrderKey, @cExternOrderKey)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 140567
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins CtnTrk Fail
               GOTO RollBackTran
            END
         END
      END

      UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
         [Status] = '9'
      WHERE PickSlipNo = @cPickSlipNo
      AND   [Status] < '9'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 140568
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail
         GOTO RollBackTran
      END

      EXEC isp_ScanOutPickSlip
         @c_PickSlipNo = @cPickSlipNo,
         @n_err = @nErrNo OUTPUT,
         @c_errmsg = @cErrMsg OUTPUT

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 140569
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scan Out Fail
         GOTO RollBackTran
      END


      IF @cITF = 'ITF'
      BEGIN
         UPDATE dbo.Orders WITH (ROWLOCK) SET
            SOStatus = 'PENDGET'
         WHERE OrderKey = @cPD_OrderKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 140570
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd SOStat Fail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         UPDATE dbo.Orders WITH (ROWLOCK) SET
            SOStatus = '5'
         WHERE OrderKey = @cPD_OrderKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 140571
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd SOStat Fail
            GOTO RollBackTran
         END
      END
   END
      
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_835ExtPack01

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_835ExtPack01

   IF @nErrNo <> 0
      GOTO Fail

   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
   IF @cShipLabel = '0'
      SET @cShipLabel = ''

   IF @cShipLabel <> ''
   BEGIN
      DECLARE @tSHIPPLABEL AS VariableTable
      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)
      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cDropID',      @cDropID)
      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cShipperKey',  @cShipperKey)
      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nFromCartonNo',  @nCartonNo)
      INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nToCartonNo',    @nCartonNo)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
         @cShipLabel, -- Report type
         @tSHIPPLABEL, -- Report params
         'rdt_835ExtPack01', 
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT 
   END

   

   Fail:
END

GO