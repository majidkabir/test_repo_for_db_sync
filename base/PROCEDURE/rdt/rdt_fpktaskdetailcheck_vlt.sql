SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_FPKTaskDetailCheck_VLT                          */
/* Purpose: FOR VLT                                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2024-10-12   Dennis    1.0   FCR-775                                 */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_FPKTaskDetailCheck_VLT
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT 
   ,@nInputKey       INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@cID             NVARCHAR( 18)
   ,@cFromLoc        NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @cOrderKey NVARCHAR(10),
   @cWaveKey         NVARCHAR( 10),
   @cNextOrderKey    NVARCHAR(10),
   @cUserID          NVARCHAR(18)
   DECLARE @cStorerKey NVARCHAR(15),
   @cFacility          NVARCHAR(5),
   @cGroupKey        NVARCHAR(10)

   SELECT @cFacility = Facility,@cStorerKey = StorerKey FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE  Mobile = @nMobile 

   -- TM Pallet Pick
   IF @nFunc = 1770
   BEGIN
      SELECT @cOrderKey = OrderKey,@cWaveKey = Wavekey,@cUserID = USERKEY FROM TASKDETAIL WITH(NOLOCK) WHERE TASKDETAILKEY = @cTaskDetailKey
   END
   ELSE IF @nFunc = 511
   BEGIN
      SELECT @cOrderKey = OrderKey,@cWaveKey = Wavekey,@cUserID = USERKEY FROM TASKDETAIL WITH(NOLOCK) WHERE ToID = @cID AND StorerKey = @cStorerKey AND TOLOC = @cFromLOC
   END

   IF NOT EXISTS (SELECT 1 FROM TASKDETAIL TD WITH(NOLOCK) 
               WHERE OrderKey = @cOrderKey AND STATUS <> '9') -- ALL tasks done
   AND NOT EXISTS ( SELECT 1 FROM LOTxLOCxID LLI WITH(NOLOCK) -- All pallets in stageob
               INNER JOIN LOC LOC WITH(NOLOCK) ON LOC.LOC = LLI.LOC 
               WHERE LOC.LocationType <> 'STAGEOB' 
               AND LLI.StorerKey = @cStorerKey
               AND LOC.Facility = @cFacility
               AND EXISTS( SELECT 1 FROM TASKDETAIL TD WITH(NOLOCK) WHERE OrderKey = @cOrderKey AND (TD.ToID = LLI.ID OR TD.DropID = LLI.ID) AND StorerKey = @cStorerKey) 
               AND LLI.QTY-LLI.QTYPicked > 0)
   BEGIN

      SELECT TOP 1 @cNextOrderKey = TD.Orderkey,@cGroupKey = GroupKey
      FROM TASKDETAIL TD WITH(NOLOCK) 
      INNER JOIN ORDERS O WITH(NOLOCK) ON TD.StorerKey = O.StorerKey AND TD.OrderKey = O.OrderKey
      WHERE TD.STATUS = 'S' AND TD.WAVEKEY = @cWaveKey AND TD.StorerKey = @cStorerKey
      Order by DeliveryDate

      IF ISNULL(@cNextOrderKey,'')<>''
      BEGIN
         DECLARE @cAssignee NVARCHAR(18) = ''

         --UPDATE status first
         UPDATE TASKDETAIL SET 
            STATUS = '0'           
            WHERE OrderKey = @cNextOrderKey
         SELECT TOP 1 @cAssignee = ISNULL(USERKEY,'') FROM TASKDETAIL TD2 WITH(NOLOCK) WHERE STATUS IN ('0','3') AND TD2.GroupKey = @cGroupKey AND UserKey<>''
         --assign task
         UPDATE TASKDETAIL SET 
            USERKEY          = @cAssignee
            ,StartTime       = CURRENT_TIMESTAMP
            ,EditDate        = CURRENT_TIMESTAMP
            ,EditWho         = @cUserID
            ,TrafficCop      = NULL        
         WHERE OrderKey = @cNextOrderKey
      END
   END

Quit:

END

GO