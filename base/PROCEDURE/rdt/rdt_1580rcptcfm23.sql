SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580RcptCfm23                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2021-03-31 1.0  James   WMS-16653. Created                              */
/* 2023-04-13 1.1  James   WMS-21975 Change I_Field02->V_Barcode (james01) */
/***************************************************************************/
CREATE   PROC [RDT].[rdt_1580RcptCfm23](
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
   
   DECLARE @cLottable06    NVARCHAR( 30)
          ,@cLottable07    NVARCHAR( 30)
          ,@cLottable08    NVARCHAR( 30)
          ,@cLottable09    NVARCHAR( 30)
          ,@cLottable10    NVARCHAR( 30)
          ,@cLottable11    NVARCHAR( 30)
          ,@cLottable12    NVARCHAR( 30)
          ,@dLottable13    DATETIME
          ,@dLottable14    DATETIME
          ,@dLottable15    DATETIME
          ,@cLabelNo       NVARCHAR( 60)
          ,@cDecodeLabelNo NVARCHAR( 20)
          
   SELECT @cLabelNo = V_Barcode,
          @cDecodeLabelNo = V_String19
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   IF @cDecodeLabelNo <> ''
   BEGIN
      SET @cLottable01 = SUBSTRING( @cLabelNo, 15, 10)
      SET @dLottable04 = SUBSTRING( @cLabelNo, 26, 10)
      SET @cLottable06 = SUBSTRING( @cLabelNo, 37, LEN( RTRIM( @cLabelNo)) - 36)
   END

   EXEC rdt.rdt_Receive_v7  
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
      @cSubreasonCode = @cSubreasonCode
      
      
   
Quit:

END

GO