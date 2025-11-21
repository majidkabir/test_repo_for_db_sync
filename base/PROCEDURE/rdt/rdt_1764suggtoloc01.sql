SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1764SuggToLoc01                                       */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date        Rev  Author    Purposes                                        */
/* 2021-05-07  1.0  James     WMS-16964. Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1764SuggToLoc01] (
   @nMobile            INT,
   @nFunc              INT,
   @cLangCode          NVARCHAR( 3),
   @cUserName          NVARCHAR( 18),
   @cTaskDetailKey     NVARCHAR( 10),
   @cSuggToLOC         NVARCHAR( 10),
   @cNewSuggToLOC      NVARCHAR( 10) OUTPUT,
   @nErrNo             INT           OUTPUT,
   @cErrMsg            NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @cLocAisle      NVARCHAR( 10)
   DECLARE @cToLoc         NVARCHAR( 10)
   
   SELECT @cStorerKey = StorerKey,
          @cFacility = Facility
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   SELECT @cToLoc = ToLoc
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey
   
   SELECT @cLocAisle = LocAisle
   FROM dbo.LOC WITH (NOLOCK)
   WHERE Loc = @cToLoc
   AND   Facility = @cFacility
   
   SELECT @cNewSuggToLOC = Code
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE LISTNAME = 'PND'
   AND   Storerkey = @cStorerKey
   AND   Long = 'IN'
   AND   code2 = @cLocAisle
   
   --INSERT into traceinfo (tracename, timein, col1, col2, col3, col4, col5, step1, step2) values
   --('123', getdate(), @cToLoc, @cTaskDetailKey, @cLocAisle, @cStorerKey, @cFacility, @cNewSuggToLOC, @nMobile)
END

GO