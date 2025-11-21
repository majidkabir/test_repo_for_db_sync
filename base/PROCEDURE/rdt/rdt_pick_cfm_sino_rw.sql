SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Pick_Cfm_SINO_RW                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2014-08-28 1.0  Ung     SOS307606 Created                            */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_Pick_Cfm_SINO_RW] (
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
      Swap criteria: same LOC, SKU, L1, L4, QTY, different ID
   */

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount         INT
   DECLARE @nTranCount        INT
   DECLARE @cFacility         NVARCHAR(5)
   DECLARE @cUserName         NVARCHAR(18)
   
   DECLARE @cPalletOverPctg   NVARCHAR(10)
   DECLARE @cPalletUnderPctg  NVARCHAR(10)
   DECLARE @cCaseOverPctg     NVARCHAR(10)
   DECLARE @cCaseUnderPctg    NVARCHAR(10)
   DECLARE @nPalletCnt        INT
   DECLARE @nCaseCnt          INT
   DECLARE @nMaxQTYOver       INT

   DECLARE @cActSKU           NVARCHAR(20)
   DECLARE @cActLOT           NVARCHAR(10)
   DECLARE @cActLOC           NVARCHAR(10)
   DECLARE @cActID            NVARCHAR(18)
   DECLARE @cActCase          NVARCHAR(18)
   DECLARE @nActQTY           INT
   DECLARE @nActQTYAlloc      INT
   DECLARE @nActQTYPicked     INT
   DECLARE @cActL01           NVARCHAR(18)
   DECLARE @dActL04           DATETIME

   DECLARE @cPickDetailKey    NVARCHAR(10)
   DECLARE @cOrderKey         NVARCHAR(10)
   DECLARE @cOrderLineNumber  NVARCHAR(5)
   DECLARE @cSKUType          NVARCHAR(10)
   DECLARE @nSuggQTY          INT
   DECLARE @nQTYPicked        INT
   DECLARE @nQTYAfterPick     INT
   DECLARE @nOriginalQTY      INT

   DECLARE @nQTY              INT
   DECLARE @cLOT              NVARCHAR(10)
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
      LOT           NVARCHAR( 10) NOT NULL,
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

   -- Get storer config
   SET @cPalletOverPctg  = rdt.RDTGetConfig( 862, 'PalletOverPickPctg',  @cStorerKey)
   SET @cPalletUnderPctg = rdt.RDTGetConfig( 862, 'PalletUnderPickPctg', @cStorerKey)
   SET @cCaseOverPctg    = rdt.RDTGetConfig( 862, 'CaseOverPickPctg',    @cStorerKey)
   SET @cCaseUnderPctg   = rdt.RDTGetConfig( 862, 'CaseUnderPickPctg',   @cStorerKey)

   -- Check storer config
   IF rdt.rdtIsValidQTY( @cPalletOverPctg,  21) = 0 SET @cPalletOverPctg = '0'
   IF rdt.rdtIsValidQTY( @cPalletUnderPctg, 21) = 0 SET @cPalletUnderPctg = '0'
   IF rdt.rdtIsValidQTY( @cCaseOverPctg,    21) = 0 SET @cCaseOverPctg = '0'
   IF rdt.rdtIsValidQTY( @cCaseUnderPctg,   21) = 0 SET @cCaseUnderPctg = '0'

   -- Get Act ID scanned
   SELECT @cActID = I_Field14 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   -- Get SKU type
   SELECT @cSKUType =
      CASE BUSR2
         WHEN 'PALLET' THEN 'RM-PALLET' -- Raw material, pick by pallet
         WHEN 'CRTID'  THEN 'RM-CASE'   -- Raw material, pick by case
         ELSE 'FG'                      -- Finish good,  pick by pallet
      END,
      @nPalletCnt = Pack.Pallet,
      @nCaseCnt = Pack.CaseCnt
   FROM SKU WITH (NOLOCK)
      JOIN Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

   -- Get Act ID info
   IF @cSKUType = 'RM-CASE'
   BEGIN
      SET @cActCase = @cActID
      SELECT
         @cActSKU = LLI.SKU,
         @cActLOT = LLI.LOT,
         @cActLOC = LLI.LOC,
         @cActID = LLI.ID,
         @nActQTY = LLI.QTY,
         @nActQTYAlloc= LLI.QTYAllocated,
         @nActQTYPickED = LLI.QTYPicked
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LotAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      WHERE LLI.StorerKey = @cStorerKey
         AND LA.Lottable01 = @cActCase
         AND LLI.QTY > 0
   END
   ELSE
      SELECT
         @cActSKU = SKU,
         @cActLOT = LOT,
         @cActLOC = LOC,
         @cActID = ID,
         @nActQTY = QTY,
         @nActQTYAlloc= QTYAllocated,
         @nActQTYPickED = QTYPicked
      FROM LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ID = @cActID
         AND QTY > 0

   SET @nRowCount = @@ROWCOUNT

if @nDebug = 1
select @cSKUType '@cSKUType', @cActLOT '@cActLOT', @cActLOC '@cActLOC', @cActID '@cActID', @cActCase '@cActCase', @nActQTY '@nActQTY', @nActQTYAlloc '@nActQTYAlloc'

   -- Check ID valid
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 125151
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
      GOTO Quit
   END

   -- Check ID valid
   IF @nRowCount > 1
   BEGIN
      SET @nErrNo = 125152
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IDMultiLOT/LOC
      GOTO Quit
   END

   -- Check LOC match
   IF @cActLOC <> @cLOC
   BEGIN
      SET @nErrNo = 125153
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOC not match
      GOTO Quit
   END

   -- Check SKU match
   IF @cActSKU <> @cSKU
   BEGIN
      SET @nErrNo = 125154
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not match
      GOTO Quit
   END

   -- Check QTYPicked
   IF @nActQTYPicked > 0
   BEGIN
      SET @nErrNo = 125155
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID Picked
      GOTO Quit
   END

   -- Get LOT info
   SELECT
      @cActL01 = Lottable01,
      @dActL04 = Lottable04
   FROM LotAttribute WITH (NOLOCK)
   WHERE LOT = @cActLOT

   -- Get suggested PickDetail
   IF @cSKUType = 'FG'
   BEGIN
      -- Check Conso PickSlip
      IF NOT EXISTS( SELECT 1 FROM dbo.PickHeader PH (NOLOCK) WHERE PH.PickHeaderKey = @cPickSlipNo AND ExternOrderKey <> '' AND OrderKey = '')
      BEGIN
         SET @nErrNo = 125156
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FG NeedConsoPS
         GOTO Quit
      END
      
      -- Get suggested PickDetail
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
   END
   ELSE
   BEGIN
      -- Discrete PickSlip
      IF NOT EXISTS( SELECT 1 FROM dbo.PickHeader PH (NOLOCK) WHERE PH.PickHeaderKey = @cPickSlipNo AND OrderKey <> '')
      BEGIN
         SET @nErrNo = 125157
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RM NeedOrderPS
         GOTO Quit
      END
      
      -- Get suggested PickDetail
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
   END

   SELECT @nSuggQTY = ISNULL( SUM( QTY), 0) FROM @tSuggPD
   SELECT @cLOT = LOT FROM @tSuggPD

IF @nDebug = 1
select * from @tSuggPD

   -- Check QTY (PickDetail vs Task)
   IF @nSuggQTY <> @nTaskQTY
   BEGIN
      SET @nErrNo = 125158
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
      GOTO Quit
   END

   -- FG specific checking
   IF @cSKUType = 'FG'
   BEGIN
      -- Check QTY match
      IF @nActQTY <> @nTaskQTY
      BEGIN
         SET @nErrNo = 125159
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY not match
         GOTO Quit
      END

      -- Check QTYAlloc
      IF @nActQTYAlloc > 0 AND @nActQTYAlloc <> @nTaskQTY
      BEGIN
         SET @nErrNo = 125160
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IDNotFullAlloc
         GOTO Quit
      END

      -- Check L01 match
      IF @cActL01 <> @cLottable01
      BEGIN
         SET @nErrNo = 125161
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L01 not match
         GOTO Quit
      END

      -- Check L04 match
      IF @dActL04 <> @dLottable04
      BEGIN
         SET @nErrNo = 125162
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L04 not match
         GOTO Quit
      END

      -- Check QTY (PickDetail vs LLI)
      IF @nSuggQTY <> @nActQTY
      BEGIN
         SET @nErrNo = 125163
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
         GOTO Quit
      END
      
      -- Auto save DropID = ID
      IF @cDropID = ''
         SET @cDropID = @cActID
   END
/*
   -- RM specific QTY checking
   IF @cSKUType = 'RM-PALLET'
   BEGIN
      -- Get original QTY
      SELECT
         @nOriginalQTY = ISNULL( SUM( OriginalQTY), 0),
         @nQTYPicked = ISNULL( SUM( QTYPicked), 0)
      FROM OrderDetail WITH (NOLOCK)
      WHERE OrderKey IN (SELECT TOP 1 OrderKey FROM @tSuggPD)
         AND SKU = @cSKU

      -- Calc QTY after pick
      SET @nQTYAfterPick = @nQTYPicked - @nSuggQTY + @nActQTY

      -- Calc max QTY over allow
      SET @nMaxQTYOver = CAST( CEILING( @nCaseCnt * (CAST( @cPalletOverPctg AS FLOAT)/ 100)) AS INT)

if @nDebug = 1
select 
   @nQTYPicked '@nQTYPicked', 
   @nSuggQTY '@nSuggQTY', 
   @nActQTY '@nActQTY', 
   @nQTYAfterPick '@nQTYAfterPick', 
   @nOriginalQTY '@nOriginalQTY', 
   @nPalletCnt '@nPalletCnt', 
   @cPalletOverPctg '@cPalletOverPctg',
   @nMaxQTYOver '@nMaxQTYOver'

      -- Check over
      IF @nQTYAfterPick > @nOriginalQTY AND (@nQTYAfterPick - @nOriginalQTY) > @nMaxQTYOver
      BEGIN
         SET @nErrNo = 91812
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY is over
         GOTO Quit
      END
   END

   -- RM specific QTY checking
   IF @cSKUType = 'RM-CASE'
   BEGIN
      -- Get original QTY
      SELECT
         @nOriginalQTY = ISNULL( SUM( OriginalQTY), 0),
         @nQTYPicked = ISNULL( SUM( QTYPicked), 0)
      FROM OrderDetail WITH (NOLOCK)
      WHERE OrderKey IN (SELECT TOP 1 OrderKey FROM @tSuggPD)
         AND SKU = @cSKU

      -- Calc QTY after pick
      SET @nQTYAfterPick = @nQTYPicked - @nSuggQTY + @nActQTY
      
      -- Calc max QTY over allow
      SET @nMaxQTYOver = CAST( CEILING( @nCaseCnt * (CAST( @cCaseOverPctg AS FLOAT)/ 100)) AS INT)

if @nDebug = 1
select 
   @nQTYPicked '@nQTYPicked', 
   @nSuggQTY '@nSuggQTY', 
   @nActQTY '@nActQTY', 
   @nQTYAfterPick '@nQTYAfterPick', 
   @nOriginalQTY '@nOriginalQTY', 
   @nCaseCnt '@nCaseCnt', 
   @cCaseOverPctg '@cCaseOverPctg',
   @nMaxQTYOver '@nMaxQTYOver'

      -- Check over
      IF @nQTYAfterPick > @nOriginalQTY AND (@nQTYAfterPick - @nOriginalQTY) > @nMaxQTYOver
      BEGIN
         SET @nErrNo = 91813
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTY is over
         GOTO Quit
      END
   END
*/

   /***********************************************************************************************

                                  Picked ID is the suggested ID

   ***********************************************************************************************/
   BEGIN TRAN                     -- Begin our own transaction
   SAVE TRAN rdt_Pick_Cfm_SINO_RW  -- For rollback or commit only our own transaction

   DECLARE @nExactMatch INT
   SET @nExactMatch = 0

if @nDebug = 1
select @cSKUType '@cSKUType', @cActID '@cActID', @cID '@cID', @nActQTY '@nActQTY', @nSuggQTY '@nSuggQTY', @cActCase '@cActCase', @cLottable01 '@cLottable01'

   IF @cSKUType = 'FG' AND @cActID = @cID AND @nActQTY = @nSuggQTY
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
      
      SET @nExactMatch = 1
   END

   IF (@cSKUType = 'RM-CASE'   AND @cActID = @cID AND @cActCase = @cLottable01) OR
      (@cSKUType = 'RM-PALLET' AND @cActID = @cID) 
   BEGIN
      IF @nActQTY = @nSuggQTY
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
      END
      
      -- Adjust OrderDetail.OpenQTY
      IF @nActQTY <> @nSuggQTY
      BEGIN
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
            
         -- Get one of suggested OrderDetail (OrderDetail no duplicate SKU)
         SELECT TOP 1
            @cPickDetailKey = PD.PickDetailKey,
            @cOrderKey = OD.OrderKey,
            @cOrderLineNumber = OD.OrderLineNumber
         FROM OrderDetail OD WITH (NOLOCK)
            JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
         WHERE PickDetailKey IN (SELECT TOP 1 PickDetailKey FROM @tSuggPD)

         -- Adjust OrderDetail.OpenQTY
         UPDATE OrderDetail SET
            OpenQTY = OpenQTY - @nSuggQTY + @nActQTY
         WHERE OrderKey = @cOrderKey
            AND OrderLineNumber = @cOrderLineNumber
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END

         -- Pick confirm one of PickDetail
         UPDATE PickDetail SET
            Status = '5',
            QTY = @nActQTY, 
            DropID = @cDropID
         WHERE PickDetailKey = @cPickDetailKey
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END
      
      SET @nExactMatch = 1
   END
   
   IF @nExactMatch = 1
   BEGIN
      EXEC RDT.rdt_STD_EventLog
          @cActionType   = '3', -- Picking
          @cUserID       = @cUserName,
          @nMobileNo     = @nMobile,
          @nFunctionID   = @nFunc,
          @cFacility     = @cFacility,
          @cStorerKey    = @cStorerKey,
          @cLocation     = @cLOC,
          @cID           = @cID,
          @cSKU          = @cSKU,
          @cUOM          = @cUOM,
          @nQTY          = @nPQTY,
          @cLottable02   = @cLottable02,
          @cLottable03   = @cLottable03,
          @dLottable04   = @dLottable04,
          @cRefNo1       = @cPickSlipNo,
          @cRefNo2       = @cDropID,
          @cRefNo3       = @cPickType,
          @cPickSlipNo   = @cPickSlipNo,
          @cDropID       = @cDropID
      
      GOTO Quit
   END


   /***********************************************************************************************

                            Picked ID is not the suggested, but on the list

   ***********************************************************************************************/



   /***********************************************************************************************

                                    Unallocated suggested, actual

   ***********************************************************************************************/
   -- Suggested
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

if @ndebug = 1
select @nActQTYAlloc '@nActQTYAlloc', @cActLOC '@cActLOC', @cActID '@cActID', @cActLOT '@cActLOT'
   
   -- Actual
   IF @nActQTYAlloc > 0
   BEGIN
      -- Get actual PickDetail
      INSERT INTO @tActPD (PickDetailKey, LOT, QTY)
      SELECT PD.PickDetailKey, PD.LOT, PD.QTY
      FROM dbo.PickDetail PD WITH (NOLOCK)
      WHERE PD.LOC = @cActLOC
         AND PD.ID = @cActID
         AND PD.LOT = @cActLOT
         AND PD.Status < '4' -- Not yet picked
         AND PD.QTY > 0

      -- Check multi PickDetail
      IF @@ROWCOUNT > 1
      BEGIN
         SET @nErrNo = 125164
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi PKDtl
         GOTO RollBackTran
      END

IF @nDebug = 1
select * from @tActPD

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
   END

   /***********************************************************************************************

                                       allocate suggested, actual

   ***********************************************************************************************/
   -- Get one of suggested
   SELECT TOP 1
      @cPickDetailKey = PD.PickDetailKey,
      @cOrderKey = OD.OrderKey,
      @cOrderLineNumber = OD.OrderLineNumber
   FROM OrderDetail OD WITH (NOLOCK)
      JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
   WHERE PickDetailKey IN (SELECT TOP 1 PickDetailKey FROM @tSuggPD)

   -- OpenQTY
   IF @nActQTY <> @nSuggQTY
   BEGIN
      UPDATE OrderDetail SET
         OpenQTY = OpenQTY - @nSuggQTY + @nActQTY
      WHERE OrderKey = @cOrderKey
         AND OrderLineNumber = @cOrderLineNumber
      SET @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
   END

   -- Alloc suggested with actual
   UPDATE PickDetail SET
      LOT = @cActLOT,
      ID = @cActID,
      DropID = @cDropID,
      QTY = @nActQTY,
      Status = '5'
   WHERE PickDetailKey = @cPickDetailKey
   SET @nErrNo = @@ERROR
   IF @nErrNo <> 0
   BEGIN
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
      GOTO RollBackTran
   END

   -- Alloc actual with suggested
   IF @nActQTYAlloc > 0
   BEGIN
      -- Get one of actual
      SELECT TOP 1
         @cPickDetailKey = PD.PickDetailKey,
         @cOrderKey = OD.OrderKey,
         @cOrderLineNumber = OD.OrderLineNumber
      FROM OrderDetail OD WITH (NOLOCK)
         JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
      WHERE PickDetailKey IN (SELECT TOP 1 PickDetailKey FROM @tActPD)

      -- OpenQTY
      IF @nActQTY <> @nSuggQTY
      BEGIN
         UPDATE OrderDetail SET
            OpenQTY = OpenQTY - @nActQTYAlloc + @nSuggQTY
         WHERE OrderKey = @cOrderKey
            AND OrderLineNumber = @cOrderLineNumber
         SET @nErrNo = @@ERROR
         IF @nErrNo <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END

      -- Alloc actual with suggested
      UPDATE PickDetail SET
         LOT = @cLOT,
         ID = @cID,
         QTY = @nSuggQTY
      WHERE PickDetailKey = @cPickDetailKey
      SET @nErrNo = @@ERROR
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
   END

   EXEC RDT.rdt_STD_EventLog
       @cActionType   = '3', -- Picking
       @cUserID       = @cUserName,
       @nMobileNo     = @nMobile,
       @nFunctionID   = @nFunc,
       @cFacility     = @cFacility,
       @cStorerKey    = @cStorerKey,
       @cLocation     = @cLOC,
       @cID           = @cID,
       @cSKU          = @cSKU,
       @cUOM          = @cUOM,
       @nQTY          = @nPQTY,
       @cLottable02   = @cLottable02,
       @cLottable03   = @cLottable03,
       @dLottable04   = @dLottable04,
       @cRefNo1       = @cPickSlipNo,
       @cRefNo2       = @cDropID,
       @cRefNo3       = @cPickType,
       @cPickSlipNo   = @cPickSlipNo,
       @cDropID       = @cDropID

   COMMIT TRAN rdt_Pick_Cfm_SINO_RW
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Pick_Cfm_SINO_RW
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN

GO