SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_598RcvToloc01                                         */
/* Copyright      : Maersk WMS                                                */
/*                                                                            */
/* Purpose: To location for receiving                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 29-May-2024  NLT013    1.0   UWP-20190 Create. Original owner is Bruce     */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_598RcvToloc01]
   @nMobile                INT,
   @nFunc                  INT,
   @cLangCode              NVARCHAR( 3),
   @nStep                  INT,
   @nInputKey              INT,
   @cFacility              NVARCHAR(5),
   @cStorerKey             NVARCHAR( 15),
   @cRefNo                 NVARCHAR( 20),
   @cColumnName            NVARCHAR( 20),
   @cLOC                   NVARCHAR( 10),
   @cID                    NVARCHAR( 18),
   @cSKU                   NVARCHAR( 20),
   @nQTY                   INT,
   @cReceiptKey            NVARCHAR( 10),
   @cReceiptLineNumber     NVARCHAR( 10),
   @tDefaultToLOC          VARIABLETABLE READONLY,
   @cDefaultToLOC          NVARCHAR( 10)  OUTPUT,
   @nErrNo                 INT            OUTPUT,
   @cErrMsg                NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 598 -- Container receive
   BEGIN
      IF @nStep = 1
      BEGIN
         IF @nInputKey = 1
         BEGIN
            SELECT TOP 1 @cDefaultToLOC = RD.ToLoc
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
            INNER JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON (RD.ReceiptKey = CRL.ReceiptKey)
            WHERE CRL.Mobile = @nMobile
         END
      END
   END
END

GO