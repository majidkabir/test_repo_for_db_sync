SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_957SwapID01                                           */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev    Author   Purposes                                        */
/* 2024-07-10 1.0    NLT013   FCR-454 Created                                 */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_957SwapID01] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 18),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPickSlipNo   NVARCHAR( 10),
   @cPickZone     NVARCHAR( 10),
   @cLOC          NVARCHAR( 10),
   @cSuggID       NVARCHAR( 18) OUTPUT,
   @cID           NVARCHAR( 18) OUTPUT,
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cSQL                 NVARCHAR( MAX)
   DECLARE @cSQLParam            NVARCHAR( MAX)      
   DECLARE @nTranCount           INT
   DECLARE @nRowCount            INT
   DECLARE @bSuccess             INT
   DECLARE @cLottableField       NVARCHAR( MAX) = ''
   DECLARE @cLottableCompare     NVARCHAR( MAX) = ''
  
   DECLARE @cOrderKey            NVARCHAR( 10)
   DECLARE @cLoadKey             NVARCHAR( 10)
   DECLARE @cZone                NVARCHAR( 18)

   DECLARE @cSuggSKU             NVARCHAR( 20)
   DECLARE @cSuggLOT             NVARCHAR( 10)
   DECLARE @nSuggQTY             INT
   DECLARE @cActSKU              NVARCHAR( 20)
   DECLARE @cActLOT              NVARCHAR( 10)
   DECLARE @nActQTY              INT

   DECLARE @cPickDetailKey       NVARCHAR( 10)
   DECLARE @cNewPickDetailKey    NVARCHAR( 10)
   DECLARE @nQTY_Alloc           INT
   DECLARE @nQTY_Bal             INT
   DECLARE @nQTY_PD              INT
   DECLARE @cPickConfirmStatus   NVARCHAR( 1)
   DECLARE @curPD                CURSOR
   
   IF OBJECT_ID( 'tempdb..#tSuggPD') IS NOT NULL DROP TABLE #tSuggPD
   CREATE TABLE #tSuggPD 
   (
      PickDetailKey  NVARCHAR( 10) NOT NULL, 
      SKU            NVARCHAR( 20) NOT NULL, 
      QTY            INT           NOT NULL, 
      Lottable01     NVARCHAR( 18) NOT NULL,
      Lottable02     NVARCHAR( 18) NOT NULL,
      Lottable03     NVARCHAR( 18) NOT NULL,
      Lottable04     DATETIME      NULL,
      Lottable05     DATETIME      NULL,
      Lottable06     NVARCHAR( 30) NOT NULL,
      Lottable07     NVARCHAR( 30) NOT NULL,
      Lottable08     NVARCHAR( 30) NOT NULL,
      Lottable09     NVARCHAR( 30) NOT NULL,
      Lottable10     NVARCHAR( 30) NOT NULL,
      Lottable11     NVARCHAR( 30) NOT NULL,
      Lottable12     NVARCHAR( 30) NOT NULL,
      Lottable13     DATETIME      NULL,
      Lottable14     DATETIME      NULL,
      Lottable15     DATETIME      NULL,
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )
   
   IF OBJECT_ID( 'tempdb..#tActPD') IS NOT NULL DROP TABLE #tActPD
   CREATE TABLE #tActPD 
   (
      PickDetailKey  NVARCHAR( 10) NOT NULL, 
      SKU            NVARCHAR( 20) NOT NULL, 
      QTY            INT           NOT NULL, 
      Lottable01     NVARCHAR( 18) NOT NULL,
      Lottable02     NVARCHAR( 18) NOT NULL,
      Lottable03     NVARCHAR( 18) NOT NULL,
      Lottable04     DATETIME      NULL,
      Lottable05     DATETIME      NULL,
      Lottable06     NVARCHAR( 30) NOT NULL,
      Lottable07     NVARCHAR( 30) NOT NULL,
      Lottable08     NVARCHAR( 30) NOT NULL,
      Lottable09     NVARCHAR( 30) NOT NULL,
      Lottable10     NVARCHAR( 30) NOT NULL,
      Lottable11     NVARCHAR( 30) NOT NULL,
      Lottable12     NVARCHAR( 30) NOT NULL,
      Lottable13     DATETIME      NULL,
      Lottable14     DATETIME      NULL,
      Lottable15     DATETIME      NULL,
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )
   
   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   IF @cPickConfirmStatus NOT IN ( '3', '5')
      SET @cPickConfirmStatus = '5'

   SET @nTranCount = @@TRANCOUNT

   -- Check ID in LOC
   IF NOT EXISTS( SELECT 1
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LOC = @cLOC
         AND ID = @cID
         AND QTY - QTYPicked > 0)
   BEGIN
      SET @nErrNo = 204951
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID not in LOC
      GOTO Quit
   END

   -- Check ID not fully available or fully allocated
   IF EXISTS( SELECT 1
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND LOC = @cLOC
         AND ID = @cID
         AND QTY - QTYAllocated - QTYPicked > 0 -- Available
         AND QTYAllocated > 0)                  -- Allocated
   BEGIN
      SET @nErrNo = 204968
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ID part alloc
      GOTO Quit
   END

   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   print 'NICK - 0' + @cOrderKey + ' - ' + @cOrderKey + ' - ' + @cLoadKey + ' - ' + @cZone

   -- Get suggest PickDetail
   BEGIN      
      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
         INSERT INTO #tSuggPD (PickDetailKey, SKU, QTY, 
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
         SELECT PD.PickDetailKey, PD.SKU, PD.QTY, 
            LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
            LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
            LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) 
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) 
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) 
         WHERE RKL.PickSlipNo = @cPickSlipNo 
            AND PD.LOC = @cLOC 
            AND PD.ID = @cSuggID 
            AND PD.QTY > 0 
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus

      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
         INSERT INTO #tSuggPD (PickDetailKey, SKU, QTY, 
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
         SELECT PD.PickDetailKey, PD.SKU, PD.QTY, 
            LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
            LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
            LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) 
         WHERE PD.OrderKey = @cOrderKey 
            AND PD.LOC = @cLOC 
            AND PD.ID = @cSuggID 
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus

      -- Conso PickSlip
      ELSE IF @cLoadKey <> ''
         INSERT INTO #tSuggPD (PickDetailKey, SKU, QTY, 
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
         SELECT PD.PickDetailKey, PD.SKU, PD.QTY, 
            LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
            LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
            LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) 
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) 
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) 
         WHERE LPD.LoadKey = @cLoadKey 
            AND PD.LOC = @cLOC 
            AND PD.ID = @cSuggID 
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus

      -- Custom PickSlip
      ELSE
         INSERT INTO #tSuggPD (PickDetailKey, SKU, QTY, 
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
         SELECT PD.PickDetailKey, PD.SKU, PD.QTY, 
            LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
            LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
            LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15
         FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) 
            JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) 
         WHERE PD.PickSlipNo = @cPickSlipNo 
            AND PD.LOC = @cLOC 
            AND PD.ID = @cSuggID 
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
   END

   select 1, * from #tSuggPD

   -- Get actual PickDetail
   INSERT INTO #tActPD (PickDetailKey, SKU, QTY, 
      Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
      Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
      Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
   SELECT PD.PickDetailKey, PD.SKU, PD.QTY, 
      LA.Lottable01, LA.Lottable02, LA.Lottable03, LA.Lottable04, LA.Lottable05, 
      LA.Lottable06, LA.Lottable07, LA.Lottable08, LA.Lottable09, LA.Lottable10, 
      LA.Lottable11, LA.Lottable12, LA.Lottable13, LA.Lottable14, LA.Lottable15
   FROM dbo.PickDetail PD WITH (NOLOCK) 
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) 
   WHERE PD.LOC = @cLOC 
      AND PD.ID = @cID 
      AND PD.QTY > 0
      AND PD.Status <> '4'
      AND PD.Status < @cPickConfirmStatus

	select 2, * from #tActPD

   SELECT @cLottableField += ', Lottable01', @cLottableCompare += ' AND S.Lottable01 = A.Lottable01'

