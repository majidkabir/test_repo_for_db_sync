SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1812ExtInfo02                                   */
/* Purpose: Display custom info                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-10-27   Ung       1.0   WMS-3273 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1812ExtInfo02]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
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
   IF @nFunc = 1812
   BEGIN
      /*
      IF @nAfterStep = 1 -- FromLOC
      BEGIN
         SET @cExtendedInfo1 = 'PICKMETHOD: ' + RTRIM( @cPickMethod)
      END
      */
      
      IF @nAfterStep = 7 -- Next task 
      BEGIN
         -- Get LoadKey
         DECLARE @cLoadKey NVARCHAR(10)
         DECLARE @nBookingNo INT
         
         SELECT @cLoadKey = LoadKey FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey
         SELECT @nBookingNo = BookingNo FROM LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey
         
         SET @cExtendedInfo1 = @cLoadKey + '  ' + CAST( @nBookingNo AS NVARCHAR(8))
      END
   END
END

GO