SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_941ExtVal01                                     */
/* Copyright      : Maersk                                              */
/* Customer       : Granite                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2024-10-01 1.0  NLT013   FCR-939 Created                             */
/* 2024-11-12 1.1  PYW009   Filter Non Damage & Hold Location Flag(PY01)*/
/************************************************************************/
CREATE   PROC rdt.rdt_941ExtVal01 (
   @nMobile                INT,
   @nFunc                  INT,
   @cLangCode              NVARCHAR( 3),
   @nStep                  INT,
   @nInputKey              INT,
   @cFacility              NVARCHAR( 5),
   @cStorerKey             NVARCHAR(15),
   @cUCC                   NVARCHAR(20),
   @cToLoc                 NVARCHAR(10),
   @tExtValidateData       VariableTable READONLY,
   @nErrNo                 INT           OUTPUT,
   @cErrMsg                NVARCHAR( 20) OUTPUT
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE 
      @cLocPickZone              NVARCHAR(10),
      @nRowCount                 INT

   IF @nFunc = 941
   BEGIN
      IF @nStep = 2
      BEGIN
         IF @nInputKey = 1
         BEGIN
            SELECT @cLocPickZone = PickZone
            FROM dbo.Loc WITH (NOLOCK) 
            WHERE Facility = @cFacility 
               AND Loc = @cToLoc
               AND loc.LocationFlag not in ('DAMAGE','HOLD') --py01

            SELECT @nRowCount = @@ROWCOUNT
            IF @nRowCount = 0
            BEGIN    
               SET @nErrNo = 225351
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidLoc'    
               GOTO Quit
            END 

            IF ISNULL(@cLocPickZone, '') <> 'PICK'
            BEGIN    
               SET @nErrNo = 225352
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidPKZone'    
               GOTO Quit
            END 
         END
      END
   END
Quit:

GO