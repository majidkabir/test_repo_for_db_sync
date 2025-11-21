SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1804ExtValidSP01                                */  
/* Purpose: Validate  UCC                                               */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2015-03-24 1.0  ChewKP     SOS#336025                                */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1804ExtValidSP01] (  
     @nMobile         INT, 
     @nFunc           INT, 
     @cLangCode       NVARCHAR(3), 
     @nStep           INT, 
     @cStorerKey      NVARCHAR(15),
     @cFacility       NVARCHAR(5), 
     @cFromLOC        NVARCHAR(10),
     @cFromID         NVARCHAR(18),
     @cSKU            NVARCHAR(20),
     @nQTY            INT, 
     @cUCC            NVARCHAR(20),
     @cToID           NVARCHAR(18),
     @cToLOC          NVARCHAR(10),
     @nErrNo          INT OUTPUT, 
     @cErrMsg         NVARCHAR(20) OUTPUT
)  
AS  
  
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
  
IF @nFunc = 1804  
BEGIN  
   
    
    DECLARE  @cUCCWithMultiSKU       NVARCHAR(1)
           , @cShort                 NVARCHAR(10)
--           , @cChildID            NVARCHAR(20)

    
    SET @nErrNo          = 0
    SET @cErrMSG         = ''
    

    SET @cUCCWithMultiSKU = rdt.rdtGetConfig( @nFunc, 'UCCWithMultiSKU', @cStorerKey)
    IF @cUCCWithMultiSKU = '0'
      SET @cUCCWithMultiSKU = ''
  
       
    IF @nStep = '7'
    BEGIN

       IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
                   WHERE UCCNo = @cUCC
                   AND   Status IN ( '3' , '6' ) ) 
       BEGIN
         SET @nErrNo = 93201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCCStatus'
         GOTO QUIT
       END  
       
       
       IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) 
                   WHERE UCCNo = @cUCC
                   AND Status = '1' ) 
       BEGIN       
          
          
          IF @cUCCWithMultiSKU = '1'
          BEGIN 
             
             SELECT @cShort = ISNULL(RTRIM(Short),'') 
             FROM dbo.Codelkup WITH (NOLOCK) 
             WHERE ListName = 'AFMIXUCC'
             AND StorerKey = 'ANF'
             
             IF NOT EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK) 
                             WHERE Loc = @cToLoc
                             AND Facility = @cShort ) 
             BEGIN
                  SET @nErrNo = 93203
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidFacility'
                  GOTO QUIT
             END
              
             IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                             WHERE UCCNo = @cUCC
                             AND Status  = '1'
                             AND Loc     = @cToLoc
                             AND ID      = @cToID ) 
             BEGIN
                  SET @nErrNo = 93202
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCC'
                  GOTO QUIT
             END  
          END
          ELSE
          BEGIN
                  SET @nErrNo = 93204
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCCExists'
                  GOTO QUIT
          END                  
       END
       
       
       
       
    END
    
    

   
END  
  
QUIT:  

 

GO