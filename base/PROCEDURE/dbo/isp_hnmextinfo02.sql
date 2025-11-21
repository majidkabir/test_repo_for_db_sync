SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: isp_HnMExtInfo02                                     */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Extended Info (to determine the param pass into printing)   */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2014-06-12 1.0  James    SOS304122 Created                           */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_HnMExtInfo02]  
   @nMobile         INT,       
   @nFunc           INT,       
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT,       
   @nInputKey       INT,       
   @cStorerKey      NVARCHAR( 15),  
   @cOrderKey       NVARCHAR( 10), 
   @cPickZone       NVARCHAR( 10), 
   @cSuggestedLOC   NVARCHAR( 10), 
   @cFinalLoc       NVARCHAR( 10), 
   @cExtendedInfo   NVARCHAR( 20) OUTPUT  

AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @nSum_Qty        INT, 
           @nPickZone_Cnt   INT 
   
   SET @nPickZone_Cnt = 0
   SET @nSum_Qty = 0

   SELECT @nSum_Qty = ISNULL( SUM( QTY), 0)
   FROM dbo.PickDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey  
   AND   OrderKey = @cOrderKey  

   SELECT @nPickZone_Cnt = COUNT( DISTINCT LOC.PickZone)
   FROM dbo.PickDetail PD WITH (NOLOCK) 
   JOIN dbo.LOC LOC WITH (NOLOCK) ON PD.LOC = LOC.LOC
   WHERE PD.StorerKey = @cStorerKey
   AND   PD.OrderKey = @cOrderKey
      
   IF @nSum_Qty = 1
      SET @cExtendedInfo = '1'
      
   IF @nSum_Qty > 1
   BEGIN
      IF @nPickZone_Cnt = 1
         SET @cExtendedInfo = '9'
      ELSE
         SET @cExtendedInfo = '2'
   END

QUIT:  
END -- End Procedure  


GO