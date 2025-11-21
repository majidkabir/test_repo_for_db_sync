SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: [rdt_511ExtUpdVLT]                                  */
/* Copyright: Maersk                                                    */
/*                                                                      */
/*                                                                      */
/* Date       VER    Author   Purpose                                   */
/* 15/07/24   1.0    PPA374   Clearing outstanding pending moves        */
/* 21/10/24   1.1    PPA374   UWP-25931                                 */
/* 23/10/24   1.2    Dennis	  Task Detail Check                       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_511ExtUpdVLT] (
@nMobile    INT,
@nFunc      INT,
@cLangCode  NVARCHAR( 3),
@nStep      INT,
@nInputKey  INT,
@cFacility  NVARCHAR( 5),
@cStorerKey NVARCHAR( 15),
@cFromID    NVARCHAR( 18),
@cFromLOC   NVARCHAR( 10),
@cToLOC     NVARCHAR( 10),
@nErrNo     INT           OUTPUT,
@cErrMsg    NVARCHAR( 20) OUTPUT
) AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

DECLARE
   @Orderkey NVARCHAR(15),
   @Wavekey NVARCHAR(15),
   @NextOrderKey NVARCHAR(15)

SET @Orderkey = ''
SET @Wavekey = ''
SET @NextOrderKey = ''

IF @nStep = 3 -- To Loc
   -- Clearing outstanding pending moves, as since ID is moved, it is not required anymore.
   BEGIN
      UPDATE LOTxLOCxID WITH(ROWLOCK)
      SET PendingMoveIN = 0
      WHERE id = @cFromID AND PendingMoveIN > 0 AND StorerKey = @cStorerKey AND ID <> ''

     IF EXISTS (SELECT 1 FROM loc L (NOLOCK) WHERE loc = @cToLOC
      AND EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'OUTZONHUSQ' AND Storerkey = @cStorerKey AND L.LocationType = Code))
      BEGIN
         SELECT TOP 1 @Orderkey = orderkey FROM PICKDETAIL (NOLOCK) WHERE id = @cFromID AND Storerkey = @cStorerKey
         SELECT TOP 1 @Wavekey = wavekey FROM TaskDetail (NOLOCK) WHERE OrderKey = @Orderkey AND Storerkey = @cStorerKey AND TaskType in ('FCP','FPK')
         SELECT TOP 1 @NextOrderKey = OrderKey FROM TaskDetail (NOLOCK) WHERE Message01 = '' AND orderkey <> @Orderkey AND WaveKey = @Wavekey AND Storerkey = @cStorerKey AND TaskType in ('FCP','FPK') order by TaskDetailKey

         IF (SELECT isnull(sum(openqty),0)-isnull(sum(QtyPicked),0) FROM orderdetail (NOLOCK)
         WHERE orderkey = @Orderkey AND StorerKey = @cStorerKey AND Facility = @cFacility) <= 0
         AND not EXISTS (SELECT 1 FROM PICKDETAIL (NOLOCK) WHERE OrderKey = @Orderkey AND Status < '5' AND Storerkey = @cStorerKey)
         BEGIN
            UPDATE TaskDetail WITH(ROWLOCK)
            SET Message01 = 'Staged'
            WHERE OrderKey = @Orderkey AND Message01 = ''

            UPDATE TaskDetail WITH(ROWLOCK)
            SET Status = '0'
            WHERE OrderKey = @NextOrderKey AND status = 'S'
         END
      END
      IF rdt.rdtGetConfig(@nFunc,'HUSQGRPPICK',@cStorerKey) = '1'
      BEGIN
         DECLARE @cUserID NVARCHAR(18),
         @cOrderKey NVARCHAR(10),
         @cLoadKey NVARCHAR(20),
         @cPickSlipNo NVARCHAR(20),
         @cHUSQGRPPICK NVARCHAR(1),
         @cGroupKey NVARCHAR(10),
         @cDropID   NVARCHAR(20)

         --From Vas LOC to marshalling lane
         IF EXISTS (SELECT 1 FROM LOC WITH(NOLOCK) WHERE FACILITY = @cFacility AND LOC = @cFromLOC AND LocationType = 'VAS')
         AND EXISTS (SELECT 1 FROM LOC WITH(NOLOCK) WHERE FACILITY = @cFacility AND LOC = @cToLOC AND LocationType = 'STAGEOB')
         BEGIN
            SELECT @cOrderKey = OrderKey,@cUserID = USERKEY,@cLoadKey = LOADKEY,@cDropID = DropID FROM TASKDETAIL WITH(NOLOCK) WHERE ToID = @cFromID AND StorerKey = @cStorerKey AND TOLOC = @cFromLOC
            SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PICKHEADER (NOLOCK) WHERE orderkey = @cOrderKey

            INSERT INTO Dropid(Dropid,Droploc,AdditionalLoc,DropIDType,LabelPrinted,ManifestPrinted,Status,TrafficCop,ArchiveCop,Loadkey,PickSlipNo)
            VALUES(@cDropID,'','',0,'N',0,5,null,null,@cLoadKey,@cPickSlipNo)

            EXEC rdt.rdt_FPKTaskDetailCheck_VLT
                  @nMobile = @nMobile
                  ,@nFunc  = @nFunc
                  ,@cLangCode = @cLangCode
                  ,@nStep  = @nStep
                  ,@nInputKey = @nInputKey
                  ,@cTaskdetailKey = ''
                  ,@cID = @cFromID
                  ,@cFromLoc = @cFromLOC
                  ,@nErrNo = @nErrNo OUTPUT
                  ,@cErrMsg = @cErrMsg OUTPUT
         END
      END
   END
END


GO