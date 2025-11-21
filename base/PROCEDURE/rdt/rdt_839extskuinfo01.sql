SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_839ExtSkuInfo01                                 */    
/* Copyright      : LF                                                  */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2020-10-12 1.0  James    WMS-14522. Created                          */  
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_839ExtSkuInfo01]    
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5) , 
   @cStorerKey   NVARCHAR( 15), 
   @cType        NVARCHAR( 10), 
   @cPickSlipNo  NVARCHAR( 10), 
   @cPickZone    NVARCHAR( 10), 
   @cDropID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,           
   @cExtDescr1   NVARCHAR( 20) OUTPUT, 
   @cExtDescr2   NVARCHAR( 20) OUTPUT   

AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   SET @cExtDescr1 = ''
   SET @cExtDescr2 = ''
      
   SELECT @cExtDescr1 = ManufacturerSKU
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   Sku = @cSKU 
   
Quit:
    
END

GO