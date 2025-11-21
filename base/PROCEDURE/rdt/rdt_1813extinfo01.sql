SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1813ExtInfo01                                   */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Show the Ship To information                                */    
/*                                                                      */    
/* Called from: rdtfnc_PalletConsolidate                                */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author      Purposes                                */    
/* 17-02-2015  1.0  James       SOS315975 Created                       */   
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1813ExtInfo01]    
   @nMobile         INT,       
   @nFunc           INT,       
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,       
   @nInputKey       INT,       
   @cStorerKey      NVARCHAR( 15), 
   @cFromID         NVARCHAR( 20), 
   @cOption         NVARCHAR( 1), 
   @cSKU            NVARCHAR( 20), 
   @nQty            INT, 
   @cToID           NVARCHAR( 20), 
   @coFieled01      NVARCHAR( 20) OUTPUT
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @cCongsineeKey     NVARCHAR( 15) 

   SET @coFieled01 = ''
   
   IF @nInputKey = 1
   BEGIN
      IF @nStep = 2
      BEGIN
         -- 1 Pallet 1 Ship To (Consignee)
         SET @cCongsineeKey = ''

         SELECT TOP 1 @cCongsineeKey = O.ConsigneeKey  
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.Orders O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
         WHERE PD.StorerKey = @cStorerKey 
         AND   PD.ID = @cFromID

         SET @coFieled01 = 'SHIP TO:' + @cCongsineeKey
      END
   END

   QUIT:

END -- End Procedure    

GO