SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_862PickCfm03                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2014-08-28 1.0  Ung     SOS307606 Created                            */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_862PickCfm03] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 18),
   @cPickSlipNo   NVARCHAR( 10),
   @cDropID       NVARCHAR( 18),
   @cLOC          NVARCHAR( 10),
   @cID           NVARCHAR( 18),
   @cStorerKey    NVARCHAR( 15),
   @cSKU          NVARCHAR( 20),
   @cUOM          NVARCHAR( 10),
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @nTaskQTY      INT,
   @nPQTY         INT,
   @cUCCTask      NVARCHAR( 1),
   @cPickType     NVARCHAR( 1),
   @bSuccess      INT            OUTPUT,
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT,  -- screen limitation, 20 NVARCHAR max
   @nDebug        INT = 0

) AS

   /*
      Finish good, pick by pallet
      Swap criteria: Different LOC, different ID, same SKU, same LOT, different QTY (less or same)
   */

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount         INT
   DECLARE @nTranCount        INT
   DECLARE @cFacility         NVARCHAR(5)
   DECLARE @cUserName         NVARCHAR(18)

   DECLARE @cActSKU           NVARCHAR(20)
   DECLARE @cActLOT           NVARCHAR(10)
   DECLARE @cActLOC           NVARCHAR(10)
   DECLARE @cActID            NVARCHAR(18)
   DECLARE @nActQTY           INT
   DECLARE @nActQTYAlloc      INT
   DECLARE @dActL05           DATETIME

   DECLARE @cNewPickDetailKey NVARCHAR( 10)
   DECLARE @cPickDetailKey    NVARCHAR(10)
   DECLARE @cOrderKey         NVARCHAR(10)
   DECLARE @cOrderLineNumber  NVARCHAR(5)
   DECLARE @cLoadKey          NVARCHAR(10)
   DECLARE @nSuggQTY          INT
   DECLARE @nQTY              INT
   DECLARE @nBal              INT
   DECLARE @cLOT              NVARCHAR(10)
   DECLARE @dLottable05       DATETIME
   DECLARE @curPD CURSOR

   DECLARE @tSuggPD TABLE
   (
      PickDetailKey NVARCHAR( 10) NOT NULL,
      OrderKey      NVARCHAR( 10) NOT NULL,
      LOT           NVARCHAR( 10) NOT NULL,
      QTY           INT           NOT NULL
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )

   DECLARE @tActPD TABLE
   (
      PickDetailKey NVARCHAR( 10) NOT NULL,
      QTY           INT           NOT NULL
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )

   SET @nTranCount = @@TRANCOUNT

   -- Get MobRec info
   SELECT 
      @cFacility = Facility, 
      @cUserName = UserName
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   -- Get Act ID scanned
   SELECT @cActID = I_Field14 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   -- Get Act ID info
   SELECT
      @cActSKU = LLI.SKU,
      @cActLOT = LLI.LOT,
      @cActLOC = LLI.LOC,
      @cActID = LLI.ID,
      @nActQTY = LLI.QTY-LLI.QTYPicked,
      @nActQTYAlloc= LLI.QTYAllocated, 
      @dActL05 = LA.Lottable05
   FROM LOTxLOCxID LLI WITH (NOLOCK)
      JOIN LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
   WHERE LLI.StorerKey = @cStorerKey
      AND LLI.ID = @cActID
      AND LLI.QTY-LLI.QTYPicked > 0

   SET @nRowCount = @@ROWCOUNT

