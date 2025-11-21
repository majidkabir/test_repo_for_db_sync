SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_1637ExtValid13                                        */
/* Copyright      : Maersk                                                    */
/* Customer       : Inditex                                                   */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2024-08-15 1.0  NLT013     FCR-673 Created                                 */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1637ExtValid13] (
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

   DECLARE
      @nRowCount           INT,
      @cStatus             NVARCHAR( 10),
      @cOrderKey           NVARCHAR( 10),
      @cCurrentContainerNo   NVARCHAR(20),
      @cPickConfirmStatus  NVARCHAR( 1),
      @cMBOLKeyScanned     NVARCHAR( 10)

   SET @nErrNo = 0

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   IF @cPickConfirmStatus NOT IN ( '3', '5')
      SET @cPickConfirmStatus = '5'

   IF @nFunc  = 1637
   BEGIN
      IF @nStep = 3 --ContainerKey & Pallet Key
      BEGIN
         SELECT @cOrderKey = OrderKey
         FROM dbo.PickDetail WITH(NOLOCK)
         WHERE StorerKey = @cStorerkey
            AND ID = @cPalletKey
            AND Status = @cPickConfirmStatus

         SELECT @nRowCount = @@ROWCOUNT

         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 221206
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Pallet ID
            GOTO Quit
         END

         SELECT @nRowCount = COUNT(1)
         FROM dbo.ContainerDetail WITH (NOLOCK)
         WHERE ContainerKey = @cContainerKey
            AND PalletKey = @cPalletKey

         IF @nRowCount > 0
         BEGIN
            SET @nErrNo = 221207
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet ID Already Scanned
            GOTO Quit
         END

         SELECT @cMBOLKeyScanned = MBolKey
         FROM dbo.MBOLDETAIL WITH(NOLOCK)
         WHERE OrderKey = @cOrderKey

         IF @cMBOLKey <> @cMBOLKeyScanned
         BEGIN
            SET @nErrNo = 221208
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DiffMBolKey
            GOTO Quit
         END

         SELECT @cCurrentContainerNo = ExternOrderKey
         FROM dbo.ORDERS WITH(NOLOCK)
         WHERE StorerKey = @cStorerkey
            AND OrderKey = @cOrderKey

         IF @cCurrentContainerNo <> @cContainerNo
         BEGIN
            SET @nErrNo = 221209
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different Container#
            GOTO Quit
         END
      END
   END

Fail:

Quit:


GO