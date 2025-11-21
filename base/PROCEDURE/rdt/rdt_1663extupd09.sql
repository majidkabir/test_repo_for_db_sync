SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtUpd09                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2022-06-03 1.0  Ung      WMS-19821 Created                                 */  
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1663ExtUpd09](
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
   @cTrackNo      NVARCHAR( 20), 
   @cOrderKey     NVARCHAR( 10), 
   @cShipperKey   NVARCHAR( 15),  
   @cCartonType   NVARCHAR( 10),  
   @cWeight       NVARCHAR( 10), 
   @cOption       NVARCHAR( 1),  
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess INT

   IF @nFunc = 1663 -- TrackNoToPallet    
   BEGIN    
      IF @nStep = 3 OR -- Track no    
         @nStep = 4 OR -- Weight    
         @nStep = 5    -- Carton type    
      BEGIN    
         IF @nInputKey = 1 -- ENTER    
         BEGIN   
            EXEC dbo.ispGenTransmitLog3
                 'SCPLRDTLOG' -- TableName
               , @cOrderKey   -- Key1
               , ''           -- Key2
               , @cStorerKey  -- Key3
               , ''           -- Batch
               , @bSuccess  OUTPUT
               , @nErrNo    OUTPUT
               , @cErrMsg   OUTPUT
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 187101
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen TLOG3 Fail
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO