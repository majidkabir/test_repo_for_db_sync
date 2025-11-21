SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580RcptCfm04                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2018-01-24 1.0  Ung     WMS-3651 Created                                */
/* 2018-09-25 1.1  Ung     WMS-5722 Add param                              */
/***************************************************************************/
CREATE PROC [RDT].[rdt_1580RcptCfm04](
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
   @cSubreasonCode NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT, 
   @cSerialNo      NVARCHAR( 30) = '', 
   @nSerialQTY     INT = 0, 
   @nBulkSNO       INT = 0,
   @nBulkSNOQTY    INT = 0
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   EXEC rdt.rdt_Receive    
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
      @cToID          = @cTOID,
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
      @cSubreasonCode = @cSubreasonCode, 
      @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT

   IF @nErrNo <> 0
   BEGIN
      IF @cTOID <> '' AND @cReceiptLineNumber <> ''
      BEGIN
         IF EXISTS( SELECT 1 
            FROM ReceiptDetail WITH (NOLOCK) 
            WHERE ReceiptKey = @cReceiptKey 
               AND ReceiptLineNumber = @cReceiptLineNumber
               AND ISNULL( UserDefine10, '') = '')
         BEGIN
            -- Get ExtendedInfo (PutawayZone)
            DECLARE @cPutawayZone NVARCHAR( 20)
            SELECT @cPutawayZone = O_Field15 FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
            
            -- Update PutawayZone to UDF10
            UPDATE ReceiptDetail SET 
               UserDefine10 = @cPutawayZone, 
               EditDate = GETDATE(), 
               EditWho = SUSER_SNAME(), 
               TrafficCop = NULL
            WHERE ReceiptKey = @cReceiptKey 
               AND ReceiptLineNumber = @cReceiptLineNumber
         END
      END
   END
   
Quit:

END

GO