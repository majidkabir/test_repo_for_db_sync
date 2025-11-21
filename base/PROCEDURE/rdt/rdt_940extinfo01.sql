SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_940ExtInfo01                                    */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_DynamicPick_UCCReplenFrom                        */    
/*                                                                      */    
/* Purpose: Display route                                               */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2020-10-08  1.0  James    WMS-15412. Created                         */  
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_940ExtInfo01] (    
   @nMobile          INT,           
   @nFunc            INT,           
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,           
   @nAfterStep       INT,           
   @nInputKey        INT,           
   @cStorerkey       NVARCHAR( 15), 
   @cReplenGroup     NVARCHAR( 10), 
   @cLoadKey         NVARCHAR( 10), 
   @cLOC             NVARCHAR( 10), 
   @cUCC             NVARCHAR( 20), 
   @tExtInfoVar      VariableTable READONLY,  
   @cExtendedInfo    NVARCHAR( 20) OUTPUT

) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @cToLoc         NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cRoute         NVARCHAR( 10)
   DECLARE @cC_Country     NVARCHAR( 30)
      
   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cToLoc = ToLoc      
         FROM dbo.Replenishment WITH (NOLOCK)      
         WHERE ReplenishmentGroup = @cReplenGroup      
         AND   RefNo = @cUCC       
         AND   StorerKey = @cStorerKey      
         AND   Confirmed = 'S'

         --for FCP(Replenishment.ToLoc = 'PICK')      
         IF RTRIM(@cToLoc) = 'PICK'      
         BEGIN      
            SELECT @cPickDetailKey = PickDetailKey
            FROM dbo.UCC WITH (NOLOCK)      
            WHERE StorerKey = @cStorerKey      
            AND   UCCNo = @cUCC      
            AND   STATUS = '5'  
            
            SELECT @cOrderKey = OrderKey
            FROM dbo.PICKDETAIL WITH (NOLOCK)
            WHERE PickDetailKey = @cPickDetailKey
            
            SELECT @cRoute = [Route], 
                   @cC_Country = C_Country
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
            
            SET @cExtendedInfo = ''
            SET @cExtendedInfo = 'ROUTE:' + RTRIM( @cRoute) + '/' + @cC_Country
         END
      END
   END
   
Quit:    
END    

GO