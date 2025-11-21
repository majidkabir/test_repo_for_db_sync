SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_606ExtInfo02                                          */
/* Purpose: Display carrier address                                           */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2018-02-05  1.0  James    WMS3885. Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_606ExtInfo02] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nAfterStep    INT, 
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cRefNo        NVARCHAR( 20),
   @nQTY          INT,
   @cID           NVARCHAR( 18),
   @cExtendedInfo NVARCHAR(20)  OUTPUT, 
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS

BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cCarrierAddress1  NVARCHAR( 45)

   IF @nFunc = 606 -- Return registration
   BEGIN
      IF @nAfterStep = 1 -- ASN
      BEGIN
         IF @cReceiptKey <> ''
         BEGIN
            SELECT @cCarrierAddress1 = CarrierAddress1
            FROM dbo.Receipt WITH (NOLOCK) 
            WHERE ReceiptKey = @cReceiptKey

            SET @cExtendedInfo = SUBSTRING( @cCarrierAddress1, 1, 20)
         END
      END
   END
END


Quit:



GO