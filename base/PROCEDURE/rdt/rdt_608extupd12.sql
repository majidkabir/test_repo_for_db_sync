SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608ExtUpd12                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Calc suggest location, booking                                    */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 25-01-2021   Chermaine 1.0   WMS-16119 Created                             */
/* 08-09-2022   Ung       1.1   WMS-20348 Expand RefNo to 60 chars            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608ExtUpd12]
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,           
   @nAfterStep    INT,            
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5),   
   @cStorerKey    NVARCHAR( 15), 
   @cReceiptKey   NVARCHAR( 10), 
   @cPOKey        NVARCHAR( 10), 
   @cRefNo        NVARCHAR( 60), 
   @cID           NVARCHAR( 18), 
   @cLOC          NVARCHAR( 10), 
   @cMethod       NVARCHAR( 1), 
   @cSKU          NVARCHAR( 20), 
   @nQTY          INT,           
   @cLottable01   NVARCHAR( 18), 
   @cLottable02   NVARCHAR( 18), 
   @cLottable03   NVARCHAR( 18), 
   @dLottable04   DATETIME,      
   @dLottable05   DATETIME,      
   @cLottable06   NVARCHAR( 30), 
   @cLottable07   NVARCHAR( 30), 
   @cLottable08   NVARCHAR( 30), 
   @cLottable09   NVARCHAR( 30), 
   @cLottable10   NVARCHAR( 30), 
   @cLottable11   NVARCHAR( 30), 
   @cLottable12   NVARCHAR( 30), 
   @dLottable13   DATETIME,      
   @dLottable14   DATETIME,      
   @dLottable15   DATETIME, 
   @cRDLineNo     NVARCHAR( 5), 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cRecType    NVARCHAR(10) 
   DECLARE @cExtRecKey  NVARCHAR(20)
   DECLARE @cUDF02      NVARCHAR(60)
   DECLARE @cUDF03      NVARCHAR(60)    
   
   DECLARE @bSuccess    INT
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT

   IF @nFunc = 608 -- Piece return
   BEGIN  
   	IF (@nStep = 2 AND @nInputKey = 1 AND @cMethod = '1')
   	BEGIN
   		UPDATE rdt.rdtmobrec WITH (ROWLOCK) SET
   		   V_loc = @cLOC
   		WHERE Mobile = @nMobile
   		
   	END
   	
      IF (@nStep = 4 AND @nInputKey = 1 AND @cMethod = '1') OR  -- lottable before method, received at SKU QTY screen 
         (@nStep = 5 AND @nInputKey = 1 AND @cMethod = '2')     -- lottable after  method, received at POST lottable screen
      BEGIN
         /*
            User turn on OverReceiptToMatchLine (it only match ID and lottables) to avoid initial split line due to 
            default ToLOC (interface/populate) is different from actual ToLOC 
         */         
         --IF EXISTS( SELECT 1 FROM ReceiptDetail WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND ReceiptLineNumber = @cRDLineNo)
         --BEGIN
         --   BEGIN TRAN  -- Begin our own transaction
         --   SAVE TRAN rdt_608ExtUpd12 -- For rollback or commit only our own transaction
            
         --   SELECT @cRecType = Rectype, @cExtRecKey = ExternReceiptKey FROM Receipt WITH (NOLOCK) WHERE storerKey = @cStorerKey AND ReceiptKey = @cReceiptKey
         --   SELECT @cUDF03 = UDF03 FROM  Codelkup WITH(nolock) WHERE Listname='RecType' AND Storerkey=@cStorerKey AND Code= @cRecType
         --   SELECT @cUDF02 = UDF02 FROM  Codelkup WITH(nolock) WHERE Listname='RTNLOC2L10' AND Storerkey=@cStorerKey AND Code= @cLOC 
            
         --   IF @cUDF03 = ''
         --   BEGIN
         --   	SET @cUDF03 = @cRecType
         --   END
            
         --   UPDATE ReceiptDetail SET
         --      ToLOC = @cLOC
         --      ,Lottable09 = @cExtRecKey
         --      ,Lottable11 = @cUDF03
         --      ,Lottable12 = @cUDF02
         --   WHERE ReceiptKey = @cReceiptKey
         --      AND ReceiptLineNumber = @cRDLineNo
         --   SET @nErrNo = @@ERROR
         --   IF @nErrNo <> 0
         --   BEGIN
         --      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         --      GOTO RollBackTran
         --   END
            
         --   COMMIT TRAN rdt_608ExtUpd12 -- Only commit change made here
         --END
         
         IF EXISTS( SELECT 1 FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey AND ASNStatus = 'RCVD' AND StorerKey = @cStorerKey)
         BEGIN
         	Update Receipt SET 
         	   ASNStatus='1'
         	Where Receiptkey=@cReceiptkey 
         	AND ASNStatus='RCVD'
         	AND StorerKey = @cStorerKey
         END
      END
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_608ExtUpd12 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

SET QUOTED_IDENTIFIER OFF

GO