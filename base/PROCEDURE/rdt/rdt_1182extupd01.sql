SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1182ExtUpd01                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 19-Jun-2019 1.0  James       WMS-9423 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_1182ExtUpd01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @tExtUpdate     VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cExternOrderKey   NVARCHAR( 20)
   DECLARE @cPalletStorerKey  NVARCHAR( 20)
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cCartonCount      NVARCHAR( 5)
   DECLARE @cPalletKey        NVARCHAR( 20)

   -- Variable mapping
   SELECT @cPalletStorerKey = Value FROM @tExtUpdate WHERE Variable = '@cPalletStorerKey'
   SELECT @cOrderKey = Value FROM @tExtUpdate WHERE Variable = '@cOrderKey'
   SELECT @cCartonCount = Value FROM @tExtUpdate WHERE Variable = '@cCartonCount'
   SELECT @cPalletKey = Value FROM @tExtUpdate WHERE Variable = '@cPalletKey'

   IF @nStep = 3 -- Pallet Key
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SELECT @cExternOrderKey = ExternOrderKey
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         UPDATE dbo.OTMIDTRACK WITH (ROWLOCK) SET 
            MUType = 'OTMPLT',
            Length = 1,
            Width = 1,
            Height = 1,
            GrossVolume = 1,
            GrossWeight = 1,
            OrderID = @cExternOrderKey,
            ExternOrderKey = @cExternOrderKey
         WHERE PalletKey = @cPalletKey
         AND   ExternOrderKey = @cOrderKey
         AND   Principal = @cPalletStorerKey

         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 139851
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --EXTUPD OTM ERR
            GOTO Quit
         END
      END
   END

   Quit:

END

GO