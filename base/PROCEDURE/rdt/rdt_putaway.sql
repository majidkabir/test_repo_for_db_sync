SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Putaway                                         */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Putaway                                                     */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2011-09-06 1.0  Ung      Created                                     */
/* 2012-11-21 1.1  Ung      SOS257047 Add Multi SKU UCC and LOC.LoseUCC */
/* 2014-02-10 1.2  Ung      Fix split UCC multiple times                */
/* 2019-10-08 1.3  Chermain WMS-10753 Change Eventlog Col from          */
/*                          @cRefNo3 to @cucc (cc01)                    */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_Putaway] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @cUserName   NVARCHAR( 10), 
   @cFacility   NVARCHAR( 5), 
   @cLOT        NVARCHAR( 10), -- optional
   @cLOC        NVARCHAR( 10), 
   @cID         NVARCHAR( 18), 
   @cStorerKey  NVARCHAR( 15), -- optional
   @cSKU        NVARCHAR( 20), -- optional
   @nPutawayQTY INT, 
   @cFinalLOC   NVARCHAR( 10), 
   @cLabelType  NVARCHAR( 20) = '', 
   @cUCC		    NVARCHAR( 20) = '',
   @nErrNo      INT          OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max
) AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success INT
   DECLARE @c_outstring NVARCHAR( 255)

   DECLARE @cPA_StorerKey NVARCHAR( 15)
   DECLARE @cPA_SKU   NVARCHAR( 20)
   DECLARE @cPA_LOT   NVARCHAR( 10)
   DECLARE @nPA_QTY   INT
   DECLARE @cPackKey  NVARCHAR( 10)
   DECLARE @cPackUOM3 NVARCHAR( 10)
   DECLARE @nQTY INT
   
   -- Get PackKey, UOM
   SELECT @cPackKey = PackKey FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU
   SELECT @cPackUOM3 = PackUOM3 FROM Pack WITH (NOLOCK) WHERE PackKey = @cPackKey
   
   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_Putaway -- For rollback or commit only our own transaction

   DECLARE @curPutaway CURSOR 
   SET @curPutaway = CURSOR FOR
      SELECT 
         StorerKey, SKU, LOT, 
         (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END))
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = CASE WHEN @cStorerKey = '' THEN StorerKey ELSE @cStorerKey END
         AND SKU = CASE WHEN @cSKU = '' THEN SKU ELSE @cSKU END
         AND LOT = CASE WHEN @cLOT = '' THEN LOT ELSE @cLOT END
         AND LOC = @cLOC
         AND ID  = @cID
         AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)) > 0
      ORDER BY LOT

   OPEN @curPutaway
   FETCH NEXT FROM @curPutaway INTO @cPA_StorerKey, @cPA_SKU, @cPA_LOT, @nPA_QTY

   SET @nQTY = @nPutawayQTY
   WHILE @@FETCH_STATUS = 0
   BEGIN
      IF @nQTY < @nPA_QTY
         SET @nPA_QTY = @nQTY

/* Remark due to not support LOC.CommingleSKU

      -- NOTE: Not convert QTY as nspItrnAddMove will convert QTY based on pass-in UOM
      EXEC dbo.nspRFPA02
           @c_sendDelimiter = '`'           -- NVARCHAR(1)
         , @c_ptcid         = 'RDT'         -- NVARCHAR(5)
         , @c_userid        = 'RDT'         -- NVARCHAR(10)
         , @c_taskId        = 'RDT'         -- NVARCHAR(10)
         , @c_databasename  = NULL          -- NVARCHAR(5)
         , @c_appflag       = NULL          -- NVARCHAR(2)
         , @c_recordType    = NULL          -- NVARCHAR(2)
         , @c_server        = NULL          -- NVARCHAR(30)
         , @c_storerkey     = @cPA_StorerKey-- NVARCHAR(30)
         , @c_lot           = @cPA_LOT      -- NVARCHAR(10) -- optional
         , @c_sku           = @cPA_SKU      -- NVARCHAR(30)
         , @c_fromloc       = @cLOC         -- NVARCHAR(18)
         , @c_fromid        = @cID          -- NVARCHAR(18)
         , @c_toloc         = @cFinalLOC    -- NVARCHAR(18)
         , @c_toid          = @cID          -- NVARCHAR(18)
         , @n_qty           = @nPA_QTY      -- int
         , @c_uom           = @cPackUOM3    -- NVARCHAR(10)
         , @c_packkey       = @cPackKey     -- NVARCHAR(10) -- optional
         , @c_reference     = ' '           -- NVARCHAR(10) -- not used
         , @c_outstring     = @c_outstring  OUTPUT   -- NVARCHAR(255)  OUTPUT
         , @b_Success       = @b_Success    OUTPUT   -- int        OUTPUT
         , @n_err           = @nErrNo       OUTPUT   -- int        OUTPUT
         , @c_errmsg        = @cErrMsg      OUTPUT   -- NVARCHAR(250)  OUTPUT
*/
      
      EXEC rdt.rdt_Move
         @nMobile     = @nMobile,
         @cLangCode   = @cLangCode, 
         @nErrNo      = @nErrNo  OUTPUT,
         @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
         @cSourceType = 'rdt_Putaway', 
         @cStorerKey  = @cStorerKey,
         @cFacility   = @cFacility, 
         @cFromLOC    = @cLOC, 
         @cToLOC      = @cFinalLOC, 
         @cFromID     = @cID,       -- NULL means not filter by ID. Blank is a valid ID
         @cToID       = @cID,       -- NULL means not changing ID. Blank consider a valid ID
         @cSKU        = @cPA_SKU, 
         @nQTY        = @nPA_QTY, 
         @cFromLOT    = @cPA_LOT

      IF @nErrNo <> 0
         GOTO RollBackTran

      SET @nQTY = @nQTY - @nPA_QTY
      IF @nQTY = 0
         BREAK
         
      FETCH NEXT FROM @curPutaway INTO @cPA_StorerKey, @cPA_SKU, @cPA_LOT, @nPA_QTY
   END
   CLOSE @curPutaway
   DEALLOCATE @curPutaway

   -- Update UCC
   IF @cLabelType = 'UCC' OR @cUCC <> ''
   BEGIN
      DECLARE @cLoseID NVARCHAR( 1)
      DECLARE @cLoseUCC NVARCHAR( 1)
      DECLARE @nUCCQTY INT
      
      -- Get LOC info
      SELECT 
         @cLoseID = LoseID, 
         @cLoseUCC = LoseUCC
      FROM LOC WITH (NOLOCK) 
      WHERE LOC = @cFinalLOC

      -- Get UCC info
      SELECT @nUCCQTY = QTY
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo = @cUCC 
         AND StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND Status = '1'
         
      -- Update UCC 
      IF @nPutawayQTY = @nUCCQTY
      BEGIN
         UPDATE UCC WITH (ROWLOCK) SET 
            ID = CASE WHEN @cLoseID = '1' THEN '' ELSE ID END, 
            LOC = @cFinalLOC, 
            EditWho  = sUser_sName(),  
            EditDate = GETDATE(), 
            Status = CASE WHEN @cLoseUCC = '1' THEN '6' ELSE Status END
         WHERE UCCNo = @cUCC 
            AND StorerKey = @cStorerKey
            AND SKU = @cSKU
            AND Status = '1'
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 73901
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UCC Fail
            GOTO RollBackTran
         END
      END
      ELSE
      -- Split UCC record
      BEGIN
/*         
         IF EXISTS( SELECT 1 
            FROM dbo.UCC WITH (NOLOCK) 
            WHERE UCCNo = @cUCC
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND Status = '6')
         BEGIN
            UPDATE dbo.UCC SET
               QTY = QTY + @nPutawayQTY
            WHERE UCCNo = @cUCC
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND Status = '6'
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 73902
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UCC Fail
               GOTO RollBackTran
            END
         END
         ELSE
*/
         BEGIN
            -- Insert putaway QTY
            INSERT INTO dbo.UCC (
               UCCNo, Storerkey, ExternKey, SKU, Sourcekey, Sourcetype, Userdefined01, Userdefined02, Userdefined03, Lot, Receiptkey, ReceiptLineNumber, Orderkey, OrderLineNumber, WaveKey, PickDetailKey, Userdefined04, Userdefined05, Userdefined06, Userdefined07, Userdefined08, Userdefined09, Userdefined10, 
               ID, LOC, QTY, EditWho, EditDate, Status)
            SELECT 
               UCCNo, Storerkey, ExternKey, SKU, Sourcekey, Sourcetype, Userdefined01, Userdefined02, Userdefined03, Lot, Receiptkey, ReceiptLineNumber, Orderkey, OrderLineNumber, WaveKey, PickDetailKey, Userdefined04, Userdefined05, Userdefined06, Userdefined07, Userdefined08, Userdefined09, Userdefined10, 
               CASE WHEN @cLoseID = '1' THEN '' ELSE ID END, --ID
               @cFinalLOC,    --LOC
               @nPutawayQTY,  --QTY 
               sUser_sName(), --EditWho
               GETDATE(),     --EditDate
               '6'            --Status
            FROM dbo.UCC WITH (NOLOCK)
            WHERE UCCNo = @cUCC
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND Status = '1'
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 73903
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS UCC Fail
               GOTO RollBackTran
            END

            -- Update remaining QTY
            UPDATE UCC WITH (ROWLOCK) SET 
               QTY = @nUCCQTY - @nPutawayQTY, 
               EditWho  = sUser_sName(),  
               EditDate = GETDATE()
            WHERE UCCNo = @cUCC 
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND Status = '1'
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 73904
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UCC Fail
               GOTO RollBackTran
            END
         END
      END
   END

   COMMIT TRAN rdt_Putaway -- Only commit change made here
   
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '4', -- Putaway
      @cUserID       = @cUserName,
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerKey,
      @cLocation     = @cLOC,
      @cToLocation   = @cFinalLOC,
      @cID           = @cID,
      @cToID         = @cID,
      @cSKU          = @cSKU,
      @cUOM          = @cPackUOM3,
      @nQTY          = @nPutawayQTY,
      @cLOT          = @cLOT, 
      @cUCC          = @cUCC     --(cc01)
      
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_Putaway -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO