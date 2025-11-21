SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_898RcvCfm03                                        */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2017-10-06 1.0  Ung     WMS-2112 Created                                */
/***************************************************************************/
CREATE PROC [RDT].[rdt_898RcvCfm03](
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

   DECLARE @cSourceType       NVARCHAR(20)
   DECLARE @cSourceKey        NVARCHAR(20)
   DECLARE @cUCCReceiptKey    NVARCHAR(10)
   DECLARE @cUCCPOKey         NVARCHAR(10)
   DECLARE @cUCCPOLineNumber  NVARCHAR(5)
   
   IF @cCreateUCC = '1' OR -- Create new UCC
      @cUCC = ''           -- Receive loose SKU
   BEGIN
      SET @cUCCReceiptKey = @cReceiptKey
      SET @cUCCPOKey = @cPOKey
   END
   ELSE
   BEGIN
      -- Get UCC info
      SELECT 
         @cSourceType = ISNULL( SourceType, ''), 
         @cSourceKey = SourceKey
      FROM dbo.UCC WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
         AND UCCNo = @cUCC 

      IF @cSourceType = 'ASN'
      BEGIN
         SET @cUCCReceiptKey = SUBSTRING( @cSourcekey, 1, 10) 
         SET @cUCCPOKey = ''
         SET @nNOPOFlag = 1
      END
      
      ELSE IF @cSourceType = 'PO'
      BEGIN
         SET @cUCCPOKey = SUBSTRING( @cSourcekey, 1, 10) 
         SET @cUCCPOLineNumber = SUBSTRING( @cSourcekey, 11, 5) 
         SET @nNOPOFlag = 0
   
         -- Get ASN
         SELECT TOP 1 
            @cUCCReceiptKey = R.ReceiptKey
         FROM Receipt R WITH (NOLOCK)
            JOIN ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
         WHERE R.StorerKey = @cStorerKey
            AND R.Facility = @cFacility
            AND RD.POKey = @cUCCPOKey
            AND RD.POLineNumber = @cUCCPOLineNumber
      END
   END

   -- Get ASN info
   DECLARE @cDocType NVARCHAR( 1)
   IF @cDocType = ''
      SELECT @cDocType = DocType FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cUCCReceiptKey

   -- Insert interface ADDCTNLOG
   DECLARE @b_success INT
   EXEC dbo.ispGenTransmitLog3 'ADDCTNLOG', @cUCCReceiptKey, @cDocType, @cStorerKey, ''
      , @b_success OUTPUT
      , @nErrNo    OUTPUT
      , @cErrMsg   OUTPUT
   IF @b_success <> 1
   BEGIN
      SET @nErrNo = 85303
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins TLog3 Fail
      GOTO Quit
   END

   EXEC rdt.rdt_Receive    
      @nFunc          = @nFunc,
      @nMobile        = @nMobile,
      @cLangCode      = @cLangCode,
      @nErrNo         = @nErrNo  OUTPUT,
      @cErrMsg        = @cErrMsg OUTPUT,
      @cStorerKey     = @cStorerKey,
      @cFacility      = @cFacility,
      @cReceiptKey    = @cUCCReceiptKey,
      @cPOKey         = @cUCCPOKey,
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
      @dLottable05    = @dLottable05,
      @nNOPOFlag      = @nNOPOFlag,
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = @cSubreasonCode

Quit:
      
END

GO