if @nDebug = 1
   select @cActLOT '@cActLOT', @cActLOC '@cActLOC', @cActID '@cActID', @nActQTY '@nActQTY', @nActQTYAlloc '@nActQTYAlloc'

   -- Check ID valid
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 96201
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
      GOTO Quit
   END

   -- Check ID valid
   IF @nRowCount > 1
   BEGIN
      SET @nErrNo = 96202
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IDMultiLOT/LOC
      GOTO Quit
   END

   -- Check LOC type match
   IF @cActLOC <> @cLOC
   BEGIN
      DECLARE @cActLOCType NVARCHAR(10)
      DECLARE @cLOCType NVARCHAR(10)
      SELECT @cActLOCType = LocationType FROM LOC WITH (NOLOCK) WHERE LOC = @cActLOC
      SELECT @cLOCType = LocationType FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC

      IF @cActLOCType <> @cLOCType
      BEGIN
         SET @nErrNo = 96203
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff LOCType
         GOTO Quit
      END
   END

   -- Check SKU match
   IF @cActSKU <> @cSKU
   BEGIN
      SET @nErrNo = 96204
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not match
      GOTO Quit
   END

   -- Get PickHeader info
   DECLARE @cZone NVARCHAR( 18)
   SELECT 
      @cZone = Zone, 
      @cOrderKey = OrderKey, 
      @cLoadKey = ExternOrderKey     
   FROM dbo.PickHeader WITH (NOLOCK)     
   WHERE PickHeaderKey = @cPickSlipNo   

   -- Get suggested PickDetail
   IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP' 
      -- CrossDock PickSlip
      INSERT INTO @tSuggPD (PickDetailKey, OrderKey, LOT, QTY)
      SELECT PD.PickDetailKey, PD.OrderKey, PD.LOT, PD.QTY
      FROM RefKeyLookup WITH (NOLOCK) 
         JOIN PickDetail PD WITH (NOLOCK) ON (RefKeyLookup.PickDetailKey = PD.PickDetailKey)
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
      WHERE RefKeyLookup.PickslipNo = @cPickSlipNo
         AND PD.LOC = @cLOC
         AND PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.ID = @cID
         AND LA.Lottable01 = @cLottable01
         AND LA.Lottable02 = @cLottable02
         AND LA.Lottable03 = @cLottable03
         AND LA.Lottable04 = @dLottable04
         AND PD.Status < '4' -- Not yet picked
         AND PD.QTY > 0

   ELSE IF @cOrderKey = ''
      -- Conso PickDetail
      INSERT INTO @tSuggPD (PickDetailKey, OrderKey, LOT, QTY)
      SELECT PD.PickDetailKey, PD.OrderKey, PD.LOT, PD.QTY
      FROM dbo.PickHeader PH (NOLOCK)
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
      WHERE PH.PickHeaderKey = @cPickSlipNo
         AND PD.LOC = @cLOC
         AND PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.ID = @cID
         AND LA.Lottable01 = @cLottable01
         AND LA.Lottable02 = @cLottable02
         AND LA.Lottable03 = @cLottable03
         AND LA.Lottable04 = @dLottable04
         AND PD.Status < '4' -- Not yet picked
         AND PD.QTY > 0
   ELSE
      -- Discrete PickSlip
      INSERT INTO @tSuggPD (PickDetailKey, OrderKey, LOT, QTY)
      SELECT PD.PickDetailKey, PD.OrderKey, PD.LOT, PD.QTY
      FROM dbo.PickHeader PH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
         JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT)
      WHERE PH.PickHeaderKey = @cPickSlipNo
         AND PD.LOC = @cLOC
         AND PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.ID = @cID
         AND LA.Lottable01 = @cLottable01
         AND LA.Lottable02 = @cLottable02
         AND LA.Lottable03 = @cLottable03
         AND LA.Lottable04 = @dLottable04
         AND PD.Status < '4' -- Not yet picked
         AND PD.QTY > 0

   SELECT @nSuggQTY = ISNULL( SUM( QTY), 0) FROM @tSuggPD
   SELECT 
      @cLOT = LA.LOT, 
      @dLottable05 = LA.Lottable05
   FROM @tSuggPD t
      JOIN LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = t.LOT)

