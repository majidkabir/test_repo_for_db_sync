SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1764ExtInfo09                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date         Author     Ver.  Purposes                               */
/* 2022-04-07   yeekung    1.0   WMS-19409 Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764ExtInfo09]
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

   DECLARE @cTaskType   NVARCHAR( 10)
   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cFromLOC    NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @nTotalTask  INT
   DECLARE @nFinishTask INT

   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @nAfterStep = 4
      BEGIN
         -- Get TaskDetail info
         SELECT 
            @cExtendedInfo1 = ISNULL(caseid,'')
         FROM taskdetail WITH (NOLOCK) 
         WHERE TaskdetailKey = @cTaskdetailKey
      END

      IF @nAfterStep = 5
      BEGIN
         -- Get TaskDetail info
         SELECT 
            @cExtendedInfo1 = ISNULL(FinalLOC,'')
         FROM taskdetail WITH (NOLOCK) 
         WHERE TaskdetailKey = @cTaskdetailKey
      END
   END

Quit:

END

GO