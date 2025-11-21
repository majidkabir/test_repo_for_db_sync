SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtNIKECNPCRcvSKULBL                                */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Call from RDT piece receiving, SKULabelSP                   */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 30-07-2013  1.0  Ung         SOS273208. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdtNIKECNPCRcvSKULBL]
    @nMobile            INT
   ,@nFunc              INT
   ,@nStep              INT
   ,@cLangCode          NVARCHAR( 3)
   ,@cStorerKey         NVARCHAR( 15)
   ,@cDataWindow        NVARCHAR( 60)
   ,@cPrinter           NVARCHAR( 10)
   ,@cTargetDB          NVARCHAR( 20)
   ,@cReceiptKey        NVARCHAR( 10) 
   ,@cReceiptLineNumber NVARCHAR( 5) 
   ,@nQTY               INT
   ,@nErrNo             INT           OUTPUT 
   ,@cErrMsg            NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   -- Get Receipt info
   DECLARE @cProcessType NVARCHAR(1)
   SELECT @cProcessType = ProcessType
   FROM dbo.Receipt WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
   
   -- Get code lookup info
   DECLARE @cShort NVARCHAR(10)
   SELECT @cShort = Short
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'PROTYPE'
      AND Code = @cProcessType

/*   
   -- Get grade info
   DECLARE @cGrade NVARCHAR(1)
   SELECT @cGrade = LEFT( ToID, 1)
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey 
      AND ReceiptLineNumber = @cReceiptLineNumber
*/
   
   -- Print
   IF @cShort = 'Y' --AND @cGrade IN ('A', 'B')
   BEGIN
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
      GOTO Quit
   END
   
   IF @cShort = 'Y1' -- AND @cGrade IN ('A', 'B')
   BEGIN
      -- Get ToID
      DECLARE @cToID NVARCHAR( 18)
      SELECT @cToID = ToID 
      FROM ReceiptDetail WITH (NOLOCK) 
      WHERE ReceiptKey = @cReceiptKey 
         AND ReceiptLineNumber = @cReceiptLineNumber
      
      -- Check SKU printed
      IF NOT EXISTS( SELECT TOP 1 1 
         FROM rdt.rdtPrintJob WITH (NOLOCK) 
         WHERE ReportID = 'SKULABEL'
            AND Parm1 = @cReceiptKey 
            AND Parm2 IN (
               SELECT ReceiptLineNumber 
               FROM ReceiptDetail WITH (NOLOCK) 
               WHERE ReceiptKey = @cReceiptKey 
                  AND ToID = @cToID))
      BEGIN
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
Quit:
END

GO