IF @nDebug = 1
   select * from @tSuggPD

   -- Check LOC match
   IF @dActL05 <> @dLottable05
   BEGIN
      IF @nDebug = 1
         select @dActL05, @dLottable05
      SET @nErrNo = 96205
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L05 not match
      GOTO Quit
   END

   -- Check QTY (PickDetail vs Task)
   IF @nSuggQTY <> @nTaskQTY
   BEGIN
      SET @nErrNo = 96206
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
      GOTO Quit
   END
   

   /***********************************************************************************************

                                  Picked ID is the suggested ID

   ***********************************************************************************************/
   BEGIN TRAN                  -- Begin our own transaction
   SAVE TRAN rdt_862PickCfm03  -- For rollback or commit only our own transaction

if @nDebug = 1
   select @cActID '@cActID', @cID '@cID', @nActQTY '@nActQTY', @nSuggQTY '@nSuggQTY'

   IF @cActID = @cID AND @nActQTY >= @nSuggQTY
   BEGIN
      -- Loop suggested
      SET @curPD = CURSOR FOR
         SELECT PickDetailKey FROM @tSuggPD ORDER BY PickDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE PickDetail SET
            Status = '5',
            DropID = @cDropID
         WHERE PickDetailKey = @cPickDetailKey
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
      END
      
      EXEC RDT.rdt_STD_EventLog
          @cActionType   = '3', -- Picking
          @cUserID       = @cUserName,
          @nMobileNo     = @nMobile,
          @nFunctionID   = @nFunc,
          @cFacility     = @cFacility,
          @cStorerKey    = @cStorerKey,
          @cLocation     = @cActLOC,
          @cID           = @cActID,
          @cLOT          = @cLOT,
          @cSKU          = @cSKU,
          @cUOM          = @cUOM,
          @nQTY          = @nPQTY,
          @cRefNo1       = @cPickSlipNo,
          @cRefNo2       = @cDropID,
          @cRefNo3       = @cPickType,
          @cPickSlipNo   = @cPickSlipNo,
          @cDropID       = @cDropID
      
      GOTO Quit
   END


   /***********************************************************************************************

                                 Split PickDetail of suggested, actual

   ***********************************************************************************************/
/*
   suggest = 4-alloc
   actual = 3-free
      split suggest 1-3
      swap actual 3 with suggest 3
   
   suggest = 4-alloc
   actual = 3-alloc
      split suggest 1-3
      swap actual 3 with suggest 3

   suggest = 3-alloc
   actual = 4-free
      swap actual 3 with suggest 3

   suggest = 3-alloc (order 1, id1)
   actual = 4-alloc (order a,b,c,d, id2)
      split actual 1-3 (a-b,c,d)
      swap actual 3 with suggest 3 (id2=3qty, order1. id1=3qty, order b,c,d)

*/
IF @nDebug = 1 
   select @nActQTY '@nActQTY', @nSuggQTY '@nSuggQTY', @nActQTYAlloc '@nActQTYAlloc', @nSuggQTY '@nSuggQTY'

   IF @nActQTY <= @nSuggQTY                  -- Actual have less then demand
   BEGIN
      -- Get all actual PickDetail
      INSERT INTO @tActPD (PickDetailKey, QTY) 
      SELECT PD.PickDetailKey, PD.QTY
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.LOC = @cActLOC
         AND PD.ID = @cActID
         AND PD.LOT = @cActLOT
         AND PD.Status < '4' -- Not yet picked
         AND PD.QTY > 0

      SET @nBal = @nActQTY

      -- Remove excess suggested PickDetail
      SET @curPD = CURSOR FOR
         SELECT PickDetailKey, QTY
         FROM @tSuggPD 
         ORDER BY PickDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @nBal >= @nQTY
            SET @nBal = @nBal - @nQTY
         ELSE
         BEGIN
            SET @cNewPickDetailKey = ''
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY', 
               10 ,
               @cNewPickDetailKey OUTPUT,
               @bSuccess          OUTPUT,
               @nErrNo            OUTPUT,
               @cErrMsg           OUTPUT
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 96207
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- GetDetKey Fail
               GOTO RollBackTran
            END

            -- Create new a PickDetail to hold the excess
            INSERT INTO dbo.PickDetail (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, 
               QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, 
               DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, 
               ShipFlag, PickSlipNo, PickDetailKey, QTY, TrafficCop, OptimizeCop, AddWho)
            SELECT 
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, 
               QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 'SwpLotAdd', ToLoc, 
               DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, 
               ShipFlag, PickSlipNo, @cNewPickDetailKey, @nQTY - @nBal, NULL, '1', SUSER_SNAME()
            FROM dbo.PickDetail WITH (NOLOCK) 
   		      WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
   			   SET @nErrNo = 96208
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PDtl Fail
               GOTO RollBackTran
            END
   
            -- Split the RefKeyLookup also
            IF EXISTS (SELECT 1 FROM dbo.RefKeyLookup WITH (NOLOCK) WHERE Pickdetailkey = @cPickDetailKey) 
            BEGIN 
               INSERT INTO dbo.RefkeyLookup (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, LoadKey)  
               SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, LoadKey 
               FROM dbo.RefKeyLookup WITH (NOLOCK) 
               WHERE Pickdetailkey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
		            SET @nErrNo = 96209
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsRefKLupFail
                  GOTO RollBackTran
               END
            END
            
            -- Update original PickDetail to exact needed QTY
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
               QTY = @nBal, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME(), 
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey     
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 96210
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PDtl Fail
               GOTO RollBackTran
            END

            -- Update original PickDetail to exact needed QTY
            UPDATE @tSuggPD SET 
               QTY = @nBal 
            WHERE PickDetailKey = @cPickDetailKey 
            
            -- Delete exccess PickDetail
            DELETE @tSuggPD WHERE PickDetailKey > @cPickDetailKey
            
            -- Exit loop
            BREAK
         END
         
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
      END
   END

   IF @nActQTY > @nSuggQTY AND               -- Actual have more then demand
      (@nActQTY - @nActQTYAlloc) < @nSuggQTY -- Actual avail portion not enough to cover demand QTY (means need to touch alloc portion)
   BEGIN
      -- Get affected alloc portion
      SET @nBal = @nSuggQTY - (@nActQTY - @nActQTYAlloc)
      
      -- Get actual PickDetail
      SET @curPD = CURSOR FOR
         SELECT PD.PickDetailKey, PD.QTY
         FROM dbo.PickDetail PD WITH (NOLOCK)
         WHERE PD.LOC = @cActLOC
            AND PD.ID = @cActID
            AND PD.LOT = @cActLOT
            AND PD.Status < '4' -- Not yet picked
            AND PD.QTY > 0
         ORDER BY PD.QTY
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         IF @nBal >= @nQTY
         BEGIN
            INSERT INTO @tActPD (PickDetailKey, QTY) VALUES (@cPickDetailKey, @nQTY)
            SET @nBal = @nBal - @nQTY
         END
         
         ELSE
         BEGIN
            SET @cNewPickDetailKey = ''
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY', 
               10 ,
               @cNewPickDetailKey OUTPUT,
               @bSuccess          OUTPUT,
               @nErrNo            OUTPUT,
               @cErrMsg           OUTPUT
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 96211
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetDetKey Fail
               GOTO RollBackTran
            END

            -- Create new a PickDetail to hold the excess
            INSERT INTO dbo.PickDetail (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, 
               QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, 
               DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, 
               ShipFlag, PickSlipNo, PickDetailKey, QTY, TrafficCop, OptimizeCop, AddWho)
            SELECT 
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, 
               QTYMoved, Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, 'SwpLotAdd', ToLoc, 
               DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, 
               ShipFlag, PickSlipNo, @cNewPickDetailKey, @nQTY - @nBal, NULL, '1', SUSER_SNAME()
            FROM dbo.PickDetail WITH (NOLOCK) 
   		      WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
   			   SET @nErrNo = 96212
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PDtl Fail
               GOTO RollBackTran
            END
   
            -- Split the RefKeyLookup also
            IF EXISTS (SELECT 1 FROM dbo.RefKeyLookup WITH (NOLOCK) WHERE Pickdetailkey = @cPickDetailKey) 
            BEGIN 
               INSERT INTO dbo.RefkeyLookup (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, LoadKey)  
               SELECT @cNewPickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, LoadKey 
               FROM dbo.RefKeyLookup WITH (NOLOCK) 
               WHERE Pickdetailkey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
		            SET @nErrNo = 96213
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsRefKLupFail
                  GOTO RollBackTran
               END
            END
            
            -- Update original PickDetail to exact needed QTY
            UPDATE dbo.PICKDETAIL WITH (ROWLOCK) SET 
               QTY = @nBal, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME(), 
               TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey     
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 96214
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PDtl Fail
               GOTO RollBackTran
            END

            INSERT INTO @tActPD (PickDetailKey, QTY) VALUES (@cPickDetailKey, @nBal)
            SET @nBal = 0
         END
         
         IF @nBal = 0
            BREAK
   
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
      END
   END

IF @nDebug = 1 select * from @tSuggPD
IF @nDebug = 1 select * from @tActPD
IF @nDebug = 1 select * from pickdetail (nolock) where id = @cActID

   /***********************************************************************************************

                                    Unallocated suggested, actual

   ***********************************************************************************************/
   -- Unallocate suggested
   SET @curPD = CURSOR FOR
      SELECT PickDetailKey FROM @tSuggPD ORDER BY PickDetailKey
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cPickDetailKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE PickDetail SET
         QTY = 0
      WHERE PickDetailKey = @cPickDetailKey
      SET @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
   END
   
   -- Unallocate actual
   SET @curPD = CURSOR FOR
      SELECT PickDetailKey FROM @tActPD ORDER BY PickDetailKey
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cPickDetailKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE PickDetail SET
         QTY = 0
      WHERE PickDetailKey = @cPickDetailKey
      SET @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
   END

   /***********************************************************************************************

                                       allocate suggested, actual

   ***********************************************************************************************/
   -- Alloc suggested with actual
   SET @curPD = CURSOR FOR
      SELECT PickDetailKey, QTY
      FROM @tSuggPD 
      ORDER BY PickDetailKey
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE PickDetail SET
         LOC = @cActLOC, 
         LOT = @cActLOT,
         ID = @cActID,
         DropID = @cDropID,
         QTY = @nQTY,
         Status = '5'
      WHERE PickDetailKey = @cPickDetailKey
      SET @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
   END

   -- Alloc actual with suggested
   SET @curPD = CURSOR FOR
      SELECT PickDetailKey, QTY
      FROM @tActPD 
      ORDER BY PickDetailKey
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE PickDetail SET
         LOC = @cLOC, 
         LOT = @cLOT,
         ID = @cID,
         QTY = @nQTY
      WHERE PickDetailKey = @cPickDetailKey
      SET @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
   END

   EXEC RDT.rdt_STD_EventLog
       @cActionType   = '3', -- Picking
       @cUserID       = @cUserName,
       @nMobileNo     = @nMobile,
       @nFunctionID   = @nFunc,
       @cFacility     = @cFacility,
       @cStorerKey    = @cStorerKey,
       @cLocation     = @cActLOC,
       @cID           = @cActID,
       @cSKU          = @cSKU,
       @cUOM          = @cUOM,
       @nQTY          = @nPQTY,
       @cLOT          = @cLOT,
       @cRefNo1       = @cPickSlipNo,
       @cRefNo2       = @cDropID,
       @cRefNo3       = @cPickType,
       @cPickSlipNo   = @cPickSlipNo,
       @cDropID       = @cDropID

   COMMIT TRAN rdt_862PickCfm03
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_862PickCfm03
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN

GO