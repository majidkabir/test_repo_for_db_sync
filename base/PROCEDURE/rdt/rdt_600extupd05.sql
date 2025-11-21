SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600ExtUpd05                                           */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Print label                                                       */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 12-Apr-2017  ChewKP    1.0   WNS-1566 Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_600ExtUpd05] (
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
      IF @nStep = 6 -- QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cPrinter    NVARCHAR( 10)
            DECLARE @cUserName   NVARCHAR( 18)
            DECLARE @cDataWindow NVARCHAR( 50)
            DECLARE @cTargetDB   NVARCHAR( 20)

            SELECT @cPrinter = PRINTER 
            FROM rdt.rdtmobrec WITH (NOLOCK)
            WHERE Mobile = @nMobile 

            SELECT @cDataWindow = DataWindow,     
          					@cTargetDB = TargetDB     
			      FROM rdt.rdtReport WITH (NOLOCK)     
			      WHERE StorerKey = @cStorerKey    
			      AND   ReportType = 'CUSTOMLBL'   
			      
            
                       			      
	   			  EXEC RDT.rdt_BuiltPrintJob      
			                   @nMobile,      
			                   @cStorerKey,      
			                   'CUSTOMLBL',      -- ReportType      
			                   'CustomLabel',    -- PrintJobName      
			                   @cDataWindow,      
			                   @cPrinter,      
			                   @cTargetDB,      
			                   @cLangCode,      
			                   @nErrNo  OUTPUT,      
			                   @cErrMsg OUTPUT,    
			                   @cReceiptKey,   
			                   @cID
			                   
            
         END
      END
   END
END

GO