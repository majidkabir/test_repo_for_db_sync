SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_BebeExtInfoSP01                                 */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: Inditex PPA Extended info                                   */    
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2012-12-24 1.0  ChewKP   SOS#303019 Created                          */    
/* 2014-05-14 1.1  James    Output extended info (james01)              */
/* 2015-03-26 1.2  James    SOS336885 - Extend variable (james02)       */
/************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_BebeExtInfoSP01]    
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
       
   DECLARE @nUnPickQty     INT,
           @nTtl2PickQty   INT, 
           @nMultiStorer   INT, 
           @nPickQty       INT, 
           @cUserName      NVARCHAR( 18)

   SET @cExtendedInfo = ''

   SELECT @cOrderKey = V_OrderKey, 
          @nMultiStorer = V_String37, 
          @cUserName = UserName 
   FROM rdt.rdtMobrec WITH (NOLOCK) WHERE Mobile = @nMobile

   SELECT @nPickQty = ISNULL( SUM( PickQty), 0) 
   FROM RDT.RDTPICKLOCK WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey
      AND StorerKey = CASE WHEN @nMultiStorer = 1 THEN StorerKey ELSE @cStorerKey END     --tlting03
      AND SKU = @cSKU
      AND LOC = @cLOC
      --AND DropID = @cDropID
      AND Status = '1'
      AND AddWho = @cUserName


--   IF rdt.RDTGetConfig( @nFunc, 'SHOWQTYPICK/UNPICK', @cStorerKey) = '1'
--   BEGIN
      -- If no loadkey then try look for loadkey from orders
      IF ISNULL( @cLoadKey, '') = ''
         SELECT @cLoadKey = LoadKey FROM dbo.Orders WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   OrderKey = @cOrderKey

      -- If still no loadkey then calc qty by orders only
      IF ISNULL( @cLoadKey, '') = ''
      BEGIN
         SELECT @nUnPickQty = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   OrderKey = @cOrderKey
         AND   [Status] = '0'

         SELECT @nTtl2PickQty = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   OrderKey = @cOrderKey
      END
      ELSE-- found loadkey then calc qty by load
      BEGIN
         SELECT @nUnPickQty = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
         WHERE PD.StorerKey = @cStorerKey
         AND   PD.Status = '0'
         AND   LPD.LoadKey = @cLoadKey

         SELECT @nTtl2PickQty = ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PD.OrderKey = LPD.OrderKey
         WHERE PD.StorerKey = @cStorerKey
         AND   LPD.LoadKey = @cLoadKey
      END

      SET @nUnPickQty = @nUnPickQty - @nPickQty
--      SET @cExtendedInfo = 'OS QTY: ' + CAST(@nUnPickQty AS NVARCHAR(3)) + '/'
--                                      + CAST(@nTtl2PickQty AS NVARCHAR(4)) 
      -- (james02)
      SET @cExtendedInfo = 'OS QTY: ' + CAST(@nUnPickQty AS NVARCHAR(5)) + '/'
                                      + CAST(@nTtl2PickQty AS NVARCHAR(5)) 
--  END
--     INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3, COL4, COL5) VALUES 
--     ('BB', GETDATE(), @cLoadKey, @cOrderKey, @nUnPickQty, @nTtl2PickQty, @nPickQty)
QUIT:    
END -- End Procedure  

GO