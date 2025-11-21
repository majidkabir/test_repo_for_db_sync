SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1637ExtValid06                                  */
/* Copyright      : LF Logistics                                        */  
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2020-08-06 1.0  James      WMS-14252 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1637ExtValid06] (
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
         IF NOT EXISTS ( SELECT 1  
                         FROM dbo.MBOL WITH (NOLOCK)
                         WHERE ExternMbolKey = @cPalletKey
                         AND   [Status] = '5')
         BEGIN
            SET @nErrNo = 156651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet Not Close
            GOTO Fail         
         END
      END
   END

Fail:


GO