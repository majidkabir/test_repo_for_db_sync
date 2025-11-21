SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600ExtUpd02                                           */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 19-Apr-2015  Ung       1.0   SOS335126 Created                             */
/******************************************************************************/

CREATE PROC [RDT].[rdt_600ExtUpd02] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5), 
   @cStorerKey   NVARCHAR( 15), 
   @cReceiptKey  NVARCHAR( 10), 
   @cPOKey       NVARCHAR( 10), 
   @cLOC         NVARCHAR( 10), 
   @cID          NVARCHAR( 18), 
   @cSKU         NVARCHAR( 20), 
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
   @nQTY         INT,           
   @cReasonCode  NVARCHAR( 10), 
   @cSuggToLOC   NVARCHAR( 10), 
   @cFinalLOC    NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 10), 
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 12 -- Putaway
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cFinalLOC <> ''
            BEGIN
               -- Update ReceiptDetail
               IF EXISTS( SELECT 1 
                  FROM ReceiptDetail WITH (NOLOCK) 
                  WHERE ReceiptKey = @cReceiptKey 
                     AND ReceiptLineNumber = @cReceiptLineNumber
                     AND PutawayLOC <> @cFinalLOC)
               BEGIN
                  UPDATE ReceiptDetail SET
                     PutawayLOC = @cFinalLOC, 
                     EditDate = GETDATE(), 
                     EditWho = SUSER_SNAME(), 
                     TrafficCop = NULL
                  WHERE ReceiptKey = @cReceiptKey
                     AND ReceiptLineNumber = @cReceiptLineNumber
               END            

               -- Get printer
               DECLARE @cPrinter NVARCHAR( 10)
               SELECT @cPrinter = Printer FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()

               IF @cPrinter <> ''
               BEGIN
                  -- Get report info
                  DECLARE @cDataWindow NVARCHAR(50)
                  DECLARE @cTargetDB   NVARCHAR(10)
                  SELECT
                     @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
                     @cTargetDB = ISNULL(RTRIM(TargetDB), '')
                  FROM RDT.RDTReport WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                     AND ReportType ='SKULABEL'
                  
                  -- Print SKU label
                  EXEC RDT.rdt_BuiltPrintJob  
                     @nMobile,  
                     @cStorerKey,  
                     'SKULABEL',       -- ReportType  
                     'PRINT_SKULABEL', -- PrintJobName  
                     @cDataWindow,  
                     @cPrinter,  
                     @cTargetDB,  
                     @cLangCode,  
                     @nErrNo  OUTPUT,  
                     @cErrMsg OUTPUT,  
                     @cReceiptKey,  
                     @cReceiptLineNumber,  
                     @nQTY  
               END
            END
         END
      END
   END
END

GO