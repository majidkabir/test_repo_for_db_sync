SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_608RcvCfm16                                        */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/* Date       Rev  Author    Purposes                                      */
/* 2023-08-18 1.0  yeekung   WMS-23405 Created                             */
/* 2023-11-16 1.1  Calvin    JSM-191025 Retain SubreasonCode (CLVN01)      */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_608RcvCfm16](
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
    @cRDLineNo      NVARCHAR( 5)  OUTPUT,
    @nErrNo         INT           OUTPUT,
    @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   --(CLVN01) START--
   SELECT TOP 1 @cSubreasonCode = RD.SubreasonCode 
   FROM ReceiptDetail RD (NOLOCK)
   JOIN Receipt R (NOLOCK) ON R.receiptkey = RD.ReceiptKey
   WHERE RD.Receiptkey = @cReceiptkey
         AND RD.Storerkey = @cStorerkey
         AND SKU = @cSKUCode
         AND R.DOCTYPE = 'R'
         AND R.RECEIPTGROUP = 'OMNI'
   --(CLVN01) END--

   IF EXISTS ( SELECT 1
               FROM ReceiptDetail RD (NOLOCK)
               JOIN Receipt R (NOLOCK) ON R.receiptkey = RD.ReceiptKey
               WHERE RD.Receiptkey = @cReceiptkey
                  AND RD.Storerkey = @cStorerkey
                  AND SKU = @cSKUCode
                  AND R.ReceiptGroup = 'AFS'
                  AND R.DOCTYPE = 'R'
                  and ISNULL(SubreasonCode,'') <> ''

               ) AND 
            NOT EXISTS ( SELECT 1
               FROM ReceiptDetail RD (NOLOCK)
               JOIN Receipt R (NOLOCK) ON R.receiptkey = RD.ReceiptKey
               WHERE R.Receiptkey = @cReceiptkey
                  AND RD.Storerkey = @cStorerkey
                  AND SKU = @cSKUCode
                  and ISNULL(SubreasonCode,'') = ''
                  AND R.ReceiptGroup = 'AFS'
                  AND R.DOCTYPE = 'R'
               GROUP BY SKU,SubreasonCode
               HAVING SUM(QTYEXPECTED) > SUM(BEFOREReceivedqty))
               
   BEGIN  
      SET @nErrNo = 205501  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over receive  
      GOTO QUIT
   END  
  
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
      @cPOKey        = @cPoKey,
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
      @cSubreasonCode = @cSubreasonCode,  --(CLVN01)
      @cReceiptLineNumberOutput = @cRDLineNo OUTPUT

QUIT:

END

GO