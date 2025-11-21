SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_MoveByLabelNo                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Move by PaclDetail.LabelNo                                  */
/*                                                                      */
/* Modifications log:                                                   */
/* Date       Rev  Author   Purposes                                    */
/* 2012-10-08 1.0  Ung      SOS257810 Created                           */
/* 2012-11-23 1.1  Ung      SOS261923 CartonType, ExtendedUpdate        */
/* 2019-03-05 1.2  James    WMS8054 - Add extended move sp (james01)    */
/* 2022-08-18 1.3  James    WMS-20234 Add update label no to pickdetail */
/*                          caseid and/or dropid (james02)              */
/*                          Add on move pallet id (james03)             */
/************************************************************************/

CREATE   PROC [RDT].[rdt_MoveByLabelNo] (
   @nMobile      INT,
   @nFunc        INT, 
   @cLangCode    NVARCHAR( 3), 
   @cUserName    NVARCHAR( 18), 
   @cFacility    NVARCHAR( 5), 
   @cStorerKey   NVARCHAR( 15),
   @cPickSlipNo  NVARCHAR( 10),
   @cFromLabelNo NVARCHAR( 20),
   @cToLabelNo   NVARCHAR( 20),
   @cCartonType  NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20),
   @nQTY_Move    INT,
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nQTY           INT
   DECLARE @nQty_Bal       INT
   DECLARE @nTranCount     INT
   DECLARE @nRowCount      INT

   DECLARE @nFromCartonNo  INT
   DECLARE @cFromLabelLine NVARCHAR( 5)
   DECLARE @cFromSKU       NVARCHAR( 20)
   DECLARE @nFromQTY       INT

   DECLARE @nToCartonNo  INT
   DECLARE @cToLabelLine NVARCHAR( 5)
   DECLARE @cSQL             NVARCHAR( MAX)
   DECLARE @cSQLParam        NVARCHAR( MAX)

   SET @nErrNo = 0
   SET @cErrMsg = ''

   DECLARE
       @n_debug INT
      ,@d_date       DATETIME
      ,@d_starttime  DATETIME
      ,@d_endtime    DATETIME
      ,@d_total      DATETIME, @n_total  INT
      ,@d_step1      DATETIME, @n_step1  INT
      ,@d_step2      DATETIME, @n_step2  INT
      ,@d_step3      DATETIME, @n_step3  INT
      ,@d_step4      DATETIME, @n_step4  INT
      ,@d_step5      DATETIME, @n_step5  INT
      ,@d_step6      DATETIME, @n_step6  INT
      ,@d_step7      DATETIME, @n_step7  INT
      ,@d_step8      DATETIME, @n_step8  INT
      ,@d_step9      DATETIME, @n_step9  INT
      ,@d_step10     DATETIME, @n_step10 INT
      ,@c_TraceName  NVARCHAR(80)

   SET @d_starttime = GETDATE()
   SELECT @d_total     = 0, @n_total  = 0
   SELECT @d_step1     = 0, @n_step1  = 0
   SELECT @d_step2     = 0, @n_step2  = 0
   SELECT @d_step3     = 0, @n_step3  = 0
   SELECT @d_step4     = 0, @n_step4  = 0
   SELECT @d_step5     = 0, @n_step5  = 0
   SELECT @d_step6     = 0, @n_step6  = 0
   SELECT @d_step7     = 0, @n_step7  = 0
   SELECT @d_step8     = 0, @n_step8  = 0
   SELECT @d_step9     = 0, @n_step9  = 0
   SELECT @d_step10    = 0, @n_step10 = 0

   -- Get extended MoveByLabelNo SP
   DECLARE @cExtendedMoveByLabelNoSP NVARCHAR(20)
   SET @cExtendedMoveByLabelNoSP = rdt.rdtGetConfig( @nFunc, 'ExtendedMoveByLabelNoSP', @cStorerKey)
   IF @cExtendedMoveByLabelNoSP = '0'
      SET @cExtendedMoveByLabelNoSP = ''  

   -- Extended putaway
   IF @cExtendedMoveByLabelNoSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedMoveByLabelNoSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedMoveByLabelNoSP) +
            ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cPickSlipNo, @cFromLabelNo, ' + 
            ' @cToLabelNo, @cCartonType, @cSKU, @nQTY_Move, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile         INT,                  ' +
            '@nFunc           INT,                  ' +
            '@cLangCode       NVARCHAR( 3),         ' +
            '@cUserName       NVARCHAR( 18),        ' +
            '@cFacility       NVARCHAR( 5),         ' + 
            '@cStorerKey      NVARCHAR( 15),        ' +
            '@cPickSlipNo     NVARCHAR( 10),        ' +
            '@cFromLabelNo    NVARCHAR( 20),        ' +
            '@cToLabelNo      NVARCHAR( 20) OUTPUT, ' + 
            '@cCartonType     NVARCHAR( 10) OUTPUT, ' + 
            '@cSKU            NVARCHAR( 20)  OUTPUT, ' + 
            '@nQTY_Move       INT           OUTPUT, ' + 
            '@nErrNo          INT           OUTPUT, ' +
            '@cErrMsg         NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cPickSlipNo, @cFromLabelNo, 
            @cToLabelNo, @cCartonType, @cSKU, @nQTY_Move, @nErrNo OUTPUT, @cErrMsg OUTPUT

         IF @nErrNo <> 0
            GOTO Fail
      END
   END
   ELSE
   BEGIN
      /*--------------------------------------------------------------------------------------------------

                                                PackDetail line

      --------------------------------------------------------------------------------------------------*/
      DECLARE @cUpdLabelNoToCaseID  NVARCHAR( 1) = ''
      DECLARE @cUpdLabelNoToDropID  NVARCHAR( 1) = ''
      DECLARE @cOrderKey            NVARCHAR( 10) = ''
      DECLARE @cPack_SKU            NVARCHAR( 20) = ''   
      DECLARE @cPack_LblNo          NVARCHAR( 20) = ''
      DECLARE @cPickDetailKey       NVARCHAR( 10) = ''
      DECLARE @nPack_QTY            INT = 0
      DECLARE @nPD_QTY              INT = 0
      DECLARE @curPACKD             CURSOR
      DECLARE @curPICKD             CURSOR
      DECLARE @b_success            INT  
      DECLARE @n_err                INT  
      DECLARE @c_errmsg             NVARCHAR( 20)
      DECLARE @cFilterPickDetailCaseId NVARCHAR( 1)
      DECLARE @cMoveId              NVARCHAR( 1)
      DECLARE @cFromID              NVARCHAR( 18)
      DECLARE @cToID                NVARCHAR( 18)
      DECLARE @cFromLOC             NVARCHAR( 10)
      DECLARE @cToLOC               NVARCHAR( 10)
      DECLARE @curMoveId            CURSOR
      DECLARE @cMvLOC               NVARCHAR( 10)
      DECLARE @cMvID                NVARCHAR( 18)
      DECLARE @cMvSKU               NVARCHAR( 20)
      DECLARE @nMvQty               INT
      DECLARE @cFromStatus          NVARCHAR( 10)
      DECLARE @nQTYAlloc            INT
      DECLARE @nQTYPick             INT
      DECLARE @nMoved_Qty           INT
      
      SET @cFilterPickDetailCaseId = rdt.rdtGetConfig( @nFunc, 'FilterPickDetailCaseId', @cStorerKey)
      SET @cUpdLabelNoToCaseID = rdt.rdtGetConfig( @nFunc, 'UpdLabelNoToCaseID', @cStorerKey)
      SET @cUpdLabelNoToDropID = rdt.rdtGetConfig( @nFunc, 'UpdLabelNoToDropID', @cStorerKey)
      SET @cMoveId = rdt.rdtGetConfig( @nFunc, 'MoveId', @cStorerKey)

      IF @cMoveId = '1'
      BEGIN
         IF OBJECT_ID('tempdb..#MoveId') IS NOT NULL  
            DROP TABLE #MoveId
         
         CREATE TABLE #MoveId  (  
            RowRef        BIGINT IDENTITY(1,1)  Primary Key,
            LOC           NVARCHAR( 10),
            Id            NVARCHAR( 18),
            SKU           NVARCHAR( 20),
            Qty           INT)  
      END
               
      SET @nQTY_Bal = @nQTY_Move
      SET @d_step1 = GETDATE()

      SET @nFromCartonNo = 0
      SELECT @nFromCartonNo = CartonNo FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cFromLabelNo

      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN
      SAVE TRAN rdt_MoveByLabelNo

      -- Loop from PackDetail lines
      DECLARE @curPD CURSOR
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LabelLine, SKU, QTY
         FROM dbo.PackDetail PD WITH (NOLOCK)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.LabelNo = @cFromLabelNo
            AND PD.StorerKey = @cStorerKey
            AND PD.SKU = CASE WHEN @cSKU = '' THEN PD.SKU ELSE @cSKU END
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cFromLabelLine, @cFromSKU, @nFromQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Calc QTY to move
         IF @cSKU = '' -- Merge carton
            SET @nQTY = @nFromQTY 
         ELSE
         BEGIN
            -- Merge by SKU
            IF @nQTY_Bal > @nFromQTY
               SET @nQTY = @nFromQTY
            ELSE
               SET @nQTY = @nQTY_Bal

            SET @nQTY_Bal = @nQTY_Bal - @nQTY
         END

         -- Find TO PackDetail line
         SET @nToCartonNo = 0
         SET @cToLabelLine = ''
         SELECT
            @nToCartonNo = CartonNo, 
            @cToLabelLine = LabelLine
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND LabelNo = @cToLabelNo
            AND StorerKey = @cStorerKey
            AND SKU = @cFromSKU

         -- TO PackDetail line
         -- Add new SKU to existing carton
         IF @@ROWCOUNT = 0
         BEGIN
            -- Get max LabelLine
            SET @d_date = GETDATE()
            SELECT @cToLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
            FROM dbo.PackDetail (NOLOCK)
            WHERE Pickslipno = @cPickSlipNo
               AND LabelNo = @cToLabelNo

            -- Insert PackDetail
            INSERT INTO dbo.PackDetail
               (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate)
            VALUES
               (@cPickSlipNo, @nToCartonNo, @cToLabelNo, @cToLabelLine, @cStorerKey, @cFromSKU, @nQTY, 
               LEFT( 'rdt.' + SUSER_SNAME(), 18), GETDATE(), 
               LEFT( 'rdt.' + SUSER_SNAME(), 18), GETDATE())
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 77651
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
               GOTO RollBackTran
            END
            SELECT @d_step3 = @d_step3 + (GETDATE() - @d_date), @n_step3 = @n_step3 + 1
         END
         ELSE
         BEGIN
            -- Top up to existing carton and SKU
            SET @d_date = GETDATE()
            UPDATE dbo.PackDetail SET
               QTY = QTY + @nQTY,
               EditWho = LEFT( 'rdt.' + SUSER_SNAME(), 18),
               EditDate = GETDATE(), 
               ArchiveCop = NULL
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @nToCartonNo
               AND LabelNo = @cToLabelNo
               AND LabelLine = @cToLabelLine
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 77652
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
               GOTO RollBackTran
            END
            SELECT @d_step4 = @d_step4 + (GETDATE() - @d_date), @n_step4 = @n_step4 + 1
         END

         -- FROM PackDetail line
         IF @nFromQTY = @nQTY
         BEGIN
            -- Delete PackDetail
            SET @d_date = GETDATE()
            DELETE PackDetail
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @nFromCartonNo
               AND LabelNo = @cFromLabelNo
               AND LabelLine = @cFromLabelLine
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 77653
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPackDtlFail
               GOTO RollBackTran
            END
            SELECT @d_step5 = @d_step5 + (GETDATE() - @d_date), @n_step5 = @n_step5 + 1
         END
         ELSE
         BEGIN
            -- Update PackDetail
            SET @d_date = GETDATE()
            UPDATE PackDetail SET
               QTY = QTY - @nQTY, 
               EditWho = LEFT( 'rdt.' + SUSER_SNAME(), 18), 
               EditDate = GETDATE(), 
               ArchiveCop = NULL
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @nFromCartonNo
               AND LabelNo = @cFromLabelNo
               AND LabelLine = @cFromLabelLine
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 77654
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail
               GOTO RollBackTran
            END
            SELECT @d_step6 = @d_step6 + (GETDATE() - @d_date), @n_step6 = @n_step6 + 1
         END

         FETCH NEXT FROM @curPD INTO @cFromLabelLine, @cFromSKU, @nFromQTY
      END
      CLOSE @curPD
      DEALLOCATE @curPD

      -- Check if fully offset (when by SKU)
      IF @cSKU <> '' AND @nQty_Bal <> 0
      BEGIN
         SET @nErrNo = 77655
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OffsetError
         GOTO RollBackTran
      END
      SELECT @d_step1 = GETDATE() - @d_step1, @n_step1 = @n_step1 + 1


   /*--------------------------------------------------------------------------------------------------

                                                PackInfo

   --------------------------------------------------------------------------------------------------*/
      DECLARE @nCartonWeight FLOAT
      DECLARE @nCartonCube   FLOAT
      SET @d_step2 = GETDATE()

      SET @nToCartonNo = 0
      SELECT @nToCartonNo   = CartonNo FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND LabelNo = @cToLabelNo

      -- From carton
      IF EXISTS( SELECT 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nFromCartonNo)
      BEGIN
         -- Recalc from carton's weight, cube
         SELECT
            @nCartonWeight = ISNULL( SUM( PD.QTY * SKU.STDGrossWGT), 0),
            @nCartonCube   = ISNULL( SUM( PD.QTY * SKU.STDCube), 0)
         FROM dbo.PackDetail PD WITH (NOLOCK)
            INNER JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND PD.CartonNo = @nFromCartonNo

         -- Update PackInfo
         UPDATE dbo.PackInfo SET
            Weight = @nCartonWeight,
            Cube = @nCartonCube
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nFromCartonNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 77656
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPKInfoFail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         DELETE dbo.PackInfo WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nFromCartonNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 77657
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelPKInfoFail
            GOTO RollBackTran
         END
      END

      -- Calc To carton's weight, cube
      SELECT
         @nCartonWeight = ISNULL( SUM( PD.QTY * SKU.STDGrossWGT), 0),
         @nCartonCube   = ISNULL( SUM( PD.QTY * SKU.STDCube), 0)
      FROM dbo.PackDetail PD WITH (NOLOCK)
         INNER JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND PD.CartonNo = @nToCartonNo

      -- To carton
      IF NOT EXISTS( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nToCartonNo)
      BEGIN
         INSERT INTO dbo.PackInfo (PickSlipNo, CartonNo, Weight, Cube, CartonType)
         VALUES ( @cPickSlipNo, @nToCartonNo, @nCartonWeight, @nCartonCube, @cCartonType)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 77658
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPKInfoFail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         UPDATE dbo.PackInfo SET
            Weight = @nCartonWeight,
            Cube = @nCartonCube
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nToCartonNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 77659
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPKInfoFail
            GOTO RollBackTran
         END
      END
      SELECT @d_step2 = GETDATE() - @d_step2, @n_step2 = @n_step2 + 1

      /*--------------------------------------------------------------------------------------------------

                              Update PickDetail.CaseID and/or Dropid

      --------------------------------------------------------------------------------------------------*/
      IF @cUpdLabelNoToCaseID = '1' OR @cUpdLabelNoToDropID = '1'
      BEGIN
         SELECT @cOrderKey = OrderKey
         FROM dbo.PackHeader WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
      
         SET @curPACKD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT LabelNo, SKU, SUM( Qty)  
         FROM dbo.PackDetail WITH (NOLOCK)   
         WHERE StorerKey = @cStorerkey  
         AND   PickSlipNo = @cPickSlipNo  
         AND   LabelNo = @cToLabelNo
         GROUP BY LabelNo, SKU  
         ORDER BY LabelNo, SKU  
         OPEN @curPACKD  
         FETCH NEXT FROM @curPACKD INTO @cPack_LblNo, @cPack_SKU, @nPack_QTY  
         WHILE @@FETCH_STATUS = 0  
         BEGIN  
      	   SELECT TOP 1 
      	      @cToLOC = Loc, 
      	      @cToID = ID
      	   FROM dbo.PICKDETAIL WITH (NOLOCK)
      	   WHERE OrderKey = @cOrderKey
      	   AND   Storerkey = @cStorerKey
      	   AND   CaseID = @cPack_LblNo
      	   AND   (( @cFilterPickDetailCaseId = '1' AND CaseID = @cPack_LblNo) OR ( DropID = @cPack_LblNo))
      	   AND   Sku = @cPack_SKU
      	   ORDER BY 1

            -- Stamp pickdetail.caseid (to know which case in which pickdetail line)  
            SET @curPICKD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT PickDetailKey, QTY, ID, Loc  
            FROM dbo.PickDetail WITH (NOLOCK)  
            WHERE OrderKey  = @cOrderKey  
            AND   StorerKey  = @cStorerKey  
            AND   SKU = @cPack_SKU  
            AND   (( @cFilterPickDetailCaseId = '1' AND CaseID = @cFromLabelNo) OR 
                   ( @cFilterPickDetailCaseId = '0' AND DropID = @cFromLabelNo))
            AND   Status < '9'  
            ORDER BY PickDetailKey  
            OPEN @curPICKD  
            FETCH NEXT FROM @curPICKD INTO @cPickDetailKey, @nPD_QTY, @cFromID, @cFromLOC  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               -- Exact match  
               IF @nPD_QTY = @nPack_QTY  
               BEGIN  
                  -- Confirm PickDetail  
                  UPDATE dbo.PickDetail SET  
                     CaseID = CASE WHEN @cUpdLabelNoToCaseID = '1' THEN @cPack_LblNo ELSE CaseID END,   
                     DropID = CASE WHEN @cUpdLabelNoToDropID = '1' THEN @cPack_LblNo ELSE DropID END,
                     EditWho = SUSER_SNAME(),
                     EditDate = GETDATE()  
                  WHERE PickDetailKey = @cPickDetailKey  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 77660  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PDtl Fail'  
                     GOTO RollBackTran  
                  END  
  
                  SET @nPack_QTY = @nPack_QTY - @nPD_QTY -- Reduce balance   
               END  
               -- PickDetail have less  
               ELSE IF @nPD_QTY < @nPack_QTY  
               BEGIN  
                  -- Confirm PickDetail  
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
                     CaseID = CASE WHEN @cUpdLabelNoToCaseID = '1' THEN @cPack_LblNo ELSE CaseID END,   
                     DropID = CASE WHEN @cUpdLabelNoToDropID = '1' THEN @cPack_LblNo ELSE DropID END,
                     EditWho = SUSER_SNAME(),
                     EditDate = GETDATE()  
                  WHERE PickDetailKey = @cPickDetailKey  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 77661  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PDtl Fail'  
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
                     SET @nErrNo = 77662  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Get PDKey Fail'  
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
                     SET @nErrNo = 77663  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PDtl Fail'  
                     GOTO RollBackTran  
                  END  
  
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
                     Qty = @nPack_QTY,   -- deduct original qty  
                     CaseID = CASE WHEN @cUpdLabelNoToCaseID = '1' THEN @cPack_LblNo ELSE CaseID END,   
                     DropID = CASE WHEN @cUpdLabelNoToDropID = '1' THEN @cPack_LblNo ELSE DropID END,
                     EditWho = SUSER_SNAME(),
                     EditDate = GETDATE()  
                  WHERE PickDetailKey = @cPickDetailKey  
  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 77664  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PDtl Fail'  
                     GOTO RollBackTran  
                  END  
  
                  SET @nPack_QTY = 0 -- Reduce balance    
               END  
  
               IF NOT EXISTS ( SELECT 1 FROM #MoveId WHERE Id = @cFromID AND SKU = @cPack_SKU)
                  INSERT INTO #MoveId (Loc, Id, SKU, Qty) VALUES (@cFromLOC, @cFromID, @cPack_SKU, @nPD_QTY)
               ELSE
               	UPDATE #MoveId SET 
               	   Qty = Qty + @nPD_QTY
               	WHERE Loc = @cFromLOC
               	AND   Id = @cFromID
               	AND   SKU = @cPack_SKU
               	
               IF @nPack_QTY = 0   
                  BREAK -- Exit  
  
               FETCH NEXT FROM @curPICKD INTO @cPickDetailKey, @nPD_QTY, @cFromID, @cFromLOC  
            END  
            CLOSE @curPICKD
            DEALLOCATE @curPICKD

            FETCH NEXT FROM @curPACKD INTO @cPack_LblNo, @cPack_SKU, @nPack_QTY           
         END  

         IF @cMoveId = 1
         BEGIN
            SET @curMoveId = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT Loc, Id, SKU, Qty
            FROM #MoveId
            OPEN @curMoveId
            FETCH NEXT FROM @curMoveId INTO @cMvLOC, @cMvID, @cMvSKU, @nMvQty
            WHILE @@FETCH_STATUS = 0
            BEGIN
               SELECT @cFromStatus = MAX( [STATUS]) 
               FROM dbo.PICKDETAIL WITH (NOLOCK)
      	      WHERE OrderKey = @cOrderKey
      	      AND   Storerkey = @cStorerKey
      	      AND   CaseID = @cPack_LblNo
      	      AND   (( @cFilterPickDetailCaseId = '1' AND CaseID = @cPack_LblNo) OR ( DropID = @cPack_LblNo))
      	      AND   Sku = @cMvSKU
               	
               IF @cFromStatus = '0'
               BEGIN
               	SET @nQtyAlloc = @nMvQty
               	SET @nQtyPick = 0
               END
               ELSE
               BEGIN
               	SET @nQtyAlloc = 0
               	SET @nQtyPick = @nMvQty
               END

               --IF SUSER_SNAME() = 'jameswong'
               --BEGIN
               --	SELECT '#MoveId', * FROM #MoveId
               --   SELECT @cStorerKey '@cStorerKey', @cFacility '@cFacility', @cMvLOC '@cMvLOC', @cToLOC '@cToLOC'
               --   SELECT @cMvID '@cMvID', @cToID '@cToID', @cMvSKU '@cMvSKU', @nMvQty '@nMvQty', @nQtyAlloc '@nQtyAlloc', @nQtyPick '@nQtyPick'	
               --END
               
               IF @cFilterPickDetailCaseId = '1'
                  EXECUTE rdt.rdt_Move
                     @nMobile     	= @nMobile,
                     @cLangCode   	= @cLangCode,
                     @nErrNo      	= @nErrNo  OUTPUT,
                     @cErrMsg     	= @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
                     @cSourceType 	= 'rdt_MoveByLabelNo',
                     @cStorerKey  	= @cStorerKey,
                     @cFacility   	= @cFacility,
                     @cFromLOC    	= @cMvLOC,
                     @cToLOC      	= @cToLOC,
                     @cFromID     	= @cMvID,     -- NULL means not filter by ID. Blank is a valid ID
                     @cToID       	= @cToID,     -- NULL means not changing ID. Blank consider a valid ID
                     @cSKU        	= @cMvSKU,
                     @nQTY        	= @nMvQty,
                     @nQTYAlloc     = @nQtyAlloc,
                     @nQTYPick      = @nQtyPick, 
			            @nFunc   		= @nFunc,
			            @cCaseID       = @cPack_LblNo
               ELSE
                  EXECUTE rdt.rdt_Move
                     @nMobile     	= @nMobile,
                     @cLangCode   	= @cLangCode,
                     @nErrNo      	= @nErrNo  OUTPUT,
                     @cErrMsg     	= @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
                     @cSourceType 	= 'rdt_MoveByLabelNo',
                     @cStorerKey  	= @cStorerKey,
                     @cFacility   	= @cFacility,
                     @cFromLOC    	= @cMvLOC,
                     @cToLOC      	= @cToLOC,
                     @cFromID     	= @cMvID,     -- NULL means not filter by ID. Blank is a valid ID
                     @cToID       	= @cToID,     -- NULL means not changing ID. Blank consider a valid ID
                     @cSKU        	= @cMvSKU,
                     @nQTY        	= @nMvQty,
                     @nQTYAlloc     = @nQtyAlloc,
                     @nQTYPick      = @nQtyPick, 
			            @nFunc   		= @nFunc,
			            @cDropID       = @cPack_LblNo
               
               
               IF @nErrNo <> 0
                  GOTO RollBackTran

            	FETCH NEXT FROM @curMoveId INTO @cMvLOC, @cMvID, @cMvSKU, @nMvQty
            END
         END
      END
      
      /*--------------------------------------------------------------------------------------------------

                                                  ExtendedUpdate

      --------------------------------------------------------------------------------------------------*/
      DECLARE @cExtendedUpdateSP NVARCHAR( 20)
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)
      IF @cExtendedUpdateSP = '0'
         SET @cExtendedUpdateSP = ''
      
      -- LabelNo extended validation
      IF @cExtendedUpdateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC ' + RTRIM( @cExtendedUpdateSP) + 
               ' @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cPickSlipNo, @cFromLabelNo, @cToLabelNo, @cCartonType, @cSKU, @nQTY_Move, ' + 
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT'
            SET @cSQLParam =
               '@nMobile       INT,        ' +
               '@nFunc         INT,        ' +
               '@cLangCode     NVARCHAR(3),    ' +
               '@cUserName     NVARCHAR( 18),  ' + 
               '@cFacility     NVARCHAR( 5),   ' + 
               '@cStorerKey    NVARCHAR( 15),  ' + 
               '@cPickSlipNo   NVARCHAR( 10),  ' + 
               '@cFromLabelNo  NVARCHAR( 20),  ' + 
               '@cToLabelNo    NVARCHAR( 20),  ' + 
               '@cCartonType   NVARCHAR( 10),  ' + 
               '@cSKU          NVARCHAR( 20),  ' + 
               '@nQTY_Move     INT,        ' + 
               '@nErrNo        INT OUTPUT, ' +  
               '@cErrMsg       NVARCHAR( 20) OUTPUT'
         
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
               @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility, @cStorerKey, @cPickSlipNo, @cFromLabelNo, @cToLabelNo, @cCartonType, @cSKU, @nQTY_Move, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO RollBackTran
         END
      END

      IF @n_debug = 1
      BEGIN
         SET @c_TraceName = LEFT( 
            'rdt_MoveByLabelNo' + 
            ' F=' + RTRIM( @cFromLabelNo) + 
            ' T=' + RTRIM( @cToLabelNo) + 
            ' S=' + RTRIM( @cSKU) + 
            ' Q=' + CAST( @nQTY_Move AS NVARCHAR( 5)), 80)

         SET @d_endtime = GETDATE()
         SET @d_total = @d_endtime - @d_starttime
         SET @n_total = @n_step1 + @n_step2 + @n_step3 + @n_step4 + @n_step5 + @n_step6 + @n_step7 + @n_step8 + @n_step9 + @n_step10

         INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)
         VALUES ( @c_TraceName ,@d_starttime, @d_endtime,
            RIGHT( CONVERT( NVARCHAR( 12), @d_total, 114), 8) + '-' + CAST( @n_total AS NVARCHAR( 3)),
            RIGHT( CONVERT( NVARCHAR( 12), @d_step1, 114), 8) + '-' + CAST( @n_step1 AS NVARCHAR( 3)),
            RIGHT( CONVERT( NVARCHAR( 12), @d_step2, 114), 8) + '-' + CAST( @n_step2 AS NVARCHAR( 3)),
            RIGHT( CONVERT( NVARCHAR( 12), @d_step3, 114), 8) + '-' + CAST( @n_step3 AS NVARCHAR( 3)),
            RIGHT( CONVERT( NVARCHAR( 12), @d_step4, 114), 8) + '-' + CAST( @n_step4 AS NVARCHAR( 3)),
            RIGHT( CONVERT( NVARCHAR( 12), @d_step5, 114), 8) + '-' + CAST( @n_step5 AS NVARCHAR( 3)),
            RIGHT( CONVERT( NVARCHAR( 12), @d_step6, 114), 8) + '-' + CAST( @n_step6 AS NVARCHAR( 3)),
            RIGHT( CONVERT( NVARCHAR( 12), @d_step7, 114), 8) + '-' + CAST( @n_step7 AS NVARCHAR( 3)),
            RIGHT( CONVERT( NVARCHAR( 12), @d_step8, 114), 8) + '-' + CAST( @n_step8 AS NVARCHAR( 3)),
            RIGHT( CONVERT( NVARCHAR( 12), @d_step9, 114), 8) + '-' + CAST( @n_step9 AS NVARCHAR( 3)),
            RIGHT( CONVERT( NVARCHAR( 12), @d_step10,114), 8) + '-' + CAST( @n_step10 AS NVARCHAR( 3)))
      END

      COMMIT TRAN rdt_MoveByLabelNo -- Only commit change made in rdt_MoveByLabelNo
      GOTO Quit

      RollBackTran:
         ROLLBACK TRAN rdt_MoveByLabelNo -- Only rollback change made in rdt_MoveByLabelNo
      Quit:
         -- Commit until the level we started
         WHILE @@TRANCOUNT > @nTranCount
            COMMIT TRAN
   END
Fail:
END

GO