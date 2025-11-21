SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LOCLookUp_CheckDigit                            */
/* Purpose: Return loc with prefix or custom method                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-05-21 1.0  Dennis     FCR-336 Check Digit                       */
/************************************************************************/

CREATE   PROC rdt.rdt_LOCLookUp_CheckDigit (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cStorerkey  NVARCHAR( 15), 
   @cFacility   NVARCHAR( 5), 
   @cLOC        NVARCHAR( 20) OUTPUT, 
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPrefix  NVARCHAR( 10)
   DECLARE
   @nRowCount            INT,
   @cPalletTypeInUse     NVARCHAR( 5),
   @nCheckDigit          INT,
   @cActLoc              NVARCHAR( 20),
   @cPalletTypeSave      NVARCHAR( 10)

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

QUIT:


GO