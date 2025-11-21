SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663DecodeTK02                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2018-11-01 1.0  Ung      WMS-6883 Created                                  */
/* 2020-03-20 1.1  James    WMS-12486 Extend Trackno variable (james01)       */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1663DecodeTK02](
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
   @cTrackNo      NVARCHAR( 60) OUTPUT,   -- (james01)
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
      DECLARE @nPOS INT
      
      -- 1st delimeter
      SELECT @nPOS = CHARINDEX( '-', @cTrackNo)
      IF @nPOS > 0
      BEGIN
         -- 2nd delimeter
         SELECT @nPOS = CASE WHEN @cStorerKey IN ('18354') THEN  @nPOS ELSE  CHARINDEX( '-', @cTrackNo, @nPOS+1) END
         IF @nPOS > 0
            -- Get chars before 2nd delimeter
            SET @cTrackNo = SUBSTRING( @cTrackNo, 1, @nPOS-1) 
      END
   END

Quit:

END

GO