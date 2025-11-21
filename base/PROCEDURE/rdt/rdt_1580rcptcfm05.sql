SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580RcptCfm05                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2018-02-23 1.0  ChewKP  WMS-4094 Created                                */
/* 2018-09-25 1.1  Ung     WMS-5722 Add param                              */
/***************************************************************************/
CREATE PROC [RDT].[rdt_1580RcptCfm05](
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
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT, 
   @cSerialNo        NVARCHAR( 30) = '', 
   @nSerialQTY       INT = 0, 
   @nBulkSNO         INT = 0,
   @nBulkSNOQTY      INT = 0
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE 
    @cLottable06    NVARCHAR( 30),    
    @cLottable07    NVARCHAR( 30),    
    @cLottable08    NVARCHAR( 30),    
    @cLottable09    NVARCHAR( 30),    
    @cLottable10    NVARCHAR( 30),    
    @cLottable11    NVARCHAR( 30),    
    @cLottable12    NVARCHAR( 30),    
    @dLottable13    DATETIME,         
    @dLottable14    DATETIME,         
    @dLottable15    DATETIME
    

   SET @cLottable08 = ''
   SET @cLottable09 = ''
   
   SELECT TOP 1 @cLottable06   = Lottable06
               ,@cLottable07   = Lottable07
               ,@cLottable08   = Lottable08
               ,@cLottable09   = Lottable09
               ,@cLottable10   = Lottable10
               ,@cLottable11   = Lottable11
               ,@cLottable12   = Lottable12
               ,@dLottable13   = Lottable13
               ,@dLottable14   = Lottable14
               ,@dLottable15   = Lottable15
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND ReceiptKey = @cReceiptKey
   AND SKU = @cSKUCode
   ORDER BY ReceiptLineNumber
   
   IF ISNULL(@cLottable08,'') = '' 
   BEGIN
      SELECT @cLottable08 = CountryOfOrigin 
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND SKU = @cSKUCode 
   END
   
   IF ISNULL(@cLottable09,'') = '' 
   BEGIN
      SELECT @cLottable09 = ItemClass 
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND SKU = @cSKUCode 
   END
      

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

--   EXEC rdt.rdt_Receive    
--      @nFunc          = @nFunc,
--      @nMobile        = @nMobile,
--      @cLangCode      = @cLangCode,
--      @nErrNo         = @nErrNo  OUTPUT,
--      @cErrMsg        = @cErrMsg OUTPUT,
--      @cStorerKey     = @cStorerKey,
--      @cFacility      = @cFacility,
--      @cReceiptKey    = @cReceiptKey,
--      @cPOKey         = @cPOKey,
--      @cToLOC         = @cToLOC,
--      @cToID          = @cTOID,
--      @cSKUCode       = @cSKUCode,
--      @cSKUUOM        = @cSKUUOM,
--      @nSKUQTY        = @nSKUQTY,
--      @cUCC           = @cUCC,
--      @cUCCSKU        = @cUCCSKU,
--      @nUCCQTY        = @nUCCQTY,
--      @cCreateUCC     = @cCreateUCC,
--      @cLottable01    = @cLottable01,
--      @cLottable02    = @cLottable02,   
--      @cLottable03    = @cLottable03,
--      @dLottable04    = @dLottable04,
--      @dLottable05    = @dLottable05,
--      @nNOPOFlag      = @nNOPOFlag,
--      @cConditionCode = @cConditionCode,
--      @cSubreasonCode = @cSubreasonCode, 
--      @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT
--
--   IF @nErrNo <> 0
--   BEGIN
--      IF @cTOID <> '' AND @cReceiptLineNumber <> ''
--      BEGIN
--         IF EXISTS( SELECT 1 
--            FROM ReceiptDetail WITH (NOLOCK) 
--            WHERE ReceiptKey = @cReceiptKey 
--               AND ReceiptLineNumber = @cReceiptLineNumber
--               AND ISNULL( UserDefine10, '') = '')
--         BEGIN
--            -- Get ExtendedInfo (PutawayZone)
--            DECLARE @cPutawayZone NVARCHAR( 20)
--            SELECT @cPutawayZone = O_Field15 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
--            
--            -- Update PutawayZone to UDF10
--            UPDATE ReceiptDetail SET 
--               UserDefine10 = @cPutawayZone, 
--               EditDate = GETDATE(), 
--               EditWho = SUSER_SNAME(), 
--               TrafficCop = NULL
--            WHERE ReceiptKey = @cReceiptKey 
--               AND ReceiptLineNumber = @cReceiptLineNumber
--         END
--      END
--   END
   
Quit:

END

GO