SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_573ExtValidSP02                                 */  
/* Purpose: Validate  UCC                                               */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2019-06-25 1.0  James      WMS-9427 Created                          */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_573ExtValidSP02] (  
   @nMobile     INT, 
   @nFunc       INT, 
   @cLangCode   NVARCHAR(3), 
   @nStep       INT, 
   @cStorerKey  NVARCHAR(15),
   @cFacility   NVARCHAR(5), 
   @cReceiptKey1 NVARCHAR(20),          
   @cReceiptKey2 NVARCHAR(20),          
   @cReceiptKey3 NVARCHAR(20),          
   @cReceiptKey4 NVARCHAR(20),          
   @cReceiptKey5 NVARCHAR(20),          
   @cLoc        NVARCHAR(20),           
   @cID         NVARCHAR(18),           
   @cUCC        NVARCHAR(20),           
   @nErrNo      INT  OUTPUT,            
   @cErrMsg     NVARCHAR(1024) OUTPUT
)  
AS  
  
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   
   DECLARE @nInputKey  INT 
   DECLARE @cID_ReceiptKey    NVARCHAR( 10)
   DECLARE @cUCC_ReceiptKey   NVARCHAR( 10)
   DECLARE @cErrMsg01         NVARCHAR( 20)
    
   SET @nErrNo          = 0
   SET @cErrMSG         = ''

   SELECT @nInputKey = InputKey  
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep = '4'
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF EXISTS ( SELECT 1 
                     FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                     JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON ( RD.ReceiptKey = CRL.ReceiptKey)
                     WHERE RD.Userdefine01 = @cUCC
                     AND   RD.Lottable02 IN ( 'PNP', 'ZPPK')
                     AND   CRL.Mobile = @nMobile
                     GROUP BY SKU
                     HAVING COUNT( 1) > 1)
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg01 = rdt.rdtgetmessage( 141201, @cLangCode, 'DSP') -- UCC Mix SKU
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg01
            -- Warning only, can continue scan
            SET @nErrNo = 0
            GOTO Quit
         END  

         IF EXISTS ( SELECT 1
                     FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                     JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON ( RD.ReceiptKey = CRL.ReceiptKey)
                     JOIN dbo.SKU SKU WITH (NOLOCK) ON ( RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)
                     WHERE RD.Userdefine01 = @cUCC
                     AND   RD.Lottable02 IN ( 'PNP', 'ZPPK')
                     AND   CRL.Mobile = @nMobile
                     AND   ( ( ISNULL( SKU.STDGrosswgt, 0) = 0) OR ( ISNULL( SKU.STDCube, 0) = 0)))
         BEGIN
            SET @nErrNo = 0
            SET @cErrMsg01 = rdt.rdtgetmessage( 141202, @cLangCode, 'DSP') -- Need Cubic
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg01
            -- Warning only, can continue scan
            SET @nErrNo = 0
            GOTO Quit
         END  

         CREATE TABLE #ChkReceipt (
         RowRef         INT IDENTITY(1,1) NOT NULL,
         ReceiptKey     NVARCHAR(10)  NULL)

         INSERT INTO #ChkReceipt ( ReceiptKey)
         SELECT DISTINCT RD.ReceiptKey
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         WHERE RD.StorerKey = @cStorerKey
         AND   RD.ToId = @cID
         AND   (( FinalizeFlag <> 'Y' AND BeforeReceivedQty > 0) OR ( FinalizeFlag = 'Y' AND QtyReceived > 0))

         IF @@ROWCOUNT > 1
         BEGIN
		      SET @nErrNo = 141203
	         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Mix PO'
            GOTO QUIT
         END 

         -- Only 1 ASN
         SELECT @cID_ReceiptKey = ReceiptKey FROM #ChkReceipt

         SELECT TOP 1 @cUCC_ReceiptKey = RD.ReceiptKey
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON ( RD.ReceiptKey = CRL.ReceiptKey)
         WHERE RD.Userdefine01 = @cUCC
         AND   CRL.Mobile = @nMobile
         ORDER BY 1
         
         IF ISNULL( @cID_ReceiptKey, '') <> '' AND 
            ISNULL( @cUCC_ReceiptKey, '') <> '' AND 
            @cID_ReceiptKey <> @cUCC_ReceiptKey
         BEGIN
		      SET @nErrNo = 141204
	         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Mix PO'
            GOTO QUIT
         END 
      END
   END
  
QUIT:  

 

GO