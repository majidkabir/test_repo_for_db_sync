SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_512ExtVal04                                     */
/* Purpose: For Ace                                                     */
/*                                                                      */
/* Called from: rdtfnc_Move_LOC                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2024-08-28  1.0  JHU151      FCR-650. Created                       */
/************************************************************************/

CREATE PROC rdt.rdt_512ExtVal04 (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFromLOC         NVARCHAR( 10),
   @cToLOC           NVARCHAR( 10),
   @cToID            NVARCHAR( 18),
   @cOption          NVARCHAR( 1), 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   
   
   IF @nFunc = 512 -- Move by LOC
   BEGIN      
      IF @nStep = 2 -- To LOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cToIDMandatory           NVARCHAR(30)
               
            SET @cToIDMandatory = rdt.RDTGetConfig( @nFunc, 'ToIDMandatory', @cStorerKey)

            IF @cToIDMandatory = '1'
            BEGIN
               IF @cToID = ''
               BEGIN
                  SET @nErrNo = 221951
                  SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --Need To ID
                  GOTO QUIT
               END
            END
         END
      END
   END

QUIT:

GO