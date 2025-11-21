SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600RcvCfm15                                           */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: insert uccno                                                      */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 2023-05-04  Yeekung   1.0   WMS-22369 Created                              */
/* 2023-08-02  YeeKung   1.1   WMS-22921 Update UCC status (yeekung01)        */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600RcvCfm15] (
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
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT,
   @cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT,
   @cSerialNo      NVARCHAR( 30) = '',
   @nSerialQTY     INT = 0,
   @nBulkSNO       INT = 0,
   @nBulkSNOQTY    INT = 0
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Handling transaction
   DECLARE @nTranCount     INT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_600RcvCfm15 -- For rollback or commit only our own transaction

   DECLARE @cExternReceiptKey NVARCHAR(20)

   IF @nFunc = 600 -- Normal receiving
   BEGIN

      DECLARE @cBarcode NVARCHAR(MAX)
      DECLARE @cBOX  NVARCHAR(50)

      SELECT @cBarcode = v_max
      FROM RDT.RDTMOBREC (NOLOCK)
      WHERE mobile = @nMobile
    
      DECLARE @tUCCtbl Table 
      ( 
      ROW INT NOT NULL identity(1,1),
      Value NVARCHAR(MAX)
      )
      DECLARE @cPatindex INT

      set @cBarcode = replace(@cBarcode,'<rs>','')

      set @cBarcode = replace(@cBarcode,'<eot>','')


      set @cBarcode = replace(@cBarcode,'<gs>',' ')


      set @cBarcode = replace(@cBarcode,'-','&')

      WHILE (1 = 1)
      BEGIN
         select  @cPatindex= patindex('%[^A-Z|0-9|/|&|'' '']%',@cBarcode) 

         IF @cPatindex <>0
         BEGIN
            SET @cBarcode = replace(@cBarcode,substring(@cBarcode,@cPatindex,1),' ')  
         END
         ELSE
            BREAK
      END


      set @cBarcode = replace(@cBarcode,'&','-')


      insert into @tUCCtbl (Value)
      select value from string_split(@cBarcode,' ') where value<>''


      SELECT @cBOX = value
      FROM @tUCCtbl
      WHERE row = 8

      
      SELECT @nUCCQTY = value
      FROM @tUCCtbl
      WHERE row = 10

      SET @cUCC = @cLottable02 + '-' + @cBOX

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
         @cSKUCode      = '',
         @cSKUUOM       = '',
         @nSKUQTY       = '',
         @cUCC          = @cUCC,
         @cUCCSKU       = @cSKUCode,
         @nUCCQTY       = @nUCCQTY,
         @cCreateUCC    = '1',
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
         @cReceiptLineNumberOutput = @cReceiptLineNumberOutput OUTPUT

      IF @nErrNo <> 0
         GOTO RollBackTran

      SELECT @cExternReceiptKey = ExternReceiptKey,
            @cLottable01 = Lottable01,
            @cLottable02 = Lottable02,
            @cLottable03 = Lottable03,
            @cLottable06 = Lottable06,
            @cLottable07 = Lottable07,
            @cLottable08 = Lottable08,
            @cLottable09 = Lottable09
      FROM Receiptdetail (nolock) 
      where receiptkey = @cReceiptKey
         AND storerkey =  @cStorerKey
         AND ReceiptLineNumber = @cReceiptLineNumberOutput

      UPDATE ucc WITH (ROWLOCK)
      SET   userdefined01 = @cLottable01,
            userdefined02 = @cLottable02,
            userdefined06 = @cLottable06,
            userdefined07 = @cLottable06,
            userdefined08 = @cLottable08,
            userdefined09 = @cLottable09,
            ExternKey = @cExternReceiptKey
      where UCCNo=@cUCC
         AND storerkey = @cStorerKey

      
      IF @nErrNo <> 0
         GOTO RollBackTran

   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_600RcvCfm15
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO