SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1766DefCCOpt01                                  */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Purpose: Default option based on loc attribute                       */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2021-05-08  1.0  James     WMS-16965 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1766DefCCOpt01] (
   @nMobile            INT,
   @nFunc              INT,
   @cLangCode          NVARCHAR( 3),
   @nStep              INT,
   @nInputKey          INT,
   @cFacility          NVARCHAR( 15),
   @cStorerKey         NVARCHAR( 15),
   @cTaskdetailkey     NVARCHAR( 20),
   @cDefaultCCOption   NVARCHAR( 20)  OUTPUT
 
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFromLoc    NVARCHAR( 10)
   DECLARE @nIsLoseUCC  INT = 0
   
   SELECT @cFromLoc = FromLoc
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskdetailkey

   SELECT @nIsLoseUCC = LoseUCC
   FROM dbo.Loc WITH (NOLOCK)
   WHERE Loc = @cFromLoc
   AND   Facility = @cFacility
   
      IF @nStep IN (1, 2) 
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @nIsLoseUCC = 0
               SET @cDefaultCCOption = '1'
            ELSE
               SET @cDefaultCCOption = '2'
         END
      END

END

Quit:

SET QUOTED_IDENTIFIER OFF

GO