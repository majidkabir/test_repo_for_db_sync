SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/    
/* Store procedure: rdt_1723DecodSKUSP01                                      */    
/* Copyright: LF Logistics                                                    */    
/*                                                                            */    
/* Purpose: Decode carton id                                                  */    
/*                                                                            */    
/* Called from: rdtfnc_PalletConsolidate_SSCC                                 */    
/*                                                                            */    
/*                                                                            */    
/* Date        Author    Ver.  Purposes                                       */      
/* 03-March-2021  yeekung  1.0    WMS-18008 Created                           */        
/******************************************************************************/    
    
CREATE PROC [RDT].[rdt_1723DecodSKUSP01] (    
   @nMobile         INT,     
   @nFunc           INT,     
   @cLangCode       NVARCHAR( 3),     
   @nStep           INT,      
   @nInputKey       INT,     
   @cStorerKey      NVARCHAR( 15),     
   @cFromID         NVARCHAR( 18),     
   @cToID           NVARCHAR( 18),     
   @cOption         NVARCHAR( 10),     
   @cSKU            NVARCHAR( 20)  OUTPUT,     
   @nQty            INT            OUTPUT,        
   @nErrNo          INT            OUTPUT,     
   @cErrMsg         NVARCHAR( 20)  OUTPUT    
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   IF EXISTS (SELECT 1 from SKU (NOLOCK)
               where sku=@cSKU
               and storerkey=@cStorerKey)
   BEGIN
      SET @nErrNo = 97752
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
      GOTO quit
   END

    
Quit:    

Fail:    
END 

GO