SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_898ExtInfo01                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2015-08-28 1.0  Ung     SOS345120 Created                            */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898ExtInfo01]
    @nMobile       INT
   ,@nFunc         INT
   ,@cLangCode     NVARCHAR( 3)
   ,@nStep         INT
   ,@nAfterStep    INT
   ,@nInputKey     INT
   ,@cReceiptKey   NVARCHAR( 10)
   ,@cPOKey        NVARCHAR( 10)
   ,@cLOC          NVARCHAR( 10)
   ,@cToID         NVARCHAR( 18)
   ,@cLottable01   NVARCHAR( 18)
   ,@cLottable02   NVARCHAR( 18)
   ,@cLottable03   NVARCHAR( 18)
   ,@dLottable04   DATETIME
   ,@cUCC          NVARCHAR( 20)
   ,@cSKU          NVARCHAR( 20)
   ,@nQTY          INT
   ,@cParam1       NVARCHAR( 20) 
   ,@cParam2       NVARCHAR( 20) 
   ,@cParam3       NVARCHAR( 20) 
   ,@cParam4       NVARCHAR( 20) 
   ,@cParam5       NVARCHAR( 20) 
   ,@cOption       NVARCHAR( 1)
   ,@cExtendedInfo NVARCHAR( 20) OUTPUT
   ,@nErrNo       INT            OUTPUT
   ,@cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nFunc = 898 -- UCC receiving
   BEGIN
      IF @nAfterStep = 6 -- UCC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @nTotalUCC INT
            DECLARE @nBalUCC   INT
            
            -- Get total UCC in ASN
            SELECT @nTotalUCC = COUNT( DISTINCT UCCNo)
            FROM UCC WITH (NOLOCK) 
               JOIN ReceiptDetail RD WITH (NOLOCK) ON (RD.POKey + RD.POLineNumber = UCC.SourceKey)
            WHERE RD.ReceiptKey = @cReceiptKey

            -- Get UCC not yet received in ASN
            SELECT @nBalUCC = COUNT( DISTINCT UCCNo)
            FROM UCC WITH (NOLOCK) 
               JOIN ReceiptDetail RD WITH (NOLOCK) ON (RD.POKey + RD.POLineNumber = UCC.SourceKey)
            WHERE RD.ReceiptKey = @cReceiptKey
               AND UCC.Status = '0' 
            
            -- Output balance/total
            SET @cExtendedInfo = 'BAL/TTL: ' + CAST( @nBalUCC AS NVARCHAR( 5)) + '/' + CAST( @nTotalUCC AS NVARCHAR( 5))
         END
      END
   END
   
Quit:

END

GO