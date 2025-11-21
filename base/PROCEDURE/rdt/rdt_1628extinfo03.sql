SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1628ExtInfo03                                   */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Nike extended info                                          */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2017-12-06 1.0  James    WMS3572 Created                             */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1628ExtInfo03]    
   @nMobile          INT, 
   @nFunc            INT,       
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,
   @nInputKey        INT,
   @cWaveKey         NVARCHAR( 10), 
   @cLoadKey         NVARCHAR( 10), 
   @cOrderKey        NVARCHAR( 10), 
   @cDropID          NVARCHAR( 20), 
   @cStorerKey       NVARCHAR( 15), 
   @cSKU             NVARCHAR( 20), 
   @cLOC             NVARCHAR( 10), 
   @cExtendedInfo    NVARCHAR( 20) OUTPUT 

AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @cPackUOM3            NVARCHAR( 10),
           @nPackQtyIndicator    INT,
           @nTTL_Pick_ORD        INT,
           @nTTL_UnPick_ORD      INT

   SELECT @cPackUOM3 = PackUOM3,
          @nPackQtyIndicator = PackQtyIndicator
   FROM dbo.SKU SKU WITH (NOLOCK)
   JOIN dbo.Pack PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey
   WHERE SKU.StorerKey = @cStorerKey
   AND   SKU.SKU = @cSKU

   -- Get the total qty picked per orders
   SELECT @nTTL_Pick_ORD = ISNULL( SUM(PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK)
   JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
   WHERE PD.StorerKey = @cStorerKey
      AND LPD.LoadKey = @cLoadKey

   -- Get the total qty unpick per orders
   SELECT @nTTL_UnPick_ORD = ISNULL( SUM(PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK)
   JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
   WHERE PD.StorerKey = @cStorerKey
      AND PD.Status >= '3'
      AND LPD.LoadKey = @cLoadKey

   SET @cExtendedInfo = 'LQTY:' + 
                        RTRIM( CAST( @nTTL_UnPick_ORD AS NVARCHAR( 4))) + 
                        '/' + 
                        RTRIM( CAST( @nTTL_Pick_ORD AS NVARCHAR( 4))) + 
                        ' ' + 
                        LEFT( @cPackUOM3, 2) + ' ' + 
                        CAST( @nPackQtyIndicator AS NVARCHAR( 4))
   --LQTY: + 9999 (total qty picked, max. 4 digits) + / + 9999 (total qty to be picked, max. 4 digits) + " " + Pack.PackUOM3 (max. 2 chars) + " " + SKU.PackQtyIndicator (max. 2 chars)

QUIT:    
END -- End Procedure  

GO