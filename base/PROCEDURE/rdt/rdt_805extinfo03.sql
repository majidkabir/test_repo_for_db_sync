SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_805ExtInfo03                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev Author      Purposes                                  */
/* 17-12-2018 1.0 ChewKP      WMS-4538 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_805ExtInfo03] (
   @nMobile        INT,          
   @nFunc          INT,          
   @cLangCode      NVARCHAR( 3), 
   @nStep          INT,          
   @nAfterStep     INT,          
   @nInputKey      INT,          
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15),
   @tVar           VariableTable READONLY,
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSKU          NVARCHAR(20)
          ,@cStation1     NVARCHAR(10)
          ,@cWaveKey      NVARCHAR(10)
          ,@cOrderKey     NVARCHAR(10) 
          ,@cScanID       NVARCHAR(20) 
          ,@nCurrentStationQty   INT
          ,@nOtherStationQty     INT
          ,@cSKUGroup     NVARCHAR(10) 
   
   SET @nErrNo = 0
   SET @cErrMsg = ''

   IF @nFunc = 805 -- PTLStation
   BEGIN
      IF @nAfterStep = 4 -- Matrix
      BEGIN
         
         
         -- Variable mapping
         SELECT @cSKU = Value FROM @tVar WHERE Variable = '@cSKU'
         SELECT @cScanID = Value FROM @tVar WHERE Variable = '@cScanID'
         SELECT @cStation1 = Value FROM @tVar WHERE Variable = '@cStation1'

         SELECT TOP 1 @cSKUGroup = CD.Short FROM dbo.SKU SKU WITH (NOLOCK) 
         JOIN dbo.Codelkup CD WITH (NOLOCK) ON CD.StorerKey = SKU.StorerKey AND CD.Code = SKU.SUSR3 AND CD.ListName = 'SKUGROUP' 
         WHERE SKU.StorerKey = @cStorerkey  
         AND  CD.ListName = 'SKUGROUP'
         AND SKU.SKU = @cSKU
         
         SELECT TOP 1 @cOrderKey = OrderKey 
         FROM PTL.PTLTran WITH (NOLOCK) 
         WHERE DropID = @cScanID
         AND SKU = @cSKU 
         AND DeviceID = @cStation1
         AND StorerKey = @cStorerKey 
         
         SELECT @cWaveKey = UserDefine09 
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND OrderKey = @cOrderKey 
         
         SELECT @nCurrentStationQty = SUM(PD.Qty) 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         INNER JOIN rdt.rdtPTLStationLog PTL WITH (NOLOCK) ON PTL.OrderKey = PD.OrderKey 
         WHERE PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.DropID = @cScanID 
         AND PD.Status = '3'
         AND PD.WaveKey = @cWaveKey 
         AND PTL.Station = @cStation1 
         AND PTL.UserDefine02 = @cSKUGroup
         
         SELECT @nOtherStationQty = SUM(PD.Qty) 
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         INNER JOIN rdt.rdtPTLStationLog PTL WITH (NOLOCK) ON PTL.OrderKey = PD.OrderKey 
         WHERE PD.StorerKey = @cStorerKey
         AND PD.SKU = @cSKU
         AND PD.DropID = @cScanID 
         AND PD.Status = '3'
         AND PD.WaveKey = @cWaveKey 
         AND PTL.Station <> @cStation1 
         AND PTL.UserDefine02 = @cSKUGroup
         
         
         
         SET @cExtendedInfo = 'PICK:' + CAST( ISNULL(@nCurrentStationQty,0) AS NVARCHAR(4)) + ' LEFT:' + CAST( ISNULL(@nOtherStationQty,0) AS NVARCHAR(4))
         
      END
   END

Quit:

END

GO