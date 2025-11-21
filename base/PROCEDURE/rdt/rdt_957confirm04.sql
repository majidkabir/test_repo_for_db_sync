SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************************/
/* Store procedure: rdt_957Confirm04                                                               */
/* Copyright      : Maersk                                                                         */
/*                                                                                                 */
/* Purpose: Swap UCC                                                                               */
/*          Full carton (UOM = 2)                                                                  */
/*             PackDetail.Status = 5, CaseID = UCCNo                                               */
/*             Auto generate pack data (conso pick, discrete pack)                                 */
/*             Auto pack confirm                                                                   */
/*             Send WCS                                                                            */
/*          Conso carton (UOM = 7)                                                                 */
/*             PackDetail.Status = 3                                                               */
/*                                                                                                 */
/* Date       Rev   Author     Purposes                                                            */
/* 07-12-2023 1.0   Ung        WMS-24353 base on rdt_957Confirm02, 03                              */
/* 04-29-2024 1.1   CYU027     UWP-18306 Short Pick                                                */
/* 06-05-2024 1.2   Dennis     FCR-133   Trigger only uom =7                                       */
/* 08-05-2024 1.3   JHU151     FCR-330   No Pack Confirm                                           */
/* 12-10-2024 1.4.0 LJQ006     FCR-1168  Adjust from WMS-24353, FCR-630                            */
/***************************************************************************************************/

CREATE   PROC [RDT].[rdt_957Confirm04] (
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cType        NVARCHAR( 10) -- CONFIRM/SHORT/CLOSE
   ,@cPickSlipNo  NVARCHAR( 10)
   ,@cPickZone    NVARCHAR( 10)
   ,@cDropID      NVARCHAR( 20)
   ,@cLOC         NVARCHAR( 10)
   ,@cID          NVARCHAR( 18)
   ,@cBarcode     NVARCHAR( 60)
   ,@cSKU         NVARCHAR( 20) -- SKU is blank
   ,@nQTY         INT           -- QTY is 0
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQLCommon        NVARCHAR( MAX)
   DECLARE @cSQLCommonParam   NVARCHAR( MAX)
   DECLARE @cSQLCustom        NVARCHAR( MAX)
   DECLARE @cSQLCustomParam   NVARCHAR( MAX)
   DECLARE @nRowCount         INT
   DECLARE @nTranCount        INT
   DECLARE @cReplenKey        NVARCHAR( 10) = ''

   DECLARE @cActUCCNo         NVARCHAR( 20)
   DECLARE @cActUCCLOT        NVARCHAR( 10)
   DECLARE @cActUCCLOC        NVARCHAR( 10)
   DECLARE @cActUCCID         NVARCHAR( 18)
   DECLARE @cActUCCSKU        NVARCHAR( 20)
   DECLARE @nActUCCQTY        INT
   DECLARE @cActUCCStatus     NVARCHAR( 1)
   DECLARE @cActToLOC         NVARCHAR( 10)
   DECLARE @cActToID          NVARCHAR( 18)
   DECLARE @nActQTYReplen     INT
   DECLARE @nActPendingMoveIn INT
   DECLARE @cActLottable01    NVARCHAR( 18)

   DECLARE @cTaskUCCNo        NVARCHAR( 20) = ''
   DECLARE @cTaskLOT          NVARCHAR( 10)
   DECLARE @nTaskQTY          INT

   IF OBJECT_ID( 'tempdb..#tTaskPD') IS NOT NULL DROP TABLE #tTaskPD
   CREATE TABLE #tTaskPD
   (
      PickDetailKey NVARCHAR( 10) NOT NULL,
      LOT           NVARCHAR( 10) NOT NULL,
      QTY           INT           NOT NULL,
      UOM           NVARCHAR( 10) NOT NULL
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )

   IF OBJECT_ID( 'tempdb..#tActPD') IS NOT NULL DROP TABLE #tActPD
   CREATE TABLE #tActPD
   (
      PickDetailKey NVARCHAR( 10) NOT NULL,
      LOT           NVARCHAR( 10) NOT NULL,
      QTY           INT           NOT NULL
      PRIMARY KEY CLUSTERED (PickDetailKey)
   )

   SET @nTranCount = @@TRANCOUNT
   IF @cType = 'SHORT'
      GOTO BUILD_SQL
   -- Get UCC info
   SELECT
      @cActUCCNo = @cBarcode,
      @cActUCCLOT = UCC.LOT,
      @cActUCCLOC = UCC.LOC,
      @cActUCCID = UCC.ID,
      @cActUCCSKU = UCC.SKU,
      @nActUCCQTY = UCC.QTY,
      @cActUCCStatus = UCC.Status,
      @cActLottable01 = LA.Lottable01
   FROM dbo.UCC WITH (NOLOCK)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (UCC.LOT = LA.LOT)
   WHERE UCC.StorerKey = @cStorerKey
      AND UCC.UCCNo = @cBarcode

   SET @nRowCount = @@ROWCOUNT

   -- Check UCC valid
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 209751
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not an UCC
      GOTO Quit
   END

   -- Check multi SKU UCC
   IF @nRowCount > 1
   BEGIN
      SET @nErrNo = 209752
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi SKU UCC
      GOTO Quit
   END

   -- Check UCC status
   IF @cActUCCStatus NOT IN ('1', '3', '4')
   BEGIN
      SET @nErrNo = 209753
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad UCC Status
      GOTO Quit
   END

   -- Check UCC LOC match
   IF @cLOC <> @cActUCCLOC
   BEGIN
      SET @nErrNo = 209754
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCLOCNotMatch
      GOTO Quit
   END

   -- Check UCC ID match
   IF @cID <> @cActUCCID
   BEGIN
      SET @nErrNo = 209755
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCIDNotMatch
      GOTO Quit
   END

   -- Set task info
   SET @nTaskQTY = @nActUCCQTY

/*--------------------------------------------------------------------------------------------------
                                            Build common SQL
--------------------------------------------------------------------------------------------------*/
BUILD_SQL:
BEGIN
   DECLARE @cOrderKey NVARCHAR( 10) = ''
   DECLARE @cLoadKey  NVARCHAR( 10) = ''
   DECLARE @cZone     NVARCHAR( 18) = ''

   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
      SET @cSQLCommon =
         ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +
            ' JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +
            ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         ' WHERE RKL.PickSlipNo = @cPickSlipNo '

   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
      SET @cSQLCommon =
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
            ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         ' WHERE PD.OrderKey = @cOrderKey '

   -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
      SET @cSQLCommon =
         ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +
            ' JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
            ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         ' WHERE LPD.LoadKey = @cLoadKey '

   -- Custom PickSlip
   ELSE
      SET @cSQLCommon =
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +
            ' JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +
            ' JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = PD.LOT) ' +
         ' WHERE PD.PickSlipNo = @cPickSlipNo '

   SET @cSQLCommon +=
      ' AND PD.LOC = @cLOC ' +
      ' AND PD.ID  = @cID ' +
      ' AND PD.SKU = @cSKU ' +
      ' AND PD.QTY > 0 ' +
      ' AND PD.Status <> ''4'' '

   SET @cSQLCommonParam =
      ' @cPickSlipNo NVARCHAR( 10) ' +
      ',@cOrderKey   NVARCHAR( 10) ' +
      ',@cLoadKey    NVARCHAR( 10) ' +
      ',@cLOC        NVARCHAR( 10) ' +
      ',@cID         NVARCHAR( 18) ' +
      ',@cSKU        NVARCHAR( 20) '
END

/*--------------------------------------------------------------------------------------------------
                                               Swap UCC
--------------------------------------------------------------------------------------------------*/
BEGIN
/*
   Task dispatched:
   UCC to pick (UCC on PickDetail.DropID). Only LOC, ID, not specify SKU, QTY

   Actual UCC scanned:
   UCC free from alloc
   UCC with replen
   UCC with alloc

   All scenarios:
   1. UCC to pick = UCC taken, no swap
   2. UCC to pick, swap UCC free
      4.1. No swap LOT
      4.2. Swap LOT
   3. UCC to pick, swap UCC with alloc (might in other pickslip)
      2.1. No swap LOT
      2.2. Swap LOT
   4. UCC to pick, swap UCC with replen
      3.1. No swap LOT
      3.2. Swap LOT
*/

   DECLARE @cNewPickDetailKey NVARCHAR( 10)
   DECLARE @cPickDetailKey    NVARCHAR( 18)
   DECLARE @nQTY_Bal          INT
   DECLARE @nQTY_PD           INT
   DECLARE @curPD             CURSOR
   DECLARE @cLOT              NVARCHAR( 10)

   --UWP-18306 CYU027
   IF @cType = 'SHORT'
   BEGIN
      SET @cSQLCustom =
              'INSERT INTO #tTaskPD (PickDetailKey, LOT, QTY, UOM) ' +
              'SELECT PD.PickDetailKey, PD.LOT, PD.QTY, PD.UOM ' +
              @cSQLCommon +
              ' AND PD.Status = ''0'' '
      SET @cSQLCustomParam = @cSQLCommonParam
      EXEC sp_executeSQL @cSQLCustom, @cSQLCustomParam
         ,@cPickSlipNo = @cPickSlipNo
         ,@cOrderKey   = @cOrderKey
         ,@cLoadKey    = @cLoadKey
         ,@cLOC        = @cLOC
         ,@cID         = @cID
         ,@cSKU        = @cSKU

      SET @curPD = CURSOR FOR
         SELECT PickDetailKey FROM #tTaskPD ORDER BY PickDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
         BEGIN
            BEGIN TRAN
            SAVE TRAN rdt_957Confirm04
            -- Update PickDetail
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                                                    Status = '4',
                                                    EditDate = GETDATE(),
                                                    EditWho  = SUSER_SNAME(),
                                                    TrafficCop = NULL
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 209758
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail
               GOTO RollBackTran
            END

            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

      GOTO SHORT_PICK_QUIT
   END

   -- Check SKU on pick slip
   SET @nRowCount = 0
   SET @cSQLCustom = 'SELECT TOP 1 @nRowCount = 1 ' + @cSQLCommon
   SET @cSQLCustomParam = @cSQLCommonParam +
      ',@nRowCount   INT OUTPUT '
   exec sp_executeSQL @cSQLCustom, @cSQLCustomParam
      ,@cPickSlipNo = @cPickSlipNo
      ,@cOrderKey   = @cOrderKey
      ,@cLoadKey    = @cLoadKey
      ,@cLOC        = @cLOC
      ,@cID         = @cID
      ,@cSKU        = @cActUCCSKU
      ,@nRowCount   = @nRowCount OUTPUT
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 209756
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- SKU not on PS
      GOTO Quit
   END

   -- Get task PickDetail (match UCCNo)
   SET @cSQLCustom =
      'INSERT INTO #tTaskPD (PickDetailKey, LOT, QTY, UOM) ' +
      'SELECT PD.PickDetailKey, PD.LOT, PD.QTY, PD.UOM ' +
      @cSQLCommon +
         ' AND PD.DropID = @cActUCCNo ' +
         ' AND PD.Status = ''0'' '
   SET @cSQLCustomParam = @cSQLCommonParam +
      ',@cActUCCNo  NVARCHAR( 20) '
   EXEC sp_executeSQL @cSQLCustom, @cSQLCustomParam
      ,@cPickSlipNo = @cPickSlipNo
      ,@cOrderKey   = @cOrderKey
      ,@cLoadKey    = @cLoadKey
      ,@cLOC        = @cLOC
      ,@cID         = @cID
      ,@cSKU        = @cActUCCSKU
      ,@cActUCCNo   = @cActUCCNo

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_957Confirm04 -- For rollback or commit only our own transaction

   -- 1. UCC to pick = UCC taken, no swap
   IF EXISTS( SELECT TOP 1 1 FROM #tTaskPD)
   BEGIN
      -- Get task's PickDetail info
      SELECT @nTaskQTY = ISNULL( SUM( QTY), 0) FROM #tTaskPD

      -- Check PickDetail changed
      IF @nTaskQTY <> @nActUCCQTY
      BEGIN
         SET @nErrNo = 209757
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
         GOTO RollBackTran
      END

      SET @curPD = CURSOR FOR
         SELECT PickDetailKey FROM #tTaskPD ORDER BY PickDetailKey
      OPEN @curPD
      FETCH NEXT FROM @curPD INTO @cPickDetailKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Update PickDetail
         UPDATE dbo.PickDetail WITH(ROWLOCK) SET
            Status = CASE WHEN UOM = '2' THEN '5' ELSE '3' END,
            --CaseID = CASE WHEN UOM = '2' THEN @cActUCCNo ELSE CaseID END,
            CaseID = CASE WHEN UOM = '2' THEN @cDropID ELSE CaseID END,
            Notes = @cActUCCNo,
            DropID = @cDropID,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE PickDetailKey = @cPickDetailKey
         IF @@ERROR <> 0 OR @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 209758
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
            GOTO RollBackTran
         END
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
      END

      -- Actual
      UPDATE dbo.UCC WITH(ROWLOCK) SET
         Status = '5', -- 5=Picked
         UserDefined01 = @cDropID,
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cActUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 209759
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

      GOTO SwapUCC_Quit
   END

   -- Get randomly 1 carton on own pickslip (match LOC, ID, SKU, QTY, L01, optional match LOT)
   SET @cSQLCustom =
      ' SELECT TOP 1 @cTaskUCCNo = PD.DropID ' +
      @cSQLCommon +
         ' AND PD.DropID <> '''' ' +
         ' AND PD.Status = ''0'' ' +
         ' AND LA.Lottable01 = @cLottable01 ' +
      ' GROUP BY PD.DropID, PD.LOT ' +
      ' HAVING SUM( PD.QTY) = @nQTY ' +
      ' ORDER BY CASE WHEN PD.LOT = @cActUCCLOT THEN 1 ELSE 2 END '
   SET @cSQLCustomParam = @cSQLCommonParam +
      ',@cTaskUCCNo     NVARCHAR( 20) OUTPUT ' +
      ',@nQTY           INT ' +
      ',@cActUCCLOT     NVARCHAR( 10) ' +
      ',@cLottable01    NVARCHAR( 18)  '
   EXEC sp_executeSQL @cSQLCustom, @cSQLCustomParam
      ,@cPickSlipNo = @cPickSlipNo
      ,@cOrderKey   = @cOrderKey
      ,@cLoadKey    = @cLoadKey
      ,@cLOC        = @cLOC
      ,@cID         = @cID
      ,@cSKU        = @cActUCCSKU
      ,@nQTY        = @nActUCCQTY
      ,@cTaskUCCNo  = @cTaskUCCNo OUTPUT
      ,@cActUCCLOT  = @cActUCCLOT -- for sorting only
      ,@cLottable01 = @cActLottable01

   -- Check QTY
   IF @cTaskUCCNo = ''
   BEGIN
      SET @nErrNo = 209760
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff QTY / L01
      GOTO RollBackTran
   END

   -- Get task PickDetail (of that random carton)
   SET @cSQLCustom =
      ' INSERT INTO #tTaskPD (PickDetailKey, LOT, QTY, UOM) ' +
      ' SELECT PD.PickDetailKey, PD.LOT, PD.QTY, PD.UOM ' +
      @cSQLCommon +
         ' AND PD.DropID = @cTaskUCCNo ' +
         ' AND PD.Status = ''0'' '
   SET @cSQLCustomParam = @cSQLCommonParam +
      ',@cTaskUCCNo         NVARCHAR( 20) '
   EXEC sp_executeSQL @cSQLCustom, @cSQLCustomParam
      ,@cPickSlipNo = @cPickSlipNo
      ,@cOrderKey   = @cOrderKey
      ,@cLoadKey    = @cLoadKey
      ,@cLOC        = @cLOC
      ,@cID         = @cID
      ,@cSKU        = @cActUCCSKU
      ,@cTaskUCCNo  = @cTaskUCCNo

   -- Get storer config
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   -- SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   -- IF @cPickConfirmStatus = '0'
   --    SET @cPickConfirmStatus = '5'

   -- PickConfirmStatus by UOM
   SELECT TOP 1
      @cPickConfirmStatus =
         CASE WHEN UOM = '2' THEN '5' -- Full carton
              WHEN UOM = '7' THEN '3' -- Conso carton
              ELSE '5'
         END
   FROM #tTaskPD

   -- Get Task UCC info
   SELECT TOP 1 @cTaskLOT = LOT FROM #tTaskPD
   SET @nTaskQTY = @nActUCCQTY

   -- 2. UCC to pick, swap UCC free
   IF @cActUCCStatus = '1' -- Free
   BEGIN
      -- Don't need to swap LOT
      IF @cTaskLOT = @cActUCCLOT
      BEGIN
         -- Task
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM #tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update PickDetail
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               --DropID = @cActUCCNo,
               DropID = @cDropID,
               -- CaseID = CASE WHEN UOM = '2' THEN @cActUCCNo ELSE CaseID END,
               CaseID = CASE WHEN UOM = '2' THEN @cDropID ELSE CaseID END,
               Status = @cPickConfirmStatus,
               Notes = @cActUCCNo,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 209761
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END
      END
      ELSE
      BEGIN
         -- Task
         -- Unallocate
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM #tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               QTY = 0,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         -- Reallocate
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, QTY FROM #tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               Status = @cPickConfirmStatus,
               LOT = @cActUCCLOT,
               --DropID = @cActUCCNo,
               DropID = @cDropID,
               Notes = @cActUCCNo,
               --CaseID = CASE WHEN UOM = '2' THEN @cActUCCNo ELSE CaseID END,
               CaseID = CASE WHEN UOM = '2' THEN @cDropID ELSE CaseID END,
               QTY = @nQTY,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END
      END

      -- Task
      UPDATE dbo.UCC WITH(ROWLOCK) SET
         Status = '1', -- 1=Received
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cTaskUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 209762
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

      -- Actual
      UPDATE dbo.UCC WITH(ROWLOCK) SET
         Status = '5', -- 5=Picked
         UserDefined01 = @cDropID,
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cActUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 209763
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END
   END

   -- 3. UCC to pick, swap UCC with alloc (might in other pickslip)
   IF @cActUCCStatus = '3' -- Alloc
   BEGIN
      -- Get actual PickDetail
      SET @cSQLCustom =
         ' INSERT INTO #tActPD (PickDetailKey, LOT, QTY) ' +
         ' SELECT PD.PickDetailKey, LOT, QTY ' +
         ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +
         ' WHERE PD.StorerKey = @cStorerKey ' +
            ' AND PD.LOC = @cLOC ' +
            ' AND PD.ID  = @cID ' +
            ' AND PD.SKU = @cSKU ' +
            ' AND PD.QTY > 0 ' +
            ' AND PD.Status = ''0'' ' +
            ' AND PD.DropID = @cActUCCNo ' +
            ' AND PD.LOT = @cActUCCLOT '
      SET @cSQLCustomParam =
         ' @cStorerKey  NVARCHAR( 15) ' +
         ',@cLOC        NVARCHAR( 10) ' +
         ',@cID         NVARCHAR( 18) ' +
         ',@cSKU        NVARCHAR( 20) ' +
         ',@cActUCCNo   NVARCHAR( 20) ' +
         ',@cActUCCLOT  NVARCHAR( 10) '
      EXEC sp_executeSQL @cSQLCustom, @cSQLCustomParam
         ,@cStorerKey  = @cStorerKey
         ,@cLOC        = @cLOC
         ,@cID         = @cID
         ,@cSKU        = @cActUCCSKU
         ,@cActUCCNo   = @cActUCCNo
         ,@cActUCCLOT  = @cActUCCLOT

      -- Get task's PickDetail info
      SELECT @nQTY = ISNULL( SUM( QTY), 0) FROM #tActPD

      -- Check PickDetail changed
      IF @nQTY <> @nActUCCQTY
      BEGIN
         SET @nErrNo = 209764
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PKDtl changed
         GOTO RollBackTran
      END

      -- Don't need to swap LOT
      IF @cTaskLOT = @cActUCCLOT
      BEGIN
         -- Task
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM #tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update PickDetail
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               -- DropID = @cActUCCNo,
               DropID = @cDropID,
               -- CaseID = CASE WHEN UOM = '2' THEN @cActUCCNo ELSE CaseID END,
               CaseID = CASE WHEN UOM = '2' THEN @cDropID ELSE CaseID END,
               Notes = @cActUCCNo,
               Status = @cPickConfirmStatus,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 209765
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         -- Actual
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM #tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update PickDetail
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               DropID = @cTaskUCCNo,
               -- Status = @cPickConfirmStatus,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 209766
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END
      END
      ELSE
      BEGIN
         -- Unallocate
         -- Task
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM #tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               QTY = 0,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         -- Actual
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM #tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               QTY = 0,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         -- Reallocate
         -- Task
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, QTY FROM #tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               Status = @cPickConfirmStatus,
               LOT = @cActUCCLOT,
               -- DropID = @cActUCCNo,
               DropID = @cDropID,
               --CaseID = CASE WHEN UOM = '2' THEN @cActUCCNo ELSE CaseID END,
               CaseID = CASE WHEN UOM = '2' THEN @cDropID ELSE CaseID END,
               Notes = @cActUCCNo,
               QTY = @nQTY,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END

         -- Actual
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, QTY FROM #tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               -- Status = @cPickConfirmStatus,
               LOT = @cTaskLOT,
               DropID = @cTaskUCCNo,
               QTY = @nQTY,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END
      END

      -- Actual
      UPDATE dbo.UCC WITH(ROWLOCK) SET
         Status = '5', -- 5=Picked
         UserDefined01 = @cDropID,
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cActUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 209767
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END
   END

   -- 4. UCC to pick, swap UCC with replen
   IF @cActUCCStatus = '4' -- Replen
   BEGIN
      -- Get actual replen info
      SELECT
         @cReplenKey = ReplenishmentKey,
         @cActToLOC = ToLOC,
         @cActToID = ToID,
         @nActPendingMoveIn = ISNULL( PendingMoveIn, 0),
         @nActQTYReplen = ISNULL( QTYReplen, 0)
      FROM dbo.Replenishment WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND FromLoc = @cLOC
         AND ID = @cID
         AND RefNo = @cActUCCNo
         AND SKU = @cActUCCSKU
         AND QTY = @nActUCCQTY
         AND LOT = @cActUCCLOT
         AND Confirmed = 'N'

      -- Check replen changed
      IF @cReplenKey = ''
      BEGIN
         SET @nErrNo = 209768
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Replen changed
         GOTO RollBackTran
      END

      DECLARE @cAllowOverAllocations NVARCHAR( 1) = '0'
      DECLARE @bSuccess INT = 0
      EXECUTE nspGetRight
         @cFacility,             -- Facility
         @cStorerKey,            -- Storerkey
         '',                     -- SKU
         'ALLOWOVERALLOCATIONS', -- ConfigKey
         @bSuccess              OUTPUT,
         @cAllowOverAllocations OUTPUT,
         0, -- @n_err                 OUTPUT,
         '' -- @c_errmsg              OUTPUT
      IF @bSuccess <> 1
      BEGIN
         SET @nErrNo = 209769
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspGetRight
         GOTO Quit
      END

      -- Replenish LOT could be partially or fully overallocated in pick face (have PickDetail)
      IF @cAllowOverAllocations = '1' AND
         (SELECT QTY-QTYAllocated-QTYPicked FROM dbo.LOT WITH (NOLOCK) WHERE LOT = @cActUCCLOT) < @nActUCCQTY
      BEGIN
         -- Get actual PickDetail
         SET @nQTY_Bal = @nActUCCQTY
         SET @curPD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT PD.PickDetailKey, PD.LOT, PD.QTY
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.StorerKey = @cStorerkey
               AND PD.LOT = @cActUCCLOT
               AND PD.LOC = @cActToLOC
               AND PD.Status = '0'
               AND PD.QTY > 0
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cLOT, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @nQTY <= @nQTY_Bal
            BEGIN
               INSERT INTO #tActPD (PickDetailKey, LOT, QTY) VALUES (@cPickDetailKey, @cLOT, @nQTY)
               SET @nQTY_Bal = @nQTY_Bal - @nQTY
            END
            ELSE
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
                  SET @nErrNo = 209770
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --nspg_GetKey
                  GOTO RollBackTran
               END

               -- Create new a PickDetail to hold the balance
               INSERT INTO dbo.PickDetail (
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM,
                  UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                  ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                  PickDetailKey,
                  Status,
                  QTY,
                  TrafficCop,
                  OptimizeCop)
               SELECT
                  CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,
                  UOMQTY, QTYMoved, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup,
                  CartonType, ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod, WaveKey,
                  EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, TaskDetailKey, TaskManagerReasonKey, Notes,
                  @cNewPickDetailKey,
                  Status,
                  @nQTY - @nQTY_Bal, -- QTY
                  NULL, -- TrafficCop
                  '1'   -- OptimizeCop
               FROM dbo.PickDetail WITH (NOLOCK)
      			WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
      				SET @nErrNo = 209771
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PKDtl Fail
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
                     SET @nErrNo = 209772
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RefKeyFail
                     GOTO RollBackTran
                  END
               END

               -- Change orginal PickDetail with exact QTY (with TrafficCop)
               UPDATE dbo.PickDetail WITH (ROWLOCK) SET
                  QTY = @nQTY_Bal,
                  EditDate = GETDATE(),
                  EditWho  = SUSER_SNAME(),
                  Trafficcop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 209773
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
                  GOTO RollBackTran
               END

               INSERT INTO #tActPD (PickDetailKey, LOT, QTY) VALUES (@cPickDetailKey, @cLOT, @nQTY_Bal)
               SET @nQTY_Bal = 0
            END

            IF @nQTY_Bal = 0
               BREAK

            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @cLOT, @nQTY
         END
      END

      -- Don't need to swap LOT
      IF @cTaskLOT = @cActUCCLOT
      BEGIN
         -- Task
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM #tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update PickDetail
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               -- DropID = @cActUCCNo,
               DropID = @cDropID,
               -- CaseID = CASE WHEN UOM = '2' THEN @cActUCCNo ELSE CaseID END,
               CaseID = CASE WHEN UOM = '2' THEN @cDropID ELSE CaseID END,
               Notes = @cActUCCNo,
               Status = @cPickConfirmStatus,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            IF @@ERROR <> 0 OR @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 209774
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PKDtl Fail
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         -- Actual
         UPDATE dbo.Replenishment WITH(ROWLOCK) SET
            RefNo = @cTaskUCCNo,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME(),
            ArchiveCop = NULL
         WHERE ReplenishmentKey = @cReplenKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 209775
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RPL Fail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         -- Unallocate (task)
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM #tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               QTY = 0,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         -- Unallocate (actual)
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey FROM #tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               QTY = 0,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
         END

         -- Reallocate (task)
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, QTY FROM #tTaskPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               LOT = @cActUCCLOT,
               --DropID = @cActUCCNo,
               DropID = @cDropID,
               -- CaseID = CASE WHEN UOM = '2' THEN @cActUCCNo ELSE CaseID END,
               CaseID = CASE WHEN UOM = '2' THEN @cDropID ELSE CaseID END,
               Notes = @cActUCCNo,
               QTY = @nQTY,
               Status = @cPickConfirmStatus,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END

         -- Reallocate (actual)
         SET @curPD = CURSOR FOR
            SELECT PickDetailKey, QTY FROM #tActPD ORDER BY PickDetailKey
         OPEN @curPD
         FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            UPDATE dbo.PickDetail WITH(ROWLOCK) SET
               LOT = @cTaskLOT,
               -- DropID = @cTaskUCCNo,
               QTY = @nQTY,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE PickDetailKey = @cPickDetailKey
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
               GOTO RollBackTran
            END
            FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nQTY
         END

         -- Actual
         UPDATE dbo.Replenishment WITH(ROWLOCK) SET
            LOT = @cTaskLOT,
            RefNo = @cTaskUCCNo,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME(),
            ArchiveCop = NULL
         WHERE ReplenishmentKey = @cReplenKey
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 209776
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RPL Fail
            GOTO RollBackTran
         END

         -- Locking
         IF @nActQTYReplen > 0
         BEGIN
            -- Task
            UPDATE dbo.LOTxLOCxID WITH(ROWLOCK) SET
               QTYReplen = QTYReplen + @nActQTYReplen,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE LOT = @cTaskLOT
               AND LOC = @cLOC
               AND ID = @cID
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 209777
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd LLI Fail
               GOTO RollBackTran
            END

            -- Actual
            UPDATE dbo.LOTxLOCxID WITH(ROWLOCK) SET
               QTYReplen = QTYReplen - @nActQTYReplen,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE LOT = @cActUCCLOT
               AND LOC = @cLOC
               AND ID = @cID
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 209778
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd LLI Fail
               GOTO RollBackTran
            END
         END

         -- Booking
         IF @nActPendingMoveIn > 0
         BEGIN
            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
               ,'' --FromLOC
               ,'' --FromID
               ,'' --SuggLOC
               ,'' --Storer
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cUCCNo = @cActUCCNo
            IF @nErrNo <> 0
               GOTO RollbackTran

            EXEC rdt.rdt_Putaway_PendingMoveIn '', 'LOCK'
               ,@cLOC --FromLOC
               ,@cID  --FromID
               ,@cActToLOC --SuggLOC
               ,@cStorerKey --Storer
               ,@nErrNo  OUTPUT
               ,@cErrMsg OUTPUT
               ,@cSKU = @cActUCCSKU
               ,@nPutawayQTY = @nTaskQTY
               ,@cFromLOT = @cTaskLOT
               ,@cToID = @cActToID
               ,@cUCCNo = @cTaskUCCNo
               ,@nFunc = @nFunc
            IF @nErrNo <> 0
            GOTO RollBackTran
         END
      END

      -- Task
      UPDATE dbo.UCC WITH(ROWLOCK) SET
         Status = '4', -- 4=Replen
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cTaskUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 209779
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END

      -- Actual
      UPDATE dbo.UCC WITH(ROWLOCK) SET
         Status = '5', -- 5=Picked
         UserDefined01 = @cDropID,
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE StorerKey = @cStorerkey
         AND UCCNo = @cActUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 209780
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
         GOTO RollBackTran
      END
   END

   SwapUCC_Quit:

END

/*--------------------------------------------------------------------------------------------------
                                               Packing
--------------------------------------------------------------------------------------------------*/
BEGIN
   -- Full carton
   IF EXISTS( SELECT TOP 1 1 FROM #tTaskPD WHERE UOM = '2')
   BEGIN
      DECLARE @cPackOrderKey   NVARCHAR( 10)
      DECLARE @cPackLoadKey    NVARCHAR( 10)
      DECLARE @cConsigneeKey   NVARCHAR( 15)

      -- Get UCC info
      SELECT TOP 1
         @cPackOrderKey = O.OrderKey,
         @cPackLoadKey = O.LoadKey,
         @cConsigneeKey = O.ConsigneeKey
      FROM dbo.Orders O WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
      WHERE O.StorerKey = @cStorerKey
         AND PD.Notes = @cActUCCNo
         AND PD.Status <> '4'
         AND PD.QTY > 0

      /*--------------------------------------------------------------------------------------------------
                                                   PackHeader
      --------------------------------------------------------------------------------------------------*/
      DECLARE @cPackPickSlipNo NVARCHAR( 10) = ''
      DECLARE @cPackHeaderTypeSP NVARCHAR( 20)

      -- Config follow FN832 Carton Pack module
      SET @cPackHeaderTypeSP = rdt.RDTGetConfig( @nFunc, 'PackHeaderTypeSP', @cStorerKey)
      IF @cPackHeaderTypeSP = '0'
         SET @cPackHeaderTypeSP = ''

      -- Auto detact or pack by order
      IF @cPackHeaderTypeSP IN ('', 'ORDER')
         SELECT @cPackPickSlipNo = PickSlipNo FROM dbo.PackHeader WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND OrderKey = @cPackOrderKey

      -- Auto detact or pack by load
      IF @cPackHeaderTypeSP IN ('', 'LOAD') OR @cPackPickSlipNo = ''
         SELECT @cPackPickSlipNo = PickSlipNo FROM dbo.PackHeader WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND OrderKey = '' AND LoadKey = @cPackLoadKey

      -- PackHeader
      IF @cPackPickSlipNo = ''
      BEGIN
         -- New PickSlipNo
         IF @cPackPickSlipNo = ''
         BEGIN
            EXECUTE dbo.nspg_GetKey
               'PICKSLIP',
               9,
               @cPackPickSlipNo  OUTPUT,
               @bSuccess         OUTPUT,
               @nErrNo           OUTPUT,
               @cErrMsg          OUTPUT
            IF @nErrNo <> 0
               GOTO RollBackTran

            SET @cPackPickSlipNo = 'P' + @cPackPickSlipNo
         END

         -- Specified as ORDER or not specify
         IF @cPackHeaderTypeSP IN ('', 'ORDER')
         BEGIN
            INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, ConsigneeKey, LoadKey)
            VALUES (@cPackPickSlipNo, @cStorerKey, @cPackOrderKey, @cConsigneeKey, @cPackLoadKey)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 209781
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PHdr Fail
               GOTO RollBackTran
            END
         END

         -- Specified as LOAD
         ELSE IF @cPackHeaderTypeSP = 'LOAD'
         BEGIN
            INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, ConsigneeKey, LoadKey)
            VALUES (@cPackPickSlipNo, @cStorerKey, '', '', @cPackLoadKey)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 209782
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PHdr Fail
               GOTO RollBackTran
            END
         END
      END


      /*--------------------------------------------------------------------------------------------------
                                                   PackDetail
      --------------------------------------------------------------------------------------------------*/
      -- New carton
      DECLARE @nCartonNo INT = 0
      DECLARE @cLabelNo NVARCHAR( 20) = ''

      -- Get UCC info
      SELECT
         @cSKU = SKU,
         @nQTY = QTY
      FROM UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cActUCCNo
      SET @nRowCount = @@ROWCOUNT

      -- Confirm SKU
      IF @nRowCount = 1
      BEGIN
         -- Confirm
         EXEC RDT.rdt_Pack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
            ,@cPickSlipNo    = @cPackPickSlipNo
            ,@cFromDropID    = '' -- @cFromDropID
            ,@cSKU           = @cSKU
            ,@nQTY           = @nQTY
            ,@cUCCNo         = @cActUCCNo
            ,@cSerialNo      = '' -- @cSerialNo
            ,@nSerialQTY     = 0  -- @nSerialQTY
            ,@cPackDtlRefNo  = '' -- @cPackDtlRefNo
            ,@cPackDtlRefNo2 = '' -- @cPackDtlRefNo2
            ,@cPackDtlUPC    = '' -- @cPackDtlUPC
            --,@cPackDtlDropID = @cActUCCNo -- @cPackDtlDropID
            ,@cPackDtlDropID = @cDropID
            ,@nCartonNo      = @nCartonNo    OUTPUT
            ,@cLabelNo       = @cLabelNo     OUTPUT
            ,@nErrNo         = @nErrNo       OUTPUT
            ,@cErrMsg        = @cErrMsg      OUTPUT
            ,@nBulkSNO       = 0
            ,@nBulkSNOQTY    = 0
            ,@cPackData1     = ''
            ,@cPackData2     = ''
            ,@cPackData3     = ''
            ,@nUseStandard   = 1
         IF @nErrNo <> 0
            GOTO RollBackTran
      END

      -- Confirm SKU for multi SKU UCC
      IF @nRowCount > 1
      BEGIN
         DECLARE @curUCC CURSOR
         SET @curUCC = CURSOR SCROLL FOR -- Need scroll cursor for 2nd loop in below
            SELECT SKU, QTY
            FROM UCC WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND UCCNo = @cActUCCNo
            ORDER BY UCC_RowRef
         OPEN @curUCC
         FETCH NEXT FROM @curUCC INTO @cSKU, @nQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Confirm
            EXEC RDT.rdt_Pack_Confirm @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey
               ,@cPickSlipNo    = @cPackPickSlipNo
               ,@cFromDropID    = '' -- @cFromDropID
               ,@cSKU           = @cSKU
               ,@nQTY           = @nQTY
               ,@cUCCNo         = @cActUCCNo
               ,@cSerialNo      = '' -- @cSerialNo
               ,@nSerialQTY     = 0  -- @nSerialQTY
               ,@cPackDtlRefNo  = '' -- @cPackDtlRefNo
               ,@cPackDtlRefNo2 = '' -- @cPackDtlRefNo2
               ,@cPackDtlUPC    = '' -- @cPackDtlUPC
               -- ,@cPackDtlDropID = @cActUCCNo -- @cPackDtlDropID
               ,@cPackDtlDropID = @cDropID
               ,@nCartonNo      = @nCartonNo    OUTPUT
               ,@cLabelNo       = @cLabelNo     OUTPUT
               ,@nErrNo         = @nErrNo       OUTPUT
               ,@cErrMsg        = @cErrMsg      OUTPUT
               ,@nBulkSNO       = 0
               ,@nBulkSNOQTY    = 0
               ,@cPackData1     = ''
               ,@cPackData2     = ''
               ,@cPackData3     = ''
               ,@nUseStandard   = 1
            IF @nErrNo <> 0
               GOTO RollBackTran

            FETCH NEXT FROM @curUCC INTO @cSKU, @nQTY
         END
      END


      /*--------------------------------------------------------------------------------------------------
                                               Auto pack confirm
      --------------------------------------------------------------------------------------------------*/
      DECLARE @cNoPackConfirm    NVARCHAR(1)
      SET @cNoPackConfirm = rdt.rdtGetConfig( @nFunc, 'NoPackConfirm', @cStorerKey)

      IF @cNoPackConfirm <> '1'
      BEGIN
         DECLARE @nPickQTY INT
         DECLARE @nPackQTY INT
         DECLARE @cPackConfirm NVARCHAR( 1) = ''

         -- Get pack QTY
         SELECT @nPackQTY = ISNULL( SUM( QTY), 0)
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPackPickSlipNo

         -- Discrete PickSlip
         IF @cPackHeaderTypeSP IN ('', 'ORDER')
         BEGIN
            -- Check outstanding PickDetail
            IF EXISTS( SELECT TOP 1 1
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.OrderKey = @cPackOrderKey
                  AND (PD.Status = '4' OR PD.Status < '5') -- Short pick or not yet pick
                  AND PD.QTY > 0)
               SET @cPackConfirm = 'N'
            ELSE
               SET @cPackConfirm = 'Y'

            -- Check fully packed
            IF @cPackConfirm = 'Y'
            BEGIN
               SELECT @nPickQTY = SUM( PD.QTY)
               FROM dbo.PickDetail PD WITH (NOLOCK)
               WHERE PD.OrderKey = @cPackOrderKey

               IF @nPickQTY <> @nPackQTY
                  SET @cPackConfirm = 'N'
            END
         END

         -- Conso PickSlip
         ELSE IF @cPackHeaderTypeSP = 'LOAD'
         BEGIN
            -- Check outstanding PickDetail
            IF EXISTS( SELECT TOP 1 1
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
               WHERE LPD.LoadKey = @cLoadKey
                  AND (PD.Status = '4' OR PD.Status < '5') -- Short pick or not yet pick
                  AND PD.QTY > 0)
               SET @cPackConfirm = 'N'
            ELSE
               SET @cPackConfirm = 'Y'

            -- Check fully packed
            IF @cPackConfirm = 'Y'
            BEGIN
               SELECT @nPickQTY = SUM( PD.QTY)
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
               WHERE LPD.LoadKey = @cLoadKey

               IF @nPickQTY <> @nPackQTY
                  SET @cPackConfirm = 'N'
            END
         END

         -- Pack confirm
         IF @cPackConfirm = 'Y'
         BEGIN
            -- Pack confirm
            UPDATE PackHeader WITH(ROWLOCK) SET
               Status = '9'
            WHERE PickSlipNo = @cPackPickSlipNo
               AND Status <> '9'
            SET @nErrNo = @@ERROR
            IF @nErrNo <> 0
            BEGIN
               -- SET @nErrNo = 209783
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PackCfm Fail
               GOTO RollBackTran
            END
         END
      END
   END
END

/*--------------------------------------------------------------------------------------------------
                                                 WCS
--------------------------------------------------------------------------------------------------*/
BEGIN
   IF dbo.fnc_GetRight( @cFacility, @cStorerKey, '', 'WCS') = '1'
   BEGIN
      DECLARE @cPickUOM NVARCHAR( 1)
      SELECT TOP 1
      @cPickUOM =
         CASE WHEN UOM = '7' THEN '7' -- Conso carton
              ELSE '0'
         END
      FROM #tTaskPD
      IF @cPickUOM = '7'
      BEGIN
         DECLARE @cKey NVARCHAR( 20)
         -- SET @cKey =  @cActUCCNo
         SET @cKey = @cDropID

         EXEC dbo.ispGenTransmitLog2
            @c_TableName      = 'WSRDTTOTECFM',
            @c_Key1           = @cPickSlipNo,
            @c_Key2           = @cKey,
            @c_Key3           = @cStorerKey,
            @c_TransmitBatch  = '',
            @b_success        = @bSuccess    OUTPUT,
            @n_err            = @nErrNo      OUTPUT,
            @c_errmsg         = @cErrMsg     OUTPUT
         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 209784
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS TLog2 Fail
            GOTO Quit
         END
         IF ISNULL(@cTaskUCCNo,'')!=''
         BEGIN
            SET @cKey = @cTaskUCCNo

            EXEC dbo.ispGenTransmitLog2
               @c_TableName      = 'WSRDTTOTECFM',
               @c_Key1           = @cPickSlipNo,
               @c_Key2           = @cKey,
               @c_Key3           = @cStorerKey,
               @c_TransmitBatch  = '',
               @b_success        = @bSuccess    OUTPUT,
               @n_err            = @nErrNo      OUTPUT,
               @c_errmsg         = @cErrMsg     OUTPUT
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 209784
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS TLog2 Fail
               GOTO Quit
            END
         END
      END
   END
END

SHORT_PICK_QUIT:
   -- Event log
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '3', -- Picking
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerKey,
      @cLocation     = @cLOC,
      @cID           = @cID,
      @cUCC          = @cActUCCNo,
      @cPickSlipNo   = @cPickSlipNo,
      @cPickZone     = @cPickZone,
      @cDropID       = @cDropID

   -- Log UCC swap
   IF @cTaskUCCNo <> @cActUCCNo
   BEGIN
      DECLARE @cTaskUCCStatus NVARCHAR(1)
      SELECT @cTaskUCCStatus = Status FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cTaskUCCNo AND StorerKey = @cStorerkey

      INSERT INTO rdt.SwapUCC (Func, UCC, NewUCC, ReplenGroup, UCCStatus, NewUCCStatus)
      VALUES (@nFunc, @cTaskUCCNo, @cActUCCNo, @cReplenKey, @cTaskUCCStatus, @cActUCCStatus)
   END

   COMMIT TRAN rdt_957Confirm04
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_957Confirm04 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO