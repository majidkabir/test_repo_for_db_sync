SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_808DispSCS01                                          */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Display SKU Chinese Descr using                                   */
/*          OrderDetail.UserDefine01 + OrderDetail.UserDefine02               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 19-01-2015 1.0  James    SOS330799 Created                                 */
/* 29-05-2015 1.1  Ung      SOS336312 Migrate from rdt_HnMDispSCS01           */
/******************************************************************************/

CREATE PROC [RDT].[rdt_808DispSCS01] (
    @nMobile    INT         
   ,@nFunc      INT         
   ,@cLangCode  NVARCHAR( 3)
   ,@nStep      INT 
   ,@nInputKey  INT 
   ,@cFacility  NVARCHAR( 5)
   ,@cStorerKey NVARCHAR( 15)
   ,@cDPLKey    NVARCHAR(10)
   ,@cCartID    NVARCHAR(10)
   ,@cPickZone  NVARCHAR(10)
   ,@cMethod    NVARCHAR(10)
   ,@cLOC       NVARCHAR(10)
   ,@cSKU       NVARCHAR(20)
   ,@cToteID    NVARCHAR(10)
   ,@nErrNo     INT          OUTPUT
   ,@cErrMsg    NVARCHAR(20) OUTPUT
   ,@cSKUDescr  NVARCHAR(60) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUserDefine01 NCHAR( 18)
   DECLARE @cUserDefine02 NCHAR( 18)
   DECLARE @cOrderKey     NVARCHAR( 10) 
            
   SET @cUserDefine01 = ''
   SET @cUserDefine02 = ''
   SET @cOrderKey = ''
   
   -- Get any orders with this SKU
   SELECT TOP 1 
      @cOrderKey = OrderKey 
   FROM dbo.PTLTran WITH (NOLOCK) 
   WHERE DeviceProfileLogKey = @cDPLKey
      AND StorerKey = @cStorerKey
      AND SKU = @cSKU
      AND OrderKey <> ''

   IF @cOrderKey <> ''
   BEGIN
      SELECT TOP 1 
         @cUserDefine01 = ISNULL( UserDefine01, ''), 
         @cUserDefine02 = ISNULL( UserDefine02, '') 
      FROM dbo.OrderDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey
         AND SKU = @cSKU
      
      SET @cSKUDescr = 
         @cUserDefine01 + SPACE(2) + 
         @cUserDefine02 + SPACE(2)
   END
   
Quit:

END

GO