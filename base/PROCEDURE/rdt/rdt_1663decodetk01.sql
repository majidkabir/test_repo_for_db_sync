SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663DecodeTK01                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2018-10-02 1.0  Ung      WMS-6516 Created                                  */
/* 2018-11-01 1.1  Ung      WMS-6883 DecodeTrackNoSP output TrackNo           */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1663DecodeTK01](
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPalletKey    NVARCHAR( 20), 
   @cPalletLOC    NVARCHAR( 10), 
   @cMBOLKey      NVARCHAR( 10), 
   @cTrackNo      NVARCHAR( 20) OUTPUT, 
   @cOrderKey     NVARCHAR( 10) OUTPUT, 
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1663 -- TrackNoToPallet
   BEGIN
      -- Get order info
      SELECT @cOrderKey = OrderKey
      FROM PickHeader WITH (NOLOCK) 
      WHERE PickHeaderKey = @cTrackNo
      
      -- Check track no valid
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 129651
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidTrackNo
         GOTO Quit
      END

      -- Check track no valid
      IF @cOrderKey = ''
      BEGIN
         SET @nErrNo = 129652
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No order
         GOTO Quit
      END
   END

Quit:

END

GO