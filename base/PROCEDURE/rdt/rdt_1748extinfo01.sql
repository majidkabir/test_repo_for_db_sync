SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1748ExtInfo01                                   */
/* Purpose: Extended info                                               */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2018-05-24   Ung       1.0   WMS-4933 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1748ExtInfo01]
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

   DECLARE @nQTY   INT
   DECLARE @cUCCNo NVARCHAR(20)

   -- TM Move
   IF @nFunc = 1748
   BEGIN
      IF @nAfterStep = 6 -- TO LOC
      BEGIN
         DECLARE @cContainerKey  NVARCHAR(20)
         DECLARE @cStorerKey     NVARCHAR(15)
         DECLARE @cTaskType      NVARCHAR(10)
         DECLARE @nTotalPallet   INT
         DECLARE @nPickedPallet  INT

         -- Get task info
         SELECT 
            @cContainerKey = DropID, 
            @cStorerKey = StorerKey, 
            @cTaskType = TaskType
         FROM TaskDetail WITH (NOLOCK)
         WHERE TaskDetailKey = @cTaskDetailKey

         -- Get container info
         SELECT 
            @nTotalPallet = COUNT(1), 
            @nPickedPallet = ISNULL( SUM( CASE WHEN Status = '9' THEN 1 ELSE 0 END), 0)
         FROM TaskDetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND TaskType = @cTaskType
            AND DropID = @cContainerKey
         
         SET @cExtendedInfo1 = 
            RIGHT( RTRIM( @cContainerKey), 10) + 
            rdt.rdtRightAlign( CAST( @nPickedPallet AS NVARCHAR(5)) + '/' + CAST( @nTotalPallet AS NVARCHAR(5)), 10)
      END
   END
END

GO