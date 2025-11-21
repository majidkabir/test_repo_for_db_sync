SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1830ExtInfo01                                   */
/* Purpose: Display custom info                                         */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2017-11-17   Ung       1.0   WMS-3272 Created                        */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1830ExtInfo01]
   @nMobile         INT,           
   @nFunc           INT,           
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,           
   @nAfterStep      INT,           
   @nInputKey       INT,            
   @cTaskdetailKey  NVARCHAR( 10), 
   @cFinalLOC       NVARCHAR( 10), 
   @cExtendedInfo   NVARCHAR( 20) OUTPUT, 
   @nErrNo          INT           OUTPUT, 
   @cErrMsg         NVARCHAR( 20) OUTPUT  
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
   IF @nFunc = 1830
   BEGIN
      IF @nAfterStep = 1 -- Final LOC 
      BEGIN
         -- Get LoadKey
         DECLARE @cLoadKey NVARCHAR(10)
         DECLARE @nBookingNo INT
         
         SELECT @cLoadKey = LoadKey FROM TaskDetail WITH (NOLOCK) WHERE TaskDetailKey = @cTaskDetailKey
         SELECT @nBookingNo = BookingNo FROM LoadPlan WITH (NOLOCK) WHERE LoadKey = @cLoadKey
         
         SET @cExtendedInfo = @cLoadKey + '  ' + CAST( @nBookingNo AS NVARCHAR(8))
      END
   END
END

GO