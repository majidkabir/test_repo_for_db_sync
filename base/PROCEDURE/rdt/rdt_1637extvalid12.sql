SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_1637ExtValid12                                        */
/* Copyright      : Maersk                                                    */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2023-10-20 1.0  Ung        WMS-23860 Created                               */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1637ExtValid12] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cStorerkey    NVARCHAR( 15),
   @cContainerKey NVARCHAR( 10),
   @cContainerNo  NVARCHAR( 20),
   @cMBOLKey      NVARCHAR( 10),
   @cSSCCNo       NVARCHAR( 20),
   @cPalletKey    NVARCHAR( 30),
   @cTrackNo      NVARCHAR( 20),
   @cOption       NVARCHAR( 1),
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nStep = 3 -- PalletKey
   BEGIN
      IF @nInputKey = 1  -- ENTER
      BEGIN
         DECLARE @cCurrPalletKey NVARCHAR( 30)
         DECLARE @cCurrOrderKey  NVARCHAR( 45)
         DECLARE @cNewOrderKey   NVARCHAR( 45)

         -- Check pallet valid
         IF NOT EXISTS( SELECT 1
            FROM dbo.LOTxLOCxID WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
               AND ID = @cPalletKey
               AND QTYPicked > 0)
         BEGIN
            SET @nErrNo = 207601
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid PLKey
            GOTO Fail
         END

         -- Get any existing pallet
         SET @cCurrPalletKey = ''
         SELECT TOP 1
            @cCurrPalletKey = PalletKey
         FROM ContainerDetail WITH (NOLOCK)
         WHERE ContainerKey = @cContainerKey

         -- There is existing pallet
         IF @cCurrPalletKey <> ''
         BEGIN
            -- Get current pallet order
            SELECT TOP 1
               @cCurrOrderKey = PD.OrderKey
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LLI.LOT = PD.LOT AND LLI.LOC = PD.LOC AND LLI.ID = PD.ID)
            WHERE LLI.ID = @cCurrPalletKey

            -- Get new pallet order
            SELECT TOP 1
               @cNewOrderKey = PD.OrderKey
            FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LLI.LOT = PD.LOT AND LLI.LOC = PD.LOC AND LLI.ID = PD.ID)
            WHERE LLI.ID = @cPalletKey

            -- Check same order
            IF @cCurrOrderKey <> @cNewOrderKey
            BEGIN
               SET @nErrNo = 207602
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Diff order
               GOTO Fail
            END
         END
      END
   END

Fail:


GO