SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580ExtUpd09                                          */
/* Copyright      : LF logistics                                              */
/*                                                                            */
/* Purpose: Print case label after scan toid. Only print for line             */
/*          not yet received                                                  */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 12-Jul-2018  1.1  James       WMS-5467 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtUpd09]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cReceiptKey  NVARCHAR( 10) 
   ,@cPOKey       NVARCHAR( 10) 
   ,@cExtASN      NVARCHAR( 20)
   ,@cToLOC       NVARCHAR( 10) 
   ,@cToID        NVARCHAR( 18) 
   ,@cLottable01  NVARCHAR( 18) 
   ,@cLottable02  NVARCHAR( 18) 
   ,@cLottable03  NVARCHAR( 18) 
   ,@dLottable04  DATETIME  
   ,@cSKU         NVARCHAR( 20) 
   ,@nQTY         INT
   ,@nAfterStep   INT
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cReceiptLineNumber NVARCHAR( 5)
          ,@cLabelPrinter      NVARCHAR( 10)
   
   
   IF @nFunc = 1580 -- Piece receiving
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF @nStep IN ( 3, 5) -- To ID, Qty
         BEGIN
            IF ISNULL( @cToID, '') = ''
               GOTO Quit

            --IF @nStep = 3
               SELECT TOP 1 @cReceiptLineNumber = ReceiptLineNumber
               FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   ReceiptKey = @cReceiptKey 
               AND   BeforeReceivedQty = 0 -- no split line, every scan 1 line received
               ORDER BY 1
            --ELSE
            --   SELECT TOP 1 @cReceiptLineNumber = ReceiptLineNumber
            --   FROM dbo.ReceiptDetail WITH (NOLOCK)
            --   WHERE StorerKey = @cStorerKey
            --   AND   ReceiptKey = @cReceiptKey 
            --   AND   ToLoc = @cToLOC
            --   AND   ToID = @cToID
            --   AND   Sku = @cSKU
            --   AND   BeforeReceivedQty > 0
            --   ORDER BY EditDate DESC
               
            IF @@ROWCOUNT > 0
            BEGIN
               SELECT @cLabelPrinter = Printer
               FROM rdt.RDTMOBREC WITH (NOLOCK)
               WHERE Mobile = @nMobile

               IF ISNULL( @cLabelPrinter, '') = ''
               BEGIN
                  SET @nErrNo = 126101
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Printer
                  GOTO Quit
               END

               -- Printing start
               DECLARE @tCASELABEL1 AS VariableTable
               INSERT INTO @tCASELABEL1 (Variable, Value) VALUES ( '@cReceiptKey',  @cReceiptKey)
               INSERT INTO @tCASELABEL1 (Variable, Value) VALUES ( '@cReceiptLineNumber',  @cReceiptLineNumber)

               SET @nErrNo = 0
               -- Print label
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
                  'CASELABEL1', -- Report type
                  @tCASELABEL1, -- Report params
                  'rdt_1580ExtUpd09', 
                  @nErrNo  OUTPUT,
                  @cErrMsg OUTPUT 

               IF @nErrNo <> 0
               BEGIN
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO Quit
               END
            END
         END
      END
   END
   GOTO Quit
   
Quit:

END

GO