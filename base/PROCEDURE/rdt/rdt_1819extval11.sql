SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1819ExtVal11                                    */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Validate location type                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2020-08-28   Chermaine 1.0   WMS-14921 Created                       */
/************************************************************************/

CREATE PROCEDURE rdt.rdt_1819ExtVal11
   @nMobile         INT,          
   @nFunc           INT,          
   @cLangCode       NVARCHAR( 3), 
   @nStep           INT,          
   @nInputKey       INT,           
   @cFromID         NVARCHAR( 18),
   @cSuggLOC        NVARCHAR( 10),
   @cPickAndDropLOC NVARCHAR( 10),
   @cToLOC          NVARCHAR( 10),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFacility NVARCHAR(5)

   -- Change ID
   IF @nFunc = 1819
   BEGIN
      IF @nStep = 2 -- ToLoc
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get Facility
            SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()

            -- Check ID in transit
            IF EXISTS( 
               SELECT U.ID 
               FROM UCC U WITH (NOLOCK)
               JOIN SKU S WITH (NOLOCK) ON (S.SKU = U.SKU AND S.StorerKey = U.Storerkey)
               JOIN Pack p WITH (NOLOCK) ON (S.PACKKey = P.PackKey)
               WHERE  U.ID = @cFromID
               AND U.[Status] = '1'
               GROUP BY U.ID,P.Casecnt,U.QTY
               HAVING U.QTY <> P.Casecnt)
            BEGIN
               SET @nErrNo = 158251
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoSuitableLOC
               GOTO Quit
            END
         END
      END
   END

Quit:

END

GO