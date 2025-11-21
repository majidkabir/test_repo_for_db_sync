SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/    
/* Store procedure: rdt_727Inquiry02                                       */    
/*                                                                         */    
/* Modifications log:                                                      */    
/*                                                                         */    
/* Date       Rev  Author   Purposes                                       */    
/* 2017-03-08 1.0  ChewKP   WMS-1280 Created                               */  
/* 2018-01-15 1.1  ChewKP   WMS-3749 (ChewKP01)                            */
/* 2019-09-20 1.2  YeeKung  WMS-10536 Change the parameter                 */ 
/***************************************************************************/    
    
CREATE PROC [RDT].[rdt_727Inquiry02] (    
 	 @nMobile    		INT,               
	 @nFunc      		INT,               
	 @nStep      		INT,                
	 @cLangCode  		NVARCHAR( 3),      
	 @cStorerKey 		NVARCHAR( 15),      
	 @cOption    		NVARCHAR( 1),      
	 @cParam1Label    NVARCHAR(20), 
	 @cParam2Label    NVARCHAR(20),   
	 @cParam3Label    NVARCHAR(20),   
	 @cParam4Label    NVARCHAR(20),  
	 @cParam5Label    NVARCHAR(20),  
	 @cParam1         NVARCHAR(20),   
	 @cParam2         NVARCHAR(20),   
	 @cParam3         NVARCHAR(20),   
	 @cParam4         NVARCHAR(20),   
	 @cParam5         NVARCHAR(20),          
	 @cOutField01  	NVARCHAR(20) OUTPUT,    
	 @cOutField02  	NVARCHAR(20) OUTPUT,    
	 @cOutField03  	NVARCHAR(20) OUTPUT,    
	 @cOutField04  	NVARCHAR(20) OUTPUT,    
	 @cOutField05  	NVARCHAR(20) OUTPUT,    
	 @cOutField06  	NVARCHAR(20) OUTPUT,    
	 @cOutField07  	NVARCHAR(20) OUTPUT,    
	 @cOutField08  	NVARCHAR(20) OUTPUT,    
	 @cOutField09  	NVARCHAR(20) OUTPUT,    
	 @cOutField10  	NVARCHAR(20) OUTPUT,
	 @cOutField11  	NVARCHAR(20) OUTPUT,
	 @cOutField12  	NVARCHAR(20) OUTPUT,
	 @cFieldAttr02 	NVARCHAR( 1) OUTPUT,  
	 @cFieldAttr04 	NVARCHAR( 1) OUTPUT,  
	 @cFieldAttr06 	NVARCHAR( 1) OUTPUT,  
	 @cFieldAttr08 	NVARCHAR( 1) OUTPUT,  
	 @cFieldAttr10 	NVARCHAR( 1) OUTPUT,        
	 @nNextPage    	INT          OUTPUT,    
	 @nErrNo     		INT 			 OUTPUT,        
	 @cErrMsg    		NVARCHAR( 20) OUTPUT 
)    
AS    
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF     
    
   DECLARE @cSKU        NVARCHAR(20) 
         , @nSKUCnt     INT
         , @b_Success   INT
         , @cPAZone     NVARCHAR(10) 
         , @cLoc        NVARCHAR(10)
         , @cFacility   NVARCHAR(5) 

   
          
SET @nErrNo = 0 


