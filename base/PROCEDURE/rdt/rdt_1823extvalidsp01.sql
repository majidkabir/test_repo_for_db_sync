SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
    
/************************************************************************/        
/* Store procedure: rdt_1823ExtValidSP01                                */        
/* Purpose: Validate                                                    */        
/*                                                                      */        
/* Modifications log:                                                   */        
/*                                                                      */        
/* Date       Rev  Author     Purposes                                  */        
/* 2019-07-16 1.0  YeeKung    WMS-10286 Created                         */         
/************************************************************************/        
    
CREATE PROC [RDT].[rdt_1823ExtValidSP01] (        
   @nMobile       INT,        
   @nFunc         INT,       
   @cLangCode     NVARCHAR( 3),    
   @nStep         INT,    
   @nInputKey     INT,         
   @cStorerKey    NVARCHAR( 15),       
   @cToID         NVARCHAR( 18),       
   @cReceiptKey   NVARCHAR( 20),    
   @cExtPalletID  NVARCHAR( 20),     
   @cExternReceiptKey NVARCHAR(20),    
   @cSKU          NVARCHAR(20),     
   @nErrNo        INT           OUTPUT,    
   @cErrMsg       NVARCHAR( 20) OUTPUT      
)        
AS        
    
    
SET NOCOUNT ON      
SET QUOTED_IDENTIFIER OFF      
SET ANSI_NULLS OFF      
SET CONCAT_NULL_YIELDS_NULL OFF      
        
IF @nFunc = 1823        
BEGIN     
   IF @nStep = 5    
   BEGIN    
    
      IF NOT EXISTS( SELECT 1      
                     FROM dbo.ReceiptDetail WITH (NOLOCK)         
                     WHERE StorerKey = @cStorerKey        
                     AND   ReceiptKey = @cReceiptKey        
                     AND   Lottable11 = @cToID  )    
         			OR @cExtPalletID <> @cToID    
      BEGIN    
         SET @nErrNo = 143451    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DropIDNoAllow'      
         GOTO QUIT       
      END      
   END    
END    
QUIT: 

GO