SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_835PackConfirm01                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pick and pack confirm                                       */
/*                                                                      */
/* Called from: rdtfnc_Pallet_Pack                                      */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 26-04-2019  1.0  James       WMS8709.Created                         */
/* 19-07-2019  1.1  James       Add @cPrintPackList variable (james01)  */
/************************************************************************/

CREATE PROC [RDT].[rdt_835PackConfirm01] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5), 
   @tPackCfm      VariableTable READONLY, 
   @cPrintPackList  NVARCHAR( 1) OUTPUT,
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
   DECLARE @cPH_LoadKey    NVARCHAR( 10)
   DECLARE @cPH_OrderKey   NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @nQTY_PD        INT
   DECLARE @bSuccess       INT
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
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @nStep          INT
   DECLARE @nInputKey      INT
   DECLARE @nQty           INT
   DECLARE @nSum_PickDQty  INT
   DECLARE @nSum_PackDQty  INT
   DECLARE @cGenLabelNo_SP NVARCHAR( 20)
   DECLARE @nPickQty       INT
   DECLARE @cErrMsg1       NVARCHAR( 20)
   DECLARE @cErrMsg2       NVARCHAR( 20)
   DECLARE @cErrMsg3       NVARCHAR( 20)
   DECLARE @cOrderKey      NVARCHAR( 10)

   SET @nErrNo = 0

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @cGenLabelNo_SP = rdt.RDTGetConfig( @nFunc, 'GenLabelNo_SP', @cStorerKey) 
   IF @cGenLabelNo_SP = '0'
      SET @cGenLabelNo_SP = ''  

   -- Variable mapping
   SELECT @cPalletID = Value FROM @tPackCfm WHERE Variable = '@cPalletID'

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_835PackConfirm01

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'


      SELECT @nSum_PickDQty = ISNULL( SUM( Qty), 0)
      FROM dbo.PickDetail WITH (NOLOCK)     
      WHERE ID = @cPalletID
      AND   Status = @cPickConfirmStatus
      AND   Status <> '4'
      AND   StorerKey  = @cStorerKey

      SELECT @nSum_PackDQty = ISNULL( SUM( Qty), 0)
      FROM dbo.PackDetail PD WITH (NOLOCK)
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
      WHERE PD.StorerKey = @cStorerKey
      AND   PD.DropID = @cPalletID
      AND   PH.OrderKey IN (
            SELECT DISTINCT OrderKey
            FROM dbo.PickDetail PickD WITH (NOLOCK) 
            WHERE PickD.ID = @cPalletID
            AND   PickD.StorerKey  = @cStorerKey)

      IF @nSum_PickDQty <= @nSum_PackDQty AND @nSum_PackDQty > 0
      BEGIN
         SET @nErrNo = 138051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Fully Packed'
         GOTO RollBackTran
      END

      SELECT @nPickQty = ISNULL( SUM( QTY  ), 0)
      FROM dbo.PickDetail PD (NOLOCK)     
      WHERE PD.ID = @cPalletID
      AND   PD.Status < @cPickConfirmStatus
      AND   PD.Status <> '4'
      AND   PD.QTY > 0
      AND   PD.StorerKey  = @cStorerKey

      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.PickDetailKey, SKU, QTY  
      FROM dbo.PickDetail PD (NOLOCK)     
      WHERE ID = @cPalletID
      AND   PD.Status < @cPickConfirmStatus
      AND   PD.Status <> '4'
      AND   PD.QTY > 0
      AND   PD.StorerKey  = @cStorerKey
      ORDER BY PD.PickDetailKey

      OPEN curPD
      FETCH NEXT FROM curPD INTO @cPickDetailKey, @cSKU, @nQTY_PD
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
         IF @cPickSlipNo = ''  
            SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cPD_Loadkey  

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
               SET @nErrNo = 138652
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
               SET @nErrNo = 138653
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
                  SET @nErrNo = 138654
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
                  SET @nErrNo = 138655
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
                  SET @nErrNo = 138656
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  Status = @cPickConfirmStatus, 
                  EditDate = GETDATE()
               WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 138657
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
                  GOTO RollBackTran
               END

               SET @nPickQty = 0 -- Reduce balance
            END
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND PickSlipNo = @cPickSlipNo)
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE Pickslipno = @cPickSlipNo)
            BEGIN
               SELECT @cRoute = [Route], 
                      @cOrderRefNo = SUBSTRING(ExternOrderKey, 1, 18), 
                      @cConsigneekey = ConsigneeKey 
               FROM dbo.Orders WITH (NOLOCK) 
               WHERE OrderKey = @cPD_OrderKey
               AND   StorerKey = @cStorerKey
   
               INSERT INTO dbo.PackHeader
               (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
               VALUES
               (@cRoute, @cPD_OrderKey, @cOrderRefNo, @cLoadKey, @cConsigneekey, @cStorerKey, @cPickSlipNo)

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 138658
                  SET @cErrMsg = rdt.rdtgetmessage( 66040, @cLangCode, 'DSP') --'InsPHdrFail'
                  GOTO RollBackTran
               END 
            END
         END

         IF NOT EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo
            AND   DropID = @cPalletID
            AND   SKU = @cSKU)
         BEGIN
            SET @nCartonNo = 0

            SET @cLabelNo = ''

            IF @cGenLabelNo_SP <> '' AND 
               EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cGenLabelNo_SP AND type = 'P')
            BEGIN
               SET @nErrNo = 0
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cGenLabelNo_SP) +     
                  ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' + 
                  ' @tExtValidate, @nErrNo OUTPUT, @cErrMsg OUTPUT '    

                  SET @cSQLParam =    
                     '@nMobile                   INT,           ' +
                     '@nFunc                     INT,           ' +
                     '@cLangCode                 NVARCHAR( 3),  ' +
                     '@nStep                     INT,           ' +
                     '@nInputKey                 INT,           ' +
                     '@cFacility                 NVARCHAR( 5),  ' +
                     '@cStorerkey                NVARCHAR( 15), ' +
                     '@tExtValidate              VariableTable READONLY, ' +
                     '@nErrNo                    INT           OUTPUT, ' +
                     '@cErrMsg                   NVARCHAR( 20) OUTPUT  ' 
               
                  EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
                     @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, 
                     @tPackCfm, @nErrNo OUTPUT, @cErrMsg OUTPUT 

                  IF @nErrNo <> 0
                     GOTO RollBackTran
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
                  @n_err         = @nErrNo    OUTPUT,
                  @c_errmsg      = @cErrMsg   OUTPUT

               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 138659
                  SET @cErrMsg = rdt.rdtgetmessage( 66038, @cLangCode, 'DSP') --'GenLabelFail'
                  GOTO RollBackTran
               END
            END

            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, Refno, AddWho, AddDate, EditWho, EditDate, DropID)
            VALUES
               (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSku, @nQTY_PD,
               '', 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cPalletID)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 138660
               SET @cErrMsg = rdt.rdtgetmessage( 66035, @cLangCode, 'DSP') --'InsPackDtlFail'
               GOTO RollBackTran
            END 
         END -- DropID not exists
         ELSE
         BEGIN
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET
               QTY = QTY + @nQTY_PD,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE PickSlipNo = @cPickSlipNo
            AND   DropID = @cPalletID
            AND   SKU = @cSKU

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 138661
               SET @cErrMsg = rdt.rdtgetmessage( 66037, @cLangCode, 'DSP') --'UpdPackDtlFail'
               GOTO RollBackTran
            END
         END   -- DropID exists and SKU exists (update qty only)
            
         FETCH NEXT FROM curPD INTO @cPickDetailKey, @cSKU, @nQTY_PD
      END
      CLOSE curPD
      DEALLOCATE curPD



      GOTO Quit

      RollBackTran:
         ROLLBACK TRAN rdt_835PackConfirm01

      Quit:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN rdt_835PackConfirm01

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
            'rdt_835PackConfirm01', 
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT 
      END

      SELECT TOP 1 @cOrderKey = OrderKey
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE ID = @cPalletID
      AND   StorerKey  = @cStorerKey
      ORDER BY 1

      -- Orders no more outstanding pallet to scan, prompt msg
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                      WHERE ID <> ''
                      AND   Status < @cPickConfirmStatus
                      AND   Status <> '4'
                      AND   QTY > 0
                      AND   OrderKey = @cOrderKey
                      AND   StorerKey  = @cStorerKey)
      BEGIN
         SET @cErrMsg1 = rdt.rdtgetmessage( 138662, @cLangCode, 'DSP')
         SET @cErrMsg2 = rdt.rdtgetmessage( 138663, @cLangCode, 'DSP')
            
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
              @cErrMsg1, @cErrMsg2

         SET @nErrNo = 0
         SET @cErrMsg = ''
      END
   

   Fail:
END

GO