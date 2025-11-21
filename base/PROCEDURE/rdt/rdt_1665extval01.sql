SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_1665ExtVal01                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2018-03-20 1.0  Ung      WMS-4225 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1665ExtVal01] (
   @nMobile        INT,           
   @nFunc          INT,           
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,           
   @nInputKey      INT,           
   @cFacility      NVARCHAR( 5),   
   @cStorerKey     NVARCHAR( 15), 
   @cPalletKey     NVARCHAR( 20), 
   @cMBOLKey       NVARCHAR( 10), 
   @cTrackNo       NVARCHAR( 20), 
   @cOption        NVARCHAR( 1), 
   @tVar           VariableTable  READONLY, 
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1665 -- Pallet track no inquiry
   BEGIN
      IF @nStep = 3 -- Track
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check track no in bad list
            IF NOT EXISTS( SELECT 1
               FROM PalletDetail PD WITH (NOLOCK) 
                  LEFT JOIN CartonTrack CT WITH (NOLOCK) ON (PD.CaseID = CT.TrackingNo)
                  LEFT JOIN Orders O WITH (NOLOCK) ON (CT.LabelNo = O.OrderKey)
                  LEFT JOIN CodeLKUP CL WITH (NOLOCK) ON (CL.ListName = 'SOSTSBLOCK' AND CL.Code = O.SOStatus AND CL.StorerKey = @cStorerKey AND CL.Code2 = @nFunc) -- TrackNoToPallet
               WHERE PalletKey = @cPalletKey
                  AND PD.CaseID = @cTrackNo
                  AND (O.OrderKey IS NULL -- Order had changed the tracking no
                  OR CL.Code IS NOT NULL)) -- Order status is blocked
            BEGIN
               SET @nErrNo = 127651
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Valid carton
               SET @nErrNo = -1 -- Warning
               GOTO Quit
            END
         END
      END
   END
Quit:

END

GO