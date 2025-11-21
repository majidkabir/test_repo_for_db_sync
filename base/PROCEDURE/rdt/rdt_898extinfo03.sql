SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_898ExtInfo03                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author  Purposes                                     */
/* 2022-09-08 1.0  yeekung WMS-20650 Created                            */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_898ExtInfo03]
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

   DECLARE @cStorerKey NVARCHAR(20)
   DECLARE @nTotalUCC INT

   IF @nFunc = 898 -- UCC receiving
   BEGIN
      IF @nAfterStep = 3 -- palletID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
          
            -- Get StorerKey
            SELECT @cStorerKey = StorerKey FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

            -- Get total UCC in ASN
               SELECT @nTotalUCC = COUNT( DISTINCT RD.UserDefine01)
               FROM ReceiptDetail RD
               WHERE RD.ReceiptKey = @cReceiptKey
                  AND RD.toid=@cToID
                  AND RD.storerkey = @cStorerKey
                  AND RD.BeforeReceivedQty > 0

            -- Output balance/total
            SET @cExtendedInfo = 'Scan UCC: ' +  CAST (@nTotalUCC AS NVARCHAR(5))
         END
      END
   END

Quit:

END

GO