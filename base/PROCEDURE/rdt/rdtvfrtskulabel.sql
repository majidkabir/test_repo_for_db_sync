SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdtVFRTSKULabel                                        */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2013-09-03 1.0  Ung      SOS288143 Created                              */
/***************************************************************************/

CREATE PROC [RDT].[rdtVFRTSKULabel] (
   @nMobile            INT,
   @nFunc              INT,
   @nStep              INT,
   @cLangCode          NVARCHAR( 3),
   @cStorerKey         NVARCHAR( 15),
   @cDataWindow        NVARCHAR( 60),
   @cPrinter           NVARCHAR( 10),
   @cTargetDB          NVARCHAR( 20),
   @cReceiptKey        NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR(  5),
   @nQTY               INT,
   @nErrNo             INT           OUTPUT,
   @cErrMsg            NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @b_Success INT

   DECLARE @cRecType  NVARCHAR( 10)
   DECLARE @cDocType  NVARCHAR( 1)
   DECLARE @cShort    NVARCHAR( 10)
   DECLARE @cToLOC    NVARCHAR( 10)

   -- Get Receipt info
   SELECT
      @cDocType = DocType,
      @cRecType = RecType
   FROM dbo.Receipt WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey

   -- Get ReceiptDetail info
   SELECT
      @cToLOC = ToLOC
   FROM dbo.ReceiptDetail WITH (NOLOCK)
   WHERE ReceiptKey = @cReceiptKey
      AND ReceiptLineNumber = @cReceiptLineNumber

   -- Get code lookup info
   SELECT @cShort = Short
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'RECTYPE'
      AND Code = @cRecType
      AND StorerKey = @cStorerKey

   IF @cDocType = 'R' AND @cShort = 'R' AND @cToLOC = 'VFRTSTG'
      -- Insert print job
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
Quit:


GO