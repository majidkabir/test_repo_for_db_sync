SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/      
/* Store procedure: rdt_573ExtValidSP04                                 */      
/* Purpose: Validate  UCC                                               */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date       Rev  Author     Purposes                                  */      
/* 2021-10-12 1.0  James      WMS-18123 Created                         */      
/************************************************************************/      
      
CREATE PROC [RDT].[rdt_573ExtValidSP04] (      
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
   DECLARE @cPO        NVARCHAR( 18) = ''
   DECLARE @cUCC_PO    NVARCHAR( 18) = ''
        
   SET @nErrNo = 0    
    
   SELECT @nInputKey = InputKey  
   FROM RDT.RDTMOBREC WITH (NOLOCK)    
   WHERE Mobile = @nMobile    
    
   IF @nStep = 4
   BEGIN    
      IF @nInputKey = 1    
      BEGIN    
         IF NOT EXISTS ( SELECT 1 FROM RECEIPT R WITH (NOLOCK) 
                         JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON ( R.ReceiptKey = CRL.ReceiptKey)
                         WHERE R.RECType = 'CASEPACK'
                         AND   CRL.Mobile = @nMobile)
            GOTO QUIT

         -- If pallet not receive before then no need further check
         IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL RD WITH (NOLOCK)
                         JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON ( RD.ReceiptKey = CRL.ReceiptKey)
                         WHERE ToId = @cID
                         GROUP BY RD.ReceiptKey
                         HAVING ISNULL( SUM( RD.BeforeReceivedQty), 0) > 0)
            GOTO Quit
               
         SELECT TOP 1 @cPO = Lottable03
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON ( RD.ReceiptKey = CRL.ReceiptKey)
         WHERE ToId = @cID
         AND   BeforeReceivedQty > 0
         AND   CRL.Mobile = @nMobile
         ORDER BY 1

         SELECT TOP 1 @cUCC_PO = Lottable03
         FROM dbo.ReceiptDetail RD WITH (NOLOCK)
         JOIN rdt.rdtConReceiveLog CRL WITH (NOLOCK) ON ( RD.ReceiptKey = CRL.ReceiptKey)
         WHERE UserDefine01 = @cUCC
         AND   CRL.Mobile = @nMobile
         ORDER BY 1

         -- UCCs in One Pallet Id must have the same Po Number
         IF @cPO <> @cUCC_PO      
         BEGIN
            SET @nErrNo = 176851
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode,'DSP') --Mix PO Pallet 
            GOTO Quit
         END  
      END    
   END
   
QUIT:        

GO