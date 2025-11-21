SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1628ExtInfo04                                   */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: UA extended info use ClusterPickNike config to show         */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2017-12-06 1.0  James    WMS3572 Created                             */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1628ExtInfo04]    
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
       
   SET @cExtendedInfo = 'ID:' + RTRIM( LEFT( @cDropID, 17))

QUIT:    
END -- End Procedure  

GO