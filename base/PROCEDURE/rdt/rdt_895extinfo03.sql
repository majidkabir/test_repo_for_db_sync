SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_895ExtInfo03                                    */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose: Call From rdtfnc_Replenishment                              */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2021-02-23  1.0  James    WMS-16020. Created                         */   
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_895ExtInfo03] (    
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

   DECLARE @nTtl_RepQty       INT          
   DECLARE @nTtl_Qty          INT
   DECLARE @nInnerPack        INT
   DECLARE @nRemainder        INT
   DECLARE @nTtl_Carton       INT
   DECLARE @nTtl_ScanCarton   INT
   DECLARE @cSKU              NVARCHAR( 20)

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
      IF @nStep = 4  
      BEGIN       
         IF @nInputKey = 1
         BEGIN
            SELECT @nTtl_RepQty = ISNULL( SUM( Qty), 0)
            FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
            WHERE StorerKey = @cStorerkey
            AND   WaveKey = @cWaveKey
            AND   FromLoc = @cFromLoc
            AND   ID  = @cFromID
            AND   Confirmed = 'N'
            AND   AddWho = @cUserName

            SELECT TOP 1 @cSKU = Sku
            FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
            WHERE StorerKey = @cStorerkey
            AND   WaveKey = @cWaveKey
            AND   FromLoc = @cFromLoc
            AND   ID  = @cFromID
            AND   Confirmed = 'N'
            AND   AddWho = @cUserName
            ORDER BY 1
            
            SELECT @nInnerPack = PACK.InnerPack
            FROM dbo.SKU SKU WITH (NOLOCK) 
            JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
            AND   SKU.Sku = @cSKU
            
            IF @nInnerPack > 0
            BEGIN
               SET @nRemainder = 0
               SET @nTtl_Carton = @nTtl_RepQty / @nInnerPack
               SET @nRemainder = @nTtl_RepQty % @nInnerPack
            
               IF @nRemainder > 0
                  SET @nTtl_Carton = @nTtl_Carton + 1
            
               IF @nInnerPack > 0
                  SET @cOutInfo01 = 'CNT: 0/' + CAST( @nTtl_Carton AS NVARCHAR( 2))
            END
            ELSE
               SET @cOutInfo01 = 'CNT: 0/0'
         END
      END      

      IF @nStep = 5  
      BEGIN       
         IF @nInputKey = 1
         BEGIN
            SELECT @nTtl_RepQty = ISNULL( SUM( Qty), 0),
                  @nTtl_Qty = ISNULL( SUM( QtyMoved), 0)
            FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
            WHERE StorerKey = @cStorerkey
            AND   WaveKey = @cWaveKey
            AND   FromLoc = @cFromLoc
            AND   ID  = @cFromID
            AND   Confirmed IN ( '1', 'N')
            AND   AddWho = @cUserName

            SELECT TOP 1 @cSKU = Sku
            FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
            WHERE StorerKey = @cStorerkey
            AND   WaveKey = @cWaveKey
            AND   FromLoc = @cFromLoc
            AND   ID  = @cFromID
            AND   Confirmed IN ( '1', 'N')
            AND   AddWho = @cUserName
            ORDER BY 1
            
            SELECT @nInnerPack = PACK.InnerPack
            FROM dbo.SKU SKU WITH (NOLOCK) 
            JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey)
            WHERE SKU.StorerKey = @cStorerKey
            AND   SKU.Sku = @cSKU

            IF @nInnerPack > 0
            BEGIN
               SET @nRemainder = 0
               SET @nTtl_Carton = @nTtl_RepQty / @nInnerPack
               SET @nRemainder = @nTtl_RepQty % @nInnerPack
            
               IF @nRemainder > 0
                  SET @nTtl_Carton = @nTtl_Carton + 1
               
               SET @nRemainder = 0
               SET @nTtl_ScanCarton = @nTtl_Qty / @nInnerPack
               SET @nRemainder = @nTtl_Qty % @nInnerPack
            
               IF @nRemainder > 0
                  SET @nTtl_ScanCarton = @nTtl_ScanCarton + 1
               
               IF @nInnerPack > 0
                  SET @cOutInfo01 = 'CNT: ' + CAST( @nTtl_ScanCarton AS NVARCHAR( 2)) + '/' + CAST( @nTtl_Carton AS NVARCHAR( 2))
            END
            ELSE
               SET @cOutInfo01 = 'CNT: 0/0'
         END
      END            
   END          
END     

GO