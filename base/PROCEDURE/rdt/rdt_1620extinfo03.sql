SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_1620ExtInfo03                                   */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: NIKE TH show qty scanned to drop id                         */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2018-05-30 1.0  James    WMS5199 - Created                           */    
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1620ExtInfo03]    
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
       
   DECLARE @nPDQty      INT,
           @nPLQty      INT,
           @cUserName   NVARCHAR( 18)

   SELECT @cUserName = UserName
   FROM rdt.rdtMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nPDQty = 0
   SET @nPLQty = 0

   IF @nInputKey = 1
   BEGIN
      --IF @nStep = 8
      --BEGIN
         SELECT @nPDQty = ISNULL( SUM( Qty), 0)
         FROM dbo.PICKDETAIL WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
         AND   OrderKey = @cOrderKey
         AND   Dropid = @cDropID
         AND   [Status] < '9'

         SELECT @nPLQty = ISNULL( SUM( PickQty), 0)
         FROM RDT.rdtPickLock WITH (NOLOCK)
         WHERE DropID = @cDropID
         AND   [Status] = '1'
         AND   AddWho = @cUserName
         AND   OrderKey = @cOrderKey
         AND   Storerkey = @cStorerKey
      --END
      --ELSE
      --BEGIN
      --   SELECT @nPDQty = ISNULL( SUM( Qty), 0)
      --   FROM dbo.PICKDETAIL WITH (NOLOCK)
      --   WHERE Storerkey = @cStorerKey
      --   AND   OrderKey = @cOrderKey
      --   AND   Dropid = @cDropID
      --   AND   [Status] < '9'
      --END
   END

   SET @cExtendedInfo = 'TQTY: ' + CAST( ( @nPDQty + @nPLQty) AS NVARCHAR( 3))

QUIT:    
END -- End Procedure  

GO