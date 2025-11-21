SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispMoveByIDToLOCLKUP                                */
/* Copyright: IDS                                                       */
/* Purpose: Lookup ToLOC                                                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2012-05-25   Ung       1.0   SOS243024 Lookup ToLOC                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispMoveByIDToLOCLKUP]
   @cFromID    NVARCHAR( 18), 
   @cFromLOC   NVARCHAR( 10), 
   @cStorerKey NVARCHAR( 15), 
   @cSKU       NVARCHAR( 20), 
   @cToLOC     NVARCHAR( 10) OUTPUT 
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
   SELECT @cToLOC = LEFT( RTRIM( ISNULL( @cUserDefine03, '')) + RTRIM( @cToLOC), 10)
END

GO