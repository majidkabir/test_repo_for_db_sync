SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608RcvCfm09                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: When insert new receiptdetail line, copy lottable & userdefine    */
/*          If sku not in asn, update lottable06/07 = Unexpt S/Unexpt Q       */
/*          If over receive, update lottable07 = Unexpt Q                     */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2020-05-28 1.0  James      WMS-13257. Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_608RcvCfm09] (
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

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nSKUNotInASN         INT,
           @nCopyFromASNLine     INT,
           @nQtyExpected         INT,
           @nBeforeReceivedQty   INT,
           @nRowCount            INT,
           @cExternLineNo        NVARCHAR( 20),
           @cExternReceiptKey    NVARCHAR( 20),
           @cUserDefine01        NVARCHAR( 30),
           @cUserDefine02        NVARCHAR( 30),
           @cUserDefine03        NVARCHAR( 30),
           @cUserDefine04        NVARCHAR( 30),
           @cUserDefine05        NVARCHAR( 30),
           @dUserDefine06        DATETIME,
           @dUserDefine07        DATETIME,
           @cUserDefine08        NVARCHAR( 30),
           @cUserDefine09        NVARCHAR( 30),
           @cUserDefine10        NVARCHAR( 30),
           @cReceiptLineNumber   NVARCHAR( 5),
           @cDuplicateFrom       NVARCHAR( 5),
           @cNewExternLineNo     NVARCHAR( 20)

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_608RcvCfm09 -- For rollback or commit only our own transaction

   SET @nSKUNotInASN = 0
   IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                   WHERE ReceiptKey = @cReceiptKey
                   AND   SKU = @cSKUCode)
      SET @nSKUNotInASN = 1
   ELSE
   BEGIN
      SET @nSKUNotInASN = 0

      SELECT @nQtyExpected = ISNULL( SUM( QtyExpected), 0),
             @nBeforeReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0)
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey
      AND   SKU = @cSKUCode            -- Same SKU
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

   IF @nErrNo <> 0
      GOTO RollBackTran

   IF @nSKUNotInASN = '1'
   BEGIN
      -- If the sku not in asn, copy the info 
      -- from original asn line to new asn line
      -- 1st receipdetail.ExternReceiptKey, Lottable06 ~ Lottable10, lottable02, 07,08,09, Userdefine01~10 , 

      SELECT @cNewExternLineNo = 
         RIGHT( '00000' + CAST( CAST( IsNULL( MAX( ExternLineNo), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)  
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      -- Get original line no
      SELECT TOP 1
         @cExternReceiptKey = ExternReceiptKey,
         @cLottable06 = Lottable06,
         @cLottable07 = Lottable07,
         @cLottable08 = Lottable08,
         @cLottable09 = Lottable09,
         @cLottable10 = Lottable10,
         @cUserDefine01 = UserDefine01,
         @cUserDefine02 = UserDefine02,
         @cUserDefine03 = UserDefine03,
         @cUserDefine04 = UserDefine04,
         @cUserDefine05 = UserDefine05,
         @dUserDefine06 = UserDefine06,
         @dUserDefine07 = UserDefine07,
         @cUserDefine08 = UserDefine08,
         @cUserDefine09 = UserDefine09,
         @cUserDefine10 = UserDefine10
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey
      ORDER BY ReceiptLineNumber

      -- Update values to new lines
      UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK) SET  
         ExternReceiptKey  = @cExternReceiptKey,
         ExternLineNo      = @cNewExternLineNo,
         QtyExpected       = 0,
         Lottable06        = @cLottable06,
         Lottable07        = @cLottable07,
         Lottable08        = @cLottable08,
         Lottable09        = @cLottable09,
         Lottable10        = @cLottable10,
         Userdefine01      = @cLottable01,
         Userdefine02      = @cUserDefine02,
         Userdefine03      = @cUserDefine03,
         Userdefine04      = @cUserDefine04,
         Userdefine05      = @cUserDefine05,
         Userdefine06      = @dUserDefine06,
         Userdefine07      = @dUserDefine07,
         Userdefine08      = @cUserDefine08,
         Userdefine09      = @cUserDefine09,
         Userdefine10      = @cUserDefine10,
         TrafficCop        = NULL
      WHERE ReceiptKey = @cReceiptKey
      AND   ReceiptLineNumber = @cReceiptLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 153101
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RCPT FAIL
         GOTO RollBackTran
      END
      
      GOTO Quit
   END

   SELECT @cDuplicateFrom = DuplicateFrom
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   AND   ReceiptLineNumber = @cReceiptLineNumber
   
   -- Get original line no
   SELECT TOP 1
      @cExternReceiptKey = ExternReceiptKey,
      @cLottable06 = Lottable06,
      @cLottable07 = Lottable07,
      @cLottable08 = Lottable08,
      @cLottable09 = Lottable09,
      @cLottable10 = Lottable10,
      @cUserDefine01 = UserDefine01,
      @cUserDefine02 = UserDefine02,
      @cUserDefine03 = UserDefine03,
      @cUserDefine04 = UserDefine04,
      @cUserDefine05 = UserDefine05,
      @dUserDefine06 = UserDefine06,
      @dUserDefine07 = UserDefine07,
      @cUserDefine08 = UserDefine08,
      @cUserDefine09 = UserDefine09,
      @cUserDefine10 = UserDefine10
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey
   AND   Sku = @cSKUCode
   AND   (( ISNULL( @cDuplicateFrom, '') <> '' AND ReceiptLineNumber = @cDuplicateFrom) OR ( ReceiptLineNumber = ReceiptLineNumber))
   ORDER BY ReceiptLineNumber

   -- Update values to new lines
   UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK) SET  
      ExternReceiptKey  = @cExternReceiptKey,
      Lottable06        = @cLottable06,
      Lottable07        = @cLottable07,
      Lottable08        = @cLottable08,
      Lottable09        = @cLottable09,
      Lottable10        = @cLottable10,
      Userdefine01      = @cLottable01,
      Userdefine02      = @cUserDefine02,
      Userdefine03      = @cUserDefine03,
      Userdefine04      = @cUserDefine04,
      Userdefine05      = @cUserDefine05,
      Userdefine06      = @dUserDefine06,
      Userdefine07      = @dUserDefine07,
      Userdefine08      = @cUserDefine08,
      Userdefine09      = @cUserDefine09,
      Userdefine10      = @cUserDefine10,
      TrafficCop        = NULL
   WHERE ReceiptKey = @cReceiptKey
   AND   ReceiptLineNumber = @cReceiptLineNumber

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 153102
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RCPT FAIL
      GOTO RollBackTran
   END

   SET @cExternLineNo = ''
   SET @cUserDefine01 = ''
   SELECT @cExternLineNo = ExternLineNo,
          @cUserDefine01 = UserDefine01
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   AND   ReceiptLineNumber = @cReceiptLineNumber
      
   IF ISNULL( @cExternLineNo, '') = ''
   BEGIN
      SELECT TOP 1 @cExternLineNo = ExternLineNo
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   Sku = @cSKUCode   
      ORDER BY ReceiptLineNumber
   
      -- Update values to new lines
      UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK) SET  
         ExternLineNo      = @cExternLineNo,
         TrafficCop        = NULL
      WHERE ReceiptKey = @cReceiptKey
      AND   ReceiptLineNumber = @cReceiptLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 153103
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RCPT FAIL
         GOTO RollBackTran
      END
   END

   IF ISNULL( @cUserDefine01, '') = ''
   BEGIN
      -- Update values to new lines
      UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK) SET  
         UserDefine01      = @cLottable01,
         TrafficCop        = NULL
      WHERE ReceiptKey = @cReceiptKey
      AND   ReceiptLineNumber = @cReceiptLineNumber

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 153104
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RCPT FAIL
         GOTO RollBackTran
      END
   END
   
   GOTO Quit

   RollBackTran:  
      ROLLBACK TRAN rdt_608RcvCfm09 
   Fail:  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN  

GO