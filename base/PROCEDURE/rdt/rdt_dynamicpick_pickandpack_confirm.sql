SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_DynamicPick_PickAndPack_Confirm                       */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: Get next location for Pick And Pack function                      */
/*                                                                            */
/* Called from: rdtfnc_DynamicPick_PickAndPack                                */
/*                                                                            */
/* Exceed version: 5.4                                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 19-Jun-2008 1.0  UngDH       Created                                       */
/* 27-Aug-2008 1.1  James       Add Trafficcop = NULL when update             */
/*                              PickDetail                                    */
/* 30-Oct-2008 1.2  Vicky       Add Trace Steps                               */
/* 03-Mar-2009 1.3  James       Modified by Shong to prevent multiple         */
/*                              labels in a carton                            */
/* 11-Nov-2011 1.4  Ung         SOS 230234 Remove restrict pick FCP           */
/*                              Stamp LabelNo on PackDetail.DropID            */
/*                              Stamp LabelNo on PickDetail.DropID            */
/*                              Insert RefKeyLookup                           */
/*                              Support short pick zero QTY                   */
/*                              Add event log                                 */
/* 22-Apr-2012 1.5  Shong       Confirm Pack when no more to pick             */
/* 02-May-2013 1.6  Ung         Expand DropID to 20 chars                     */
/* 10-Jan-2014 1.7  Ung         Fix same cartonno different labelno           */
/* 16-Jul-2014 1.8  Ung         SOS316336 Check PickDetail offset bal         */
/* 15-Oct-2014 1.9  Ung         SOS323013 Update EditWho/date prevent Deadlock*/
/* 05-Feb-2015 2.0  Ung         SOS318713 Book CartonNo only upon save        */
/*                              Performance tuning                            */
/* 28-Jul-2016 2.1  Ung         SOS375224 Add LoadKey, Zone optional          */
/* 06-Jan-2020 2.2  Chermaine   WMS-11660 add eventLog (cc01)                 */
/* 10-Dec-2021 2.3  Chermaine   WMS-18454 Add ConfirmSP config (cc02)         */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_DynamicPick_PickAndPack_Confirm] (
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

   DECLARE @nTranCount	INT,
		@nQTY_Bal			INT,
		@nQTY_PD				INT,
		@cPickDetailKey   NVARCHAR( 10),
		@b_success			INT,
		@n_err				INT,
		@c_errmsg		   NVARCHAR( 250),
		@cConfirmSP       NVARCHAR( 20),  --(cc02)
		@cSQL             NVARCHAR( MAX), --(cc02)
		@cSQLParam        NVARCHAR( MAX)  --(cc02)
   DECLARE @curPD CURSOR

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
   SET @d_starttime = getdate()

   SET @cConfirmSP = rdt.rdtGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)

/***********************************************************************************************
                                          Custom confirmSP
***********************************************************************************************/
   -- Lookup by SP
   IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmSP AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
         ' @cPickSlipType, @cPickSlipNo, @cPickZone, @cLOC, @cSKU, ' +
         ' @cLottable01, @cLottable02, @cLottable03, @dLottable04, ' +
         ' @nQTY, @cShort, @nCartonNo, @cLabelNo, ' +
         ' @nErrNo OUTPUT, @cErrMsg OUTPUT  '

      SET @cSQLParam =
         ' @nMobile       INT,             ' +
         ' @nFunc         INT,             ' +
         ' @cLangCode     NVARCHAR( 3),    ' +
         ' @nStep         INT,             ' +
         ' @nInputKey     INT,             ' +
         ' @cFacility     NVARCHAR( 5),    ' +
         ' @cStorerKey    NVARCHAR( 15),   ' +
         ' @cPickSlipType NVARCHAR( 10),   ' +
         ' @cPickSlipNo   NVARCHAR( 10),   ' +
         ' @cPickZone     NVARCHAR( 10),   ' +
         ' @cLOC          NVARCHAR( 10),   ' +
         ' @cSKU          NVARCHAR( 20),   ' +
         ' @cLottable01   NVARCHAR( 18),   ' +
         ' @cLottable02   NVARCHAR( 18),   ' +
         ' @cLottable03   NVARCHAR( 18),   ' +
         ' @dLottable04   DATETIME,        ' +
         ' @nQTY          INT,             ' +
         ' @cShort        NVARCHAR( 1),    ' +
         ' @nCartonNo     INT,             ' +
         ' @cLabelNo      NVARCHAR( 20),   ' +
         ' @nErrNo        INT           OUTPUT,  ' +
         ' @cErrMsg       NVARCHAR( 20) OUTPUT   '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
         @cPickSlipType, @cPickSlipNo, @cPickZone, @cLOC, @cSKU,
         @cLottable01, @cLottable02, @cLottable03, @dLottable04,
         @nQTY, @cShort, @nCartonNo, @cLabelNo,
         @nErrNo OUTPUT, @cErrMsg OUTPUT

      GOTO Quit
   END
/***********************************************************************************************
                                             Standard confirmSP
***********************************************************************************************/

   SET @c_TraceName = 'rdt_DynamicPick_PickAndPack_Confirm'


   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN DynamicPick_PickAndPack_Confirm -- For rollback or commit only our own transaction

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
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            Status = '3',
            DropID = @cLabelNo,
            TrafficCop = NULL,
            EditDate = GetDate(),
            EditWho  = sUser_sName()
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 64701
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
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET
            Status = '3',
            DropID = @cLabelNo,
            TrafficCop = NULL,
            EditDate = GetDate(),
            EditWho  = sUser_sName()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 64702
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
               EditWho  = sUser_sName()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 64711
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDtlFail'
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN -- Have balance, need to split
            SET @d_step4 = GETDATE()
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
               SET @nErrNo = 64703
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GetDetKey Fail'
               GOTO RollBackTran
            END

           SET @d_step4 = GETDATE() - @d_step4

           SET @d_step5 = GETDATE()

            -- Create new a PickDetail to hold the balance
            INSERT INTO dbo.PICKDETAIL (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo,
               PickDetailKey,
               QTY,
               Status,
               TrafficCop,
               OptimizeCop)
            SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
               CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo,
               @cNewPickDetailKey,
               @nQTY_PD - @nQTY_Bal, -- QTY
               CASE WHEN @cShort = 'Y' THEN '4' ELSE '0' END, -- Status
               NULL, --TrafficCop,
               '1'  --OptimizeCop
            FROM dbo.PickDetail WITH (NOLOCK)
   			WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
   				SET @nErrNo = 64704
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
                  SET @nErrNo = 64710
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                  GOTO RollBackTran
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
               SET @nErrNo = 64705
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDtlFail'
               GOTO RollBackTran
            END

            -- Confirm orginal PickDetail with exact QTY
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
               Status = '3',
               TrafficCop = NULL,
               EditDate = GetDate(),
               EditWho  = sUser_sName()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 64706
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPickDtlFail'
               GOTO RollBackTran
            END

            SET @d_step5 = GETDATE() - @d_step5

            SET @nQTY_Bal = 0 -- Reduce balance
         END
      END

      SET @d_endtime = GETDATE()
--      INSERT INTO TraceInfo VALUES
--		   (RTRIM(@c_TraceName), @d_starttime, @d_endtime
--		   ,CONVERT(CHAR(12),@d_endtime - @d_starttime ,114)
--		   ,CONVERT(CHAR(12),@d_step1,114)
--		   ,CONVERT(CHAR(12),@d_step2,114)
--		   ,CONVERT(CHAR(12),@d_step3,114)
--		   ,CONVERT(CHAR(12),@d_step4,114)
--		   ,CONVERT(CHAR(12),@d_step5,114)
--         ,@c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5)

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
      SET @nErrNo = 64712
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
               SET @nErrNo = 64713
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
               SET @nErrNo = 64713
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
               SET @nErrNo = 64713
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
         SET @nErrNo = 64709
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
            SET @nErrNo = 64707
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
            SET @nErrNo = 64708
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
         SET @nErrNo = 64708
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd DPL Fail'
         GOTO RollBackTran
      END
   END

   COMMIT TRAN DynamicPick_PickAndPack_Confirm

   DECLARE @cUOM NVARCHAR( 10)
   SELECT @cUOM = Pack.PackUOM3
   FROM dbo.Pack WITH (NOLOCK)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   WHERE SKU.StorerKey = @cStorerKey
      AND SKU.SKU = @cSKU

   DECLARE @cUserName NVARCHAR(18)
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
   ROLLBACK TRAN DynamicPick_PickAndPack_Confirm
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO