SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_595ExtValidSP01                                 */  
/* Purpose: Validate UCC                                                */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2014-02-10 1.0  ChewKP     SOS#326722 Created                        */  
/* 2019-05-27 1.1  James      WMS-9128 Add ASNStatus 1 (james01)        */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_595ExtValidSP01] (  
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR(3),   
   @nStep       INT,   
   @cStorerKey  NVARCHAR(15),   
   @cUCCNo      NVARCHAR(20), 
   @nErrNo      INT       OUTPUT,   
   @cErrMsg     NVARCHAR( 20) OUTPUT
)  
AS  
  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
  
IF @nFunc = 595  
BEGIN  
    
    DECLARE @nCountASN INT
    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    SET @nCountASN       = 0 
    
    
    IF @nStep = 1
    BEGIN
       SELECT @nCountASN = Count(DISTINCT RD.ReceiptKey) 
       FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
       INNER JOIN dbo.Receipt R WITH (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
       WHERE RD.StorerKey = @cStorerKey
       AND RD.UserDefine01 = @cUCCNo
       AND R.ASNStatus IN ( '0', '1')  -- (james01) 
      
                        
       IF ISNULL(@nCountASN, 0 )  = 0 
       BEGIN
         SET @nErrNo = 92401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCCNotFound'
         GOTO QUIT
       END
       
       IF ISNULL(@nCountASN, 0 )  > 1 
       BEGIN
         SET @nErrNo = 92402
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'MultiASNFound'
         GOTO QUIT
       END
       
       
    END
    
    
    

   
END  
  
QUIT:  


GO