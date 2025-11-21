SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************************/
/* Store procedure: rdt_950ConfirmSP02                                             */
/* Copyright      : Maersk                                                         */
/*                                                                                 */
/* Purpose: Confirm for Dynamic Pick And Pack function                             */
/*                                                                                 */
/* Called from: rdtfnc_DynamicPick_PickAndPack -->                                 */
/*              rdt_DynamicPick_PickAndPack_Confirm                                */
/*                                                                                 */
/* Exceed version: 5.4                                                             */
/*                                                                                 */
/* Modifications log:                                                              */
/*                                                                                 */
/* Date        Rev  Author      Purposes                                           */
/* 2023-08-28  1.0  Michael     WMS-22459 - AU ADIDAS RDT950 DynamicPICKandPACK    */
/***********************************************************************************/

CREATE   PROC [RDT].[rdt_950ConfirmSP02] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPickSlipType NVARCHAR( 10),
   @cPickSlipNo   NVARCHAR( 10),
   @cPickZone     NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cSKU          NVARCHAR( 20),
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @nQTY          INT,
   @cShort        NVARCHAR( 1),
   @nCartonNo     INT,
   @cLabelNo      NVARCHAR( 20),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT,
      @nQTY_Bal         INT,
      @nQTY_PD          INT,
      @nQTY_Act         INT,
      @cPickDetailKey   NVARCHAR( 10),
      @nRowRef          INT,
      @b_success        INT,
      @n_err            INT,
      @c_errmsg         NVARCHAR( 250),
      @c_Orderkey       NVARCHAR(10)
   DECLARE @curPD CURSOR
   DECLARE @cNewPickDetailKey NVARCHAR( 10)

   DECLARE @cSQL               NVARCHAR(MAX)
         , @cSQLParm           NVARCHAR(MAX)
         , @cCartonType        NVARCHAR(30) = ''
         , @cUpdateWGT         NVARCHAR(30) = ''
         , @cUpdateWGTFactor   NVARCHAR(30) = ''
         , @cPickConfirmStatus NVARCHAR(30) = ''
         , @cAutoShort         NVARCHAR(30) = ''
         , @cUpdateShortedWho  NVARCHAR(30) = ''
         , @cGenCarrierMWITF   NVARCHAR(30) = ''
         , @nCartonLength      FLOAT
         , @nCartonWidth       FLOAT
         , @nCartonHeight      FLOAT
         , @nCube              FLOAT
         , @nWeight            FLOAT
         , @cWeightField       NVARCHAR(500) = ''
         , @bCtnTypeFound      INT

   -- TraceInfo
   DECLARE    @d_starttime    datetime,
              @d_endtime      datetime,
              @d_step1        datetime,
              @d_step2        datetime,
              @d_step3        datetime,
              @d_step4        datetime,
              @d_step5        datetime,
              @c_col1         NVARCHAR(20),
              @c_col2         NVARCHAR(20),
              @c_col3         NVARCHAR(20),
              @c_col4         NVARCHAR(20),
              @c_col5         NVARCHAR(20),
              @c_TraceName    NVARCHAR(80)

   SET @c_col1 = @cPickSlipNo
   SET @c_col2 = @cLOC
   SET @c_col3 = @cSKU
   SET @c_col4 = @nCartonNo
   SET @c_col5 = @cLabelNo
   SET @d_starttime = GETDATE()

   DECLARE @cUsername NVARCHAR(128)

   SELECT
      @cUsername = userName
   FROM rdt.rdtmobrec WITH (NOLOCK)
   WHERE mobile = @nMobile

   SET @c_TraceName = 'rdt_950ConfirmSP02'


   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_950ConfirmSP02 -- For rollback or commit only our own transaction


   SET @cCartonType = rdt.RDTGetConfig( @nFunc, 'DynamicPickDefaultCTN', @cStorerKey)
   IF @cCartonType = '0'
      SET @cCartonType = ''
   SET @cUpdateWGT  = rdt.RDTGetConfig( @nFunc, 'UpdateWGT', @cStorerKey)
   IF @cUpdateWGT  = '0'
      SET @cUpdateWGT = ''
   SET @cUpdateWGTFactor  = rdt.RDTGetConfig( @nFunc, 'UpdateWGTFactor', @cStorerKey)
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF ISNULL(@cPickConfirmStatus,'') <> '5'
      SET @cPickConfirmStatus = '3'
   SET @cAutoShort  = rdt.RDTGetConfig( @nFunc, 'AutoShort', @cStorerKey)
   SET @cUpdateShortedWho = rdt.RDTGetConfig( @nFunc, 'UpdateShortedWho', @cStorerKey)
   SET @cGenCarrierMWITF = rdt.RDTGetConfig( @nFunc, 'GenCarrierMWITF', @cStorerKey)


   IF ISNULL(@cUpdateWGT,'') <> ''
   BEGIN
      DECLARE @cFieldName NVARCHAR(500) = ''
      SELECT @cFieldName = CASE WHEN NUMERIC_PRECISION IS NOT NULL THEN COLUMN_NAME
                                WHEN DATA_TYPE IN ('varchar', 'nvarchar', 'char', 'nchar') THEN 'TRY_PARSE(ISNULL(' + COLUMN_NAME + ','''') AS FLOAT)'
                                ELSE ''
                           END
        FROM INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK)
       WHERE TABLE_SCHEMA = 'dbo'
         AND TABLE_NAME = 'SKU'
         AND COLUMN_NAME = CASE WHEN @cUpdateWGT='1' THEN 'STDGROSSWGT' ELSE @cUpdateWGT END

      SET @cWeightField = @cFieldName
      IF @cWeightField<>'' AND @cUpdateWGTFactor<>'' AND TRY_PARSE(ISNULL(@cUpdateWGTFactor,'') AS FLOAT) IS NOT NULL
      BEGIN
         SET @cWeightField = @cWeightField + ' * CAST(' + TRIM(@cUpdateWGTFactor) + ' AS FLOAT)'
      END
   END

   /*-------------------------------------------------------------------------------

                                     PickDetail

   -------------------------------------------------------------------------------*/
   -- For calculation
   SET @nQTY_Bal = @nQTY

   SET @d_step1 = GETDATE()

   -- Cross dock PickSlip
   IF @cPickSlipType = 'X'
      -- Get PickDetail candidate
      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey, PD.QTY
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         WHERE RKL.PickSlipNo = @cPickSlipNo
            AND PD.StorerKey  = @cStorerKey
            AND PD.SKU        = @cSKU
            AND PD.Loc        = @cLOC
            AND LA.Lottable01 = @cLottable01
            AND LA.Lottable02 = @cLottable02
            AND LA.Lottable03 = @cLottable03
            AND PD.Status < '3' --5=Picked
            AND PD.QTY > 0
         ORDER BY PD.PickDetailKey

   -- Discrete PickSlip
   ELSE IF @cPickSlipType = 'D'
   BEGIN
      -- Get PickDetail candidate
      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey, PD.QTY
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         WHERE PH.PickHeaderKey = @cPickSlipNo
            AND PD.StorerKey  = @cStorerKey
            AND PD.SKU        = @cSKU
            AND PD.Loc        = @cLOC
            AND LA.Lottable01 = @cLottable01
            AND LA.Lottable02 = @cLottable02
            AND LA.Lottable03 = @cLottable03
            AND PD.Status < '3' --5=Picked
            AND PD.QTY > 0
         ORDER BY PD.PickDetailKey
   END
   -- Conso PickSlip
   ELSE IF @cPickSlipType = 'C'
      -- Get PickDetail candidate
      DECLARE curPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey, PD.QTY
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
         WHERE PH.PickHeaderKey = @cPickSlipNo
            AND PD.StorerKey  = @cStorerKey
            AND PD.SKU        = @cSKU
            AND PD.Loc        = @cLOC
            AND LA.Lottable01 = @cLottable01
            AND LA.Lottable02 = @cLottable02
            AND LA.Lottable03 = @cLottable03
            AND PD.Status < '3' --5=Picked
            AND PD.QTY > 0
         ORDER BY PD.PickDetailKey

   OPEN curPD
   SET @d_step1 = GETDATE() - @d_step1
   FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Exact match
      IF @nQTY_PD = @nQTY_Bal
      BEGIN

         SET @d_step2 = GETDATE()

         -- Confirm PickDetail
         SET @cSQL = N'UPDATE dbo.PickDetail WITH (ROWLOCK) SET'
           +  ' Status = ''' + ISNULL(REPLACE(@cPickConfirmStatus,'''',''''''),'') + ''''
           + ', DropID = ''' + ISNULL(REPLACE(@cLabelNo,'''',''''''),'') + ''''
           + ', EditDate = GetDate()'
           + ', EditWho  = sUser_sName()'
           + CASE WHEN @cPickConfirmStatus < '5' THEN ', TrafficCop = NULL' ELSE '' END
           + ' WHERE PickDetailKey = ''' + ISNULL(REPLACE(@cPickDetailKey,'''',''''''),'') + ''''

         EXEC sp_ExecuteSQL @cSQL

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 205651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDtlFail'
            GOTO RollBackTran
         END

         SET @d_step2 = GETDATE() - @d_step2

         SET @nQTY_Bal = 0 -- Reduce balance
      END

      -- PickDetail have less
      ELSE IF @nQTY_PD < @nQTY_Bal
      BEGIN
         SET @d_step3 = GETDATE()
         -- Confirm PickDetail
         SET @cSQL = N'UPDATE dbo.PickDetail WITH (ROWLOCK) SET'
           +  ' Status = ''' + ISNULL(REPLACE(@cPickConfirmStatus,'''',''''''),'') + ''''
           + ', DropID = ''' + ISNULL(REPLACE(@cLabelNo,'''',''''''),'') + ''''
           + ', EditDate = GetDate()'
           + ', EditWho  = sUser_sName()'
           + CASE WHEN @cPickConfirmStatus < '5' THEN ', TrafficCop = NULL' ELSE '' END
           + ' WHERE PickDetailKey = ''' + ISNULL(REPLACE(@cPickDetailKey,'''',''''''),'') + ''''

         EXEC sp_ExecuteSQL @cSQL

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 205652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDtlFail'
            GOTO RollBackTran
         END

         SET @d_step3 = GETDATE() - @d_step3

         SET @nQTY_Bal = @nQTY_Bal - @nQTY_PD -- Reduce balance
      END

      -- PickDetail have more
      ELSE IF @nQTY_PD > @nQTY_Bal
      BEGIN
         -- Short pick
         IF @nQTY_Bal = 0 -- Don't need to split
         BEGIN
            -- Confirm PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               Status = CASE WHEN @cShort = 'Y' THEN '4' ELSE '0' END,
               DropID = @cLabelNo,
               EditDate = GetDate(),
               EditWho  = sUser_sName(),
               Notes = CASE WHEN @cShort = 'Y' AND @cUpdateShortedWho = '1' THEN 'FN950-Shorted-'+sUser_sName()+'@'+CONVERT(VARCHAR(30),GETDATE(),121) ELSE Notes END
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 205653
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDtlFail'
               GOTO RollBackTran
            END

            IF @cShort = 'Y' AND @cAutoShort = '1'
            BEGIN
               DELETE dbo.PickDetail WITH (ROWLOCK) WHERE PickDetailKey = @cPickDetailKey AND Status = '4'
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 205654
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DelPickDtlFail'
                  GOTO RollBackTran
               END
            END
         END
         ELSE
         BEGIN -- Have balance, need to split
            SET @d_step4 = GETDATE()
            -- Get new PickDetailkey
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10 ,
               @cNewPickDetailKey OUTPUT,
               @b_success         OUTPUT,
               @n_err             OUTPUT,
               @c_errmsg          OUTPUT
            IF @b_success <> 1
            BEGIN
               SET @nErrNo = 205655
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GetDetKey Fail'
               GOTO RollBackTran
            END

           SET @d_step4 = GETDATE() - @d_step4

           SET @d_step5 = GETDATE()

            -- Create new a PickDetail to hold the balance
            -- No need to insert shorted pickdetail if AutoShort enabled
            IF NOT (@cShort = 'Y' AND @cAutoShort = '1')
            BEGIN
               INSERT INTO dbo.PICKDETAIL (
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
                  UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo,
                  PickDetailKey,
                  QTY,
                  Status,
                  TrafficCop,
                  OptimizeCop,
                  Notes)
               SELECT
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
                  UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
                  CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo,
                  @cNewPickDetailKey,
                  @nQTY_PD - @nQTY_Bal, -- QTY
                  CASE WHEN @cShort = 'Y' THEN '4' ELSE '0' END, -- Status
                  NULL, --TrafficCop,
                  '1',  --OptimizeCop
                  CASE WHEN @cShort = 'Y' AND @cUpdateShortedWho = '1' THEN 'FN950-Shorted-'+sUser_sName()+'@'+CONVERT(VARCHAR(30),GETDATE(),121) END
               FROM dbo.PickDetail WITH (NOLOCK)
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 205656
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PDtl Fail'
                  GOTO RollBackTran
               END

               -- Split RefKeyLookup
               IF EXISTS( SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @cPickDetailKey)
               BEGIN
                  -- Insert into
                  INSERT INTO dbo.RefKeyLookup (PickDetailkey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey)
                  SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, Loadkey
                  FROM RefKeyLookup WITH (NOLOCK)
                  WHERE PickDetailKey = @cPickDetailKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 205657
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'INS RefKeyFail'
                     GOTO RollBackTran
                  END
               END
            END

            -- Change orginal PickDetail with exact QTY (with TrafficCop)
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               QTY = @nQTY_Bal,
               DropID = @cLabelNo,
               Trafficcop = NULL,
               EditDate = GetDate(),
               EditWho  = sUser_sName()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 205658
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDtlFail'
               GOTO RollBackTran
            END

            -- Confirm orginal PickDetail with exact QTY
            SET @cSQL = N'UPDATE dbo.PickDetail WITH (ROWLOCK) SET'
              +  ' Status = ''' + ISNULL(REPLACE(@cPickConfirmStatus,'''',''''''),'') + ''''
              + ', EditDate = GetDate()'
              + ', EditWho  = sUser_sName()'
              + CASE WHEN @cPickConfirmStatus < '5' THEN ', TrafficCop = NULL' ELSE '' END
              + ' WHERE PickDetailKey = ''' + ISNULL(REPLACE(@cPickDetailKey,'''',''''''),'') + ''''

            EXEC sp_ExecuteSQL @cSQL

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 205659
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDtlFail'
               GOTO RollBackTran
            END

            SET @d_step5 = GETDATE() - @d_step5

            SET @nQTY_Bal = 0 -- Reduce balance
         END
      END

      SET @d_endtime = GETDATE()
--       INSERT INTO TraceInfo VALUES
--       (RTRIM(@c_TraceName), @d_starttime, @d_endtime
--       ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)
--       ,CONVERT(CHAR(12),@d_step1,114)
--       ,CONVERT(CHAR(12),@d_step2,114)
--       ,CONVERT(CHAR(12),@d_step3,114)
--       ,CONVERT(CHAR(12),@d_step4,114)
--       ,CONVERT(CHAR(12),@d_step5,114)
--       ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)

      SET @d_step1 = NULL
      SET @d_step2 = NULL
      SET @d_step3 = NULL
      SET @d_step4 = NULL
      SET @d_step5 = NULL

      IF @nQTY_Bal = 0 AND @cShort = 'N'
         BREAK -- Exit

      FETCH NEXT FROM curPD INTO @cPickDetailKey, @nQTY_PD
   END
   CLOSE curPD
   DEALLOCATE curPD

   -- Check PickDetail offset balance
   IF @nQTY_Bal <> 0
   BEGIN
      SET @nErrNo = 205660
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NotFullyOffset'
      GOTO RollBackTran
   END


   /*-------------------------------------------------------------------------------

                        Pick confirm if all tasks in the LOC is done

   -------------------------------------------------------------------------------*/
   -- Cross dock PickSlip
   IF @cPickSlipType = 'X'
   BEGIN
      IF NOT EXISTS( SELECT 1
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
         WHERE RKL.PickSlipNo = @cPickSlipNo
            AND PD.LOC = @cLOC
            AND PD.Status < '3')
      BEGIN
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.PickDetailKey
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
              AND Status = '3'
              AND LOC = @cLOC
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE PickDetail SET
               Status = '5',
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 205661
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END
      END
   END

   -- Discrete PickSlip
   ELSE IF @cPickSlipType = 'D'
   BEGIN
      IF NOT EXISTS( SELECT 1
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
         WHERE PH.PickHeaderKey = @cPickSlipNo
            AND PD.LOC = @cLOC
            AND PD.Status < '3')
      BEGIN
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.PickDetailKey
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
            WHERE PH.PickHeaderKey = @cPickSlipNo
               AND PD.LOC = @cLOC
               AND PD.Status = '3'
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE PickDetail SET
               Status = '5',
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 205662
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END
      END
   END

   -- Conso PickSlip
   ELSE IF @cPickSlipType = 'C'
   BEGIN
      IF NOT EXISTS( SELECT 1
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
         WHERE PH.PickHeaderKey = @cPickSlipNo
            AND PD.LOC = @cLOC
            AND PD.Status < '3')
      BEGIN
         SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.PickDetailKey
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            WHERE PH.PickHeaderKey = @cPickSlipNo
               AND PD.LOC = @cLOC
               AND PD.Status = '3'
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE PickDetail SET
               Status = '5',
               EditDate = GETDATE(),
               EditWho  = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 205663
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END
      END
   END

   /*-------------------------------------------------------------------------------

                                     PackDetail

   -------------------------------------------------------------------------------*/
   IF @nQTY = 0 GOTO Quit

   -- Update PackDetail
   IF EXISTS (SELECT 1 FROM dbo.PackDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND Pickslipno = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo
         AND SKU = '')
   BEGIN
      -- Update Packdetail
      UPDATE dbo.PackDetail WITH (ROWLOCK) SET
         ArchiveCop = NULL,
         EditWho = 'rdt.' + sUser_sName(),
         EditDate = GETDATE(),
         SKU = @cSKU,
         QTY = QTY + @nQTY,
         DropID = CASE WHEN DropID = '' THEN @cLabelNo ELSE DropID END
      WHERE PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND LabelNo = @cLabelNo
         AND SKU = ''

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 205664
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      IF NOT EXISTS (SELECT 1
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo
            AND SKU = @cSKU)
      BEGIN
         -- Get next LabelLine
         DECLARE @cLabelLine NVARCHAR( 5)
         SELECT @cLabelLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( LabelLine), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
         FROM dbo.PackDetail (NOLOCK)
         WHERE Pickslipno = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo

         -- Insert PackDetail
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, DropID)
         VALUES
            (@cPickSlipNo, @nCartonNo, @cLabelNo, @cLabelLine, @cStorerKey, @cSKU, @nQTY, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE(), @cLabelNo)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 205665
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPackDtlFail'
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         -- Update Packdetail
         UPDATE dbo.PackDetail WITH (ROWLOCK) SET
            ArchiveCop = NULL,
            EditWho = 'rdt.' + sUser_sName(),
            EditDate = GETDATE(),
            QTY = QTY + @nQTY,
            DropID = CASE WHEN DropID = '' THEN @cLabelNo ELSE DropID END
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = @nCartonNo
            AND LabelNo = @cLabelNo
            AND SKU = @cSKU
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 205666
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPackDtlFail'
            GOTO RollBackTran
         END
      END
   END

   IF @nCartonNo = 0
   BEGIN
      SELECT TOP 1
         @nCartonNo = CartonNo
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
         AND AddWho = 'rdt.' + SUSER_SNAME()
      ORDER BY CartonNo DESC

      UPDATE rdt.rdtDynamicPickLog SET
         CartonNo = @nCartonNo
      WHERE PickSlipNo = @cPickSlipNo
         AND LabelNo = @cLabelNo
         AND AddWho = SUSER_SNAME()
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 205667
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd DPL Fail'
         GOTO RollBackTran
      END
   END

   /*-------------------------------------------------------------------------------

                                     PackInfo

   -------------------------------------------------------------------------------*/
   IF @nQTY = 0 GOTO Quit

   IF @nCartonNo <> 0
   BEGIN
      -- Get default Carton Type and dimension
      IF ISNULL(@cCartonType,'') <> ''
      BEGIN
         SET @nWeight = 0

         IF ISNULL(@cWeightField,'') <> ''
         BEGIN
            SET @cSQL = N'SELECT @nWeight = ISNULL(@nQTY,0) * ISNULL(' + @cWeightField + ',0.0) FROM dbo.SKU (NOLOCK) WHERE Storerkey = @cStorerkey AND Sku = @cSku'
            SET @cSQLParm = N'@nQTY  INT'
                          +', @cStorerkey NVARCHAR(15)'
                          +', @cSku NVARCHAR(20)'
                          +', @nWeight FLOAT OUTPUT'
            EXEC sp_ExecuteSQL @cSQL, @cSQLParm, @nQTY, @cStorerkey, @cSku, @nWeight OUTPUT
         END
         ELSE IF ISNULL(@cUpdateWGT,'') <> ''
         BEGIN
            SET @nErrNo = 205672
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Bad UpdateWGT'
            GOTO RollBackTran
         END

         -- Update PackInfo
         IF NOT EXISTS(SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
            WHERE Pickslipno = @cPickSlipNo
              AND CartonNo = @nCartonNo)
         BEGIN
            SET @bCtnTypeFound = 0
            SELECT @nCartonLength = CT.CartonLength
                 , @nCartonWidth  = CT.CartonWidth
                 , @nCartonHeight = CT.CartonHeight
                 , @nCube         = CT.Cube
                 , @bCtnTypeFound = 1
            FROM dbo.Storer ST WITH (NOLOCK)
            JOIN dbo.CARTONIZATION CT WITH (NOLOCK) ON ST.CartonGroup = CT.CartonizationGroup
            WHERE ST.Storerkey = @cStorerkey
              AND CT.CartonType = @cCartonType

            IF @bCtnTypeFound = 0
            BEGIN
               SET @nErrNo = 205668
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidCtnType'
               GOTO RollBackTran
            END

            INSERT INTO dbo.PackInfo WITH (ROWLOCK)
                  ( PickSlipNo, CartonNo, CartonType, Length, Width, Height, Cube, Weight, AddWho, AddDate, EditWho, EditDate )
            VALUES( @cPickSlipNo, @nCartonNo, @cCartonType, @nCartonLength, @nCartonWidth, @nCartonHeight, @nCube,
                    CASE WHEN @cWeightField<>'' THEN @nWeight ELSE 0 END, 'rdt.' + sUser_sName(), GETDATE(), 'rdt.' + sUser_sName(), GETDATE() )
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 205669
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsPckInfoFail'
               GOTO RollBackTran
            END

            IF @cGenCarrierMWITF = 1
            BEGIN
               SET @c_Orderkey = ''
               SELECT @c_Orderkey = Orderkey
                 FROM dbo.PackHeader WITH (NOLOCK)
                WHERE PickslipNo = @cPickSlipNo
               
               IF ISNULL(@c_Orderkey,'')<>''
               BEGIN
                  EXEC isp_Carrier_Middleware_Interface @c_OrderKey, '', @nFunc, @nCartonNo, @nStep, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT
                  IF @b_Success = 0
                  BEGIN
                     SET @nErrNo = 205670
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GenTLogFail'
                     GOTO RollBackTran
                  END
               END
            END
         END
         ELSE
         BEGIN
            UPDATE dbo.PackInfo WITH (ROWLOCK)
               SET Weight   = ISNULL(Weight,0) + CASE WHEN @cWeightField<>'' THEN @nWeight ELSE 0 END
                 , EditWho  = 'rdt.' + sUser_sName()
                 , EditDate = GETDATE()
                 , ArchiveCop = NULL
            WHERE Pickslipno = @cPickSlipNo
              AND CartonNo = @nCartonNo
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 205671
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPckInfoFail'
               GOTO RollBackTran
            END
         END
      END
   END


   COMMIT TRAN rdt_950ConfirmSP02

   DECLARE @cUOM NVARCHAR( 10)
   SELECT @cUOM = Pack.PackUOM3
   FROM dbo.Pack WITH (NOLOCK)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   WHERE SKU.StorerKey = @cStorerKey
      AND SKU.SKU = @cSKU

   SET @cUserName = LEFT( SUSER_SNAME(), 15)
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '3', -- Picking
      @cUserID       = @cUserName,
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerKey,
      @cSKU          = @cSKU,
      @cUOM          = @cUOM,
      @nQTY          = @nQTY,
      @cLottable01   = @cLottable01,
      @cLottable02   = @cLottable02,
      @cLottable03   = @cLottable03,
      @dLottable04   = @dLottable04,
      @cLocation     = @cLOC,
      @cLabelNo      = @cLabelNo,   --(cc01)
      @cID           = @cLabelNo,
      @cRefNo4       = @cPickSlipNo

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_950ConfirmSP02
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO