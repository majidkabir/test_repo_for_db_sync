SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_573ExtInfo02                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Display PTO ASN sorting code                                */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2022-11-23  1.0  James       WMS-21207 Created                       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_573ExtInfo02] (
   @nMobile           INT, 
   @nFunc             INT, 
   @cLangCode         NVARCHAR( 3), 
   @nStep             INT, 
   @nInputKey         INT, 
   @cFacility         NVARCHAR( 5), 
   @cStorerKey        NVARCHAR( 15), 
   @cLoc              NVARCHAR( 10), 
   @cID               NVARCHAR( 18), 
   @cUCC              NVARCHAR( 20), 
   @tExtInfoVar       VariableTable READONLY, 
   @cExtendedInfo     NVARCHAR( 20) OUTPUT  
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cXdockKey      NVARCHAR( 18)

   IF @nStep = 4 
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT TOP 1 @cXdockKey = RD.XdockKey
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey         
         WHERE CR.Mobile = @nMobile
         AND   RD.UserDefine01 = @cUCC
         AND   RD.BeforeReceivedQty > 0 -- Received
         AND   (( ISNULL( @cLoc, '') = '' AND RD.ToLoc = RD.ToLoc) OR ( ISNULL( @cLoc, '') <> '' AND RD.ToLoc = @cLoc))
         AND   (( ISNULL( @cID, '') = '' AND RD.ToId = RD.ToId) OR ( ISNULL( @cID, '') <> '' AND RD.ToId = @cID))
         ORDER BY 1
         
         SET @cExtendedInfo = @cXdockKey 
      END
   END
   
Quit:

END

GO