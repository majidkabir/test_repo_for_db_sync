SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1581RcptCfm05                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: When insert new receiptdetail line, copy lottable & userdefine    */
/*          If sku not in asn, update lottable06/07 = Unexpt S/Unexpt Q       */
/*          If over receive, update lottable07 = Unexpt Q                     */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2018-10-29 1.0  James      WMS6749 Created                                 */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1581RcptCfm05] (
   @nFunc            INT,  
   @nMobile          INT,  
   @cLangCode        NVARCHAR( 3), 
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cReceiptKey      NVARCHAR( 10), 
   @cPOKey           NVARCHAR( 10), 
   @cToLOC           NVARCHAR( 10), 
   @cToID            NVARCHAR( 18), 
   @cSKUCode         NVARCHAR( 20), 
   @cSKUUOM          NVARCHAR( 10), 
   @nSKUQTY          INT, 
   @cUCC             NVARCHAR( 20), 
   @cUCCSKU          NVARCHAR( 20), 
   @nUCCQTY          INT, 
   @cCreateUCC       NVARCHAR( 1),  
   @cLottable01      NVARCHAR( 18), 
   @cLottable02      NVARCHAR( 18), 
   @cLottable03      NVARCHAR( 18), 
   @dLottable04      DATETIME, 
   @dLottable05      DATETIME, 
   @nNOPOFlag        INT, 
   @cConditionCode   NVARCHAR( 10),
   @cSubreasonCode   NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT,  --IN00392817 
   @cSerialNo        NVARCHAR( 30) = '',     --IN00392817
   @nSerialQTY       INT = 0,                --IN00392817
   @nBulkSNO         INT = 0,
   @nBulkSNOQTY      INT = 0
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nSKUNotInASN         INT,
           @nCopyFromASNLine     INT,
           @nQtyExpected         INT,
           @nBeforeReceivedQty   INT,
           @cOri_Lottable03      NVARCHAR( 18), 
           @cOri_Lottable10      NVARCHAR( 30), 
           @cOri_Lottable11      NVARCHAR( 30), 
           @cOri_Userdefine04    NVARCHAR( 30)

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_1581RcptCfm05 -- For rollback or commit only our own transaction

   IF ISNULL( @cLottable01, '') = ''
   BEGIN
      SET @nErrNo = 130951
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No RSO
      GOTO RollBackTran
   END

   IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                   WHERE ReceiptKey = @cReceiptKey
                   AND   Lottable01 = @cLottable01
                   AND   SKU = @cSKUCode)
      SET @nSKUNotInASN = 1
   ELSE
   BEGIN
      SET @nSKUNotInASN = 0

      SELECT @nQtyExpected = ISNULL( SUM( QtyExpected), 0),
             @nBeforeReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey
      AND   Lottable01 = @cLottable01  -- Same RSO (batch#)
      AND   SKU = @cSKUCode            -- Same SKU
   END
         
   EXEC rdt.rdt_Receive--_V7
      @nFunc         = @nFunc,
      @nMobile       = @nMobile,
      @cLangCode     = @cLangCode,
      @nErrNo        = @nErrNo OUTPUT,
      @cErrMsg       = @cErrMsg OUTPUT,
      @cStorerKey    = @cStorerKey,
      @cFacility     = @cFacility,
      @cReceiptKey   = @cReceiptKey,
      @cPOKey        = @cPOKey,
      @cToLOC        = @cToLOC,
      @cToID         = @cToID,
      @cSKUCode      = @cSKUCode,
      @cSKUUOM       = @cSKUUOM,
      @nSKUQTY       = @nSKUQTY,
      @cUCC          = '',
      @cUCCSKU       = '',
      @nUCCQTY       = '',
      @cCreateUCC    = '',
      @cLottable01   = @cLottable01,
      @cLottable02   = @cLottable02,
      @cLottable03   = @cLottable03,
      @dLottable04   = @dLottable04,
      @dLottable05   = NULL,
      @nNOPOFlag     = @nNOPOFlag,
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = '',
      @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT

   IF @nErrNo <> 0
      GOTO RollBackTran

   IF @nSKUNotInASN = 1
   BEGIN
      -- If the sku not in asn, copy the info 
      -- from original asn line to new asn line

      -- Get original line no
      SELECT TOP 1 
         @nCopyFromASNLine = ReceiptLineNumber
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey
      AND   Lottable01 = @cLottable01  -- Same RSO (batch#)
      AND   ToLoc = @cToLOC
      AND   ToID = @cToID
      AND   ISNULL( DuplicateFrom, '') = ''
      ORDER BY 1

      IF @@ROWCOUNT = 0
         SELECT TOP 1 
            @nCopyFromASNLine = ReceiptLineNumber
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey
         AND   Lottable01 = @cLottable01  -- Same RSO (batch#)
         AND   ISNULL( DuplicateFrom, '') = ''
         ORDER BY 1

      -- Get original line values
      SELECT @cOri_Userdefine04 = Userdefine04
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   ReceiptLineNumber = @nCopyFromASNLine

      -- Update values to new lines
      UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK) SET 
         Lottable10 = 'P',
         Lottable11 = 'H',
         Userdefine01 = 'Unexpt S',
         Userdefine04 = @cOri_Userdefine04,
         TrafficCop = NULL
      WHERE ReceiptKey = @cReceiptKey
      AND   ReceiptLineNumber = @cReceiptLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 130952
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Unexpt SKU Err
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      --SELECT @nQtyExpected = ISNULL( SUM( QtyExpected), 0),
      --       @nBeforeReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0)
      --FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
      --WHERE ReceiptKey = @cReceiptKey
      --AND   Lottable01 = @cLottable01  -- Same RSO (batch#)
      --AND   SKU = @cSKUCode            -- Same SKU
      --AND   ISNULL( DuplicateFrom, '') = ''  -- Original receiptdetail line

      -- Check if same RSO + SKU is over receive then new line need update
      -- with remark
      IF ( @nBeforeReceivedQty + @nSKUQTY) > @nQtyExpected
      BEGIN
         -- Update values to new lines
         UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK) SET 
            Lottable10 = 'P',
            Lottable11 = 'H',
            Userdefine01 = 'Unexpt Q',
            TrafficCop = NULL
         WHERE ReceiptKey = @cReceiptKey
         AND   ReceiptLineNumber = @cReceiptLineNumber
         AND   (Lottable10 = '' OR Lottable11 = '' OR Userdefine01 = '')

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 130953
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Unexpt QTY Err
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         IF EXISTS ( SELECT 1 FROM RECEIPTDETAIL WITH (NOLOCK)
                     WHERE ReceiptKey = @cReceiptKey
                     AND   ReceiptLineNumber = @cReceiptLineNumber
                     AND   ISNULL( DuplicateFrom, '') <> ''
                     AND   (Lottable10 = '' OR Lottable11 = '' OR Userdefine01 = ''))
         BEGIN
            -- Update values to new lines
            UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK) SET 
               Lottable10 = 'P',
               Lottable11 = 'H',
               Userdefine01 = 'Unexpt Q',
               TrafficCop = NULL
            WHERE ReceiptKey = @cReceiptKey
            AND   ReceiptLineNumber = @cReceiptLineNumber

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 130954
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Unexpt QTY Err
               GOTO RollBackTran
            END
         END
      END
   END

   GOTO Quit

   RollBackTran:  
      ROLLBACK TRAN rdt_1581RcptCfm05 
   Fail:  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  

GO