/*--------------------------------------------------------------------------------------------------
                                                Swap UCC
--------------------------------------------------------------------------------------------------*/
/*
   Scenario:
   1. ID is not alloc           swap
   2. ID on other PickDetail    swap
*/

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_957SwapID01 -- For rollback or commit only our own transaction

   -- 1. ID is not alloc
   IF NOT EXISTS( SELECT 1 FROM #tActPD)
   BEGIN
      -- Check pallet content is exactly same by SKU, QTY, Lottable
      IF @cLottableField <> ''
      BEGIN
         SET @cSQL = 
            ' SET @nRowCount = 0 ' + 
            ' SELECT @nRowCount = 1 ' + 
            ' FROM ' + 
            ' ( ' + 
               ' SELECT SKU, SUM( QTY) QTY' + @cLottableField + 
               ' FROM #tSuggPD ' +  
               ' GROUP BY SKU' + @cLottableField + 
            ' ) S FULL JOIN ' + 
            ' ( ' + 
               ' SELECT LLI.SKU, SUM( LLI.QTY-LLI.QTYPicked) QTY' + @cLottableField + 
               ' FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) ' + 
                  ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT) ' + 
               ' WHERE LLI.LOC = @cLOC ' + 
                  ' AND LLI.ID = @cID ' + 
               ' GROUP BY LLI.SKU' + @cLottableField + 
            ' ) A ON (S.SKU = A.SKU' + @cLottableCompare + ') ' + 
            ' WHERE S.SKU IS NULL ' + 
               ' OR A.SKU IS NULL ' + 
               ' OR S.QTY <> A.QTY ' 
         SET @cSQLParam =
            ' @cLOC      NVARCHAR( 10), ' +
            ' @cID       NVARCHAR( 18), ' + 
            ' @nRowCount INT OUTPUT     '

         EXEC sp_executeSQL @cSQL, @cSQLParam, 
            @cLOC, 
            @cID, 
            @nRowCount OUTPUT
         
         IF @nRowCount = 1
         BEGIN
            SET @nErrNo = 204970
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKUQTYLOT Diff
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         -- Check pallet content is exactly same by SKU, QTY
         IF EXISTS( SELECT TOP 1 1
            FROM
            (
               SELECT SKU, SUM( QTY) QTY FROM #tSuggPD GROUP BY SKU
            ) S FULL JOIN 
            (
               SELECT SKU, SUM( QTY-QTYPicked) QTY 
               FROM dbo.LOTxLOCxID WITH (NOLOCK) 
               WHERE LOC = @cLOC
                  AND ID = @cID
               GROUP BY SKU
            ) A ON (S.SKU = A.SKU)
            WHERE S.SKU IS NULL
               OR A.SKU IS NULL
               OR S.QTY <> A.QTY) 
         BEGIN
            SET @nErrNo = 204969
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU QTY Diff
            GOTO Quit
         END
      END
      
      -- Suggest
      -- Unallocate
      SET @curPD = CURSOR FOR
         SELECT PickDetailKey FROM #tSuggPD ORDER BY PickDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE dbo.PickDetail SET
            QTY = 0,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
      END

      -- Loop suggest
      SET @curPD = CURSOR FOR
         SELECT PickDetailKey, SKU, QTY FROM #tSuggPD ORDER BY PickDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cSuggSKU, @nSuggQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get Actual
         SET @cActLOT = ''
         SELECT 
            @cActLOT = LOT, 
            @nActQTY = QTY-QTYAllocated-QTYPicked
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE LOC = @cLOC
            AND ID = @cID
            AND StorerKey = @cStorerKey
            AND SKU = @cSuggSKU
            AND QTY-QTYAllocated-QTYPicked > 0
         IF @cActLOT = ''
         BEGIN
            SET @nErrNo = 204952
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Get PKDtl Fail 
            GOTO RollBackTran
         END

         -- Calc QTY
         IF @nActQTY >= @nSuggQTY
         BEGIN
            SET @nQTY_Alloc = @nSuggQTY
            SET @nQTY_Bal = 0
         END
         ELSE
         BEGIN
            SET @nQTY_Alloc = @nActQTY
            SET @nQTY_Bal = @nSuggQTY - @nQTY_Alloc
         END

         -- Suggest has balance
         IF @nQTY_Bal > 0
         BEGIN
            -- Get new PickDetailkey
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10 ,
               @cNewPickDetailKey OUTPUT,
               @bSuccess          OUTPUT,
               @nErrNo            OUTPUT,
               @cErrMsg           OUTPUT
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 204953
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
               GOTO RollBackTran
            END
   
            -- Create new a PickDetail to hold the balance
            INSERT INTO dbo.PickDetail (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, Channel_ID, 
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
               PickDetailKey,
               Status, 
               QTY,
               TrafficCop,
               OptimizeCop)
            SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, 
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, Channel_ID, 
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
               @cNewPickDetailKey,
               Status, 
               0, -- @nQTY_Bal, -- QTY
               NULL, -- TrafficCop
               '1'   -- OptimizeCop
            FROM dbo.PickDetail WITH (NOLOCK)
   			WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
   				SET @nErrNo = 204954
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
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
                  SET @nErrNo = 204955
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                  GOTO RollBackTran
               END
            END
   
            -- Create new a PickDetail to hold the balance
            INSERT INTO #tSuggPD (PickDetailKey, SKU, QTY, 
               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
               Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
               Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
            VALUES (@cNewPickDetailKey, @cSuggSKU, @nQTY_Bal, 
               '',   '',  '',    NULL, NULL, 
               '',   '',  '',    '',   '', 
               '',   '',  NULL,  NULL, NULL)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 204956
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
               GOTO RollBackTran
            END
         END

         -- Alloc suggest
         UPDATE dbo.PickDetail SET
            ID = @cID, 
            LOT = @cActLOT, 
            QTY = @nQTY_Alloc,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END

         
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cSuggSKU, @nSuggQTY
      END
   END

   -- 2. ID on other PickDetail
   ELSE
   BEGIN
      -- Check pallet content is exactly same by SKU, QTY, Lottable
      IF @cLottableField <> ''
      BEGIN
         SET @cSQL = 
            ' SET @nRowCount = 0 ' + 
            ' SELECT @nRowCount = 1 ' + 
            ' FROM ' + 
            ' ( ' + 
               ' SELECT SKU, SUM( QTY) QTY' + @cLottableField + 
               ' FROM #tSuggPD ' +  
               ' GROUP BY SKU' + @cLottableField + 
            ' ) S FULL JOIN ' + 
            ' ( ' + 
               ' SELECT SKU, SUM( QTY) QTY' + @cLottableField + 
               ' FROM #tActPD ' +  
               ' GROUP BY SKU' + @cLottableField + 
            ' ) A ON (S.SKU = A.SKU' + @cLottableCompare + ') ' + 
            ' WHERE S.SKU IS NULL ' + 
               ' OR A.SKU IS NULL ' + 
               ' OR S.QTY <> A.QTY ' 
         SET @cSQLParam =
            ' @cLOC      NVARCHAR( 10), ' +
            ' @cID       NVARCHAR( 18), ' + 
            ' @nRowCount INT OUTPUT     '

         EXEC sp_executeSQL @cSQL, @cSQLParam, 
            @cLOC, 
            @cID, 
            @nRowCount OUTPUT
         
         IF @nRowCount = 1
         BEGIN
            SET @nErrNo = 204971
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKUQTYLOT Diff
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         -- Check pallet content is exactly same by SKU, QTY
         IF EXISTS( SELECT TOP 1 1
            FROM
            (
               SELECT SKU, SUM( QTY) QTY FROM #tSuggPD GROUP BY SKU
            ) S FULL JOIN 
            (
               SELECT SKU, SUM( QTY) QTY FROM #tActPD GROUP BY SKU
            ) A ON (S.SKU = A.SKU)
            WHERE S.SKU IS NULL
               OR A.SKU IS NULL
               OR S.QTY <> A.QTY) 
         BEGIN
            SET @nErrNo = 204957
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU QTY Diff
            GOTO Quit
         END
      END
      
      /*
         2a. Loop sugg ID, unalloc
         2b. Loop act ID, unalloc
         2c. Loop sugg ID
               Get act ID LOT, QTY
               Alloc sugg
               If sugg not fully alloc
                  split line with bal
         2d. Loop act ID
               Get sugg ID LOT, QTY
               Alloc act
               If act not fully alloc
                  split line with bal
      */

      -- 2a. Loop sugg ID, unalloc
      SET @curPD = CURSOR FOR
         SELECT PickDetailKey FROM #tSuggPD ORDER BY PickDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE dbo.PickDetail SET
            QTY = 0,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
      END

      -- 2b. Loop act ID, unalloc
      SET @curPD = CURSOR FOR
         SELECT PickDetailKey FROM #tActPD ORDER BY PickDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE dbo.PickDetail SET
            QTY = 0,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
      END

      -- 2c. Loop sugg ID
      SET @curPD = CURSOR FOR
         SELECT PickDetailKey, SKU, QTY FROM #tSuggPD ORDER BY PickDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cSuggSKU, @nSuggQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get Actual
         SET @cActLOT = ''
         SELECT 
            @cActLOT = LOT, 
            @nActQTY = QTY-QTYAllocated-QTYPicked
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE LOC = @cLOC
            AND ID = @cID
            AND StorerKey = @cStorerKey
            AND SKU = @cSuggSKU
            AND QTY-QTYAllocated-QTYPicked > 0 
         IF @cActLOT = ''
         BEGIN
            SET @nErrNo = 204958
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Get PKDtl Fail 
            GOTO RollBackTran
         END

         -- Calc QTY
         IF @nActQTY >= @nSuggQTY
         BEGIN
            SET @nQTY_Alloc = @nSuggQTY
            SET @nQTY_Bal = 0
         END
         ELSE
         BEGIN
            SET @nQTY_Alloc = @nActQTY
            SET @nQTY_Bal = @nSuggQTY - @nQTY_Alloc
         END
         
         -- Suggest has balance
         IF @nQTY_Bal > 0
         BEGIN
            -- Get new PickDetailkey
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10 ,
               @cNewPickDetailKey OUTPUT,
               @bSuccess          OUTPUT,
               @nErrNo            OUTPUT,
               @cErrMsg           OUTPUT
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 204959
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
               GOTO RollBackTran
            END
   
            -- Create new a PickDetail to hold the balance
            INSERT INTO dbo.PickDetail (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, Channel_ID, 
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
               PickDetailKey,
               Status, 
               QTY,
               TrafficCop,
               OptimizeCop)
            SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, 
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, Channel_ID, 
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
               @cNewPickDetailKey,
               Status, 
               0, -- @nQTY_Bal, -- QTY
               NULL, -- TrafficCop
               '1'   -- OptimizeCop
            FROM dbo.PickDetail WITH (NOLOCK)
   			WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
   				SET @nErrNo = 204960
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
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
                  SET @nErrNo = 204961
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                  GOTO RollBackTran
               END
            END
   
            -- Create new a PickDetail to hold the balance
            INSERT INTO #tSuggPD (PickDetailKey, SKU, QTY, 
               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
               Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
               Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
            VALUES (@cNewPickDetailKey, @cSuggSKU, @nQTY_Bal, 
               '',   '',  '',    NULL, NULL, 
               '',   '',  '',    '',   '', 
               '',   '',  NULL,  NULL, NULL)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 204962
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
               GOTO RollBackTran
            END
         END
         
         -- Alloc suggest
         UPDATE dbo.PickDetail SET
            ID = @cID, 
            LOT = @cActLOT, 
            QTY = @nQTY_Alloc,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END

         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cSuggSKU, @nSuggQTY
      END

      -- 2d. Loop act ID
      SET @curPD = CURSOR FOR
         SELECT PickDetailKey, SKU, QTY FROM #tActPD ORDER BY PickDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cActSKU, @nActQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get Suggest
         SET @cSuggLOT = ''
         SELECT 
            @cSuggLOT = LOT, 
            @nSuggQTY = QTY-QTYAllocated-QTYPicked
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE LOC = @cLOC
            AND ID = @cSuggID
            AND StorerKey = @cStorerKey
            AND SKU = @cActSKU
            AND QTY-QTYAllocated-QTYPicked > 0 
         IF @cSuggLOT = ''
         BEGIN
            SET @nErrNo = 204963
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Get PKDtl Fail 
            GOTO RollBackTran
         END

         -- Calc QTY
         IF @nSuggQTY >= @nActQTY
         BEGIN
            SET @nQTY_Alloc = @nActQTY
            SET @nQTY_Bal = 0
         END
         ELSE
         BEGIN
            SET @nQTY_Alloc = @nSuggQTY
            SET @nQTY_Bal = @nActQTY - @nQTY_Alloc
         END

         -- Actual has balance
         IF @nQTY_Bal > 0
         BEGIN
            -- Get new PickDetailkey
            EXECUTE dbo.nspg_GetKey
               'PICKDETAILKEY',
               10 ,
               @cNewPickDetailKey OUTPUT,
               @bSuccess          OUTPUT,
               @nErrNo            OUTPUT,
               @cErrMsg           OUTPUT
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 204964
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- nspg_GetKey
               GOTO RollBackTran
            END
   
            -- Create new a PickDetail to hold the balance
            INSERT INTO dbo.PickDetail (
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, Channel_ID, 
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
               PickDetailKey,
               Status, 
               QTY,
               TrafficCop,
               OptimizeCop)
            SELECT
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
               UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, 
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey, Channel_ID, 
               EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
               @cNewPickDetailKey,
               Status, 
               0, -- @nQTY_Bal, -- QTY
               NULL, -- TrafficCop
               '1'   -- OptimizeCop
            FROM dbo.PickDetail WITH (NOLOCK)
   			WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
   				SET @nErrNo = 204965
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
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
                  SET @nErrNo = 204966
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS RefKeyFail
                  GOTO RollBackTran
               END
            END
   
            -- Create new a PickDetail to hold the balance
            INSERT INTO #tActPD (PickDetailKey, SKU, QTY, 
               Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
               Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
               Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
            VALUES (@cNewPickDetailKey, @cActSKU, @nQTY_Bal, 
               '',   '',  '',    NULL, NULL, 
               '',   '',  '',    '',   '', 
               '',   '',  NULL,  NULL, NULL)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 204967
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS PKDtl Fail
               GOTO RollBackTran
            END
         END
         
         -- Alloc actual
         UPDATE dbo.PickDetail SET
            ID = @cSuggID, 
            LOT = @cSuggLOT, 
            QTY = @nQTY_Alloc,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT
         IF @nErrNo <> 0 OR @nRowCount <> 1
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END

         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cActSKU, @nActQTY
      END
   END

   COMMIT TRAN rdt_957SwapID01
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_957SwapID01
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO