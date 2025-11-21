SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608ExtUpd11                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Finalize ASN by line                                              */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2020-12-09   James     1.0   WMS-15825 Created                             */
/* 2022-09-08   Ung       1.1   WMS-20348 Expand RefNo to 60 chars            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608ExtUpd11]
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

   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT
   DECLARE @cRDLineNumber  NVARCHAR( 5)


   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_608ExtUpd11 -- For rollback or commit only our own transaction

   IF @nFunc = 608 -- Piece return
   BEGIN  
      IF @nStep = 2 -- ID, LOC
      BEGIN
         IF @nInputKey = 0 -- ESC
         BEGIN
            -- Check variance
            IF NOT EXISTS( SELECT 1 
               FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               AND   QTYExpected <> BeforeReceivedQTY)
            BEGIN
               -- Finalize ASN by line if no more variance
               DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
               SELECT ReceiptLineNumber 
               FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               AND   QTYExpected = BeforeReceivedQTY
               AND   FinalizeFlag <> 'Y'
               OPEN CUR_UPD
               FETCH NEXT FROM CUR_UPD INTO @cRDLineNumber
               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SET @bSuccess = 0
                  EXEC dbo.ispFinalizeReceipt
                      @c_ReceiptKey        = @cReceiptKey
                     ,@b_Success           = @bSuccess   OUTPUT
                     ,@n_err               = @nErrNo     OUTPUT
                     ,@c_ErrMsg            = @cErrMsg    OUTPUT
                     ,@c_ReceiptLineNumber = @cRDLineNumber

                  IF @nErrNo <> 0 OR @bSuccess = 0
                  BEGIN
                     -- Direct retrieve err msg from stored proc as some exceed stored prod
                     -- do not have standard error no & msg
                     IF ISNULL( @cErrMsg, '') = '' -- (james01)
                        SET @cErrMsg = CAST( @nErrNo AS NVARCHAR( 6)) + rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                     CLOSE CUR_UPD
                     DEALLOCATE CUR_UPD
                     GOTO RollBackTran
                  END

                  FETCH NEXT FROM CUR_UPD INTO @cRDLineNumber
               END
               CLOSE CUR_UPD
               DEALLOCATE CUR_UPD

               -- Mark ASN fully received
               UPDATE Receipt SET
                  RoutingTool = 'FULLY',
                  ASNStatus = '9'
               WHERE ReceiptKey = @cReceiptKey
               
               IF @@ERROR <> 0
               BEGIN
               	SET @nErrNo = 161251
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Mix Order Type
                  GOTO RollBackTran
               END
            END
         END
      END

      IF @nStep = 4 -- SKU, QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get storer configure
            DECLARE @cSKULabel NVARCHAR(10)
            SET @cSKULabel = rdt.RDTGetConfig( @nFunc, 'SKULabel', @cStorerKey) 
            IF @cSKULabel = '0'
               SET @cSKULabel = ''
            
            -- SKU label
            IF @cSKULabel <> '' 
            BEGIN
               DECLARE @cLabelPrinter NVARCHAR(10) 
               DECLARE @cPaperPrinter NVARCHAR(10)
               DECLARE @cPickLOC      NVARCHAR(10)
               
               -- Get session info
               SELECT 
                  @cLabelPrinter = Printer, 
                  @cPaperPrinter = Printer_Paper
               FROM rdt.rdtMobRec WITH (NOLOCK)
               WHERE Mobile = @nMobile
               
               -- Get assigned pick LOC
               SET @cPickLOC = ''
               SELECT TOP 1 
                  @cPickLOC = LOC
               FROM SKUxLOC WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND SKU = @cSKU
                  AND LocationType = 'PICK'
               
               -- Get pick LOC
               IF @cPickLOC = ''
                  SELECT TOP 1 
                     @cPickLOC = LOC.LOC
                  FROM LOTxLOCxID LLI WITH (NOLOCK)
                     JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                  WHERE LOC.LocationType = 'PICK' 
                     AND StorerKey = @cStorerKey
                     AND SKU = @cSKU
                     AND LLI.QTY > 0 
               
               -- SKU label
               IF @cPickLOC <> ''
               BEGIN
                  -- Common params
                  DECLARE @tSKULabel AS VariableTable
                  INSERT INTO @tSKULabel (Variable, Value) VALUES 
                     ( '@cSKU', @cSKU), 
                     ( '@cPickLOC', @cPickLOC)

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter, 
                     @cSKULabel, -- Report type
                     @tSKULabel, -- Report params
                     'rdt_608ExtUpd11', 
                     @nErrNo  OUTPUT,
                     @cErrMsg OUTPUT
                  IF @nErrNo <> 0
                     GOTO RollBackTran
               END
            END
         END
		END      
   END

   GOTO Quit

   RollBackTran:  
      ROLLBACK TRAN rdt_608ExtUpd11 
   Fail:  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN


END

SET QUOTED_IDENTIFIER OFF

GO