SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_HnMDispSCS01                                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Display SKU Chinese Descr using                                   */
/*          OrderDetail.UserDefine01 + OrderDetail.UserDefine02               */
/*                                                                            */
/* Called from: rdtfnc_PTL_OrderPicking                                       */
/* Date       Rev  Author   Purposes                                          */
/* 19-01-2015 1.0  James    SOS330799 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_HnMDispSCS01] (
   @nMobile      INT,  
   @nFunc        INT,  
   @nStep        INT,  
   @nInputKey    INT,  
   @cStorerKey   NVARCHAR( 15),  
   @cCartID      NVARCHAR( 10),  
   @cPickZone    NVARCHAR( 10),  
   @cLoc         NVARCHAR( 10),  
   @cSKU         NVARCHAR( 20),  
   @cLottable02  NVARCHAR( 18),  
   @dLottable04  DATETIME,   
   @cPDDropID    NVARCHAR( 20),  
   @c_oFieled01  NVARCHAR( 20)  OUTPUT,  
   @c_oFieled02  NVARCHAR( 20)  OUTPUT,  
   @c_oFieled03  NVARCHAR( 20)  OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @cUserDefine01 NVARCHAR( 18), 
            @cUserDefine02 NVARCHAR( 18), 
            @cOrderKey     NVARCHAR( 10) 
            
   SET @c_oFieled01 = ''
   SET @c_oFieled02 = ''
   SET @c_oFieled03 = ''
   SET @cUserDefine01 = ''
   SET @cUserDefine02 = ''

   IF @nInputKey <> 1
      GOTO Quit

   SELECT TOP 1 @cOrderKey = OrderKey 
   FROM dbo.PTLTran WITH (NOLOCK) 
   WHERE DeviceID = @cCartID
   AND   StorerKey = @cStorerKey
   AND   SKU = @cSKU
   AND   [Status] < '9'

   IF ISNULL( @cOrderKey, '') <> ''
   BEGIN
      SELECT TOP 1 
         @cUserDefine01 = UserDefine01, 
         @cUserDefine02 = UserDefine02 
      FROM dbo.OrderDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   OrderKey = @cOrderKey
      AND   SKU = @cSKU
      
      SET @c_oFieled01 = SUBSTRING( RTRIM( @cUserDefine01), 1, 18)
      SET @c_oFieled02 = SUBSTRING( RTRIM( @cUserDefine02), 1, 18)
   END
   
Quit:

END

GO