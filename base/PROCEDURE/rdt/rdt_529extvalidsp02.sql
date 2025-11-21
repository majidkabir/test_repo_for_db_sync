SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_529ExtValidSP02                                 */  
/* Purpose: Validate                                                    */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2016-02-10 1.2  ChewKP     SOS#359841 Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_529ExtValidSP02] (  
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR(3),   
   @nStep       INT,   
   @cStorerKey  NVARCHAR(15),   
   @cFromTote   NVARCHAR(18),  
   @cToTote     NVARCHAR(18),  
   @nErrNo      INT       OUTPUT,   
   @cErrMsg     CHAR( 20) OUTPUT
)  
AS  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
IF @nFunc = 529  
BEGIN  
   

    DECLARE  @nValidationPass INT
           , @cFromToteConsignee  NVARCHAR(18) 
           , @cToToteConsignee    NVARCHAR(18)
           , @cCode               NVARCHAR(30)
           , @cFromToteBuyerPO    NVARCHAR(20)
           , @cToToteBuyerPO      NVARCHAR(20)
           , @cShort              NVARCHAR(10)
           , @cFromToteSectionKey NVARCHAR(10) 
           , @cToToteSectionKey   NVARCHAR(10)
           , @cFromOrderKey       NVARCHAR(10)
           , @cToOrderKey         NVARCHAR(10) 
           , @cFromCaseID         NVARCHAR(20)
           , @cToCaseID           NVARCHAR(20) 
    
    SET @nValidationPass = 0
    SET @nErrNo = 0 
    SET @cErrMsg = ''
    SET @cFromToteConsignee  = ''
    SET @cToToteConsignee    = ''
    SET @cCode               = ''
    SET @cFromToteBuyerPO    = ''
    SET @cToToteBuyerPO      = ''
    SET @cShort              = ''
    SET @cFromToteSectionKey = ''
    SET @cToToteSectionKey   = ''
    
    IF @nStep = '2'
    BEGIN
      
--         SELECT
--            @cFromToteConsignee = O.Consigneekey 
--         FROM dbo.PickDetail PD WITH (NOLOCK)
--         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey 
--         WHERE PD.StorerKey = @cStorerKey
--            AND PD.DropID = @cFromTote
--         
--         SELECT
--            @cToToteConsignee = O.Consigneekey 
--         FROM dbo.PickDetail PD WITH (NOLOCK)
--         INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey 
--         WHERE PD.StorerKey = @cStorerKey
--            AND PD.DropID = @cToTote
--         
--         IF ISNULL( @cFromToteConsignee, '' ) <> ISNULL ( @cToToteConsignee, '' ) 
--         BEGIN
--            SET @nErrNo = 95951
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DiffConsignee'
--            GOTO QUIT 
--         END     

         SELECT
             @cFromOrderKey = OrderKey 
            ,@cFromCaseID   = CaseID
         FROM dbo.PickDetail PD WITH (NOLOCK)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.DropID = @cFromTote
            AND Status = '5'
         
         
         SELECT
            @cToOrderKey = OrderKey 
            ,@cToCaseID  = CaseID
         FROM dbo.PickDetail PD WITH (NOLOCK)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.DropID = @cToTote     
            AND Status = '5'
            
         IF ISNULL( @cFromOrderKey, '' ) <> ISNULL ( @cToOrderKey, '' ) 
         BEGIN
            SET @nErrNo = 95952
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'DiffOrderKey'
            GOTO QUIT 
         END   
         
         IF ISNULL(@cFromCaseID,'') <> ''
         BEGIN
            SET @nErrNo = 95955
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CasePacked'
            GOTO QUIT 
         END
         
         IF ISNULL(@cToCaseID,'') <> ''
         BEGIN
            SET @nErrNo = 95956
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CasePacked'
            GOTO QUIT 
         END
         
--         IF ISNULL(@cFromCaseID,'') = ''
--         BEGIN
--            IF ISNULL(@cToCaseID,'' )  <> '' 
--            BEGIN
--               SET @nErrNo = 95953
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteStatNotMatch'
--               GOTO QUIT 
--            END
--         END
--         
--         IF ISNULL(@cFromCaseID,'') <> ''
--         BEGIN
--            IF ISNULL(@cToCaseID,'' )  = '' 
--            BEGIN
--               SET @nErrNo = 95954
--               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'ToteStatNotMatch'
--               GOTO QUIT 
--            END
--         END
         
         
         
    END
    
    
    

   
END  
  
QUIT:  

 

GO