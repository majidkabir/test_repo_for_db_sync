SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1584RcvCfm01                                          */
/* Copyright: Maersk                                                          */
/*                                                                            */
/* Purpose: Receive using SSCC                                                */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2023-03-02  Ung       1.0   WMS-21709 Created                              */
/* 2023-07-12  Ung       1.1   WMS-23064 Save ASRS pallet to UCC.UserDefine04 */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1584RcvCfm01] (
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT, 
   @nInputKey      INT, 
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cReceiptKey    NVARCHAR( 10),
   @cRefNo         NVARCHAR( 20),
   @cLOC           NVARCHAR( 10),
   @cID            NVARCHAR( 18),
   @cPalletSSCC    NVARCHAR( 30), 
   @cCaseSSCC      NVARCHAR( 30), 
   @cSKU           NVARCHAR( 20),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @cLottable06    NVARCHAR( 30),
   @cLottable07    NVARCHAR( 30),
   @cLottable08    NVARCHAR( 30),
   @cLottable09    NVARCHAR( 30),
   @cLottable10    NVARCHAR( 30),
   @cLottable11    NVARCHAR( 30),
   @cLottable12    NVARCHAR( 30),
   @dLottable13    DATETIME,
   @dLottable14    DATETIME,
   @dLottable15    DATETIME,
   @nQTY           INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT,
   @cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   /*
      Pallet SSCC
         Pallet SSCC = ReceiptDetail.Lottable09
         Not allow over receive
         Not allow under receive
         Not allow receive SKU not in ASN
         
         SSCC SKU will have UCC
         Non SSCC SKU, don't have UCC   
      
      Case SSCC
         Case SSCC = UCC.UCCNo
         Allow create new case
   */

   -- Get UOM
   DECLARE @cUOM NVARCHAR(10)
   SELECT @cUOM = Pack.PackUOM3
   FROM dbo.SKU WITH (NOLOCK)
      JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
   WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU

   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1584RcvCfm01 -- For rollback or commit only our own transaction

   IF @nFunc = 1584 -- SSCC Receiving1
   BEGIN
      SELECT TOP 1 
         @cLottable06 = Lottable06  
      FROM dbo.ReceiptDetail WITH (NOLOCK)  
      WHERE ReceiptKey = @cReceiptKey  
         AND SKU = @cSKU  
         AND ISNULL( DuplicateFrom, '') = ''  

   	-- Receive
      EXEC rdt.rdt_Receive_V7
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = 'NOPO',
         @cToLOC        = @cLOC,
         @cToID         = @cID,
         @cSKUCode      = @cSKU,
         @cSKUUOM       = @cUOM,
         @nSKUQTY       = @nQTY,
         @cUCC          = '',
         @cUCCSKU       = '',
         @nUCCQTY       = '',
         @cCreateUCC    = '',
         @cLottable01   = @cLottable01,
         @cLottable02   = @cLottable02,
         @cLottable03   = @cLottable03,
         @dLottable04   = @dLottable04,
         @dLottable05   = NULL,
         @cLottable06   = @cLottable06,
         @cLottable07   = @cLottable07,
         @cLottable08   = @cLottable08,
         @cLottable09   = @cLottable09,
         @cLottable10   = @cLottable10,
         @cLottable11   = @cLottable11,
         @cLottable12   = @cLottable12,
         @dLottable13   = @dLottable13,
         @dLottable14   = @dLottable14,
         @dLottable15   = @dLottable15,
         @nNOPOFlag     = 1, --1=NOPO
         @cConditionCode = @cConditionCode,
         @cSubreasonCode = '',
         @cReceiptLineNumberOutput = @cReceiptLineNumberOutput OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

   	-- Pallet SSCC
      IF @cPalletSSCC <> ''
      BEGIN
         DECLARE @cUCCNo NVARCHAR( 20)
      	DECLARE @curUCC CURSOR 
      	SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT UCC.UCCNo
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
               JOIN dbo.UCC WITH (NOLOCK) ON (RD.Lottable09 = UCC.Userdefined03 AND RD.StorerKey = UCC.Storerkey AND RD.SKU = UCC.SKU)
            WHERE RD.ReceiptKey = @cReceiptKey
               AND RD.Lottable09 = @cPalletSSCC
               AND RD.SKU = @cSKU
               AND UCC.Status = '0'
         OPEN @curUCC
         FETCH NEXT FROM @curUCC INTO @cUCCNo
         WHILE @@FETCH_STATUS = 0
         BEGIN
         	UPDATE dbo.UCC SET
   	         Receiptkey = @cReceiptKey,
   	         ReceiptLineNumber = @cReceiptLineNumberOutput,
   	         Status = '1', 
   	         EditDate = GETDATE(), 
   	         EditWho = SUSER_NAME()
   	      WHERE Storerkey = @cStorerKey
      	      AND UCCNo = @cUCCNo
      	      AND Status = '0'
   	      IF @@ERROR <> 0
   	      BEGIN
   	   	   SET @nErrNo = 197551
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
               GOTO RollBackTran
   	      END

         	FETCH NEXT FROM @curUCC INTO @cUCCNo
         END
         
         -- EventLog
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '2', -- Receiving
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerKey,
            @cReceiptKey   = @cReceiptKey,
            @cLocation     = @cLOC,
            @cID           = @cID,
            @cSKU          = @cSKU,
            @cUOM          = @cUOM,
            @nQTY          = @nQTY,
            @cRefNo1       = @cRefNo,
            @cReasonKey    = @cConditionCode,
            @cLottable01   = @cLottable01,
            @cLottable02   = @cLottable02,
            @cLottable03   = @cLottable03,
            @dLottable04   = @dLottable04,
            @dLottable05   = @dLottable05,
            @cLottable06   = @cLottable06,
            @cLottable07   = @cLottable07,
            @cLottable08   = @cLottable08,
            @cLottable09   = @cLottable09, --@cPalletSSCC
            @cLottable10   = @cLottable10,
            @cLottable11   = @cLottable11,
            @cLottable12   = @cLottable12,
            @dLottable13   = @dLottable13,
            @dLottable14   = @dLottable14,
            @dLottable15   = @dLottable15
      END
      
      -- Case SSCC
      IF @cCaseSSCC <> ''
      BEGIN
   	   -- Get UCC info
   	   IF EXISTS( SELECT 1
      	   FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
      	      JOIN dbo.UCC WITH (NOLOCK) ON (RD.Lottable09 = UCC.Userdefined03 AND RD.StorerKey = UCC.Storerkey AND RD.SKU = UCC.SKU)
            WHERE RD.ReceiptKey = @cReceiptKey
               AND UCC.StorerKey = @cStorerKey
               AND UCC.UCCNo = @cCaseSSCC
               AND UCC.Status = '0')
         BEGIN
      	   UPDATE UCC WITH (ROWLOCK) SET
   	         Receiptkey = @cReceiptKey,
   	         ReceiptLineNumber = @cReceiptLineNumberOutput,
   	         Status = '1', 
   	         UserDefined04 = @cID, 
   	         EditDate = GETDATE(), 
   	         EditWho = SUSER_NAME()
   	      WHERE Storerkey = @cStorerKey
      	      AND UCCNo = @cCaseSSCC
      	      AND Status = '0'
   	      IF @@ERROR <> 0
   	      BEGIN
   	   	   SET @nErrNo = 197552
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD UCC Fail
               GOTO RollBackTran
   	      END
   	   END

         -- EventLog
         EXEC RDT.rdt_STD_EventLog
            @cActionType   = '2', -- Receiving
            @nMobileNo     = @nMobile,
            @nFunctionID   = @nFunc,
            @cFacility     = @cFacility,
            @cStorerKey    = @cStorerKey,
            @cReceiptKey   = @cReceiptKey,
            @cLocation     = @cLOC,
            @cID           = @cID,
            @cSKU          = @cSKU,
            @cUOM          = @cUOM,
            @nQTY          = @nQTY,
            @cRefNo1       = @cRefNo,
            @cReasonKey    = @cConditionCode,
            @cLottable01   = @cLottable01,
            @cLottable02   = @cLottable02,
            @cLottable03   = @cLottable03,
            @dLottable04   = @dLottable04,
            @dLottable05   = @dLottable05,
            @cLottable06   = @cLottable06,
            @cLottable07   = @cLottable07,
            @cLottable08   = @cLottable08,
            @cLottable09   = @cLottable09,
            @cLottable10   = @cLottable10,
            @cLottable11   = @cLottable11,
            @cLottable12   = @cLottable12,
            @dLottable13   = @dLottable13,
            @dLottable14   = @dLottable14,
            @dLottable15   = @dLottable15, 
            @cUCC          = @cCaseSSCC
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1584RcvCfm01
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO