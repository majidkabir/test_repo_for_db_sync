SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_UCCMergePallet_Confirm                          */
/* Copyright: IDS                                                       */
/* Purpose: Merge UCC pallet                                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Ver  Author   Purposes                                    */
/* 2012-09-19 1.0  Ung      SOS256003 Created                           */
/* 2017-02-13 1.1  Leong    IN00251879 - Add Userdefine02,03.           */
/* 2017-05-16 1.2  James    Perf tuning (james01)                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_UCCMergePallet_Confirm]
   @nFunc        INT,
   @nMobile      INT,
   @cLangCode    NVARCHAR( 3),
   @cStorerKey   NVARCHAR( 15),
   @cFacility    NVARCHAR( 5),
   @cReceiptKey  NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cFromID      NVARCHAR( 20),
   @cToID        NVARCHAR( 20),
   @cUCCNo       NVARCHAR( 20),
   @nErrNo       INT  OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nErrNo = 0
   SET @cErrMsg = 0

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_UCCMergePallet_Confirm

   -- Merge by pallet
   IF @cUCCNo = ''
   BEGIN
      -- Loop UCC on FromID
      DECLARE curUCC CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT UCCNo
         FROM dbo.UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cLOC
            AND ID = @cFromID
            AND Status = '1'
      OPEN curUCC
      FETCH NEXT FROM curUCC INTO @cUCCNo
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Update UCC
         UPDATE UCC WITH (ROWLOCK) SET
            ID = @cToID,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE UCCNo = @cUCCNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 77051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
            GOTO RollbackTran
         END

         FETCH NEXT FROM curUCC INTO @cUCCNo
      END
      CLOSE curUCC
      DEALLOCATE curUCC

      -- Update ReceiptDetail
      UPDATE ReceiptDetail WITH (ROWLOCK) SET   -- (james01)
         ToID = @cToID,
         EditDate = GETDATE(),
         EditWho = SUSER_SNAME()
      WHERE ReceiptKey = @cReceiptKey
         AND ToID = @cFromID
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 77052
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RD Fail
         GOTO RollbackTran
      END
   END

   -- Merge by UCC
   ELSE
   BEGIN
      DECLARE @cLineNo     NVARCHAR( 5)
      DECLARE @cNewLineNo  NVARCHAR(5)
      DECLARE @cPOKey      NVARCHAR( 10)
      DECLARE @cLottable01 NVARCHAR( 18)
      DECLARE @cLottable02 NVARCHAR( 18)
      DECLARE @cLottable03 NVARCHAR( 18)
      DECLARE @dLottable04 DATETIME
      DECLARE @cUCCSKU     NVARCHAR( 20)
      DECLARE @nUCCQTY     INT
      DECLARE @nQTYExpected INT
      DECLARE @nBeforeReceivedQTY INT
      DECLARE @nBorrowQTYExpected INT
      DECLARE @cUserDefine02 NVARCHAR( 30) -- IN00251879
      DECLARE @cUserDefine03 NVARCHAR( 30) -- IN00251879

      DECLARE @curUCC CURSOR
      SET @curUCC = CURSOR FOR
         SELECT SKU, QTY, ReceiptLineNumber
         FROM dbo.UCC WITH (NOLOCK)
         WHERE UCCNo = @cUCCNo
            AND StorerKey = @cStorerKey

      OPEN @curUCC
      FETCH NEXT FROM @curUCC INTO @cUCCSKU, @nUCCQTY, @cLineNo
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get FROM ReceiptDetail info
         SELECT
            @nQTYExpected = QTYExpected,
            @nBeforeReceivedQTY = BeforeReceivedQTY,
            @cLOC = ToLOC,
            @cLottable01 = Lottable01,
            @cLottable02 = Lottable02,
            @cLottable03 = Lottable03,
            @dLottable04 = Lottable04,
            @cPOKey = POKey
          , @cUserDefine02 = UserDefine02 -- IN00251879
          , @cUserDefine03 = UserDefine03 -- IN00251879
         FROM ReceiptDetail RD WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND ReceiptLineNumber = @cLineNo
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 77053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RD lookup fail
            GOTO RollbackTran
         END

         -- Calc borrow QTYExpected
         SET @nBorrowQTYExpected = 0
         IF (@nQTYExpected -  @nBeforeReceivedQTY) >= 0
         BEGIN
            SET @nBorrowQTYExpected = @nQTYExpected -  @nBeforeReceivedQTY
            IF @nBorrowQTYExpected > @nUCCQTY
               SET @nBorrowQTYExpected = @nUCCQTY
         END

         -- Find TO ReceiptDetail
         SET @cNewLineNo = ''
         SELECT @cNewLineNo = ReceiptLineNumber
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            AND SKU = @cUCCSKU
            AND ToID = @cToID
            AND ToLOC = @cLOC
            AND Lottable01 = @cLottable01
            AND Lottable02 = @cLottable02
            AND Lottable03 = @cLottable03
            AND Lottable04 = @dLottable04
            AND POKey = @cPOKey
            AND UserDefine02 = @cUserDefine02 -- IN00251879
            AND UserDefine03 = @cUserDefine03 -- IN00251879
         -- Increase TO ReceiptDetail
         IF @cNewLineNo = ''
         BEGIN
            -- Create new line
            SET @cNewLineNo = ''
            SELECT @cNewLineNo = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( ReceiptLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
            FROM dbo.ReceiptDetail (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey

            INSERT INTO dbo.ReceiptDetail
               (ReceiptKey, ReceiptLineNumber, POKey, StorerKey, SKU, QTYExpected, BeforeReceivedQTY,
               ToID, ToLOC, Lottable01, Lottable02, Lottable03, Lottable04,
               Status, DateReceived, UOM, PackKey, ConditionCode, EffectiveDate, TariffKey, FinalizeFlag, SplitPalletFlag,
               ExternReceiptKey, ExternLineNo, AltSku, VesselKey,
               VoyageKey, XdockKey, ContainerKey, UnitPrice, ExtendedPrice, FreeGoodQtyExpected,
               FreeGoodQtyReceived, ExportStatus, LoadKey, ExternPoKey,
               UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05,
               UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, POLineNumber, SubReasonCode, DuplicateFrom)
            SELECT
               ReceiptKey, @cNewLineNo, @cPOKey, StorerKey, SKU, @nBorrowQTYExpected, @nUCCQTY,
               @cToID, @cLOC, @cLottable01, @cLottable02, @cLottable03, @dLottable04,
               Status, DateReceived, UOM, PackKey, ConditionCode, EffectiveDate, TariffKey, FinalizeFlag, SplitPalletFlag,
               ExternReceiptKey, ExternLineNo, AltSku, VesselKey,
               VoyageKey, XdockKey, ContainerKey, UnitPrice, ExtendedPrice, FreeGoodQtyExpected,
               FreeGoodQtyReceived, ExportStatus, LoadKey, ExternPoKey,
               UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05,
               UserDefine06, UserDefine07, UserDefine08, UserDefine09, UserDefine10, POLineNumber, SubReasonCode, @cLineNo -- IN00251879
            FROM ReceiptDetail RD WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND ReceiptLineNumber = @cLineNo
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 77054
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS RD Fail
               GOTO RollbackTran
            END
         END
         ELSE
         BEGIN
            -- Top up existing line
            UPDATE ReceiptDetail WITH (ROWLOCK) SET   -- (james01)
               ToID = @cToID,
               QTYExpected = QTYExpected + @nBorrowQTYExpected,
               BeforeReceivedQTY = BeforeReceivedQTY + @nUCCQTY,
               EditDate = GETDATE(),
               EditWho = SUSER_SNAME()
            WHERE ReceiptKey = @cReceiptKey
               AND ReceiptLineNumber = @cNewLineNo
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 77055
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RD Fail
               GOTO RollbackTran
            END
         END

         -- Reduce FROM ReceiptDetail
         UPDATE ReceiptDetail WITH (ROWLOCK) SET   -- (james01)
            QTYExpected = QTYExpected - @nBorrowQTYExpected,
            BeforeReceivedQTY = BeforeReceivedQTY - @nUCCQTY,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE ReceiptKey = @cReceiptKey
            AND ReceiptLineNumber = @cLineNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 77057
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RD Fail
            GOTO RollbackTran
         END

         -- Remove zero QTY line
         IF EXISTS( SELECT 1
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
               AND ReceiptLineNumber = @cLineNo
               AND QTYExpected = 0
               AND BeforeReceivedQTY = 0)
         BEGIN
            DELETE ReceiptDetail WHERE ReceiptKey = @cReceiptKey AND ReceiptLineNumber = @cLineNo
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 77056
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL RD Fail
               GOTO RollbackTran
            END
         END

         -- Update UCC
         UPDATE UCC WITH (ROWLOCK) SET
            ID = @cToID,
            ReceiptKey = @cReceiptKey,  -- Re-stamp, due to ReceiptDetail delete trigger blank it
            ReceiptLineNumber = @cNewLineNo,
            EditDate = GETDATE(),
            EditWho = SUSER_SNAME()
         WHERE UCCNo = @cUCCNo
            AND StorerKey = @cStorerKey
            AND SKU = @cUCCSKU
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 77058
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
            GOTO RollBackTran
         END

         FETCH NEXT FROM @curUCC INTO @cUCCSKU, @nUCCQTY, @cLineNo
      END
   END
   GOTO Quit

RollBackTran:
      ROLLBACK TRAN rdt_UCCMergePallet_Confirm
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO