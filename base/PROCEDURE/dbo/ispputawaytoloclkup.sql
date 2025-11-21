SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispPutawayToLOCLKUP                                 */
/* Copyright: IDS                                                       */
/* Purpose: Lookup ToLOC                                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2012-04-04   Ung       1.0   SOS239385 Lookup ToLOC                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPutawayToLOCLKUP]
   @cFromID    NVARCHAR( 18), 
   @cFromLOC   NVARCHAR( 10), 
   @cStorerKey NVARCHAR( 15), 
   @cSKU       NVARCHAR( 20), 
   @cFinalLOC  NVARCHAR( 10) OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFacility NVARCHAR( 5)
   DECLARE @cUserDefine03 NVARCHAR( 30)
   
   SELECT @cFacility = Facility FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cFromLOC
   SELECT @cUserDefine03 = UserDefine03 FROM dbo.Facility WITH (NOLOCK) WHERE Facility = @cFacility 
   SELECT @cFinalLOC = LEFT( RTRIM( ISNULL( @cUserDefine03, '')) + RTRIM( @cFinalLOC), 10)
END

GO