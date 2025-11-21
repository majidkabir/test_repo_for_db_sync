SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_IkeaEcomReturn_Confirm                             */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2023-07-21 1.0  James   WMS-22912. Created                              */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_IkeaEcomReturn_Confirm](
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cReceiptKey    NVARCHAR( 10),
   @cRefNo         NVARCHAR( 40),
   @cToLOC         NVARCHAR( 10),
   @cToID          NVARCHAR( 18),
   @cSKUCode       NVARCHAR( 20),
   @cSKUUOM        NVARCHAR( 10),
   @nSKUQTY        INT,
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
   @cConditionCode NVARCHAR( 10), 
   @cSubreasonCode NVARCHAR( 10),
   @nSkuDamage     INT, 
   @tConfirmVar    VARIABLETABLE READONLY,
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT, 
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
   
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cCurRcvRule    CURSOR
   DECLARE @curFinalizeASN CURSOR
   DECLARE @cSQL           NVARCHAR( MAX)    
   DECLARE @cSQLParam      NVARCHAR( MAX)    
   DECLARE @cCode          NVARCHAR( 30)
   DECLARE @cNotes         NVARCHAR( MAX)
   DECLARE @nTranCount     INT    
   DECLARE @nExists        INT = 0
   DECLARE @nTotalQTYExp   INT = 0
   DECLARE @nTotalQTYRcv   INT = 0
   DECLARE @bSuccess       INT = 0

   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN    
   SAVE TRAN rdt_IkeaEcomReturn_Confirm  

   --SET @cLottable02 = @cToID
   

   
   IF @nSKUQTY > 0
   BEGIN
      SELECT TOP 1 
         @cLottable01 = Lottable01,
         @cLottable03 = Lottable03,
         @dLottable04 = Lottable04,
         @cLottable06 = Lottable06,
         @cLottable07 = Lottable07,
         @cLottable08 = Lottable08,
         @cLottable09 = Lottable09,
         @cLottable10 = Lottable10,
         @cLottable12 = Lottable12,
         @dLottable13 = Lottable13,
         @dLottable14 = Lottable14,
         @dLottable15 = Lottable15,
         @cConditionCode = ConditionCode,
         @cSubreasonCode = SubreasonCode
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine02 = @cRefNo
      AND   Sku = @cSKUCode
      AND   Lottable11 = @cLottable11
      ORDER BY 1
   
      -- Receive
      EXEC rdt.rdt_Receive_V7
         @nFunc         = @nFunc,
         @nMobile       = @nMobile,
         @cLangCode     = @cLangCode,
         @nErrNo        = @nErrNo  OUTPUT,
         @cErrMsg       = @cErrMsg OUTPUT, 
         @cStorerKey    = @cStorerKey,
         @cFacility     = @cFacility,
         @cReceiptKey   = @cReceiptKey,
         @cPOKey        = 'NOPO',  
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
         @nNOPOFlag     = 1,
         @cConditionCode = @cConditionCode,
         @cSubreasonCode = @cSubreasonCode,
         @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT 
      IF @nErrNo <> 0
         GOTO RollBackTran

      IF @cReceiptLineNumber <> ''
      BEGIN
         UPDATE dbo.RECEIPTDETAIL SET 
            UserDefine01 = @cToID, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE()
         WHERE ReceiptKey = @cReceiptKey
         AND   ReceiptLineNumber = @cReceiptLineNumber	
      
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 204052
            SET @cErrMsg = RTRIM( @cCode) + rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UDF01 ERR
            GOTO RollBackTran
         END
      END
   END
   ELSE
   BEGIN
   	SELECT TOP 1 
   	   @cReceiptLineNumber = ReceiptLineNumber
   	FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   UserDefine02 = @cRefNo
      AND   Sku = @cSKUCode   
      AND   Lottable11 = @cLottable11
   	ORDER BY 1
   	
      IF @cReceiptLineNumber <> ''
      BEGIN
         UPDATE dbo.RECEIPTDETAIL SET 
            UserDefine01 = @cToID, 
            Lottable02 = @cToID,
            ToLOC = @cToLOC,
            ToID = @cToID, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE()
         WHERE ReceiptKey = @cReceiptKey
         AND   ReceiptLineNumber = @cReceiptLineNumber	
      
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 204053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD RCVDT ERR
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         SET @nErrNo = 204054
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ASN NOT FOUND
         GOTO RollBackTran
      END
   END

   -- Get statistic
   SELECT
      @nTotalQTYExp = ISNULL( SUM( QtyExpected), 0),
      @nTotalQTYRcv = ISNULL( SUM( BeforeReceivedQty), 0)
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey

   -- Already key in toid & toloc, receive and stay in sku screen
   IF @nTotalQTYExp = @nTotalQTYRcv
   BEGIN
   	-- Pre ASN finalize check
      SET @cSQL = ''
      SET @cSQLParam = ''

      SET @cCurRcvRule = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT Code, Notes
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = '2'
      ORDER BY Code
      OPEN @cCurRcvRule
      FETCH NEXT FROM @cCurRcvRule INTO @cCode, @cNotes
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @cSQL = 
            ' IF EXISTS ( SELECT 1 ' +
            ' FROM dbo.RECEIPTDETAIL RECEIPTDETAIL WITH (NOLOCK) ' +
            ' JOIN dbo.RECEIPT RECEIPT WITH (NOLOCK) ON ( RECEIPTDETAIL.ReceiptKey = RECEIPT.ReceiptKey)' +
            ' WHERE RECEIPT.StorerKey = @cStorerKey ' +
            ' AND   RECEIPT.ReceiptKey = @cReceiptKey ' +
            ' AND   RECEIPT.Facility = @cFacility ' +
            ' AND   RECEIPTDETAIL.UserDefine02 = @cRefNo '

         SET @cSQL = @cSQL + ' ' + @cNotes + ') '

         SET @cSQL = @cSQL + ' SET @nExists = 1 ' 
       
         SET @cSQLParam =     
            '@cReceiptKey     NVARCHAR( 10), ' +      
            '@cRefNo          NVARCHAR( 40), ' +      
            '@cStorerKey      NVARCHAR( 15), ' +
            '@cFacility       NVARCHAR( 5),  ' +
            '@nExists         INT OUTPUT ' 

    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,     
            @cReceiptKey = @cReceiptKey,      
            @cRefNo      = @cRefNo,      
            @cStorerKey  = @cStorerKey,
            @cFacility   = @cFacility,
            @nExists     = @nExists OUTPUT
         
         IF @nExists = 1
         BEGIN
            SET @nErrNo = 204051
            SET @cErrMsg = RTRIM( @cCode) + rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- CODE99999 ERROR
            GOTO RollBackTran
         END

         SET @cSQL = ''
         SET @cSQLParam = ''


         FETCH NEXT FROM @cCurRcvRule INTO @cCode, @cNotes	
      END
   
      -- Finalize ASN
      SET @curFinalizeASN = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT ReceiptLineNumber 
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      AND   FinalizeFlag <> 'Y'
      OPEN @curFinalizeASN
      FETCH NEXT FROM @curFinalizeASN INTO @cReceiptLineNumber
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @bSuccess = 0
         EXEC dbo.ispFinalizeReceipt
             @c_ReceiptKey        = @cReceiptKey
            ,@b_Success           = @bSuccess   OUTPUT
            ,@n_err               = @nErrNo     OUTPUT
            ,@c_ErrMsg            = @cErrMsg    OUTPUT
            ,@c_ReceiptLineNumber = @cReceiptLineNumber

         IF @nErrNo <> 0 OR @bSuccess = 0
         BEGIN
            -- Direct retrieve err msg from stored proc as some exceed stored prod
            -- do not have standard error no & msg
            IF ISNULL( @cErrMsg, '') = '' 
               SET @cErrMsg = CAST( @nErrNo AS NVARCHAR( 6)) + rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')

            GOTO RollBackTran
         END

         FETCH NEXT FROM @curFinalizeASN INTO @cReceiptLineNumber
      END
   END

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '2', -- Receiving
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerKey,
      @cReceiptKey   = @cReceiptKey,
      @cRefNo1       = @cRefNo,
      @cLocation     = @cToLOC,
      @cID           = @cToID,
      @cSKU          = @cSKUCode,
      @cUOM          = @cSKUUOM,
      @nQTY          = @nSKUQTY,
      @cLottable01   = @cLottable01,
      @cLottable02   = @cLottable02,
      @cLottable03   = @cLottable03,
      @dLottable04   = @dLottable04,
      @dLottable05   = @dLottable05,
      @cLottable06   = @cLottable06,
      @cLottable07   = @cLottable07,
      @cLottable08   = @cLottable08,
      @cLottable09   = @cLottable09,
      @cLottable10   = @cLottable10,
      @cLottable11   = @cLottable11,
      @cLottable12   = @cLottable12,
      @dLottable13   = @dLottable13,
      @dLottable14   = @dLottable14,
      @dLottable15   = @dLottable15

   GOTO QUIT           
          
RollBackTran:          
   ROLLBACK TRAN rdt_IkeaEcomReturn_Confirm -- Only rollback change made here          
Quit:          
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started          
      COMMIT TRAN 
END

GO