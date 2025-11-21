SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_607ExtUpd02                                           */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: print label                                                       */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 12-Dec-2017  ChewKP    1.0   WMS-3597 Created                              */
/* 15-Mar-2020  SPChin    1.1   INC1076149 - Enable Display Error Message     */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_607ExtUpd02]
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
   @cRefNo        NVARCHAR( 20), 
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
   @cReasonCode   NVARCHAR( 5), 
   @cSuggID       NVARCHAR( 18), 
   @cSuggLOC      NVARCHAR( 10), 
   @cID           NVARCHAR( 18), 
   @cLOC          NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 5), 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @bSuccess INT
   DECLARE @nTranCount INT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN                 --INC1076149
   SAVE TRAN rdt_607ExtUpd02  --INC1076149
   
   DECLARE @cPrinter NVARCHAR(10)
   SELECT @cPrinter = Printer FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile 
         
         
   IF @nFunc = 607 -- Return V7
   BEGIN  
      IF @nStep = 5 -- ID, LOC
      BEGIN
         
         /*-------------------------------------------------------------------------------
         
                                             Print label
      
         -------------------------------------------------------------------------------*/
         -- Get login info
         
         -- Check printer
         IF @cPrinter = ''
         BEGIN
            SET @nErrNo = 118001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLoginPrinter
            GOTO RollBackTran
         END
         
         
         DECLARE @tOutBoundList AS VariableTable
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cReceiptKey', @cReceiptKey)
         INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cID',  @cID)
         
         IF NOT EXISTS( SELECT 1 FROM rdt.rdtPrintJob WITH (NOLOCK) WHERE ReportID = 'IDLABEL' AND Parm1 = @cReceiptKey AND Parm2 = @cID)
         BEGIN
            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinter, '', 
               'IDLABEL', -- Report type
               @tOutBoundList, -- Report params
               'rdt_607ExtUpd02', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT
               
            IF @nErrNo <> 0
               GOTO RollBackTran
         END
         
      END
   END
   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_607ExtUpd02 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

SET QUOTED_IDENTIFIER OFF

GO