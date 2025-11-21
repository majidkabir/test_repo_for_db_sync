SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_898RcvCfm11                                        */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2022-12-13 1.0  yeekung WMS21053 Created                                */
/***************************************************************************/
CREATE   PROC [RDT].[rdt_898RcvCfm11](
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT, 
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
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10)
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLottable06  NVARCHAR( 30),
           @cLottable07  NVARCHAR( 30),
           @cLottable08  NVARCHAR( 30),
           @cLottable09  NVARCHAR( 30),
           @cLottable10  NVARCHAR( 30),
           @cLottable11  NVARCHAR( 30),
           @cLottable12  NVARCHAR( 30),
           @dLottable13  DATETIME,
           @dLottable14  DATETIME,
           @dLottable15  DATETIME,
           @nCnt         INT

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
      @cToLOC         = @cToLOC,
      @cToID          = @cToID, 
      @cSKUCode       = @cSKUCode,
      @cSKUUOM        = @cSKUUOM,
      @nSKUQTY        = @nSKUQTY,
      @cUCC           = @cUCC,
      @cUCCSKU        = @cUCCSKU,
      @nUCCQTY        = @nUCCQTY,
      @cCreateUCC     = @cCreateUCC,
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
      @nNOPOFlag      = @nNOPOFlag,
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = @cSubreasonCode


   IF @nErrNo =0
   BEGIN

      DECLARE @cIVAS          NVARCHAR(20)
      DECLARE @cMode          NVARCHAR(20)

      -- Get StorerKey
      SELECT @cStorerKey = StorerKey FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

      SET @cMode =  rdt.rdtGetConfig( @nFunc, 'PopUpMode', @cStorerKey) 

      -- Get UCC info
      --SELECT
      --   @cSKU = SKU
      --FROM UCC WITH (NOLOCK)
      --WHERE UCC.StorerKey = @cStorerKey
      --   AND UCC.UCCNo = @cUCC

      IF @cMode ='1'
      BEGIN
            -- Check UserDefine10 in OriLine ASN
         IF EXISTS( SELECT 1 FROM SKU WITH (NOLOCK)
                     WHERE SKU = @cUCCSKU
                     AND IVAS <>''
                     AND storerkey=@cStorerKey
                     )
         BEGIN
            SELECT @cIVAS=IVAS FROM SKU WITH (NOLOCK)
            WHERE SKU = @cUCCSKU
            AND IVAS <>''
            AND storerkey=@cStorerKey

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,  --(yeekung05)  
            'IVAS:',  
            @cIVAS,
            '%I_Field',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            @cMode

            SET @nErrNo=0
         END
      END
   END

END

GO