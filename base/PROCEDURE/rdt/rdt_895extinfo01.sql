SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_895ExtInfo01                                    */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Call From rdtfnc_Replenishment                              */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2015-06-15  1.0  ChewKP   SOS#342435 Created                         */   
/* 2017-08-04  1.1  ChewKP   WMS-2428 - Add Carton Count Screen(ChewKP01)*/ 
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_895ExtInfo01] (    
    @nMobile      INT,           
    @nFunc        INT,           
    @cLangCode    NVARCHAR( 3),  
    @nStep        INT,           
    @nInputKey    INT,           
    @cStorerKey   NVARCHAR( 15), 
    @cReplenishmentKey  NVARCHAR( 10), 
    @cPutawayZone       NVARCHAR( 10), 
    @cSuggestedLot      NVARCHAR( 10),
    @cOutInfo01         NVARCHAR( 60)  OUTPUT,
    @nErrNo             INT            OUTPUT, 
    @cErrMsg            NVARCHAR( 20)  OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON            
   SET ANSI_NULLS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
   
   DECLARE @nVASLOC NVARCHAR(10) 
          ,@cLot    NVARCHAR(10) 
          ,@cLottable11 NVARCHAR(30)
          ,@cFromLoc   NVARCHAR(10)
          ,@cFromID    NVARCHAR(18)  
          ,@cWaveKey   NVARCHAR(10)  
          ,@cSuggSKU              NVARCHAR(20)
            
   SET @nErrNo   = 0            
   SET @cErrMsg  = ''     
   
   SELECT @nStep = Step  
         ,@nFunc = Func  
         ,@cFromLoc = V_Loc  
         ,@cFromID  = V_ID  
         ,@cWaveKey = V_String12 
         ,@cLot     = V_Lot
         ,@cSuggSKU = V_String15
   FROM rdt.rdtMobrec WITH (NOLOCK)  
   WHERE Mobile = @nMobile
   
   
   IF @nFunc = 895          
   BEGIN     
         
         IF @nStep IN ( 4, 7, 8, 10 ) -- Get Input Information    -- (ChewKP01) 
         BEGIN       
            --SET @cLot = ''
            SET @cLottable11 = ''
            SET @cOutInfo01 = ''
            
--            SELECT @cLot = Lot 
--            FROM dbo.Replenishment WITH (NOLOCK)
--            WHERE ReplenishmentKey = @cReplenishmentKey
            
            SELECT @cLottable11 = Lottable11 
            FROM LotAttribute WITH (NOLOCK) 
            WHERE Lot = @cSuggestedLot 
            
            --SET @cOutInfo01 = 'PO: ' + ISNULL(RTRIM(@cLottable03),'') 
            SET @cOutInfo01 = @cLottable11
            
                      
         END      
                
   END          
          

            
       
END     

GO