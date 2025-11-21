SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_573ExtInfo01                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Display total scanned UCC on pallet                         */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2021-11-11 1.0  James       WMS-18362. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_573ExtInfo01] (
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

   DECLARE @nScanUCC    INT

   IF @nStep IN ( 3, 4) 
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT @nScanUCC = COUNT( DISTINCT IsNull( RTRIM(RD.UserDefine01), ''))
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey         
         WHERE CR.Mobile = @nMobile
         AND   RD.BeforeReceivedQty > 0 -- Received
         AND   RD.ToId = @cID

         SET @cExtendedInfo = 'UCC Scanned: ' + CAST( @nScanUCC AS NVARCHAR( 5)) 
      END
   END
   
Quit:

END

GO