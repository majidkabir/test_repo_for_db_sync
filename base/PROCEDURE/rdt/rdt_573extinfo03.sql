SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_573ExtInfo03                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Display PTO ASN sorting code                                */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2023-05-16  1.0  yeekung     WMS-22203 Created                       */
/************************************************************************/

CREATE    PROC [RDT].[rdt_573ExtInfo03] (
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

   DECLARE @cSKUTempFlag      NVARCHAR( 18)
   DECLARE @cXdockKey      NVARCHAR( 18)
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

         --SELECT @cTotalUCC = COUNT( DISTINCT IsNull( RTRIM(RD.UserDefine01), ''))
         --FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         --JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
         --WHERE CR.Mobile = @nMobile
         
         SET @cExtendedInfo = 'ID/ScanUCC: ' + RIGHT(RTRIM(@cID),4) + '/' + @cScanUCC


         IF  @nStep IN (4) 
         BEGIN
            DECLARE @nMsgQErrNo INT,
                    @nMsgQErrMsg NVARCHAR(MAX)

			SET @cSKUTempFlag = ''
			SET @cXdockKey = ''

            SELECT TOP 1 @cSKUTempFlag = ISNULL(SKU.TemperatureFlag,'')
            FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
			JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey
            JOIN dbo.sku SKU (nolock) ON RD.SKU =SKU.SKU AND RD.Storerkey = SKU.Storerkey
            WHERE CR.Mobile = @nMobile AND RD.UserDefine01 = @cUCC
               AND SKU.Storerkey = @cStorerkey
			   AND SKU.TemperatureFlag <> ''

		    SELECT TOP 1 @cXdockKey = ISNULL(RD.XdockKey ,'')
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)  
            JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON RD.ReceiptKey = CR.ReceiptKey           
            WHERE CR.Mobile = @nMobile  
            AND   RD.UserDefine01 = @cUCC  
            AND   RD.BeforeReceivedQty > 0 -- Received  
            AND   (( ISNULL( @cLoc, '') = '' AND RD.ToLoc = RD.ToLoc) OR ( ISNULL( @cLoc, '') <> '' AND RD.ToLoc = @cLoc))  
            AND   (( ISNULL( @cID, '') = '' AND RD.ToId = RD.ToId) OR ( ISNULL( @cID, '') <> '' AND RD.ToId = @cID))  
            ORDER BY RD.XdockKey  

			IF @cSKUTempFlag <> '' OR @cXdockKey <> ''
				EXEC rdt.rdtInsertMsgQueue @nMobile, @nMsgQErrNo OUTPUT, @nMsgQErrMsg OUTPUT, @cXdockKey, @cSKUTempFlag

         END
      END
   END
   
Quit:

END


GO