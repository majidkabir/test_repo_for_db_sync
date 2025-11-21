SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_607RcptCfm03                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: After received, copy fields to new line                           */
/*                                                                            */
/* Date        Author   Ver.  Purposes                                        */
/* 18-Mar-2019 James    1.0   WMS-8158 Created                                */
/* 10-May-2019 James    1.0   WMS-8158 Add logic for getting Lot05 (james01)  */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_607RcptCfm03]
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cReceiptKey    NVARCHAR( 10),
   @cPOKey         NVARCHAR( 10),
   @cToLOC         NVARCHAR( 10),  
   @cToID          NVARCHAR( 18),
   @cSKUCode       NVARCHAR( 20),
   @cSKUUOM        NVARCHAR( 10),
   @nSKUQTY        INT,
   @cUCC           NVARCHAR( 20),
   @cUCCSKU        NVARCHAR( 20),
   @nUCCQTY        INT,
   @cCreateUCC     NVARCHAR( 1),
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
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLottable01Required NVARCHAR( 1)
   DECLARE @cLottable02Required NVARCHAR( 1)
   DECLARE @cLottable03Required NVARCHAR( 1)
   DECLARE @cLottable04Required NVARCHAR( 1)
   DECLARE @cLottable05Required NVARCHAR( 1)
   DECLARE @cLottable06Required NVARCHAR( 1)
   DECLARE @cLottable07Required NVARCHAR( 1)
   DECLARE @cLottable08Required NVARCHAR( 1)
   DECLARE @cLottable09Required NVARCHAR( 1)
   DECLARE @cLottable10Required NVARCHAR( 1)
   DECLARE @cLottable11Required NVARCHAR( 1)
   DECLARE @cLottable12Required NVARCHAR( 1)
   DECLARE @cLottable13Required NVARCHAR( 1)
   DECLARE @cLottable14Required NVARCHAR( 1)
   DECLARE @cLottable15Required NVARCHAR( 1)
   DECLARE @cLottableCode       NVARCHAR( 30)
   DECLARE @cNewSKU             NVARCHAR( 30) 

   -- Handling transaction
   DECLARE @nTranCount     INT,
           @b_Success      INT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_607RcptCfm03 -- For rollback or commit only our own transaction
      
   IF @nFunc = 607 -- Return V7
   BEGIN
      SELECT
         @cLottableCode = LottableCode
      FROM dbo.SKU SKU (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKUCode

      SET @cNewSKU = ''

      SELECT
         @cLottable01Required = '0', @cLottable02Required = '0', @cLottable03Required = '0', @cLottable04Required = '0', @cLottable05Required = '0',
         @cLottable06Required = '0', @cLottable07Required = '0', @cLottable08Required = '0', @cLottable09Required = '0', @cLottable10Required = '0',
         @cLottable11Required = '0', @cLottable12Required = '0', @cLottable13Required = '0', @cLottable14Required = '0', @cLottable15Required = '0'

      -- Get LottableCode info
      SELECT
         @cLottable01Required = CASE WHEN LottableNo =  1 THEN Required ELSE @cLottable01Required END,
         @cLottable02Required = CASE WHEN LottableNo =  2 THEN Required ELSE @cLottable02Required END,
         @cLottable03Required = CASE WHEN LottableNo =  3 THEN Required ELSE @cLottable03Required END,
         @cLottable04Required = CASE WHEN LottableNo =  4 THEN Required ELSE @cLottable04Required END,
         @cLottable05Required = CASE WHEN LottableNo =  5 THEN Required ELSE @cLottable05Required END,
         @cLottable06Required = CASE WHEN LottableNo =  6 THEN Required ELSE @cLottable06Required END,
         @cLottable07Required = CASE WHEN LottableNo =  7 THEN Required ELSE @cLottable07Required END,
         @cLottable08Required = CASE WHEN LottableNo =  8 THEN Required ELSE @cLottable08Required END,
         @cLottable09Required = CASE WHEN LottableNo =  9 THEN Required ELSE @cLottable09Required END,
         @cLottable10Required = CASE WHEN LottableNo = 10 THEN Required ELSE @cLottable10Required END,
         @cLottable11Required = CASE WHEN LottableNo = 11 THEN Required ELSE @cLottable11Required END,
         @cLottable12Required = CASE WHEN LottableNo = 12 THEN Required ELSE @cLottable12Required END,
         @cLottable13Required = CASE WHEN LottableNo = 13 THEN Required ELSE @cLottable13Required END,
         @cLottable14Required = CASE WHEN LottableNo = 14 THEN Required ELSE @cLottable14Required END,
         @cLottable15Required = CASE WHEN LottableNo = 15 THEN Required ELSE @cLottable15Required END
      FROM rdt.rdtLottableCode WITH (NOLOCK)
      WHERE LottableCode = @cLottableCode
         AND Function_ID = @nFunc
         AND StorerKey = @cStorerKey

      DECLARE @cExternReceiptKey    NVARCHAR( 20),
              @cExternLineNo        NVARCHAR( 20),
              @cLoadKey             NVARCHAR( 10),
              @cExternPOKey         NVARCHAR( 20),
              @cUserDefine02        NVARCHAR( 30),
              @cUserDefine03        NVARCHAR( 30),
              @cUserDefine05        NVARCHAR( 30),
              @cUserDefine09        NVARCHAR( 30)

      -- 1st try if any receiptdetail line match (exact match)
      SELECT TOP 1
         @cExternReceiptKey = ISNULL( ExternReceiptKey, ''),
         @cExternLineNo = ISNULL( ExternLineNo, ''),
         @cLoadKey = ISNULL( LoadKey, ''),
         @cExternPOKey = ISNULL( ExternPOKey, ''),
         @cUserDefine02 = ISNULL( UserDefine02, ''),
         @cUserDefine03 = ISNULL( UserDefine03, ''),
         @cUserDefine05 = ISNULL( UserDefine05, ''),
         @cUserDefine09 = ISNULL( UserDefine09, '')
      FROM dbo.ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         --AND FinalizeFlag <> 'Y'
         AND ToLOC = @cToLOC
         AND ToID = @cToID
         AND SKU = @cSKUCode
         AND (@cLottable01Required = '0' OR Lottable01 = @cLottable01)
         AND (@cLottable02Required = '0' OR Lottable02 = @cLottable02)
         AND (@cLottable03Required = '0' OR Lottable03 = @cLottable03)
         AND (@cLottable04Required = '0' OR IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0))
         AND (@cLottable05Required = '0' OR IsNULL( Lottable05, 0) = IsNULL( @dLottable05, 0))
         AND (@cLottable06Required = '0' OR Lottable06 = @cLottable06)
         AND (@cLottable07Required = '0' OR Lottable07 = @cLottable07)
         AND (@cLottable08Required = '0' OR Lottable08 = @cLottable08)
         AND (@cLottable09Required = '0' OR Lottable09 = @cLottable09)
         AND (@cLottable10Required = '0' OR Lottable10 = @cLottable10)
         AND (@cLottable11Required = '0' OR Lottable11 = @cLottable11)
         AND (@cLottable12Required = '0' OR Lottable12 = @cLottable12)
         AND (@cLottable13Required = '0' OR IsNULL( Lottable13, 0) = IsNULL( @dLottable13, 0))
         AND (@cLottable14Required = '0' OR IsNULL( Lottable14, 0) = IsNULL( @dLottable14, 0))
         AND (@cLottable15Required = '0' OR IsNULL( Lottable15, 0) = IsNULL( @dLottable15, 0))
         AND (QTYExpected - BeforeReceivedQTY) > 0 
      ORDER BY ReceiptLineNumber

      IF @@ROWCOUNT = 0
      BEGIN
         -- Get same sku not receive line
         SELECT TOP 1
            @cExternReceiptKey = ISNULL( ExternReceiptKey, ''),
            @cExternLineNo = ISNULL( ExternLineNo, ''),
            @cLoadKey = ISNULL( LoadKey, ''),
            @cExternPOKey = ISNULL( ExternPOKey, ''),
            @cUserDefine02 = ISNULL( UserDefine02, ''),
            @cUserDefine03 = ISNULL( UserDefine03, ''),
            @cUserDefine05 = ISNULL( UserDefine05, ''),
            @cUserDefine09 = ISNULL( UserDefine09, '')
         FROM dbo.ReceiptDetail WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
            --AND FinalizeFlag <> 'Y'
            --AND BeforeReceivedQTY = 0
            AND (ToID = '' OR ToID = @cToID)
            AND SKU = @cSKUCode
            AND
            (  -- Lottable not required or (if required, Blank or exact match)
               (@cLottable01Required = '0' OR (Lottable01 = '' OR Lottable01 = @cLottable01)) AND
               (@cLottable02Required = '0' OR (Lottable02 = '' OR Lottable02 = @cLottable02)) AND
               (@cLottable03Required = '0' OR (Lottable03 = '' OR Lottable03 = @cLottable03)) AND
               (@cLottable04Required = '0' OR (Lottable04 IS NULL OR IsNULL( Lottable04, 0) = IsNULL( @dLottable04, 0))) AND
               (@cLottable05Required = '0' OR (Lottable05 IS NULL OR IsNULL( Lottable05, 0) = IsNULL( @dLottable05, 0))) AND
               (@cLottable06Required = '0' OR (Lottable06 = '' OR Lottable06 = @cLottable06)) AND
               (@cLottable07Required = '0' OR (Lottable07 = '' OR Lottable07 = @cLottable07)) AND
               (@cLottable08Required = '0' OR (Lottable08 = '' OR Lottable08 = @cLottable08)) AND
               (@cLottable09Required = '0' OR (Lottable09 = '' OR Lottable09 = @cLottable09)) AND
               (@cLottable10Required = '0' OR (Lottable10 = '' OR Lottable10 = @cLottable10)) AND
               (@cLottable11Required = '0' OR (Lottable11 = '' OR Lottable11 = @cLottable11)) AND
               (@cLottable12Required = '0' OR (Lottable12 = '' OR Lottable12 = @cLottable12)) AND
               (@cLottable13Required = '0' OR (Lottable13 IS NULL OR IsNULL( Lottable13, 0) = IsNULL( @dLottable13, 0))) AND
               (@cLottable14Required = '0' OR (Lottable14 IS NULL OR IsNULL( Lottable14, 0) = IsNULL( @dLottable14, 0))) AND
               (@cLottable15Required = '0' OR (Lottable15 IS NULL OR IsNULL( Lottable15, 0) = IsNULL( @dLottable15, 0)))
            )
            --AND QtyExpected >= @nSKUQTY 
         ORDER BY ReceiptLineNumber

         IF @@ROWCOUNT = 0
         BEGIN
            -- Get top 1 any line with same sku
            SELECT TOP 1
               @cExternReceiptKey = ISNULL( ExternReceiptKey, ''),
               @cExternLineNo = ISNULL( ExternLineNo, ''),
               @cLoadKey = ISNULL( LoadKey, ''),
               @cExternPOKey = ISNULL( ExternPOKey, ''),
               @cUserDefine02 = ISNULL( UserDefine02, ''),
               @cUserDefine03 = ISNULL( UserDefine03, ''),
               @cUserDefine05 = ISNULL( UserDefine05, ''),
               @cUserDefine09 = ISNULL( UserDefine09, ''),
               @cLottable01 = CASE WHEN ISNULL( @cLottable01, '') = '' THEN Lottable01 ELSE @cLottable01 END,
               @cLottable02 = CASE WHEN ISNULL( @cLottable02, '') = '' THEN Lottable02 ELSE @cLottable02 END,
               @cLottable03 = CASE WHEN ISNULL( @cLottable03, '') = '' THEN Lottable03 ELSE @cLottable03 END,
               @dLottable04 = CASE WHEN ISNULL( @dLottable04, '') = '' THEN Lottable04 ELSE @dLottable04 END,
               @dLottable05 = CASE WHEN ISNULL( @dLottable05, '') = '' THEN Lottable05 ELSE @dLottable05 END,
               @cLottable06 = CASE WHEN ISNULL( @cLottable06, '') = '' THEN Lottable06 ELSE @cLottable06 END,
               @cLottable07 = CASE WHEN ISNULL( @cLottable07, '') = '' THEN Lottable07 ELSE @cLottable07 END,
               @cLottable08 = CASE WHEN ISNULL( @cLottable08, '') = '' THEN Lottable08 ELSE @cLottable08 END,
               @cLottable09 = CASE WHEN ISNULL( @cLottable09, '') = '' THEN Lottable09 ELSE @cLottable09 END,
               @cLottable10 = CASE WHEN ISNULL( @cLottable10, '') = '' THEN Lottable10 ELSE @cLottable10 END,
               @cLottable11 = CASE WHEN ISNULL( @cLottable11, '') = '' THEN Lottable11 ELSE @cLottable11 END,
               @cLottable12 = CASE WHEN ISNULL( @cLottable12, '') = '' THEN Lottable12 ELSE @cLottable12 END,
               @dLottable13 = CASE WHEN ISNULL( @dLottable13, '') = '' THEN Lottable13 ELSE @dLottable13 END,
               @dLottable14 = CASE WHEN ISNULL( @dLottable14, '') = '' THEN Lottable14 ELSE @dLottable14 END,
               @dLottable15 = CASE WHEN ISNULL( @dLottable15, '') = '' THEN Lottable15 ELSE @dLottable15 END
            FROM dbo.ReceiptDetail WITH (NOLOCK)
            WHERE ReceiptKey = @cReceiptKey
            AND SKU = @cSKUCode
            ORDER BY ReceiptLineNumber

            IF @@ROWCOUNT = 0
            BEGIN
               -- Get top 1 any line
               SELECT TOP 1
                  @cExternReceiptKey = ISNULL( ExternReceiptKey, ''),
                  @cExternLineNo = ISNULL( ExternLineNo, ''),
                  @cLoadKey = ISNULL( LoadKey, ''),
                  @cExternPOKey = ISNULL( ExternPOKey, ''),
                  @cUserDefine02 = ISNULL( UserDefine02, ''),
                  @cUserDefine03 = ISNULL( UserDefine03, ''),
                  @cUserDefine05 = ISNULL( UserDefine05, ''),
                  @cUserDefine09 = ISNULL( UserDefine09, ''),
                  @cLottable01 = CASE WHEN ISNULL( @cLottable01, '') = '' THEN Lottable01 ELSE @cLottable01 END,
                  @cLottable02 = CASE WHEN ISNULL( @cLottable02, '') = '' THEN Lottable02 ELSE @cLottable02 END,
                  @cLottable03 = CASE WHEN ISNULL( @cLottable03, '') = '' THEN Lottable03 ELSE @cLottable03 END,
                  @dLottable04 = CASE WHEN ISNULL( @dLottable04, '') = '' THEN Lottable04 ELSE @dLottable04 END,
                  @dLottable05 = CASE WHEN ISNULL( @dLottable05, '') = '' THEN Lottable05 ELSE @dLottable05 END,
                  @cLottable06 = CASE WHEN ISNULL( @cLottable06, '') = '' THEN Lottable06 ELSE @cLottable06 END,
                  @cLottable07 = CASE WHEN ISNULL( @cLottable07, '') = '' THEN Lottable07 ELSE @cLottable07 END,
                  @cLottable08 = CASE WHEN ISNULL( @cLottable08, '') = '' THEN Lottable08 ELSE @cLottable08 END,
                  @cLottable09 = CASE WHEN ISNULL( @cLottable09, '') = '' THEN Lottable09 ELSE @cLottable09 END,
                  @cLottable10 = CASE WHEN ISNULL( @cLottable10, '') = '' THEN Lottable10 ELSE @cLottable10 END,
                  @cLottable11 = CASE WHEN ISNULL( @cLottable11, '') = '' THEN Lottable11 ELSE @cLottable11 END,
                  @cLottable12 = CASE WHEN ISNULL( @cLottable12, '') = '' THEN Lottable12 ELSE @cLottable12 END,
                  @dLottable13 = CASE WHEN ISNULL( @dLottable13, '') = '' THEN Lottable13 ELSE @dLottable13 END,
                  @dLottable14 = CASE WHEN ISNULL( @dLottable14, '') = '' THEN Lottable14 ELSE @dLottable14 END,
                  @dLottable15 = CASE WHEN ISNULL( @dLottable15, '') = '' THEN Lottable15 ELSE @dLottable15 END
               FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               ORDER BY ReceiptLineNumber

               SET @cNewSKU = 'NEWSKU'
            END
         END
      END

      -- (james01)
      -- Get lottable05 ( UA wanna allocate return stock first, so set the custom receipt date (lot05))

      --Get the oldest LOT with QTY
      SELECT @dLottable05 = MIN( LA.Lottable05)
      FROM dbo.LOTATTRIBUTE LA WITH (NOLOCK)
      JOIN dbo.LOTXLOCXID LLI WITH (NOLOCK) 
         ON LA.Lot = LLI.Lot AND LA.Storerkey = LLI.Storerkey AND LA.Sku = LLI.Sku
      JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.Loc = LOC.Loc
      WHERE LA.StorerKey = @cStorerKey
      AND   LA.Sku = @cSKUCode
      --AND
      --   (  -- Lottable not required or (if required, Blank or exact match)
      --      (@cLottable01Required = '0' OR (Lottable01 = '' OR Lottable01 = @cLottable01)) AND
      --      (@cLottable02Required = '0' OR (Lottable02 = '' OR Lottable02 = @cLottable02)) AND
      --      (@cLottable03Required = '0' OR (Lottable03 = '' OR Lottable03 = @cLottable03)) AND
      --      (@cLottable06Required = '0' OR (Lottable06 = '' OR Lottable06 = @cLottable06)) AND
      --      (@cLottable07Required = '0' OR (Lottable07 = '' OR Lottable07 = @cLottable07)) AND
      --      (@cLottable08Required = '0' OR (Lottable08 = '' OR Lottable08 = @cLottable08)) AND
      --      (@cLottable09Required = '0' OR (Lottable09 = '' OR Lottable09 = @cLottable09)) AND
      --      (@cLottable10Required = '0' OR (Lottable10 = '' OR Lottable10 = @cLottable10)) AND
      --      (@cLottable11Required = '0' OR (Lottable11 = '' OR Lottable11 = @cLottable11)) AND
      --      (@cLottable12Required = '0' OR (Lottable12 = '' OR Lottable12 = @cLottable12))
      --   )
         AND LLI.Qty > 0
         AND LOC.LocationCategory <> 'RETURN'

      --If such LOT not exist, return today date
      IF ISNULL(@dLottable05,'') = ''
         SET @dLottable05 = CONVERT(DATETIME, CONVERT(CHAR(20), GETDATE(), 112)) 
      ELSE
         -- Minus 1 day to not get the same receive day from previous receipt ( for sku with stock only)
         -- If 2 receipt date same then allocation might not allocate from return stock
         SET @dLottable05 = CONVERT(DATETIME, CONVERT(CHAR(20), DATEADD( day, -1, @dLottable05), 112))

      -- Receive
      EXEC rdt.rdt_Receive_V7_L05
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT,
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = @cPoKey,  -- (ChewKP01)
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
         @nNOPOFlag     = @nNOPOFlag,
         @cConditionCode = @cConditionCode,
         @cSubreasonCode = '', 
         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT

      IF @nErrNo <> 0
         GOTO RollBackTran

      UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET 
         ExternReceiptKey = CASE WHEN ISNULL( ExternReceiptKey, '') = '' THEN @cExternReceiptKey ELSE ExternReceiptKey END,
         ExternLineNo = CASE WHEN ISNULL( ExternLineNo, '') = '' THEN ISNULL( @cExternLineNo, '') ELSE ExternLineNo END,
         LoadKey = CASE WHEN ISNULL( LoadKey, '') = '' THEN @cLoadKey ELSE LoadKey END,
         ExternPOKey = CASE WHEN ISNULL( ExternPOKey, '') = '' THEN @cExternPOKey ELSE ExternPOKey END,
         UserDefine02 = CASE WHEN ISNULL( UserDefine02, '') = '' THEN @cUserDefine02 ELSE UserDefine02 END,
         UserDefine03 = CASE WHEN ISNULL( UserDefine03, '') = '' THEN @cUserDefine03 ELSE UserDefine03 END,
         UserDefine05 = CASE WHEN ISNULL( UserDefine05, '') = '' THEN @cUserDefine05 ELSE UserDefine05 END,
         UserDefine09 = CASE WHEN ISNULL( UserDefine09, '') = '' THEN @cUserDefine09 ELSE UserDefine09 END,
         UserDefine10 = CASE WHEN ISNULL( UserDefine10, '') = '' THEN @cNewSKU ELSE UserDefine10 END,
         TrafficCop = NULL
      WHERE ReceiptKey = @cReceiptKey
      AND   ReceiptLineNumber = @cReceiptLineNumber

      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 136201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO RollBackTran
      END
   END
   
   GOTO Quit

RollBackTran:  
   ROLLBACK TRAN rdt_607RcptCfm03 
Fail:  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN
      --insert into TraceInfo (TraceName, TimeIn, Col1) values ('607', getdate(), @dLottable05)
END

SET QUOTED_IDENTIFIER OFF

GO