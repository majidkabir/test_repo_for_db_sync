SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_895ExtInfo02                                    */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Call From rdtfnc_Replenishment                              */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2018-01-23  1.0  ChewKP   WMS-3807 Created                           */   
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_895ExtInfo02] (    
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
          ,@cSuggSKU   NVARCHAR(20)
          ,@cReplenNo  NVARCHAR(20) 
          ,@cUserName  NVARCHAR(18) 
            
   SET @nErrNo   = 0            
   SET @cErrMsg  = ''     
   
   SELECT @nStep = Step  
         ,@nFunc = Func  
         ,@cFromLoc = V_Loc  
         ,@cFromID  = V_ID  
         ,@cWaveKey = V_String12 
         ,@cLot     = V_Lot
         ,@cSuggSKU = V_String15
         ,@cUserName = UserName 
   FROM rdt.rdtMobrec WITH (NOLOCK)  
   WHERE Mobile = @nMobile
   
   
   IF @nFunc = 895          
   BEGIN     
         
         IF @nStep IN ( 4, 7, 8, 10 ) -- Get Input Information    -- (ChewKP01) 
         BEGIN       
            --SET @cLot = ''
            --SET @cLottable11 = ''
            SET @cOutInfo01 = ''
            
--            SELECT @cLot = Lot 
--            FROM dbo.Replenishment WITH (NOLOCK)
--            WHERE ReplenishmentKey = @cReplenishmentKey
            
--            SELECT @cLottable11 = Lottable11 
--            FROM LotAttribute WITH (NOLOCK) 
--            WHERE Lot = @cSuggestedLot 
            
 


            SELECT
            Top 1 @cReplenNo = RefNo
            FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
            WHERE StorerKey = @cStorerkey
            AND WaveKey = @cWaveKey
            AND FromLoc = @cFromLoc
            AND ID  = @cFromID
            --AND SKU = @cSuggSKU
            AND Confirmed = 'N'
            --AND Qty = @nQty
            AND AddWho = @cUserName
            Order By ReplenishmentKey



            
            --SET @cOutInfo01 = 'PO: ' + ISNULL(RTRIM(@cLottable03),'') 
            SET @cOutInfo01 = @cReplenNo
            
                      
         END      
                
   END          
          

            
       
END     

GO