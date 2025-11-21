SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580RcptCfm20                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2020-07-06 1.0  James   WMS-14064. Created                              */
/* 2023-04-13 1.1  James   WMS-21975 Change I_Field02->V_Barcode (james01) */
/***************************************************************************/
CREATE   PROC [RDT].[rdt_1580RcptCfm20](
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
   
   DECLARE @cBarcode    NVARCHAR( 60)
   DECLARE @cSeason     NVARCHAR( 2)  
   DECLARE @cLOT        NVARCHAR( 12)  
   DECLARE @cCOO        NVARCHAR( 2)  
   DECLARE @cDocType    NVARCHAR( 1)  
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
            
   SELECT @cBarcode = V_Barcode
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT @cDocType = DocType 
   FROM dbo.Receipt WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey  

   SET @cSeason = SUBSTRING( @cBarcode, 1, 2)  
   SET @cSKUCode = SUBSTRING( @cBarcode, 3, 13)  
   SET @cLOT = SUBSTRING( @cBarcode, 16, 12)  
   SET @cCOO = SUBSTRING( @cBarcode, 28, 2)  

   SET @cLottable01 = SUBSTRING( @cLOT, 1, 6)  
   SET @cLottable02 = @cLOT + '-' + @cCOO  
   SET @cLottable03 = CASE WHEN @cDocType = 'A' THEN 'STD' ELSE 'RET' END  
   SET @cLottable12 = SUBSTRING( @cLOT, 7, (LEN( @cLOT) - LEN( @cLottable01))) 
   SELECT TOP 1 @dLottable14 = Lottable14
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   AND   Lottable12 = @cLottable12
   ORDER BY 1
   
   SET @nErrNo = 0
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
   
   IF @nErrNo <> 0
      GOTO Quit

   Quit:  
  

END

GO