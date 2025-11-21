SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  

/************************************************************************/        
/* Store procedure: rdt_1832ExtValidSP01                                */        
/* Purpose: Validate  UCC                                               */        
/*                                                                      */        
/* Modifications log:                                                   */        
/*                                                                      */        
/* Date       Rev  Author     Purposes                                  */        
/* 2019-02-15 1.0  YeeKung   WMS-7796         									*/        
/************************************************************************/        
        
CREATE PROC [RDT].[rdt_1832ExtValidSP01] (        
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
        
IF @nFunc = 1832        
BEGIN       
      
   DECLARE  @cUCCWithMultiSKU       	NVARCHAR(1)      
         , @cShort                 	NVARCHAR(10)      
   --         , @cChildID            		NVARCHAR(20)      
          
   SET @nErrNo          = 0      
   SET @cErrMSG         = ''      
          
   SET @cUCCWithMultiSKU = rdt.rdtGetConfig( @nFunc, 'UCCWithMultiSKU', @cStorerKey)      
   IF @cUCCWithMultiSKU = '0'      
   SET @cUCCWithMultiSKU = ''      
    
   IF @nStep = 5      
   BEGIN      
	        
      DECLARE @cBUSR1 NVARCHAR(5);      
	      
      SELECT @cBUSR1 = BUSR1 FROM SKU WITH (NOLOCK) WHERE sku=@cSKU AND StorerKey=@cStorerKey;      
	      
      --IF (@cBUSR1 = NULL OR @cBUSR1= 'N')      
      IF(@cBUSR1 <> 'Y')    
      BEGIN      
	      SET @nErrNo = 134413      
	      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU ModFail'      
	      GOTO QUIT      
      END    
         
   END          
   ELSE IF @nStep = 8      
   BEGIN     

	   DECLARE @nUCCCnt int =''    
	   DECLARE @nSKUBUSR2 int =''    

	   IF @cSKU <> ''    
	   BEGIN    
         SELECT @nUCCCnt = count(*)        
         FROM dbo.UCC WITH (NOLOCK)       
         WHERE StorerKey = @cStorerKey        
         AND   SKU = @cSKU AND  id=@cToID     
    
   	   SELECT @nSKUBUSR2 = BUSR2      
         FROM dbo.SKU         
         WHERE StorerKey = @cStorerKey      
         AND   SKU = @cSKU    
    
		   IF (@nSKUBUSR2 = '' or ISNULL(@nSKUBUSR2,'')=0)    
			   SET @nSKUBUSR2 = 99999;    
    
		   IF @nUCCCnt >= @nSKUBUSR2    
		   BEGIN    
			   SET @nErrNo = 134438      
			   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'EXCEED UCC'      
			   GOTO QUIT    
		   END    
	   END    
      
	   IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)       
					   WHERE UCCNo = @cUCC      
					   AND   Status IN ( '3' , '6' ) )       
	   BEGIN      
		   SET @nErrNo = 134439      
		   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCCStatus'      
		   GOTO QUIT      
	   END        
             
             
	   IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)       
					   WHERE UCCNo = @cUCC      
					   AND Status = '1' 
					   AND StorerKey = @cStorerKey )            
	   BEGIN             


		   IF @cUCCWithMultiSKU = '1'      
		   BEGIN       

			   SELECT @cShort = ISNULL(RTRIM(Short),'')       
			   FROM dbo.Codelkup WITH (NOLOCK)       
			   WHERE ListName = 'AFMIXUCC'      
			   AND StorerKey = @cStorerKey     

			   IF NOT EXISTS ( 	SELECT 1 FROM dbo.Loc WITH (NOLOCK)       
				        			   WHERE Loc = @cToLoc      
				        			   AND Facility = @cShort )       
			   BEGIN      
				   SET @nErrNo = 134440      
				   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidFacility'      
				   GOTO QUIT      
			   END      
                    
			   IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)      
				               WHERE UCCNo = @cUCC      
				               AND Status  = '1'      
				               AND Loc     = @cToLoc      
				               AND ID      = @cToID )       
			   BEGIN      
				   SET @nErrNo = 134441      
				   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCC'      
				   GOTO QUIT      
			   END        
		   END      
		   ELSE      
		   BEGIN      
			   SET @nErrNo = 134442      
			   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCCExists'      
			   GOTO QUIT      
		   END                        
	   END        
   END           
        
QUIT:        

END       
   

GO