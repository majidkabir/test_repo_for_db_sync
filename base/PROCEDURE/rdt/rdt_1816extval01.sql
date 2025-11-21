SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1816ExtVal01                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Validate location type                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-03-04   Ung       1.0   SOS332730 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1816ExtVal01]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cFinalLOC       NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- TM assist NMV
   IF @nFunc = 1816
   BEGIN
      IF @nStep = 1 -- FinalLOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cFromLOC NVARCHAR(10)
            DECLARE @cFromID  NVARCHAR(18)
            DECLARE @cOrderKey NVARCHAR(10)
            DECLARE @cLoadKey  NVARCHAR(10)
            
            SET @cFromLOC = ''
            SET @cFromID = ''
            SET @cOrderKey = ''
            SET @cLoadKey = ''

            -- Check LOC category
            IF NOT EXISTS( SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @cFinalLOC AND LocationCategory = 'STAGING')
            BEGIN
               SET @nErrNo = 52201
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not stage LOC
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO