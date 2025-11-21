SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1864ExtUpd01                                          */
/* Copyright: Maersk   		                                                   */
/*                                                                            */
/* Purpose:                              							                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2024-05-21   Dennis    1.0   Fcr336 Created                                */
/******************************************************************************/

CREATE   PROC rdt.rdt_1864ExtUpd01 (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cPickSlipNo  NVARCHAR( 10),
   @cPickZone    NVARCHAR( 10),
   @cLOC         NVARCHAR( 20)  OUTPUT,
   @cSuggLOC     NVARCHAR( 18)  OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE
   @nRowCount            INT,
   @cPalletTypeInUse     NVARCHAR( 5),
   @nCheckDigit          INT,
   @cActLoc              NVARCHAR( 20),
   @cPalletTypeSave      NVARCHAR( 10)

   IF @nFunc = 1864 -- PICK PALLET
   BEGIN
      IF @nStep IN (2,5) -- LOC
      BEGIN
         IF @nInputKey = 1  -- ENTER
         BEGIN
            SELECT
               @nCheckDigit = CheckDigitLengthForLocation
            FROM dbo.FACILITY WITH (NOLOCK)
            WHERE facility = @cFacility
      
            IF @nCheckDigit > 0 
            BEGIN
               SELECT @cActLoc = loc 
               FROM dbo.LOC WITH (NOLOCK)
               WHERE Facility = @cFacility AND CONCAT(LOC,LOCCHECKDIGIT) = @cLOC
               SET @nRowCount = @@ROWCOUNT
               IF @nRowCount > 1
               BEGIN
                  SET @nErrNo = 212603
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --212603Unique location not identified
                  GOTO QUIT
               END
               ELSE IF @nRowCount = 0
               BEGIN
                  SET @nErrNo = 212604
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --212604Loc Not Found
                  GOTO QUIT
               END
               SET @cLOC = @cActLoc
            END
         END
      END
   END

Quit:

END

GO