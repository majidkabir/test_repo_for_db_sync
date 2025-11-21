SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1841ClosePlt02                                  */
/*                                                                      */
/* Purpose: Get UCC stat                                                */
/*                                                                      */
/* Called from: rdt_PrePalletizeSort_ClosePallet                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2021-04-06  1.0  James      WMS-16725. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1841ClosePlt02] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerkey      NVARCHAR( 15),
   @cFacility       NVARCHAR( 5),
   @cReceiptKey     NVARCHAR( 20),
   @cLane           NVARCHAR( 10),
   @cPosition       NVARCHAR( 20),
   @cToID           NVARCHAR( 18),
   @nErrNo          INT            OUTPUT,
   @cErrMsg         NVARCHAR( 20)  OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT,
           @bSuccess          INT,
           @nRowCount         INT,
           @cDefaultUOM       NVARCHAR( 10),
           @cLocationCategory NVARCHAR( 10),
           @cTaskdetailkey    NVARCHAR( 10),
           @cToLoc            NVARCHAR( 10),
           @cToLogicalLocation   NVARCHAR( 10),
           @cLogicalLocation     NVARCHAR( 10),
           @nPABookingKey     INT,
           @nRowRef           INT,
           @nUCCQty           INT,
           @cUserName         NVARCHAR( 18),
           @cPOKey            NVARCHAR( 10),
           @cReceiptLineNumber   NVARCHAR( 5),
           @cUCCSKU           NVARCHAR( 20),
           @cID               NVARCHAR( 18),
           @cUCC              NVARCHAR( 20),
           @cCurID            NVARCHAR( 18),
           @cCurUCC           NVARCHAR( 20),
           @cLottable01       NVARCHAR( 18),
           @cLottable02       NVARCHAR( 18),
           @cLottable03       NVARCHAR( 18),
           @dLottable04       DATETIME,
           @dLottable05       DATETIME,
           @cLottable06       NVARCHAR( 30),
           @cLottable07       NVARCHAR( 30),
           @cLottable08       NVARCHAR( 30),
           @cLottable09       NVARCHAR( 30),
           @cLottable10       NVARCHAR( 30),
           @cLottable11       NVARCHAR( 30),
           @cLottable12       NVARCHAR( 30),
           @dLottable13       DATETIME,
           @dLottable14       DATETIME,
           @dLottable15       DATETIME,
           @cUOM              NVARCHAR( 10),
           @cUOM_Desc         NVARCHAR( 10),
           @cSKUUOM           NVARCHAR( 10)

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1841ClosePlt02

   IF @cToID = '99'
      SET @cToID = ''

   SET @cCurUCC = ''
   SET @cCurID = ''

   SELECT @cUserName = USERNAME, 
          @cUOM = V_UOM 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile
   
   DECLARE @curPRL CURSOR
   SET @curPRL = CURSOR FOR
   SELECT RowRef--, ID, UCCNo, SKU, Qty
   FROM RDT.rdtPreReceiveSort WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   AND   (( @cLane = '') OR ( Loc = @cLane))
   --AND   (( @cToID = '') OR ( ID = @cToID))
   AND   [Status] = '1'
   OPEN @curPRL
   FETCH NEXT FROM @curPRL INTO @nRowRef--, @cID, @cUCC, @cUCCSKU, @nUCCQty
   WHILE @@FETCH_STATUS = 0
   BEGIN/*
      IF EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey
                  AND   UserDefine01 = @cUCC)
      BEGIN
         SELECT TOP 1 
            @cLottable01 = Lottable01,
            @cLottable02 = Lottable02,
            @cLottable03 = Lottable03,
            @dLottable04 = Lottable04,
            @cLottable06 = Lottable06,
            @cLottable07 = Lottable07,
            @cLottable08 = Lottable08,
            @cLottable09 = Lottable09,
            @cLottable11 = Lottable11,
            @cLottable12 = Lottable12,
            @dLottable13 = Lottable13,
            @dLottable14 = Lottable14,
            @dLottable15 = Lottable15,
            @cPOKey = POKey
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   UserDefine01 = @cUCC
         AND   FinalizeFlag <> 'Y'
         ORDER BY 1
      END
      ELSE
      BEGIN
         SELECT @cLottable01 = Lottable01,
                @cLottable02 = Lottable02,
                @cLottable03 = Lottable03,
                @dLottable04 = Lottable04,
                @cLottable06 = Lottable06,
                @cLottable07 = Lottable07,
                @cLottable08 = Lottable08,
                @cLottable09 = Lottable09,
                @cLottable11 = Lottable11,
                @cLottable12 = Lottable12,
                @dLottable13 = Lottable13,
                @dLottable14 = Lottable14,
                @dLottable15 = Lottable15
         FROM RDT.rdtPreReceiveSort WITH (NOLOCK)
         WHERE Rowref = @nRowRef
      END

      SELECT @cSKUUOM = P.PackUOM3
      FROM dbo.SKU S WITH (NOLOCK)
      JOIN dbo.PACK P WITH (NOLOCK) ON ( S.PACKKey = P.PackKey) 
      WHERE s.StorerKey = @cStorerkey
      AND   S.Sku = @cUCCSKU
      
      SET @nErrNo = 0
      EXEC rdt.rdt_Receive_V7    
         @nFunc          = @nFunc,
         @nMobile        = @nMobile,
         @cLangCode      = @cLangCode,
         @nErrNo         = @nErrNo  OUTPUT,
         @cErrMsg        = @cErrMsg OUTPUT,
         @cStorerKey     = @cStorerKey,
         @cFacility      = @cFacility,
         @cReceiptKey    = @cReceiptKey,
         @cPOKey         = @cPOKey,
         @cToLOC         = @cLane,
         @cToID          = @cID, 
         @cSKUCode       = @cUCCSKU,
         @cSKUUOM        = @cSKUUOM,
         @nSKUQTY        = @nUCCQTY,
         @cUCC           = '',
         @cUCCSKU        = '',
         @nUCCQTY        = 0,
         @cCreateUCC     = '0',
         @cLottable01    = @cLottable01,
         @cLottable02    = @cLottable02,   
         @cLottable03    = @cLottable03,
         @dLottable04    = @dLottable04,
         @dLottable05    = NULL,
         @cLottable06    = @cLottable06,
         @cLottable07    = @cLottable07,
         @cLottable08    = @cLottable08,
         @cLottable09    = @cLottable09,
         @cLottable10    = @cLottable10,
         @cLottable11    = @cLottable11,
         @cLottable12    = @cLottable12,
         @dLottable13    = @dLottable13,
         @dLottable14    = @dLottable14,
         @dLottable15    = @dLottable15,
         @nNOPOFlag      = 1,
         @cConditionCode = 'OK',
         @cSubreasonCode = '',
         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT,  
         @cDebug         = '0'  

      IF @nErrNo <> 0
         GOTO RollBackTran
      */
      UPDATE RDT.RDTPreReceiveSort SET 
         [Status] = '9',
         EditWho = SUSER_SNAME(),
         EditDate = GETDATE()
      WHERE Rowref = @nRowRef

      IF @@ERROR <> 0  
      BEGIN
         SET @nErrNo = 165701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Close Plt Fail
         GOTO RollBackTran
      END 
         
      FETCH NEXT FROM @curPRL INTO @nRowRef--, @cID, @cUCC, @cUCCSKU, @nUCCQty
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1841ClosePlt02

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_1841ClosePlt02

   Fail:

GO