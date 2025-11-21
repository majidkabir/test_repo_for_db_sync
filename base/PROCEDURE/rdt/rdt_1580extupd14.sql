SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1580ExtUpd14                                          */
/* Copyright      : LF logistics                                              */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 14-06-2022  1.0  Ung         WMS-19791 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580ExtUpd14]
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
   
   IF @nFunc = 1580 -- Piece receiving
   BEGIN
      IF @nStep = 1 -- ASN/PO
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cNotes NVARCHAR( MAX)
            SELECT @cNotes = ISNULL( Notes, '') FROM dbo.Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey
            
            IF @cNotes <> ''
            BEGIN
               DECLARE @cMsg1 NVARCHAR(20) 
               DECLARE @cMsg2 NVARCHAR(20)
               
               SET @cMsg1 = rdt.rdtFormatString( @cNotes, 1, 20)
               SET @cMsg2 = rdt.rdtFormatString( @cNotes, 21, 20)

               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @cMsg1, @cMsg2
            END
         END
      END
   END
END

GO