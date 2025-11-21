SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1797ExtInfo01                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2019-12-18  1.0  James    WMS11394. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_1797ExtInfo01] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cTaskdetailKey  NVARCHAR( 10),
   @tExtInfo        VariableTable READONLY,
   @cExtendedInfo   NVARCHAR( 20) OUTPUT, 
   @nErrNo          INT OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFinalLoc   NVARCHAR(10)
   
   SET @nErrNo = 0

   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- Get task info
         SELECT 
            @cFinalLoc = FinalLoc 
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskdetailKey
   
         SET @cExtendedInfo = 'FINAL LOC: ' + @cFinalLoc
      END
   END

Quit:

END

GO