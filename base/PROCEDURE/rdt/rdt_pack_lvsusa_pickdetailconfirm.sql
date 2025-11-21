SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Pack_LVSUSA_PickDetailConfirm                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: PKD handling for LVSUSA FN993                               */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2024-10-25 1.0  JACKC       FCR-946 Created. (Based on 838Confirm20) */
/************************************************************************/

CREATE   PROC [RDT].[rdt_Pack_LVSUSA_PickDetailConfirm] (
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cFromDropID     NVARCHAR( 20)
   ,@cSKU            NVARCHAR( 20) 
   ,@nQTY            INT
   ,@nCartonNo       INT           OUTPUT
   ,@cLabelNo        NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR(250) OUTPUT
   ,@nUseStandard    INT = 0
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cSQL        NVARCHAR(MAX)
   DECLARE @cSQLParam   NVARCHAR(MAX)

   DECLARE @bSuccess    INT
   DECLARE @cLabelLine  NVARCHAR( 5)
   DECLARE @cNewLine    NVARCHAR( 1)
   DECLARE @cNewCarton  NVARCHAR( 1)
   DECLARE @cDropID     NVARCHAR( 20) = ''
   DECLARE @cRefNo      NVARCHAR( 20) = ''
   DECLARE @cRefNo2     NVARCHAR( 30) = ''
   DECLARE @cUPC        NVARCHAR( 30) = ''    
   DECLARE @cLoadKey    NVARCHAR( 10) = ''
   DECLARE @cOrderKey   NVARCHAR( 10) = ''
   DECLARE @nTranCount  INT


   DECLARE  @nCartonPackQty      INT = 0,
            @nBalQty             INT = 0,
            @cOption             NVARCHAR( 1) ='0',
            @cZone               NVARCHAR( 18),
            @nTotalNoPackQty     INT = 0,
            @bDebugFlag          BINARY = 0

   -- CR-946

   SET @nBalQty = @nQTY
   SET @nErrNo = 0
   SET @cErrMsg = ''

   -----------------------------------------------------------------------------------------------------------------
   -- FCR-392 Handle the pick detail data based on the pack detail
   -----------------------------------------------------------------------------------------------------------------
   DECLARE @tPKD TABLE
   (
      PickDetailKey     NVARCHAR( 10) NOT NULL,
      CaseID            NVARCHAR( 20) NOT NULL,
      PickHeaderKey     NVARCHAR( 18) NOT NULL,
      OrderKey          NVARCHAR( 10) NOT NULL,
      OrderLineNumber   NVARCHAR( 5)  NOT NULL,
      SKU               NVARCHAR( 20) NOT NULL, 
      QTY               INT           NOT NULL,
      AdjustQty         INT           NOT NULL,
      Lot               NVARCHAR( 10) NOT NULL,
      StorerKey         NVARCHAR( 15) NOT NULL,
      UOM               NVARCHAR( 10) NOT NULL,
      UOMQty            INT           NOT NULL,
      DropID            NVARCHAR( 20) NULL,
      Loc               NVARCHAR( 10) NOT NULL,
      ID                NVARCHAR( 18) NULL,
      PackKey           NVARCHAR( 10) NOT NULL,
      CartonGroup       NVARCHAR( 10) NULL,
      PickMethod        NVARCHAR( 1)  NOT NULL,
      WaveKey           NVARCHAR( 10) NULL,
      New               NVARCHAR( 1)  NULL DEFAULT 'N',
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )

   DECLARE  
      @cPickDetailKey         NVARCHAR( 10),
      @cNewPickDetailKey      NVARCHAR( 10),
      @cPKDCaseID             NVARCHAR( 20),
      @cPKDPickHeaderKey      NVARCHAR( 18),
      @cPKDOrderKey           NVARCHAR( 10),
      @cPKDOrderLineNumber    NVARCHAR( 5),
      @cPKDLot                NVARCHAR( 10),
      @cPKDDropID             NVARCHAR( 20),
      @cPKDLoc                NVARCHAR( 10),
      @cPKDID                 NVARCHAR( 18),
      @cPKDWeaveKey           NVARCHAR( 10),
      @nPkdQty                INT = 0,
      @nNewAdjustQty          INT = 0,
      @cNewFlag               NVARCHAR( 1) = 'N'

   IF @bDebugFlag = 1
   BEGIN
         SELECT 'Start handling PKD', @nQTY AS InputQty, @nBalQty AS BalQty, @cLabelNo AS LabelNo    
   END

   --Get all unpacked pick detail with same sku under this pickslip no 
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_Pack_LVSUSA_PKDCfm -- For rollback or commit only our own transaction

   IF @nBalQty < 0 -- Move out SKU from carton
   BEGIN

      IF @bDebugFlag = 1
         SELECT 'Move out SKU from Carton', @nQTY AS NewQtyInCarton, @nCartonPackQty AS OldQtyInCarton

      INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
						 UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey)
      SELECT	PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, 0, Lot, UOM,
	   		UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, @cStorerKey
      FROM PICKDETAIL with(nolock)
      WHERE Storerkey = @cStorerKey
         AND OrderKey = @cOrderKey
	      AND CaseID = @cLabelNo
         AND Status = '5'
         AND SKU = @cSKU

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 218401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Gen tPKD Fail'
         GOTO RollBackTran
      END

      IF @bDebugFlag = 1
      BEGIN
         SELECT 'Fill in @tPKD'
         SELECT * FROM @tPKD ORDER BY Qty DESC
      END
      
      WHILE @nBalQty < 0
      BEGIN
         SET @cPickDetailKey        = ''
         SET @cNewPickDetailKey     = ''
         SET @cPKDPickHeaderKey     = ''
         SET @cPKDOrderKey          = ''          
         SET @cPKDOrderLineNumber   = ''    
         SET @cPKDLot               = ''                
         SET @cPKDDropID            = ''       
         SET @cPKDLoc               = ''
         SET @cPKDID                = ''
         SET @nPkdQty               = 0
         SET @cNewFlag              = 'N'

         SELECT TOP 1 
            @cPickDetailKey      = PickDetailKey,
            @cPKDOrderKey        = OrderKey,          
            @cPKDOrderLineNumber = OrderLineNumber,    
            @cPKDLot             = Lot,                
            @cPKDDropID          = DropID,       
            @cPKDLoc             = Loc,
            @cPKDID              = ID,
            @cPKDWeaveKey        = Wavekey,
            @nPkdQTY             = Qty
         FROM @tPKD
         WHERE (Qty - AdjustQty) >0
            AND New = 'N'
            AND CaseID <> ''
         ORDER BY QTY DESC, OrderKey, OrderLineNumber, LOT, LOC, ID, DropID

         IF @cPickDetailKey = ''
         BEGIN
            SET @nErrNo = 218402
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetPKDFail
            GOTO RollBackTran
         END

         IF @bDebugFlag = 1
            SELECT 'PKD Found', @cPickDetailKey AS PKDKey, @nBalQty AS BalQty, @nPkdQty AS PKDQty

         IF ABS(@nBalQty) < @nPkdQty -- Split original pkd
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'Splist old PKD'

            --Adjust PKD qty
            UPDATE @tPKD SET AdjustQty = AdjustQty + @nBalQty
            WHERE PickDetailKey = @cPickDetailKey

            --IF exists a pkd with same case id and all same attributes, then add qty to that one
            SELECT @cNewPickDetailKey = PickDetailKey FROM PICKDETAIL WITH (NOLOCK) 
            WHERE Storerkey = @cStorerKey AND CaseID = '' AND OrderKey = @cPKDOrderKey AND OrderLineNumber = @cPKDOrderLineNumber
               AND Lot = @cPKDLot AND SKU = @cSKU AND Status = '5' AND DropID = @cPKDDropID AND Loc = @cPKDLoc
               AND ID = @cPKDID AND WaveKey = @cPKDWeaveKey

            IF @cNewPickDetailKey <> ''
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Found PKD with all same attributes, increas qty', @cNewPickDetailKey AS PKDKey

               -- insert PKD to @tPKD to increas qty same as the qty take out from the carton
               INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
                     UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey)
                  SELECT	PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, QTY, ABS(@nBalQty), Lot, UOM,
                        UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, Storerkey
                  FROM PickDetail WITH (NOLOCK)
                  WHERE PickDetailKey = @cNewPickDetailKey
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 218406
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsExtPkdFail'
                  GOTO RollBackTran
               END

            END -- newPKDKey <> ''
            ELSE 
            BEGIN

               -- Generate new pkd
               EXECUTE dbo.nspg_GetKey
                  'PICKDETAILKEY',
                  10 ,
                  @cNewPickDetailKey OUTPUT,
                  @bSuccess          OUTPUT,
                  @nErrNo            OUTPUT,
                  @cErrMsg           OUTPUT

               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 218403
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
                  GOTO RollBackTran
               END

               IF ISNULL(@cNewPickDetailKey, '') = ''
               BEGIN
                  SET @nErrNo = 218408
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenPKDKeyFail
                  GOTO RollBackTran
               END

               IF @bDebugFlag = 1
                  SELECT 'Gen new tPKD record', @cNewPickDetailKey AS NewPKDKey

               INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
                     UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey, New)
                  SELECT	@cNewPickDetailKey, '', PickHeaderKey, OrderKey, OrderLineNumber, SKU, ABS(@nBalQty), 0, Lot, '6',
                        1, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey,StorerKey,'Y'
                  FROM @tPKD
                  WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 218404
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsNewPkdFail'
                  GOTO RollBackTran
               END
            END -- Generate new pkd
         END -- Split original pkd
         ELSE -- ABS(@nBalQty) >= @nPkdQty
         BEGIN

            IF @bDebugFlag = 1
               SELECT 'Update existing PKD'

            --IF exists a pkd without case id but has all same attributes, then add qty to that one
            SELECT @cNewPickDetailKey = PickDetailKey FROM PICKDETAIL WITH (NOLOCK) 
            WHERE Storerkey = @cStorerKey AND CaseID = '' AND OrderKey = @cPKDOrderKey AND OrderLineNumber = @cPKDOrderLineNumber
               AND Lot = @cPKDLot AND SKU = @cSKU AND Status = '5' AND DropID = @cPKDDropID AND Loc = @cPKDLoc
               AND ID = @cPKDID AND WaveKey = @cPKDWeaveKey

            IF @cNewPickDetailKey <> ''
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Found PKD with all same attributes, increas qty, delete original one', @cNewPickDetailKey AS PKDKey

               IF NOT EXISTS (SELECT 1 FROM @tPKD WHERE PickDetailKey = @cNewPickDetailKey)
               BEGIN
                  IF @bDebugFlag = 1
                     SELECT 'Found PKD not exist in @tPKD, insert it'

                  -- insert PKD to @tPKD to increas qty same as the qty take out from the carton
                  INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
                        UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey)
                     SELECT	PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, QTY, @nPkdQty, Lot, UOM,
                           UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, Storerkey
                     FROM PickDetail WITH (NOLOCK)
                     WHERE PickDetailKey = @cNewPickDetailKey
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 218406
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsExtPkdFail'
                     GOTO RollBackTran
                  END
               END -- Not Exists
               ELSE
               BEGIN -- exists in @tPKD
                  IF @bDebugFlag = 1
                     SELECT 'Found pkd exists in @tPKD, update it'

                  UPDATE @tPKD SET AdjustQty = AdjustQty + @nPkdQty WHERE PickDetailKey = @cNewPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 218411
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdtPKDFail'
                     GOTO RollBackTran
                  END
               END


               IF @bDebugFlag = 1
                  SELECT 'Mark the original PKD as delete', @cPickDetailKey

               --Mark to delete the original pkd
               UPDATE @tPKD SET New = 'D' WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 218411
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdtPKDFail'
                  GOTO RollBackTran
               END


            END -- newPKDKey <> ''
            ELSE
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Remove case id from pkd'

               -- Set case id to empty
               UPDATE @tPKD SET  CaseID = ''  WHERE PickDetailKey = @cPickDetailKey
            END
         END

         SET @nBalQty = @nBalQty + @nPkdQTY

      END --  @nBalQty < 0 While
   END -- @nBalQty < 0
   ELSE IF @nBalQty > 0 -- Add item to existing carton
   BEGIN

      IF @bDebugFlag = 1
         SELECT 'Add SKU to Carton', @nQTY AS NewQtyInCarton, @nCartonPackQty AS OldQtyInCarton

      --Get all unpacked pick detail with same sku under this pickslip no 
      /*SELECT TOP 1
         @cOrderKey = OrderKey,
         @cLoadKey = ExternOrderKey,
         @cZone = Zone
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo*/

      INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
                  UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey)
         SELECT	PD.PickDetailKey, CaseID, PickHeaderKey, PD.OrderKey, PD.OrderLineNumber, SKU, Qty, 0, Lot, UOM,
                  UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, Storerkey
         FROM dbo.PickDetail PD WITH (NOLOCK)
         WHERE PD.OrderKey = @cOrderKey
            AND PD.Status = '5' 
            AND PD.CaseID = ''
            AND PD.SKU = @cSKU
            
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 218401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Gen tPKD Fail'
         GOTO RollBackTran
      END

      SELECT @nTotalNoPackQty = ISNULL( SUM(QTY), 0)
      FROM @tPKD
      WHERE CaseID = ''

      IF @bDebugFlag = 1
      BEGIN
         SELECT 'Total Unpacked Qty', @nTotalNoPackQty
         SELECT 'Fill In @tPKD'
         SELECT * FROM @tPKD
      END

      IF @nTotalNoPackQty = 0
      BEGIN
         SET @nErrNo = 218413
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NothingToPack'
         GOTO RollBackTran
      END

      IF @nBalQty > @nTotalNoPackQty
      BEGIN
         SET @nErrNo = 218414
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ExceedUnPackQty'
         GOTO RollBackTran
      END

      WHILE @nBalQty > 0
      BEGIN
         SET @cPickDetailKey        = ''
         SET @cNewPickDetailKey     = ''
         SET @cPKDPickHeaderKey     = ''
         SET @cPKDOrderKey          = ''          
         SET @cPKDOrderLineNumber   = ''    
         SET @cPKDLot               = ''                
         SET @cPKDDropID            = ''       
         SET @cPKDLoc               = ''
         SET @cPKDID                = ''
         SET @nPkdQty               = 0
         SET @cNewFlag              = 'N'

         SELECT TOP 1 
            @cPickDetailKey      = PickDetailKey,
            @cPKDOrderKey        = OrderKey,          
            @cPKDOrderLineNumber = OrderLineNumber,    
            @cPKDLot             = Lot,                
            @cPKDDropID          = DropID,       
            @cPKDLoc             = Loc,
            @cPKDID              = ID,
            @cPKDWeaveKey        = WaveKey,
            @nPkdQTY             = Qty
         FROM @tPKD
         WHERE (Qty - AdjustQty) >0
            AND New = 'N'
            AND CaseID = ''
         ORDER BY QTY DESC, OrderKey, OrderLineNumber, LOT, LOC, ID, DropID

         IF @cPickDetailKey = ''
         BEGIN
            SET @nErrNo = 218402
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetPKDFail
            GOTO RollBackTran
         END

         IF @bDebugFlag = 1
            SELECT 'PKD Found', @cPickDetailKey AS PKDKey, @nBalQty AS BalQty, @nPkdQty AS PKDQty

         IF @nBalQty < @nPkdQty
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'Split old PKD'

            --Adjust PKD qty
            UPDATE @tPKD SET AdjustQty = AdjustQty - @nBalQty
            WHERE PickDetailKey = @cPickDetailKey

            --IF exists a pkd without case id but has all same attributes, then add qty to that one
            SELECT @cNewPickDetailKey = PickDetailKey FROM PICKDETAIL WITH (NOLOCK) 
            WHERE Storerkey = @cStorerKey AND CaseID = @cLabelNo AND OrderKey = @cPKDOrderKey AND OrderLineNumber = @cPKDOrderLineNumber
               AND Lot = @cPKDLot AND SKU = @cSKU AND Status = '5' AND DropID = @cPKDDropID AND Loc = @cPKDLoc
               AND ID = @cPKDID AND WaveKey = @cPKDWeaveKey

            IF @cNewPickDetailKey <> ''
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Found PKD with all same attributes, increas qty', @cNewPickDetailKey AS PKDKey

               -- insert PKD to @tPKD to increas qty same as the qty add to the carton
               INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
                     UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey)
                  SELECT	PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, QTY, ABS(@nBalQty), Lot, UOM,
                        UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, Storerkey
                  FROM PickDetail WITH (NOLOCK)
                  WHERE PickDetailKey = @cNewPickDetailKey
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 218406
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsExtPkdFail'
                  GOTO RollBackTran
               END
            END -- newPKDKey <> ''
            ELSE 
            BEGIN
               -- Generate new pkd
               EXECUTE dbo.nspg_GetKey
                  'PICKDETAILKEY',
                  10 ,
                  @cNewPickDetailKey OUTPUT,
                  @bSuccess          OUTPUT,
                  @nErrNo            OUTPUT,
                  @cErrMsg           OUTPUT

               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 218403
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
                  GOTO RollBackTran
               END

               IF ISNULL(@cNewPickDetailKey, '') = ''
               BEGIN
                  SET @nErrNo = 218408
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GenPKDKeyFail
                  GOTO RollBackTran
               END

               IF @bDebugFlag = 1
                  SELECT 'Gen new tPKD record', @cNewPickDetailKey AS NewPKDKey

               INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
                     UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey, New)
                  SELECT	@cNewPickDetailKey, @cLabelNo, PickHeaderKey, OrderKey, OrderLineNumber, SKU, ABS(@nBalQty), 0, Lot, '6',
                        1, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey,StorerKey,'Y'
                  FROM @tPKD
                  WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 218404
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsNewPkdFail'
                  GOTO RollBackTran
               END
            END -- Generate new pkd

         END -- @nBalQty < @nPkdQty
         ELSE -- @nBalQty >= @nPkdQty
         BEGIN
            IF @bDebugFlag = 1
               SELECT 'Update existing PKD'

            --IF exists a pkd with same case id and has all same attributes, then add qty to that one
            SELECT @cNewPickDetailKey = PickDetailKey FROM PICKDETAIL WITH (NOLOCK) 
            WHERE Storerkey = @cStorerKey AND CaseID = @cLabelNo AND OrderKey = @cPKDOrderKey AND OrderLineNumber = @cPKDOrderLineNumber
               AND Lot = @cPKDLot AND SKU = @cSKU AND Status = '5' AND DropID = @cPKDDropID AND Loc = @cPKDLoc
               AND ID = @cPKDID AND WaveKey = @cPKDWeaveKey

            IF @cNewPickDetailKey <> ''
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Found PKD with all same attributes, increas qty, delete original one', @cNewPickDetailKey AS PKDKey

               -- insert PKD to @tPKD to increas qty same as the qty take out from the carton
               IF NOT EXISTS (SELECT 1 FROM @tPKD WHERE PickDetailKey = @cNewPickDetailKey)
               BEGIN
                  IF @bDebugFlag = 1
                     SELECT 'Found PKD not Exist in @tPKD, Insert it'

                  INSERT INTO @tPKD (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, AdjustQty,Lot, UOM,
                        UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, StorerKey)
                     SELECT	PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, QTY, @nPkdQty, Lot, UOM,
                           UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey, Storerkey
                     FROM PickDetail WITH (NOLOCK)
                     WHERE PickDetailKey = @cNewPickDetailKey
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 218406
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InstPkdFail'
                     GOTO RollBackTran
                  END
               END -- Not exists
               ELSE
               BEGIN -- Exists in @tPkd
                  IF @bDebugFlag = 1
                     SELECT 'Found PKD already Exists in @tPKD, update it'

                  UPDATE @tPKD SET AdjustQty = AdjustQty + @nPkdQty WHERE PickDetailKey = @cNewPickDetailKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 218411
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdtPKDFail'
                     GOTO RollBackTran
                  END
               END

               IF @bDebugFlag = 1
                  SELECT 'Mark the original PKD as delete', @cPickDetailKey

               --Mark to delete the original pkd
               UPDATE @tPKD SET New = 'D' WHERE PickDetailKey = @cPickDetailKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 218411
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdtPKDFail'
                  GOTO RollBackTran
               END

            END -- newPKDKey <> ''
            ELSE
            BEGIN
               IF @bDebugFlag = 1
                  SELECT 'Upd pkd caseid to the scanned label no'

               -- Set case id to empty
               UPDATE @tPKD SET  CaseID = @cLabelNo  WHERE PickDetailKey = @cPickDetailKey
            END

         END -- @nBalQty >= @nPkdQty

         SET @nBalQty = @nBalQty - @nPkdQTY

      END -- while @nBalQty > 0


   END -- @nBalQty >0

   IF @bDebugFlag = 1
   BEGIN
      SELECT 'Applied to real PKD'
      SELECT * FROM @tPKD
   END

   --------------------------------------------------------------------------------------------------------------
   --Update back to PickDetail
   --------------------------------------------------------------------------------------------------------------

   -- Delete the pickdetail record which is marked as deleted in tPKD
   IF @bDebugFlag = 1
      SELECT 'Delete PickDetail'

   DELETE pkd
   FROM pickdetail pkd INNER JOIN @tPKD t
      ON pkd.PickDetailKey = t.PickDetailKey
   WHERE t.New = 'D'

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 218412
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelPKDFail'
      GOTO RollBackTran
   END

   IF @bDebugFlag = 1
      SELECT 'Update PickDetail'

   UPDATE pkd SET 
      pkd.CaseID  = t.CaseID,
      pkd.Qty     = t.Qty + t.AdjustQty,
      pkd.UOM     = '6',
      pkd.UOMQty  = 1
   FROM pickdetail pkd INNER JOIN @tPKD t
      ON pkd.pickdetailkey = t.pickdetailkey AND t.New <> 'D'
   
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 218407
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPKDFail'
      GOTO RollBackTran
   END

   --Split the update and insert code to avoid lotxlocxid check constraints
   IF @bDebugFlag = 1
      SELECT 'Insert PickDetail'

   INSERT INTO pickdetail (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, SKU, Qty, Lot, StorerKey, UOM,
               UOMQty, DropID, Loc, ID, PackKey, CartonGroup, PickMethod, WaveKey)
   SELECT  PickdetailKey,  CaseID,  PickHeaderKey,  OrderKey,  OrderLineNumber,  SKU,  Qty,  lot, @cStorerKey,  UOM,
            UOMQty,  DropID,  Loc,  ID,  PackKey,  CartonGroup,  PickMethod, WaveKey
   FROM @tPKD WHERE NEW = 'Y'

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 218409
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPKDFail'
      GOTO RollBackTran
   END

   UPDATE pkd SET status = '5'
   FROM pickdetail pkd JOIN @tPKD t
      ON pkd.PickDetailKey = t.PickDetailKey
   WHERE t.New = 'Y'

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 218410
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPKDFail'
      GOTO RollBackTran
   END

   COMMIT TRAN rdt_Pack_LVSUSA_PKDCfm
   GOTO Quit

   RollBackTran:
   BEGIN
      ROLLBACK TRAN rdt_Pack_LVSUSA_PKDCfm -- Only rollback change made here

      IF @bDebugFlag = 1
         SELECT 'Rollback Tran', @nErrNo AS ErrNo, @cErrMsg AS ErrMsg
         SELECT * FROM @tPKD

   END --rollback

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

      IF @bDebugFlag = 1
      BEGIN
         SELECT 'Quit'
         SELECT @nErrNo AS ErrNo, @cErrMsg AS ErrMessage
      END
END -- End SP

GO