SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtValid06                                   */
/* Purpose: Validate carton type                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2019-11-19 1.0  James      WMS-11146 Created                         */
/* 2020-10-06 1.1  James      WMS-14288 Add check HM Order # (james01)  */
/* 2021-04-01 1.2  YeeKung    WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtValid06] (
   @nMobile                   INT,
   @nFunc                     INT,
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT,
   @nInputKey                 INT, 
   @cStorerkey                NVARCHAR( 15),
   @cOrderKey                 NVARCHAR( 10),
   @cPickSlipNo               NVARCHAR( 10),
   @cTrackNo                  NVARCHAR( 20),
   @cSKU                      NVARCHAR( 20),
   @nCartonNo                 INT,
   @cCtnType                  NVARCHAR( 10),
   @cCtnWeight                NVARCHAR( 10),
   @cSerialNo                 NVARCHAR( 30), 
   @nSerialQTY                INT, 
   @nErrNo                    INT           OUTPUT,
   @cErrMsg                   NVARCHAR( 20) OUTPUT 
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cShipperkey          NVARCHAR( 15)
   DECLARE @cLabelNo             NVARCHAR( 20)
   DECLARE @cLot                 NVARCHAR( 10)
   DECLARE @cLottable12          NVARCHAR( 30)
   DECLARE @cPackSKU             NVARCHAR( 20)
   DECLARE @cBarcode             NVARCHAR( 60)
   DECLARE @cLottable02          NVARCHAR( 18)
   DECLARE @cUPC                 NVARCHAR( 30)
   DECLARE @nIsMoveOrder         INT
   
   SET @nErrNo = 0

   IF @nStep = 3
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)
                  JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Userdefine03 AND C.StorerKey = O.StorerKey)
                  WHERE C.ListName = 'HMCOSORD'
                  AND   C.UDF01 = 'M'
                  AND   O.OrderKey = @cOrderkey
                  AND   O.StorerKey = @cStorerKey)
         SET @nIsMoveOrder = 1
      ELSE
         SET @nIsMoveOrder = 0

      -- Move order only check 
      IF @nIsMoveOrder = 0
         GOTO Quit

      -- (james01)
      SELECT TOP 1 @cLabelNo = LabelNo, 
                   @cPackSKU = SKU,
                   @cUPC = UPC
      FROM dbo.PackDetail WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo
      AND   CartonNo = @nCartonNo
      ORDER BY 1

      -- Not yet pack anything for this carton 
      -- then no need further check      
      IF @@ROWCOUNT = 0
         GOTO Quit
      
      SET @cLottable02 = SUBSTRING( RTRIM( @cUPC), 16, 12) 
      SET @cLottable02 = RTRIM( @cLottable02) + '-' 
      SET @cLottable02 = RTRIM( @cLottable02) + SUBSTRING( RTRIM( @cUPC), 28, 2) 

      SELECT TOP 1 @cLottable12 = LA.Lottable12
      FROM dbo.PICKDETAIL PD WITH (NOLOCK) 
      JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON (PD.Lot = LA.Lot)
      WHERE PD.StorerKey = @cStorerkey
      AND   PD.OrderKey = @cOrderKey
      AND   PD.SKU = @cPackSKU
      AND   LA.Lottable02 = @cLottable02
      ORDER BY 1 
      
      SELECT @cBarcode = I_Field06
      FROM rdt.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile
      
      IF SUBSTRING( @cBarcode, 22, 6 ) <> @cLottable12
      BEGIN
         SET @nErrNo = 146052  -- HMORD# X MATCH
         GOTO Quit
      END
   END
   
   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cShipperkey = o.Shipperkey
         FROM dbo.Orders o WITH (NOLOCK) 
         WHERE o.OrderKey = @cOrderkey

         IF NOT EXISTS ( SELECT 1
                         FROM dbo.CODELKUP c WITH (NOLOCK)
                         WHERE c.ListName = 'COSCarton'
                         AND   c.UDF01 = @cShipperkey
                         AND   c.Short = @cCtnType)
         BEGIN
            SET @nErrNo = 146051  -- INV CTN TYPE
            GOTO Quit
         END
      END
   END

Quit:

GO