IF @cOption = '1' 
BEGIN          

        IF @nStep = 2 
        BEGIN
         SET @cSKU = @cParam1 

         IF @cSKU = ''
         BEGIN
            SET @nErrNo = 106701
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Req 
            GOTO QUIT 
         END
         
         -- Get SKU barcode count
         SET @nSKUCnt = 0
   
         EXEC rdt.rdt_GETSKUCNT
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU
            ,@nSKUCnt     = @nSKUCnt       OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT
   
         -- Check SKU/UPC
         IF @nSKUCnt = 0
         BEGIN
            SET @nErrNo = 106702
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
            GOTO QUIT
         END
   
         -- Check multi SKU barcode
         IF @nSKUCnt > 1
         BEGIN
            SET @nErrNo = 106703
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod
            GOTO QUIT
         END
   
         -- Get SKU code
         EXEC rdt.rdt_GETSKU
             @cStorerKey  = @cStorerKey
            ,@cSKU        = @cSKU          OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @nErrNo        OUTPUT
            ,@cErrMsg     = @cErrMsg       OUTPUT
            
         
                  
         SELECT @cFacility = Facility 
         FROM rdt.rdtMobRec WITH (NOLOCK) 
         WHERE Mobile = @nMobile 
         
         SELECT TOP 1 @cLoc = LLI.Loc 
         FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON  Loc.Loc = LLI.Loc
         WHERE LLI.StorerKey = @cStorerKey 
         AND LLI.SKU = @cSKU 
         AND LLI.Qty > 0 
         AND Loc.Facility = @cFacility
         AND Loc.LocationCategory = 'MEZZANINE'
         AND Loc.LocationFlag = 'NONE'
         Order By LLI.Qty

         -- (ChewKP01) 
         --SELECT @cPAZone = PutawayZone 
         --FROM dbo.Loc WITH (NOLOCK) 
         --WHERE Loc = @cLoc
         --AND Facility = @cFacility 
         
         SELECT @cPAZone = PutawayZone
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU

         IF ISNULL(@cPAZone,'')  = '' 
         BEGIN
            --SET @nErrNo = 106704
            --SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NoSuitPAZone
            --GOTO QUIT  
            SET @cPAZone = 'NoSuitPAZone'
         END
         
            
         SET @cOutField01 = 'SKU:'
         SET @cOutField02 = @cSKU
         SET @cOutField03 = 'PAZone   :' + @cPAZone
         SET @cOutField04 = ''
         SET @cOutField05 = ''
         SET @cOutField06 = ''
         SET @cOutField07 = ''
         SET @cOutField08 = ''
         SET @cOutField09 = ''
         SET @cOutField10 = ''
         
         SET @nNextPage = 0   
        END
      
--      IF @nStep = 2 
--      BEGIN
--         SET @cSKU = @cParam1 
--      
--         IF @cSKU = ''
--         BEGIN
--            SET @nErrNo = 106701
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Req 
--            GOTO QUIT 
--         END
--         
--         -- Get SKU barcode count
--         SET @nSKUCnt = 0
--   
--         EXEC rdt.rdt_GETSKUCNT
--             @cStorerKey  = @cStorerKey
--            ,@cSKU        = @cSKU
--            ,@nSKUCnt     = @nSKUCnt       OUTPUT
--            ,@bSuccess    = @b_Success     OUTPUT
--            ,@nErr        = @nErrNo        OUTPUT
--            ,@cErrMsg     = @cErrMsg       OUTPUT
--   
--         -- Check SKU/UPC
--         IF @nSKUCnt = 0
--         BEGIN
--            SET @nErrNo = 106702
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
--            GOTO QUIT
--         END
--   
--         -- Check multi SKU barcode
--         IF @nSKUCnt > 1
--         BEGIN
--            SET @nErrNo = 106703
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod
--            GOTO QUIT
--         END
--   
--         -- Get SKU code
--         EXEC rdt.rdt_GETSKU
--             @cStorerKey  = @cStorerKey
--            ,@cSKU        = @cSKU          OUTPUT
--            ,@bSuccess    = @b_Success     OUTPUT
--            ,@nErr        = @nErrNo        OUTPUT
--            ,@cErrMsg     = @cErrMsg       OUTPUT
--            
--         
--         SELECT @cPAZone = PutawayZone
--         FROM dbo.SKU WITH (NOLOCK) 
--         WHERE StorerKey = @cStorerKey
--         AND SKU = @cSKU
--            
--         SET @c_oFieled01 = 'SKU:'
--         SET @c_oFieled02 = @cSKU
--         SET @c_oFieled03 = 'PAZone     :' + @cPAZone
--         SET @c_oFieled04 = ''
--         SET @c_oFieled05 = ''
--         SET @c_oFieled06 = ''
--         SET @c_oFieled07 = ''
--         SET @c_oFieled08 = ''
--         SET @c_oFieled09 = ''
--         SET @c_oFieled10 = ''
--         
--         SET @nNextPage = 0   
--      END


END
QUIT:
        

GO