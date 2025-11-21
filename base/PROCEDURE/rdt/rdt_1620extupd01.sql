SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1620ExtUpd01                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Stamp PackDetail.LabelNo = PickDetail.CaseID & DropID       */
/*          Print label after each orders pick confirm                  */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author      Purposes                               */
/* 2023-07-03   1.0  James       WMS-22899. Created                     */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1620ExtUpd01] (
   @nMobile                   INT,
   @nFunc                     INT, 
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT, 
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15),
   @cWaveKey                  NVARCHAR( 10),
   @cLoadKey                  NVARCHAR( 10),
   @cOrderKey                 NVARCHAR( 10),
   @cLoc                      NVARCHAR( 10),
   @cDropID                   NVARCHAR( 20),
   @cSKU                      NVARCHAR( 20),
   @nQty                      INT,
   @nErrNo                    INT               OUTPUT,
   @cErrMsg                   NVARCHAR( 20)     OUTPUT   -- screen limitation, 20 NVARCHAR max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   DECLARE @nPickQty    INT = 0
   DECLARE @nPackQty    INT = 0
   DECLARE @nPack_QTY   INT = 0
   DECLARE @nPD_QTY     INT = 0
   DECLARE @curPACKD    CURSOR
   DECLARE @curPICKD    CURSOR
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cLabelPrinter  NVARCHAR( 10)
   DECLARE @cShipLabel     NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cLabelNo       NVARCHAR( 20)
   DECLARE @tShipLabel     VARIABLETABLE
   DECLARE @cPack_LblNo    NVARCHAR( 20)
   DECLARE @cPack_SKU      NVARCHAR( 20)
   DECLARE @cPickDetailKey NVARCHAR( 10) 
   DECLARE @b_success      INT
   DECLARE @n_err          INT
   DECLARE @c_errmsg       NVARCHAR( 20)
   
   SELECT
      @cFacility = Facility, 
      @cLabelPrinter = Printer
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep = 8
   BEGIN
      IF @nInputKey = 1
      BEGIN
      	IF NOT EXISTS ( SELECT 1 
      	            FROM dbo.ORDERS WITH (NOLOCK)
      	            WHERE OrderKey = @cOrderKey
      	            AND   ECOM_SINGLE_Flag = 'S')
            GOTO Quit
         
         SELECT @nPickQty = ISNULL( SUM( Qty), 0)
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         AND   [Status] = '5'
         
         SELECT @nPackQty = ISNULL( SUM( PD.Qty), 0)
         FROM dbo.PackDetail PD WITH (NOLOCK)
         JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
         WHERE PH.StorerKey = @cStorerkey
         AND   PH.OrderKey = @cOrderKey
         
         IF @nPickQty = @nPackQty
         BEGIN
         	SET @nTranCount = @@TRANCOUNT    

            BEGIN TRAN    
            SAVE TRAN rdt_1620ExtUpd01    

            SELECT @cPickSlipNo = PickHeaderKey FROM dbo.PickHeader WITH (NOLOCK) 
            WHERE OrderKey = @cOrderKey

            -- If still blank picklipno then look for conso pick   
            IF ISNULL(@cPickSlipNo, '') = ''
               SELECT TOP 1 @cPickSlipNo = PickHeaderKey 
               FROM dbo.PickHeader PIH WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PIH.ExternOrderKey = LPD.LoadKey)
               JOIN dbo.Orders O WITH (NOLOCK) ON (LPD.OrderKey = O.OrderKey)
               WHERE O.OrderKey = @cOrderKey
               AND   O.StorerKey = @cStorerKey
               ORDER BY 1

            SET @curPACKD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LabelNo, SKU, SUM( Qty)
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerkey
            AND   PickSlipNo = @cPickSlipNo
            GROUP BY LabelNo, SKU
            ORDER BY LabelNo, SKU
            OPEN @curPACKD
            FETCH NEXT FROM @curPACKD INTO @cPack_LblNo, @cPack_SKU, @nPack_QTY
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Stamp pickdetail.caseid (to know which case in which pickdetail line)
               SET @curPICKD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey, QTY
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE OrderKey  = @cOrderKey
               AND   StorerKey  = @cStorerKey
               AND   SKU = @cPack_SKU
               AND   Status < '9'
               AND   STATUS <> '4'
               AND   ISNULL( CaseID, '') = ''
               ORDER BY PickDetailKey
               OPEN @curPICKD
               FETCH NEXT FROM @curPICKD INTO @cPickDetailKey, @nPD_QTY
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  -- Exact match
                  IF @nPD_QTY = @nPack_QTY
                  BEGIN
                     -- Confirm PickDetail
                     UPDATE dbo.PickDetail SET
                        CaseID = @cPack_LblNo, 
                        DropID = @cPack_LblNo,
                        TrafficCop = NULL,
                        EditWho = SUSER_SNAME(),
                        EditDate = GETDATE()
                     WHERE PickDetailKey = @cPickDetailKey

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 205551
                        SET @cErrMsg = rdt.rdtgetmessage( 66027, @cLangCode, 'DSP') --'Upd Case Fail'
                        GOTO RollBackTran
                     END

                     SET @nPack_QTY = @nPack_QTY - @nPD_QTY -- Reduce balance 
                  END
                  -- PickDetail have less
                  ELSE IF @nPD_QTY < @nPack_QTY
                  BEGIN
                     -- Confirm PickDetail
                     UPDATE dbo.PickDetail SET
                        CaseID = @cPack_LblNo, 
                        DropID = @cPack_LblNo,
                        TrafficCop = NULL,
                        EditWho = SUSER_SNAME(),
                        EditDate = GETDATE()
                     WHERE PickDetailKey = @cPickDetailKey

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 205552
                        SET @cErrMsg = rdt.rdtgetmessage( 66028, @cLangCode, 'DSP') --'Upd Case Fail'
                        GOTO RollBackTran
                     END

                     SET @nPack_QTY = @nPack_QTY - @nPD_QTY -- Reduce balance
                  END
                  -- PickDetail have more, need to split
                  ELSE IF @nPD_QTY > @nQty
                  BEGIN
                     -- Get new PickDetailkey
                     DECLARE @cNewPickDetailKey NVARCHAR( 10)
                     EXECUTE dbo.nspg_GetKey
                        'PICKDETAILKEY',
                        10 ,
                        @cNewPickDetailKey OUTPUT,
                        @b_success         OUTPUT,
                        @n_err             OUTPUT,
                        @c_errmsg          OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SET @nErrNo = 205553
                        SET @cErrMsg = rdt.rdtgetmessage( 66029, @cLangCode, 'DSP') -- 'Get PDKey Fail'
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
                        Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
                        DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
                        @nPD_QTY - @nPack_QTY, 
                        NULL, --TrafficCop,
                        '1'  --OptimizeCop
                     FROM dbo.PickDetail WITH (NOLOCK)
                     WHERE PickDetailKey = @cPickDetailKey

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 205554
                        SET @cErrMsg = rdt.rdtgetmessage( 66030, @cLangCode, 'DSP') --'Ins PDtl Fail'
                        GOTO RollBackTran
                     END

                     UPDATE dbo.PickDetail SET
                        Qty = Qty - @nPack_QTY,   -- deduct original qty
                        CaseID = @cPack_LblNo, 
                        DropID = @cPack_LblNo,
                        TrafficCop = NULL,
                        EditWho = SUSER_SNAME(),
                        EditDate = GETDATE()
                     WHERE PickDetailKey = @cPickDetailKey

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 205555
                        SET @cErrMsg = rdt.rdtgetmessage( 66032, @cLangCode, 'DSP') --'Upd Case Fail'
                        GOTO RollBackTran
                     END

                     SET @nPack_QTY = 0 -- Reduce balance  
                  END

                  IF @nPack_QTY = 0 
                     BREAK -- Exit

                  FETCH NEXT FROM @curPICKD INTO @cPickDetailKey, @nPD_QTY
               END
               CLOSE @curPICKD
               DEALLOCATE @curPICKD

               FETCH NEXT FROM @curPACKD INTO @cPack_LblNo, @cPack_SKU, @nPack_QTY         
            END

            GOTO CfmQuit
   
            RollBackTran:  
                  ROLLBACK TRAN rdt_1620ExtUpd01  
            CfmQuit:  
               WHILE @@TRANCOUNT > @nTranCount  
                  COMMIT TRAN  
         
         	SELECT TOP 1 
         	   @cPickSlipNo = PD.PickSlipNo,
         	   @cLabelNo = PD.LabelNo
            FROM dbo.PackDetail PD WITH (NOLOCK)
            JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
            WHERE PH.StorerKey = @cStorerkey
            AND   PH.OrderKey = @cOrderKey
         	ORDER BY PD.LabelNo
         	
            SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)
            IF @cShipLabel = '0'
               SET @cShipLabel = ''

            IF @cShipLabel <> ''
            BEGIN
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cStorerKey',  @cStorerKey)
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cOrderKey',   @cOrderKey)
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cPickSlipNo', @cPickSlipNo)
               INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cLabelNo',    @cLabelNo)

               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, '', 
                  @cShipLabel, -- Report type
                  @tShipLabel, -- Report params
                  'rdt_1620ExtUpd01', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 

               IF @nErrNo <> 0
                  GOTO Quit
            END
         END
      END
   END

   Quit:  


END

GO