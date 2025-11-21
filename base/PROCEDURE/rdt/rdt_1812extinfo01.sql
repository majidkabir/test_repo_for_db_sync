SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812ExtInfo01                                   */
/* Purpose: Extended info                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2015-01-14   Ung       1.0   SOS327467 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1812ExtInfo01]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@cTaskdetailKey  NVARCHAR( 10) 
   ,@cExtendedInfo1  NVARCHAR( 20) OUTPUT
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- TM Case Pick
   IF @nFunc = 1812
   BEGIN
      IF @nAfterStep = 6 OR -- TOLOC 
         @nAfterStep = 7    -- Close Pallet
      BEGIN
         -- Get LoadKey
         DECLARE @cLoadKey NVARCHAR(10)
         SELECT @cLoadKey = LoadKey FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey
         SET @cExtendedInfo1 = 'LOADKEY: ' + @cLoadKey
      END
   END
END

GO