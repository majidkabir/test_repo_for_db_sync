SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_607ExcessStockToPO01                                  */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author   Ver.  Purposes                                        */
/* 16-08-2017  Ung      1.0   WMS-2369 Created                                */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_607ExcessStockToPO01]
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cStorerKey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cRefNo       NVARCHAR( 20), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,           
   @cLottable01  NVARCHAR( 18), 
   @cLottable02  NVARCHAR( 18), 
   @cLottable03  NVARCHAR( 18), 
   @dLottable04  DATETIME,      
   @dLottable05  DATETIME,      
   @cLottable06  NVARCHAR( 30), 
   @cLottable07  NVARCHAR( 30), 
   @cLottable08  NVARCHAR( 30), 
   @cLottable09  NVARCHAR( 30), 
   @cLottable10  NVARCHAR( 30), 
   @cLottable11  NVARCHAR( 30), 
   @cLottable12  NVARCHAR( 30), 
   @dLottable13  DATETIME,      
   @dLottable14  DATETIME,      
   @dLottable15  DATETIME, 
   @cReasonCode  NVARCHAR( 10), 
   @cID          NVARCHAR( 18), 
   @cLOC         NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 10), 
   @cType        NVARCHAR( 10), 
   @nExcessQTY   INT            OUTPUT, 
   @nActQTY      INT            OUTPUT,
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Handling transaction
   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_607ExcessStockToPO01 -- For rollback or commit only our own transaction

   IF @nFunc = 607 -- Return v7
   BEGIN
      IF @cType = 'CALCULATE'
      BEGIN
         DECLARE @nQTYExpected INT
         DECLARE @nBeforeReceivedQTY INT
   
         -- Get ReceiptDetail info
         SELECT 
            @nQTYExpected = ISNULL( SUM( QTYExpected), 0), 
            @nBeforeReceivedQTY = ISNULL( SUM( BeforeReceivedQTY), 0) 
         FROM ReceiptDetail WITH (NOLOCK) 
         WHERE ReceiptKey = @cReceiptKey 
            AND SKU = @cSKU
         
         -- Calc excess stock
         IF @nQTYExpected < (@nBeforeReceivedQTY + @nQTY)
         BEGIN
            IF @nQTYExpected > @nBeforeReceivedQTY
               SET @nActQTY = @nQTYExpected - @nBeforeReceivedQTY
            ELSE
               SET @nActQTY = 0
            
            SET @nExcessQTY = @nQTY - @nActQTY
         END
         ELSE
         BEGIN 
            SET @nActQTY = @nQTY
            SET @nExcessQTY = 0
         END
      END
      
      ELSE 
      BEGIN
         -- Get the excess PO
         DECLARE @cExcessPOKey NVARCHAR(10)
         SET @cExcessPOKey = ''
         SELECT TOP 1 @cExcessPOKey = POKey FROM PO WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND POGroup = @cReceiptKey
         
         -- Insert excess PO
         IF @cType = 'POHEADER'
         BEGIN
            IF @cExcessPOKey = ''
            BEGIN
               -- Get new TaskDetailKeys    
               DECLARE @bSuccess INT
            	SET @bSuccess = 1
            	EXECUTE dbo.nspg_getkey
            		'PO'
            		, 10
            		, @cExcessPOKey OUTPUT
            		, @bSuccess     OUTPUT
            		, @nErrNo       OUTPUT
            		, @cErrMsg      OUTPUT
               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 113401
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
                  GOTO Quit
               END
               
               -- Insert excess PO
               INSERT INTO PO (POKey, ExternPOKey, StorerKey, PODate, OtherReference, Status, POType, SellerName, POGroup, Userdefine01, SellerCompany, SellerAddress1)
               SELECT @cExcessPOKey, ExternReceiptKey, @cStorerKey, ReceiptDate, WarehouseReference, '0', 'P', Carrierkey, Receiptkey, Signatory, CarrierName, CarrierAddress1
               FROM Receipt WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 113402
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PO Fail
                  GOTO RollbackTran
               END
            END
         END
         
         -- Insert or update exceed PODetail
         IF @cType = 'PODETAIL'
         BEGIN
            -- Lookup PODetail
            DECLARE @cPOLineNumber NVARCHAR(5)
            SET @cPOLineNumber = ''
            SELECT @cPOLineNumber = POLineNumber 
            FROM PODetail WITH (NOLOCK) 
            WHERE POKey = @cExcessPOKey
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU
               AND ToID = @cID
               AND Lottable01 = @cLottable01
               AND Lottable02 = @cLottable02
               AND Lottable03 = @cLottable03
               AND Lottable04 = @dLottable04
               -- AND Lottable05 = @dLottable05
               AND Lottable06 = @cLottable06
               AND Lottable07 = @cLottable07
               AND Lottable08 = @cLottable08
               AND Lottable09 = @cLottable09
               AND Lottable10 = @cLottable10
               AND Lottable11 = @cLottable11
               AND Lottable12 = @cLottable12
               AND Lottable13 = @dLottable13
               AND Lottable14 = @dLottable14
               AND Lottable15 = @dLottable15
            
            IF @cPOLineNumber = ''
            BEGIN
               -- Get SKU info
               DECLARE @cPackKey NVARCHAR(10)
               DECLARE @cPackUOM3 NVARCHAR(10)
               SELECT
                  @cPackKey = SKU.PackKey, 
                  @cPackUOM3 = Pack.PackUOM3
               FROM dbo.SKU SKU (NOLOCK)
                  JOIN dbo.Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
               WHERE SKU.StorerKey = @cStorerKey
                  AND SKU.SKU = @cSKU
               
               -- Get new POLineNumber
               SELECT @cPOLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( POLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
               FROM PODetail (NOLOCK)
               WHERE POKey = @cExcessPOKey
   
               DECLARE @cExternReceiptKey NVARCHAR(20)
               DECLARE @cFacility NVARCHAR( 5)
               SELECT 
                  @cFacility = Facility, 
                  @cExternReceiptKey = ExternReceiptKey
               FROM Receipt WITH (NOLOCK) 
               WHERE ReceiptKey = @cReceiptKey
   
               -- Insert excess PO
               INSERT INTO PODetail (POKey, POLineNumber, ExternPOKey, StorerKey, SKU, QTYOrdered, UOM, PackKey, Facility, ToID,
                  Lottable01, Lottable02, Lottable03, Lottable04, --Lottable05, 
                  Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                  Lottable11, Lottable12, Lottable13, Lottable14, Lottable15)
               VALUES( @cExcessPOKey, @cPOLineNumber, @cExternReceiptKey, @cStorerKey, @cSKU, @nExcessQTY, @cPackUOM3, @cPackKey, @cFacility, @cID, 
                  @cLottable01, @cLottable02, @cLottable03, @dLottable04, --@dLottable05, 
                  @cLottable06, @cLottable07, @cLottable08, @cLottable09, @cLottable10, 
                  @cLottable11, @cLottable12, @dLottable13, @dLottable14, @dLottable15)
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 113403
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PODtl Fail
                  GOTO RollbackTran
               END
            END
            ELSE
            BEGIN
               UPDATE PODetail SET 
                  QtyOrdered = QtyOrdered + @nExcessQTY
               WHERE POKey = @cExcessPOKey
                  AND POLineNumber = @cPOLineNumber 
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 113404
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PODtl Fail
                  GOTO RollbackTran
               END
            END
         END
      END
   END
   GOTO Quit
   
RollbackTran:
   ROLLBACK TRAN rdt_607ExcessStockToPO01
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO