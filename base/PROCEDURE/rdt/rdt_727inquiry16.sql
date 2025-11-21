SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Store procedure: rdt_727Inquiry16                                       */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date       Rev  Author     Purposes                                     */  
/* 2022-05-06 1.0  ChewKP     WMS-19607 Created                            */  
/***************************************************************************/  
  
CREATE PROC [RDT].[rdt_727Inquiry16] (  
  @nMobile      INT,    
   @nFunc        INT,    
   @nStep        INT,    
   @cLangCode    NVARCHAR(3),    
   @cStorerKey   NVARCHAR(15),    
   @cOption      NVARCHAR(1),    
   @cParam1      NVARCHAR(20),    
   @cParam2      NVARCHAR(20),    
   @cParam3      NVARCHAR(20),    
   @cParam4      NVARCHAR(20),    
   @cParam5      NVARCHAR(20),    
   @c_oFieled01  NVARCHAR(20) OUTPUT,    
   @c_oFieled02  NVARCHAR(20) OUTPUT,    
   @c_oFieled03  NVARCHAR(20) OUTPUT,    
   @c_oFieled04  NVARCHAR(20) OUTPUT,    
   @c_oFieled05  NVARCHAR(20) OUTPUT,    
   @c_oFieled06  NVARCHAR(20) OUTPUT,    
   @c_oFieled07  NVARCHAR(20) OUTPUT,    
   @c_oFieled08  NVARCHAR(20) OUTPUT,    
   @c_oFieled09  NVARCHAR(20) OUTPUT,    
   @c_oFieled10  NVARCHAR(20) OUTPUT,    
   @c_oFieled11  NVARCHAR(20) OUTPUT,    
   @c_oFieled12  NVARCHAR(20) OUTPUT,    
   @nNextPage    INT          OUTPUT,    
   @nErrNo       INT          OUTPUT,    
   @cErrMsg      NVARCHAR(20) OUTPUT    
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
    
   DECLARE @cLabel_LOC   NVARCHAR( 20)  
   DECLARE @cLabel_Total NVARCHAR( 20)  
   DECLARE @cLabel_Page  NVARCHAR( 20)  
  
   DECLARE @cFacility   NVARCHAR( 5)  
   DECLARE @cID         NVARCHAR( 18)  
   DECLARE @cLOC        NVARCHAR( 10)  
 
   
   DECLARE @cSuggLoc       NVARCHAR(10)
          ,@cSKU           NVARCHAR(20)
          ,@cPutawayzone   NVARCHAR(10)
          ,@cSKUStatus     NVARCHAR(10)
          ,@bSuccess       INT
          ,@cLocAisle      NVARCHAR(10)
		  ,@cFloor		   NVARCHAR(10)
		  ,@cSKUDescr      NVARCHAR(60)
		  ,@nPage		   INT
          
  
   SET @nErrNo = 0  
  
   -- Get session info  
   SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile  
  
      
  
   IF @nFunc = 727 -- General inquiry  
   BEGIN  
      IF @nStep = 2 -- Inquiry sub module, input screen  
      BEGIN  
         -- Parameter mapping  
         SET @cSKU = @cParam1  

		 
  
         -- Check blank  
         IF @cSKU = ''   
         BEGIN  
            SET @nErrNo = 186351  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU  
            GOTO Quit  
         END  
         
		   SET @cSKUStatus = '' 

         EXEC [RDT].[rdt_GETSKU]  
                        @cStorerKey   = @cStorerKey  
         ,              @cSKU         = @cSKU         OUTPUT  
         ,              @bSuccess     = @bSuccess     OUTPUT  
         ,              @nErr         = @nErrNo       OUTPUT  
         ,              @cErrMsg      = @cErrMsg      OUTPUT  
         ,              @cSKUStatus   = @cSKUStatus  
  
	
         IF @bSuccess <> 1  
         BEGIN  
            SET @nErrNo = 186352  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'  
            GOTO Quit  
         END
         
    
         -- Get Suggested DPBulk info  
         SELECT TOP 1 @cSuggLoc = LLI.LOC 
                     ,@cLocAisle = LOC.LocAisle
                     ,@cSKUDescr  = SKU.Descr
                     ,@cFloor     = LOC.Floor
                     ,@cPutawayZone = SKU.PutawayZone
         FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
         INNER JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
         INNER JOIN dbo.SKU SKU WITH (NOLOCK) ON LLI.SKU = SKU.SKU AND LLI.StorerKey = SKU.StorerKey
         WHERE LLI.StorerKey = @cStorerKey
         AND LOC.Facility = @cFacility
         AND LOC.LocationType = 'DPBULK'
         AND LLI.SKU = @cSKU
         ORDER BY LLI.Qty DESC

		 IF ISNULL(@cSuggLoc,'')  = ''
		 BEGIN
			 SELECT   @cSKUDescr  = SKU.Descr
                     ,@cPutawayZone = SKU.PutawayZone
			 FROM dbo.SKU SKU WITH (NOLOCK) 
			 WHERE SKU.StorerKey = @cStorerKey
			 AND SKU.SKU = @cSKU
			 
		 END
         
                
         
         
         -- Get counter  
         SET @nPage = 1  
         --SET @nTotalPage = CEILING( @nRowCount / 6.0)  
         IF ISNULL(@cSuggLoc,'')  <> ''
         BEGIN
            SET @c_oFieled01 = 'SKU : '  
            SET @c_oFieled02 = @cSKU
            SET @c_oFieled03 = 'DESCRIPTION : '
            SET @c_oFieled04 = SUBSTRING( @cSKUDescr, 1, 20)  
            SET @c_oFieled05 = SUBSTRING( @cSKUDescr, 21, 20) 
            SET @c_oFieled06 = 'FLOOR : ' + @cFloor  
            SET @c_oFieled07 = 'AISLE : ' + @cLocAisle    
            SET @c_oFieled08 = ''  
            SET @c_oFieled09 = 'SUGGESTED LOC : '  
            SET @c_oFieled10 = @cSuggLoc
         END
         ELSE 
         BEGIN
            SELECT @cPutawayZone = PutawayZone
            FROM dbo.SKU WITH (NOLOCK) 
            WHERE Storerkey = @cStorerKey
            AND SKU = @cSKU 
            
            SET @c_oFieled01 = 'SKU : '  
            SET @c_oFieled02 = @cSKU
            SET @c_oFieled03 = 'DESCRIPTION : '
            SET @c_oFieled04 = SUBSTRING( @cSKUDescr, 1, 20)  
            SET @c_oFieled05 = SUBSTRING( @cSKUDescr, 21, 20) 
            SET @c_oFieled06 = '' 
            SET @c_oFieled07 = 'PUTAWAYZONE : '
            SET @c_oFieled08 = @cPutawayZone  
            SET @c_oFieled09 = ''  
            SET @c_oFieled10 = ''  
         END
         
         
    
       
      END  
     
     
   END  
  
Quit:  
  
END  

GO