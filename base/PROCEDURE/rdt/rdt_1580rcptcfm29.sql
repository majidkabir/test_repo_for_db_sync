SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580RcptCfm29                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2023-06-01 1.0  yeekung  WMS-22626 Created                              */
/***************************************************************************/
CREATE   PROC [RDT].[rdt_1580RcptCfm29](
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

   DECLARE @cLottable06 NVARCHAR( 30)    
   DECLARE @cLottable07 NVARCHAR( 30)    
   DECLARE @cLottable08 NVARCHAR( 30)    
   DECLARE @cLottable09 NVARCHAR( 30)    
   DECLARE @cLottable10 NVARCHAR( 30)    
   DECLARE @cLottable11 NVARCHAR( 30)    
   DECLARE @cLottable12 NVARCHAR( 30)    
   DECLARE @dLottable13 DATETIME         
   DECLARE @dLottable14 DATETIME         
   DECLARE @dLottable15 DATETIME
   
   SELECT @cSerialNo = V_Barcode
   FROM RDT.RdtMobrec (NOLOCK)
   WHERE mobile = @nMobile

   IF LEN(@cSerialNo) <>24
   BEGIN
      SET @cSerialNo =''
      SET @nSerialQTY = 0
   END
   ELSE
   BEGIN
      SET @nSerialQTY = @nSKUQTY
   END

   -- Use rdt_Receive_V7 due to rdt_Receive overwrite SubreasonCode
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
      @cToID          = @cTOID,
      @cSKUCode       = @cSKUCode,
      @cSKUUOM        = @cSKUUOM,
      @nSKUQTY        = @nSKUQTY,
      @cUCC           = '',
      @cUCCSKU        = '',
      @nUCCQTY        = '',
      @cCreateUCC     = @cCreateUCC,
      @cLottable01    = @cLottable01,
      @cLottable02    = @cLottable02,   
      @cLottable03    = @cLottable03,
      @dLottable04    = @dLottable04,
      @dLottable05    = @dLottable05,
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
      @cSubreasonCode = NULL, 
      @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT, 
      @cSerialNo      = @cSerialNo, 
      @nSerialQTY     = @nSerialQTY
   IF @nErrNo <> 0
      GOTO Quit

   /*
   -- Get sub reason
   SELECT @cSubReasonCode = ISNULL( SubReasonCode, '')
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
      AND ReceiptLineNumber = @cReceiptLineNumber

   -- Prompt sub reason (for operator to separate physical stock)
   IF @cSubReasonCode <> ''
   BEGIN
      IF EXISTS( SELECT 1 
         FROM dbo.CodeLKUP WITH (NOLOCK) 
         WHERE ListName = 'ASNSUBRSN' 
            AND Code = @cSubReasonCode
            AND StorerKey = @cStorerKey)
      BEGIN
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @cSubReasonCode
      END
   END
   */
   
Quit:          

END

GO