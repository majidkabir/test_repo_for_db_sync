SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1770ExtInfo02                                   */
/* Purpose: Display custom info                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-02-02   Ung       1.0   SOS327467 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1770ExtInfo02]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cExtendedInfo1  NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPickMethod NVARCHAR(10)

   -- Get TaskDetail info
   SELECT @cPickMethod = PickMethod
   FROM TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @cTaskDetailKey         

   -- TM Pallet Pick
   IF @nFunc = 1770
   BEGIN
      IF @nAfterStep = 1 -- FromLOC
      BEGIN
         SET @cExtendedInfo1 = 'PICKMETHOD: ' + RTRIM( @cPickMethod)
      END

      IF @nAfterStep = 5 -- Next task 
      BEGIN
         -- Get LoadKey
         DECLARE @cLoadKey NVARCHAR(10)
         SELECT @cLoadKey = LoadKey FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey
         SET @cExtendedInfo1 = 'LOADKEY: ' + @cLoadKey
      END
   END
END

GO