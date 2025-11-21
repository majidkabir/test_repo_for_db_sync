SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513Confirm03                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Conditional trigger transfer                                      */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2021-01-26   Ung       1.0   WMS-16054 Created                             */
/* 2022-01-03   Ung       1.1   Fix error no                                  */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_513Confirm03]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cStorerKey      NVARCHAR( 15)
   ,@cFacility       NVARCHAR(  5)
   ,@cFromLOC        NVARCHAR( 10)
   ,@cFromID         NVARCHAR( 18)
   ,@cSKU            NVARCHAR( 20)
   ,@nQTY            INT
   ,@cToID           NVARCHAR( 18)
   ,@cToLOC          NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT

   -- Move by SKU
   IF @nFunc = 513
   BEGIN
      IF @nStep = 6 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- Enter
         BEGIN
            DECLARE @b_Success   INT = 0
            DECLARE @n_Err       INT = 0
            DECLARE @c_ErrMsg    NVARCHAR(215) = ''
            
            DECLARE @cTransferKey   NVARCHAR( 10) = ''
            DECLARE @cTransferLineNumber  NVARCHAR( 5)
            DECLARE @cToLottable01  NVARCHAR( 18)
            DECLARE @cToLottable02  NVARCHAR( 18)
            DECLARE @cToLottable03  NVARCHAR( 18)
            DECLARE @dToLottable04  DATETIME
            DECLARE @dToLottable05  DATETIME
            DECLARE @cToLottable06  NVARCHAR( 30)
            DECLARE @cToLottable07  NVARCHAR( 30)
            DECLARE @cToLottable08  NVARCHAR( 30)
            DECLARE @cToLottable09  NVARCHAR( 30)
            DECLARE @cToLottable10  NVARCHAR( 30)
            DECLARE @cToLottable11  NVARCHAR( 30)
            DECLARE @cToLottable12  NVARCHAR( 30)
            DECLARE @dToLottable13  DATETIME
            DECLARE @dToLottable14  DATETIME
            DECLARE @dToLottable15  DATETIME
            DECLARE @cPackkey       NVARCHAR( 10)  
            DECLARE @cUOM           NVARCHAR( 10)

            DECLARE @nQTY_Bal    INT
            DECLARE @nQTY_Move   INT
            DECLARE @nLLI_QTY    INT
            DECLARE @cLLI_LOT    NVARCHAR( 10)
            DECLARE @cLLI_ID     NVARCHAR( 18)

            -- Trigger transfer if return stock move to sellable
            IF EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cFromLOC AND HostWhcode LIKE 'RET%') AND
               EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC AND HostWhcode = 'STD')
            BEGIN
               SELECT @cLLI_ID = CASE WHEN LoseID = '1' THEN '' ELSE @cToID END 
               FROM LOC WITH (NOLOCK) 
               WHERE LOC = @cToLOC
                     
               -- Initial 
               SET @nQTY_Bal = @nQTY

               BEGIN TRAN 
               SAVE TRAN rdt_513Confirm03

               -- Loop LLI
            	DECLARE @curLLI CURSOR
         		SET @curLLI = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         			SELECT LOT, (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END))
         			FROM LOTxLOCxID WITH (NOLOCK)
         			WHERE LOC = @cFromLOC
         				AND ID = @cFromID
         				AND StorerKey = @cStorerKey
         				AND SKU = @cSKU
                     AND (QTY - QTYAllocated - QTYPicked - (CASE WHEN QTYReplen < 0 THEN 0 ELSE QTYReplen END)) > 0
               OPEN @curLLI
               FETCH NEXT FROM @curLLI INTO @cLLI_LOT, @nLLI_QTY
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  -- Calc QTY to move
                  IF @nLLI_QTY >= @nQTY_Bal
                     SET @nQTY_Move = @nQTY_Bal
                  ELSE
                     SET @nQTY_Move = @nLLI_QTY
               
                  EXECUTE rdt.rdt_Move
                     @nMobile     = @nMobile,
                     @cLangCode   = @cLangCode,
                     @nErrNo      = @nErrNo  OUTPUT,
                     @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
                     @cSourceType = 'rdt_513Confirm03',
                     @cStorerKey  = @cStorerKey,
                     @cFacility   = @cFacility,
                     @cFromLOC    = @cFromLOC,
                     @cToLOC      = @cToLOC,
                     @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
                     @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
                     @cSKU        = @cSKU,
                     @nQTY        = @nQTY_Move,
                     @cFromLOT    = @cLLI_LOT 
                  IF @nErrNo <> 0
                  BEGIN
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     GOTO RollBackTran
                  END

                  -- Return stock
                  IF EXISTS( SELECT 1 FROM LOTAttribute WITH (NOLOCK) WHERE LOT = @cLLI_LOT AND Lottable03 = 'RET')
                  BEGIN
                     -- Get lottables
                     SELECT
                        @cToLottable01 = Lottable01,
                        @cToLottable02 = Lottable02,
                        @cToLottable03 = Lottable03, 
                        @dToLottable04 = Lottable04,
                        @dToLottable05 = Lottable05,
                        @cToLottable06 = Lottable06,
                        @cToLottable07 = Lottable07,
                        @cToLottable08 = Lottable08,
                        @cToLottable09 = Lottable09,
                        @cToLottable10 = Lottable10,
                        @cToLottable11 = Lottable11,
                        @cToLottable12 = Lottable12,
                        @dToLottable13 = Lottable13,
                        @dToLottable14 = Lottable14,
                        @dToLottable15 = Lottable15
                     FROM dbo.LOTAttribute WITH (NOLOCK)
                     WHERE LOT = @cLLI_LOT

                     -- Get TransferKey
                     IF @cTransferKey = ''
                     BEGIN
                        SELECT @b_Success = 0
                        EXECUTE nspg_getkey
                           @KeyName     = 'TRANSFER',
                           @FieldLength = 10,
                           @KeyString   = @cTransferKey OUTPUT,
                           @b_Success   = @b_Success    OUTPUT,
                           @n_Err       = @n_Err        OUTPUT,
                           @c_ErrMsg    = @c_ErrMsg     OUTPUT
                        IF @b_Success <> 1
                        BEGIN
                           SET @nErrNo = @n_Err
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Getkey Fail
                           GOTO RollBackTran
                        END

                        -- Transfer header
                        INSERT INTO dbo.Transfer
                           (Transferkey, FromStorerkey, ToStorerkey, Type, ReasonCode, Remarks, Facility, ToFacility)
                        VALUES
                           (@cTransferKey, @cStorerkey, @cStorerkey, 'HM-453', 'HM06', 'rdt_523PABySKUCfm04', @cFacility, @cFacility)
                        SET @nErrNo = @@ERROR  
                        IF @nErrNo <> 0
                        BEGIN
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins XFER Fail
                           GOTO RollBackTran
                        END
                     END

                     -- Get SKU info
                     SELECT
                        @cPackkey = Pack.PackKey,
                        @cUOM = Pack.PackUOM3
                     FROM SKU WITH (NOLOCK)
                        JOIN Pack WITH (NOLOCK) ON SKU.PackKey = Pack.PackKey
                     WHERE SKU.StorerKey = @cStorerKey
                        AND SKU = @cSKU

                     -- Get next TransferLineNumber
                     SELECT @cTransferLineNumber =
                        RIGHT( '00000' + CAST( CAST( IsNULL( MAX( TransferLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
                     FROM dbo.TransferDetail WITH (NOLOCK)
                     WHERE TransferKey = @cTransferKey

                     INSERT INTO dbo.TransferDetail (
                        TransferKey, TransferLineNumber, 
                        FromStorerKey, FromSKU, FromLOC, FromLOT, FromID, FromQty, FromPackKey, FromUOM,
                        Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
                        Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
                        Lottable11, Lottable12, Lottable13, Lottable14, Lottable15,
                        ToStorerKey, ToSKU, ToLOC, ToLOT, ToID, ToQTY, ToPackKey, ToUOM, Status, EffectiveDate,
                        ToLottable01, ToLottable02, ToLottable03, ToLottable04, ToLottable05,
                        ToLottable06, ToLottable07, ToLottable08, ToLottable09, ToLottable10,
                        ToLottable11, ToLottable12, ToLottable13, ToLottable14, ToLottable15,
                        UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05,
                        UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10)
                     VALUES (
                        @cTransferKey, @cTransferLineNumber, 
                        @cStorerKey, @cSKU, @cToLOC, @cLLI_LOT, @cLLI_ID, @nQTY_Move, @cPackkey, @cUOM,
                        @cToLottable01, @cToLottable02, @cToLottable03, @dToLottable04, @dToLottable05,
                        @cToLottable06, @cToLottable07, @cToLottable08, @cToLottable09, @cToLottable10,
                        @cToLottable11, @cToLottable12, @dToLottable13, @dToLottable14, @dToLottable15,
                        @cStorerKey, @cSKU, @cToLOC, '', @cLLI_ID, @nQTY_Move, @cPackkey, @cUOM, '0', GETDATE(),
                        @cToLottable01, @cToLottable02, 'STD',          @dToLottable04, @dToLottable05,
                        @cToLottable06, @cToLottable07, @cToLottable08, @cToLottable09, @cToLottable10,
                        @cToLottable11, @cToLottable12, @dToLottable13, @dToLottable14, @dToLottable15,
                        '', '', '', '', '', '', '', '', '', '')
                     SET @nErrNo = @@ERROR  
                     IF @nErrNo <> 0
                     BEGIN
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins XFERD Fail
                        GOTO RollBackTran
                     END
                  END
                  
                  -- Reduce QTY
                  SET @nQTY_Bal = @nQTY_Bal - @nQTY_Move

                  -- Check exit point
                  IF @nQTY_Bal = 0
                     BREAK

                  FETCH NEXT FROM @curLLI INTO @cLLI_LOT, @nLLI_QTY
               END
               
               -- Check fully offset
               IF @nQTY_Bal <> 0
               BEGIN
                  SET @nErrNo = 195351
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QTYOffsetError
                  GOTO RollBackTran
               END

               -- Closing tran due to ispFinalizeTransfer in below close all trans before start processing
               COMMIT TRAN rdt_513Confirm03
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN

               -- Finalize transfer
               EXEC ispFinalizeTransfer
                  @c_Transferkey    = @cTransferKey,
                  @b_Success        = @b_Success OUTPUT,
                  @n_Err            = @n_Err     OUTPUT,
                  @c_ErrMsg         = @c_ErrMsg  OUTPUT
               IF @b_Success <> 1
               BEGIN
                  SET @nErrNo = @n_Err
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Txf Final Fail
                  GOTO Quit
               END
            END
            
            ELSE
            BEGIN
               BEGIN TRAN 
               SAVE TRAN rdt_513Confirm03

               EXECUTE rdt.rdt_Move
                  @nMobile     = @nMobile,
                  @cLangCode   = @cLangCode,
                  @nErrNo      = @nErrNo  OUTPUT,
                  @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
                  @cSourceType = 'rdt_513Confirm03',
                  @cStorerKey  = @cStorerKey,
                  @cFacility   = @cFacility,
                  @cFromLOC    = @cFromLOC,
                  @cToLOC      = @cToLOC,
                  @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
                  @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
                  @cSKU        = @cSKU,
                  @nQTY        = @nQTY
               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO RollBackTran
               END
               
               COMMIT TRAN rdt_513Confirm03
            END
         END
      END
   END
   
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_513Confirm03 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO