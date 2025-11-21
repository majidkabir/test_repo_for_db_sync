SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtValid07                                   */
/* Purpose: Validate carton type                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-03-19 1.0  James      WMS-12366 Created                         */
/* 2021-04-01 1.1  YeeKung    WMS-16717 Add serialno and serialqty      */
/*                            Params (yeekung01)                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtValid07] (
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

   SET @nErrNo = 0

   IF @nStep = 4
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cShipperkey = o.Shipperkey
         FROM dbo.Orders o WITH (NOLOCK) 
         WHERE o.OrderKey = @cOrderkey

         IF NOT EXISTS ( SELECT 1
                         FROM dbo.CODELKUP c WITH (NOLOCK)
                         WHERE c.ListName = 'ABCarton'
                         AND   c.UDF01 = @cShipperkey
                         AND   c.Short = @cCtnType)
         BEGIN
            SET @nErrNo = 149751  -- INV CTN TYPE
            GOTO Quit
         END
      END
   END

Quit:

GO