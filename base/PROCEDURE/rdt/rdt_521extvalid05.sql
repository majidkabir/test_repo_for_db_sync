SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_521ExtValid05                                   */    
/* Purpose: Validate ucc scanned not exists in tm task with ASTRPT      */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author     Purposes                                  */    
/* 2021-10-28 1.0  James      WMS-18256. Created                        */    
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_521ExtValid05] (    
   @nMobile         INT,         
   @nFunc           INT,         
   @cLangCode       NVARCHAR( 3),    
   @nStep           INT,          
   @nInputKey       INT,         
   @cStorerKey      NVARCHAR( 15),   
   @cUCCNo          NVARCHAR( 20),   
   @cSuggestedLOC   NVARCHAR( 10),   
   @cToLOC          NVARCHAR( 10),   
   @nErrNo          INT OUTPUT,      
   @cErrMsg         NVARCHAR( 20) OUTPUT  
)    
AS    
  
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
  
   DECLARE @cErrMsg1       NVARCHAR( 20),   
           @cErrMsg2       NVARCHAR( 20)   
  
   SET @nErrNo = 0  
   SET @cErrMSG = ''  
  
   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 1  
      BEGIN  
         IF EXISTS ( SELECT 1 FROM dbo.TaskDetail WITH (NOLOCK)    
                     WHERE StorerKey = @cStorerKey    
                     AND   CaseId = @cUCCNo  
                     AND   TaskType IN ('RPF', 'ASTRPT')  
                     AND   [Status] < '9')     
         BEGIN  
            SET @nErrNo = 0    
            SET @cErrMsg1 = rdt.rdtgetmessage( 177851, @cLangCode, 'DSP') --With Pending    
            SET @cErrMsg2 = rdt.rdtgetmessage( 177852, @cLangCode, 'DSP') --ASTRPT Task    
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2    
            IF @nErrNo = 1    
            BEGIN    
               SET @cErrMsg1 = ''    
               SET @cErrMsg2 = ''    
            END    
            SET @nErrNo = 177852  
            SET @cErrMsg = @cErrMsg2  
            GOTO QUIT  
         END  
      END  
   END  
    
QUIT:    
  

GO