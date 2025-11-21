SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtUpd03                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2018-08-27 1.0  Ung      WMS-6128 Created                                  */  
/* 2018-11-08 1.1  Ung      WMS-7003 Check interface had sent (TLog2 archived)*/  
/* 2020-09-08 1.2  YeeKung  WMS-15056 add update carrierkey(yeekung01)        */
/* 2022-04-07 1.3  YeeKung  WMS-19318 Disable the trigger (yeekung02)         */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_1663ExtUpd03](
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
   DECLARE @cCarrierkey NVARCHAR(20)

   IF @nFunc = 1663 -- TrackNoToPallet
   BEGIN
      IF @nStep = 1
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Consignment planning interface 
            -- (send MBOL, IKEA return a flag, store at MBOL header, indicate permission to ship, and user close MBOL to ship)
            IF EXISTS( SELECT 1 FROM MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND STATUS = '0' AND BookingReference = 'Y' )
            BEGIN

               
               SELECT @cCarrierkey=UDF01
                FROM  dbo.CODELKUP (NOLOCK) 
               WHERE Storerkey=@cstorerkey 
                  AND LISTNAME='IKCourier' 
                  AND code2=@cFacility 
                  AND Long=LEFT(@cPalletKey,5)

               UPDATE MBOL WITH (ROWLOCK)
               SET carrierkey=@cCarrierkey
               WHERE MBOLKey = @cMBOLKey AND OtherReference = ''

               IF @@ERROR<>0
               BEGIN
                  SET @nErrNo = 128252
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdateMBOLFail
                  GOTO Quit
               END

               EXEC dbo.ispGenTransmitLog2
                    'WSMBOLADDLOG' -- TableName
                  , @cMBOLKey      -- Key1
                  , ''             -- Key2
                  , @cStorerKey    -- Key3
                  , ''             -- Batch
                  , @bSuccess  OUTPUT
                  , @nErrNo    OUTPUT
                  , @cErrMsg   OUTPUT
               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 128251
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen TLOG2 Fail
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:

END

GO