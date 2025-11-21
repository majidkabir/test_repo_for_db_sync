SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_608RcvCfm07                                        */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Purpose: Stamp userdefine01 = 'NORMAL' if newly added line              */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2019-08-13 1.0  James   WMS-10122 Created                               */
/* 2020-01-06 1.1  James   WMS-11627 Copy L07 to UDF03 (james01)           */
/* 2021-02-25 1.2  Ung     INC1423399 Change map V_DropID to V_SerialNo    */
/***************************************************************************/

CREATE PROC [RDT].[rdt_608RcvCfm07](
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
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Handling transaction
   DECLARE @nTranCount        INT
   DECLARE @nNewSKU           INT = 0
   DECLARE @cSerialNo         NVARCHAR( 30)
   DECLARE @nSerialQTY        INT
   DECLARE @nBulkSNO          INT = 0
   DECLARE @nBulkSNOQTY       INT = 0

   -- This storer not all sku has serial no to scan, even same sku some does not have serialno
   -- So need to turn off serialnocapture and manually insert here
   SELECT @cSerialNo = V_SerialNo
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   SET @nSerialQTY = @nSKUQTY

   IF ISNULL( @cSerialNo, '') <> ''
   BEGIN
      UPDATE RDT.RDTMOBREC SET V_SerialNo = ''
      WHERE Mobile = @nMobile

      IF NOT EXISTS ( SELECT 1 FROM dbo.SerialNo WITH (NOLOCK)
                      WHERE SerialNo = @cSerialNo
                      AND   StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 142901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SerialNo NotExists
         GOTO RollBackTran
      END
   END

   IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK) 
                   WHERE ReceiptKey = @cReceiptKey 
                   AND   SKU = @cSKUCode)
      SET @nNewSKU = 1

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_608RcvCfm07 -- For rollback or commit only our own transaction

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
      @cReceiptLineNumberOutput = @cRDLineNo OUTPUT,
      @cSerialNo      = @cSerialNo, 
      @nSerialQTY     = @nSerialQTY, 
      @nBulkSNO       = @nBulkSNO, 
      @nBulkSNOQTY    = @nBulkSNOQTY

   IF @nErrNo <> 0
      GOTO RollBackTran

   DECLARE @cDuplicateFrom       NVARCHAR( 5)
   DECLARE @cUserDefine01        NVARCHAR( 30)
   DECLARE @cExternLineNo        NVARCHAR( 20)
   DECLARE @nQtyExpected         INT
   DECLARE @nBeforeReceivedQty   INT
   
   SELECT @cDuplicateFrom = DuplicateFrom,
          @cExternLineNo = ExternLineNo
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   AND   ReceiptLineNumber = @cRDLineNo

   SELECT @cUserDefine01 = UserDefine01
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   AND   ReceiptLineNumber = @cDuplicateFrom
         
   SELECT @nQtyExpected = ISNULL( SUM( QtyExpected), 0),
          @nBeforeReceivedQty = ISNULL( SUM( BeforeReceivedQty), 0)
   FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   AND   SKU = @cSKUCode
   --IF EXISTS ( SELECT 1 FROM dbo.ReceiptDetail WITH (NOLOCK)
   --            WHERE ReceiptKey = @cReceiptKey
   --            AND   ReceiptLineNumber = @cRDLineNo
   --            AND   ((ISNULL( DuplicateFrom, '') <> '') OR 
   --                  ((ISNULL( DuplicateFrom, '') = '') AND ( QtyExpected = 0))))                
   --            OR @nNewSKU = 1
   IF ISNULL( @cDuplicateFrom, '') <> '' OR 
    ( ISNULL( @cDuplicateFrom, '') = '' AND ISNULL( @cExternLineNo, '') = '')
   BEGIN
      -- If new sku in asn or over receive then need stamp NORMAL to udf01
      IF @nNewSKU = 1 OR ( @nBeforeReceivedQty > @nQtyExpected)
      BEGIN
         UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET 
            UserDefine01 = 'NORMAL',
            UserDefine03 = @cLottable12,  
            EditWho = 'rdt.' + sUser_sName(),  
            EditDate = GETDATE()  
         WHERE ReceiptKey = @cReceiptKey
         AND   ReceiptLineNumber = @cRDLineNo

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 142902
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd UDF01 Fail
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         UPDATE dbo.ReceiptDetail WITH (ROWLOCK) SET 
            UserDefine01 = @cUserDefine01,
            UserDefine03 = @cLottable12,  
            EditWho = 'rdt.' + sUser_sName(),  
            EditDate = GETDATE()  
         WHERE ReceiptKey = @cReceiptKey
         AND   ReceiptLineNumber = @cRDLineNo

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 142903
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd UDF01 Fail
            GOTO RollBackTran
         END
      END
      
   END

   GOTO Quit

RollBackTran:  
   ROLLBACK TRAN rdt_608RcvCfm07 
Fail:  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN


END

GO