SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_598RcvCfm04                                           */  
/* Copyright      : LF Logistics                                              */  
/*                                                                            */  
/* Purpose: Receive across multiple ASN                                       */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2021-11-29 1.0  James      WMS-18442. Created                              */  
/******************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_598RcvCfm04] (  
   @nFunc          INT,  
   @nMobile        INT,  
   @cLangCode      NVARCHAR( 3),  
   @cStorerKey     NVARCHAR( 15),  
   @cFacility      NVARCHAR( 5),  
   @cRefNo         NVARCHAR( 20),   
   @cColumnName    NVARCHAR( 20),   
   @cToLOC         NVARCHAR( 10),  
   @cToID          NVARCHAR( 18), -- Blank = receive to blank ToID  
   @cSKUCode       NVARCHAR( 20), -- SKU code. Not SKU barcode  
   @cSKUUOM        NVARCHAR( 10),  
   @nSKUQTY        INT,           -- In master unit  
   @cUCC           NVARCHAR( 20),  
   @cUCCSKU        NVARCHAR( 20),  
   @nUCCQTY        INT,           -- In master unit. Pass in the QTY for UCCWithDynamicCaseCNT  
   @cCreateUCC     NVARCHAR( 1),  -- Create UCC. 1=Yes, the rest=No  
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
   @nErrNo         INT                    OUTPUT,  
   @cErrMsg        NVARCHAR( 20)          OUTPUT,   
   @cReceiptKeyOutput NVARCHAR( 10)       OUTPUT,  
   @cReceiptLineNumberOutput NVARCHAR( 5) OUTPUT,   
   @cDebug         NVARCHAR( 1) = '0'  
) AS  
     
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
DECLARE @cReceiptKey  NVARCHAR(10)  
DECLARE @nQTY_Bal     INT  
DECLARE @nQTY         INT  
DECLARE @nQtyExpected INT  
DECLARE @cDuplicateRD   NVARCHAR( 15)  
DECLARE @cDuplicateFrom NVARCHAR( 5)  
DECLARE @cDupReceiptKey NVARCHAR( 10)  
DECLARE @cDupReceiptLineNumber NVARCHAR( 5)  
DECLARE @cDupExternReceiptKey NVARCHAR( 50)  
DECLARE @cDupExternLineNo NVARCHAR( 20)  
DECLARE @cDupPOKey         NVARCHAR( 18)  
DECLARE @cDupPOLineNumber  NVARCHAR( 5)  
DECLARE @cDupExternPoKey   NVARCHAR( 20)  
DECLARE @cDupLottable01    NVARCHAR( 18)  
DECLARE @cDupLottable02    NVARCHAR( 18)  
DECLARE @cDupLottable03    NVARCHAR( 18)  
DECLARE @dDupLottable04    DATETIME  
DECLARE @cDupLottable06    NVARCHAR( 30)  
DECLARE @cDupLottable07    NVARCHAR( 30)  
DECLARE @cDupLottable08    NVARCHAR( 30)  
DECLARE @cDupLottable09    NVARCHAR( 30)  
DECLARE @cDupLottable10    NVARCHAR( 30)  
DECLARE @cDupUserDefine01  NVARCHAR( 30)  
DECLARE @cDupUserDefine02  NVARCHAR( 30)  
DECLARE @cDupUserDefine03  NVARCHAR( 30)  
DECLARE @cDupUserDefine04  NVARCHAR( 30)  
DECLARE @cDupUserDefine05  NVARCHAR( 30)  
DECLARE @dDupUserDefine06  DATETIME  
DECLARE @dDupUserDefine07  DATETIME  
DECLARE @cDupUserDefine08  NVARCHAR( 30)  
DECLARE @cDupUserDefine09  NVARCHAR( 30)  
DECLARE @cDupUserDefine10  NVARCHAR( 30)  
  
-- Copy QTY to process  
SET @nQTY_Bal = @nSKUQTY  
  
-- Handling transaction  
DECLARE @nTranCount INT  
SET @nTranCount = @@TRANCOUNT  
BEGIN TRAN  -- Begin our own transaction  
SAVE TRAN rdt_ConReceive -- For rollback or commit only our own transaction  
  
DECLARE @curReceipt CURSOR  
SET @curReceipt = CURSOR FOR  
   SELECT CRL.ReceiptKey, ISNULL( SUM( QTYExpected), 0)  
   FROM dbo.ReceiptDetail RD WITH (NOLOCK)  
      JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON (RD.ReceiptKey = CRL.ReceiptKey)  
   WHERE Mobile = @nMobile  
      AND RD.StorerKey = @cStorerKey  
      AND RD.SKU = @cSKUCode  
      --AND (RD.QtyExpected - RD.BeforeReceivedQty) > 0  
   GROUP BY CRL.ReceiptKey  
   ORDER BY CRL.ReceiptKey  
OPEN @curReceipt  
FETCH NEXT FROM @curReceipt INTO @cReceiptKey, @nQTY  
WHILE @@FETCH_STATUS = 0  
BEGIN  
   IF @nQTY > 0  
   BEGIN  
      IF @nQTY_Bal < @nQTY  
         SET @nQTY = @nQTY_Bal  
           
      EXEC rdt.rdt_Receive_V7  
         @nFunc         = @nFunc,  
         @nMobile       = @nMobile,  
         @cLangCode     = @cLangCode,  
         @nErrNo        = @nErrNo OUTPUT,  
         @cErrMsg       = @cErrMsg OUTPUT,  
         @cStorerKey    = @cStorerKey,  
         @cFacility     = @cFacility,  
         @cReceiptKey   = @cReceiptKey,  
         @cPOKey        = 'NOPO',  
         @cToLOC        = @cToLOC,  
         @cToID         = @cToID,  
         @cSKUCode      = @cSKUCode,  
         @cSKUUOM       = @cSKUUOM,  
         @nSKUQTY       = @nQTY,  
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
         @nNOPOFlag     = 1,  
         @cConditionCode = @cConditionCode,  
         @cSubreasonCode = '',   
         @cReceiptLineNumberOutput = @cReceiptLineNumberOutput OUTPUT  
      IF @nErrNo <> 0  
         GOTO RollBackTran  
           
      SET @cReceiptKeyOutput = @cReceiptKey  
      SET @nQTY_Bal = @nQTY_Bal - @nQTY  
      IF @nQTY_Bal = 0  
         BREAK  
   END  
   FETCH NEXT FROM @curReceipt INTO @cReceiptKey, @nQTY  
END  
  
-- If still have balance, means offset has error  
--IF @nQTY_Bal <> 0  
--BEGIN  
--   SET @nErrNo = 179251  
--   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Offset error  
--   GOTO RollBackTran  
--END  
  
SELECT   
   @cDuplicateFrom = DuplicateFrom,   
   @nQtyExpected = QtyExpected  
FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
WHERE ReceiptKey = @cReceiptKeyOutput  
AND   ReceiptLineNumber = @cReceiptLineNumberOutput  
  
IF ISNULL( @cDuplicateFrom, '') <> '' OR @nQtyExpected = 0  
BEGIN  
   SELECT @cDuplicateRD = MAX( RD.ReceiptKey+RD.ReceiptLineNumber)  
   FROM dbo.ReceiptDetail RD WITH (NOLOCK)  
   JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON (RD.ReceiptKey = CRL.ReceiptKey)  
   WHERE Mobile = @nMobile  
   AND RD.StorerKey = @cStorerKey  
   AND RD.SKU = @cSKUCode  
   AND RD.ReceiptLineNumber <> @cReceiptLineNumberOutput  
     
   SET @cDupReceiptKey = SUBSTRING( @cDuplicateRD, 1, 10)  
   SET @cDupReceiptLineNumber = SUBSTRING( @cDuplicateRD, 11, 5)  
  
--INSERT INTO traceinfo (TraceName, TimeIn, Col1, Col2, Col3, Col4, Step1, Step2) VALUES  
--('598', GETDATE(), @cReceiptKeyOutput, @cReceiptLineNumberOutput, @cDuplicateFrom, @nQtyExpected, @cDupReceiptKey, @cDupReceiptLineNumber)  
           
   SELECT   
      @cDupExternReceiptKey   = ExternReceiptKey,  
      @cDupExternLineNo       = ExternLineNo,  
      @cDupPOKey              = POKey,          
      @cDupPOLineNumber       = POLineNumber,   
      @cDupExternPoKey        = ExternPoKey,    
      @cDupLottable01         = Lottable01,     
      @cDupLottable02         = Lottable02,     
      @cDupLottable03         = Lottable03,     
      @dDupLottable04         = Lottable04,     
      @cDupLottable06         = Lottable06,     
      @cDupLottable07         = Lottable07,     
      @cDupLottable08         = Lottable08,     
      @cDupLottable09         = Lottable09,     
      @cDupLottable10         = Lottable10,     
      @cDupUserDefine01       = UserDefine01,   
      @cDupUserDefine02       = UserDefine02,   
      @cDupUserDefine03       = UserDefine03,   
      @cDupUserDefine04       = UserDefine04,   
      @cDupUserDefine05       = UserDefine05,   
      @dDupUserDefine06       = UserDefine06,   
      @dDupUserDefine07       = UserDefine07,   
      @cDupUserDefine08       = UserDefine08,   
      @cDupUserDefine09       = UserDefine09,   
      @cDupUserDefine10       = UserDefine10  
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)  
   WHERE ReceiptKey = @cDupReceiptKey  
   AND   ReceiptLineNumber = @cDupReceiptLineNumber  
           
   UPDATE dbo.ReceiptDetail SET  
      ExternReceiptKey = @cDupExternReceiptKey,  
      ExternLineNo = @cDupExternLineNo,      
      POKey = @cDupPOKey,             
      POLineNumber = @cDupPOLineNumber,      
      ExternPoKey = @cDupExternPoKey,       
      Lottable01 = @cDupLottable01,        
      Lottable02 = @cDupLottable02,        
      Lottable03 = @cDupLottable03,        
      Lottable04 = @dDupLottable04,        
      Lottable06 = @cDupLottable06,        
      Lottable07 = @cDupLottable07,        
      Lottable08 = @cDupLottable08,        
      Lottable09 = @cDupLottable09,        
      Lottable10 = @cDupLottable10,        
      UserDefine01 = @cDupUserDefine01,      
      UserDefine02 = @cDupUserDefine02,      
      UserDefine03 = @cDupUserDefine03,      
      UserDefine04 = @cDupUserDefine04,      
      UserDefine05 = @cDupUserDefine05,      
      UserDefine06 = @dDupUserDefine06,      
      UserDefine07 = @dDupUserDefine07,      
      UserDefine08 = @cDupUserDefine08,      
      UserDefine09 = @cDupUserDefine09,      
      UserDefine10 = @cDupUserDefine10,  
      EditWho = SUSER_SNAME(),  
      EditDate = GETDATE()  
   WHERE ReceiptKey = @cReceiptKeyOutput  
   AND   ReceiptLineNumber = @cReceiptLineNumberOutput  
           
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 179252  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd RcptD Err  
      GOTO RollBackTran  
   END  
END  
  
GOTO Quit  
  
RollBackTran:    
   ROLLBACK TRAN rdt_ConReceive   
Fail:    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN  

GO