SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1663ExtChkSOSt01                                      */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2019-08-14 1.0  James    WMS-10127 Created                                 */
/* 2020-09-11 1.1  YeeKung  WMS-14482 change code2=facility and short=func    */
/*                          (yeekung01)                                       */  
/******************************************************************************/

CREATE PROC [RDT].[rdt_1663ExtChkSOSt01](
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
   @cSOStatus     NVARCHAR( 10),
   @tValidateSOStatus VariableTable READONLY,
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cDeliveryNote  NVARCHAR( 10)

   IF @nFunc = 1663 -- TrackNoToPallet
   BEGIN
      IF @nStep = 3 -- Track no
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cDeliveryNote = DeliveryNote 
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            IF @cSOStatus IN ('PENDHOLD', 'PENDPACK', 'HOLD')
            BEGIN
               IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                           WHERE LISTNAME = 'DNoteToChk'
                           AND   Storerkey = @cStorerKey
                           AND   Code = @cDeliveryNote
                           AND   Short = @nFunc 
                           AND   code2 = @cFacility )  --(yeekung01)
               GOTO Quit
            END

            -- Check extern status
            IF @cSOStatus = 'HOLD'
            BEGIN
               SET @nErrNo = 143151
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order on HOLD
               GOTO Quit
            END

            ELSE IF @cSOStatus = 'PENDPACK'
            BEGIN
               SET @nErrNo = 143152
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pending Update
               GOTO Quit
            END

            ELSE IF @cSOStatus = 'PENDCANC'
            BEGIN
               SET @nErrNo = 143153
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pending CANC
               GOTO Quit
            END

            ELSE IF @cSOStatus = 'CANC'
            BEGIN
               SET @nErrNo = 143154
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL
               GOTO Quit
            END

            ELSE IF @cSOStatus = 'PACK&HOLD'
            BEGIN
               SET @nErrNo = 143155
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderPACK&HOLD
               GOTO Quit
            END


            ELSE IF @cSOStatus = 'PENDHOLD'
            BEGIN
               SET @nErrNo = 143156
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pending Hold
               GOTO Quit
            END

            -- Check SOStatus blocked
            IF EXISTS( SELECT TOP 1 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'SOSTSBLOCK' AND Code = @cSOStatus AND StorerKey = @cStorerKey AND Code2 = @nFunc)
            BEGIN
               SET @nErrNo = 143157
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Status blocked
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO