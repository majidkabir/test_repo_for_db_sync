SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1805ExtValidSP01                                */  
/* Purpose: Validate  DropID                                            */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2014-08-28 1.2  ChewKP     SOS#318380 Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1805ExtValidSP01] (  
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR(3),   
   @nStep       INT,   
   @cStorerKey  NVARCHAR(15),   
   @cDropID     NVARCHAR(20),  
   @nErrNo      INT       OUTPUT,   
   @cErrMsg     CHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
IF @nFunc = 1805  
BEGIN  
   
    
--    DECLARE  @cDropID       NVARCHAR(15)
--           , @cPalletConsigneeKey NVARCHAR(15)
--           , @cChildID            NVARCHAR(20)

    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    
    IF NOT EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                    WHERE DropID = @cDropID
                    AND Status = '5' ) 
    BEGIN
      SET @nErrNo = 91651
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidDropID'
      GOTO QUIT
    END  
    
    
    
--    IF NOT EXISTS ( SELECT 1 FROM dbo.PTLTran WITH (NOLOCK)
--                    WHERE CaseID = @cDropID
--                    AND Status <> '9' ) 
--    BEGIN
--      SET @nErrNo = 91652
--      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidDropID'
--      GOTO QUIT
--    END                                      
    
--    IF NOT EXISTS ( SELECT 1 FROM dbo.DeviceProfileLog WITH (NOLOCK)
--                    WHERE DropID = @cDropID
--                    AND Status = '3' ) 
--    BEGIN
--      SET @nErrNo = 91653
--      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidDropID'
--      GOTO QUIT
--    END       
    
                   
    
    

   
END  
  
QUIT:  

 

GO