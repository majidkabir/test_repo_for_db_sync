SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1620ExtInfo05                                   */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: UA Extended info to show Qty pick/unpick by style           */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2017-10-30 1.0  James    WMS3313. Created                            */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1620ExtInfo05]    
   @nMobile       INT, 
   @nFunc         INT,       
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,
   @nInputKey     INT,
   @cWaveKey      NVARCHAR( 10), 
   @cLoadKey      NVARCHAR( 10), 
   @cOrderKey     NVARCHAR( 10), 
   @cDropID       NVARCHAR( 15), 
   @cStorerKey    NVARCHAR( 15), 
   @cSKU          NVARCHAR( 20), 
   @cLOC          NVARCHAR( 10), 
   @cExtendedInfo NVARCHAR( 20) OUTPUT 

AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE @cLotattable12  NVARCHAR( 30),
           @cOrdType       NVARCHAR( 10)

   SET @cExtendedInfo = ''

   IF @nStep IN (7, 8)
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cOrdType = TYPE
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                     WHERE Listname = 'ORDERTYPE'
                     AND   Code = @cOrdType
                     AND   Storerkey = @cStorerKey
                     AND   code2 = 'B2B')
         BEGIN
            IF EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND   SKU = @cSKU
                        AND   SerialNoCapture = '1')
            BEGIN
               SELECT TOP 1 @cLotattable12 = Lottable12
               FROM dbo.ORDERDETAIL WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
               AND   SKU = @cSKU
               ORDER BY 1
            END
         END

         SET @cExtendedInfo = @cLotattable12
      END   -- @nInputKey = 1
   END      -- @nStep IN (7, 8)

   QUIT:    
END -- End Procedure  

GO