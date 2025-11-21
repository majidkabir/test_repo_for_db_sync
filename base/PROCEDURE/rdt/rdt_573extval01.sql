SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_573ExtVal01                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Display SCAN/TOTAL:  UCC ON ID/UCC ON ASN                   */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2020-03-03 1.0  James       WMS-12334. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_573ExtVal01] (
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

   DECLARE @cScanUCC    NVARCHAR( 5)
   DECLARE @cTotalUCC   NVARCHAR( 5)
   

   IF @nStep IN ( 3, 4) 
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT @cScanUCC = COUNT( DISTINCT IsNull( RTRIM(RD.UserDefine01), ''))
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey         
         WHERE CR.Mobile = @nMobile
         AND   RD.BeforeReceivedQty > 0 -- Received
         AND   RD.ToId = @cID

         SELECT @cTotalUCC = COUNT( DISTINCT IsNull( RTRIM(RD.UserDefine01), ''))
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
         WHERE CR.Mobile = @nMobile
         
         SET @cExtendedInfo = 'ID/TOTAL: ' + RTRIM( @cScanUCC) + '/' + @cTotalUCC
      END
   END
   
Quit:

END

GO