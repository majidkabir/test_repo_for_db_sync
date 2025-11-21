SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_513ExtInfo03                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Display SKU pack configuration                                    */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2020-10-14   Chermaine 1.0   WMS-14688 Created                             */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_513ExtInfo03]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cStorerKey      NVARCHAR( 15),
   @cFacility       NVARCHAR(  5),
   @tExtInfo       VariableTable READONLY,  
   @cExtendedInfo  NVARCHAR( 20) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFromLOC       NVARCHAR( 10)
   DECLARE @cPutawayZone   NVARCHAR( 10)

   -- Variable mapping
   SELECT @cFromLOC = Value FROM @tExtInfo WHERE Variable = '@cFromLOC'


   IF @nStep = 3 -- SKU
   BEGIN
      IF @nInputKey = 1 -- Enter
      BEGIN
         SELECT @cPutawayZone = putawayZone
         FROM dbo.LOC WITH (NOLOCK)
         WHERE LOC = @cFromLOC
         AND   Facility  = @cFacility

         SET @cExtendedInfo = @cPutawayZone
      END
   END

END
GOTO Quit

Quit:


GO