SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1797ExtUpd01                                    */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2024-04-19   NLT03     1.0   UWP-13706 Created                       */
/*                              Shinto Changing logic to putaway        */
/*                              by pallet type and ABC                  */
/* 2024-06-25   TPT001    1.1   Update putaway logic based on LocLevel  */
/*                                                                      */
/* 2024-07-01   TPT001    1.2   Adding filtering out the Inactive and   */
/*                              non BULK/PND loc                        */
/************************************************************************/
CREATE PROCEDURE [RDT].[rdt_1797ExtUpd01]
    @nMobile         INT 
   ,@nFunc           INT 
   ,@cLangCode       NVARCHAR( 3) 
   ,@nStep           INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT 
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @PAPath               NVARCHAR(10)
   DECLARE @ToLOC                NVARCHAR(20)
   DECLARE @FinalLOC             NVARCHAR(20)
   DECLARE @TMFromPutaway        NVARCHAR(10)
   DECLARE @cNewTaskDetailKey    NVARCHAR(10)
   DECLARE @nSuccess             INT
   DECLARE @cStorerkey           NVARCHAR(10)
   DECLARE @cFacility            NVARCHAR(5)
   SELECT @cStorerkey = storerkey,
      @cFacility = Facility
   FROM RDT.RDTMobrec (NOLOCK)
   where username = SYSTEM_USER
   -- TM Putaway From
   IF @nFunc = 1797
   BEGIN
      IF @nStep = 0 -- Initial Step
      BEGIN
         SET @TMFromPutaway='0'
         SELECT @TMFromPutaway = CODELKUP.code2
         FROM CODELKUP WITH(NOLOCK)
         WHERE CODELKUP.LISTNAME = 'Demeter'
            AND CODELKUP.Code = 'TMFromPutaway'
            AND CODELKUP.Storerkey = @cStorerkey
         IF @TMFromPutaway = '1'
         BEGIN
            SELECT TOP 1 @PAPath =
               CASE
              WHEN RECEIPTDETAIL.PalletType='D' THEN 'WA'
                  WHEN LEN(LOC.LocationRoom) = 0 OR LOC.LocationRoom IS NULL THEN 'WA' 
                  WHEN LOC.LocationRoom IS NOT NULL THEN 'VNA' 
               END
               ,@ToLOC = LOC.LocationRoom
               ,@FinalLOC = LOC.Loc
            FROM dbo.TaskDetail WITH (NOLOCK)
            INNER JOIN LOTxLOCxID WITH (NOLOCK) ON LOTxLOCxID.Id = TaskDetail.FromID AND LOTxLOCxID.StorerKey = TaskDetail.Storerkey AND LOTxLOCxID.StorerKey = @cStorerkey
            INNER JOIN LOC LOC1 WITH(NOLOCK) ON LOTxLOCxID.Loc = LOC1.LOC AND LOC1.Facility = @cFacility
            INNER JOIN RECEIPTDETAIL WITH (NOLOCK) ON (LOTxLOCxID.Id = RECEIPTDETAIL.ToId)
            INNER JOIN PutawayZone WITH (NOLOCK) ON PutawayZone.Pallet_type = RECEIPTDETAIL.PalletType AND PutawayZone.Facility = LOC1.Facility
            INNER JOIN LOC WITH (NOLOCK) ON PutawayZone.PutawayZone = LOC.PutawayZone AND PutawayZone.Facility = LOC.Facility AND LOC.LocationFlag NOT IN ('INACTIVE') AND LOC.LocationType IN('PND','BULK') 
            INNER JOIN SKU WITH (NOLOCK) ON SKU.Sku = LOTxLOCxID.Sku AND SKU.StorerKey = LOTxLOCxID.StorerKey AND SKU.ABC = LOC.ABC
            INNER JOIN PALLET WITH (NOLOCK) ON PALLET.PalletKey = LOTxLOCxID.Id AND PALLET.GrossWgt < LOC.WeightCapacity
               AND NOT EXISTS (
                              SELECT 1 
                              FROM LOTxLOCxID LOTxLOCxID1 WITH (NOLOCK) 
                              WHERE LOC.Loc = LOTxLOCxID1.Loc AND LOTxLOCxID1.Qty > 0
                              )
               AND NOT EXISTS (
                              SELECT 1 
                              FROM TaskDetail TaskDetail2 WITH (NOLOCK) 
                              WHERE LOC.Loc = TaskDetail2.ToLoc AND TaskDetail2.Status < '9'
                              )
               AND TaskDetail.TaskDetailKey = @cTaskDetailKey
               AND LOC.LocLevel BETWEEN 1 AND CASE WHEN Pallet.GrossWgt < 1000 THEN 99 ELSE 1 END
            ORDER BY (CASE LOC.ABC WHEN 'A' THEN Loc.LocLevel END ) ASC, (CASE WHEN LOC.ABC<>'A' THEN Loc.LocLevel END ) DESC, Loc.WeightCapacity ASC
            IF @PAPath = 'VNA'
            BEGIN
               IF (SELECT COUNT(DISTINCT PALLET.PalletKey) FROM PALLET WITH (NOLOCK) WHERE PalletKey = (SELECT TOP 1 FromID FROM TaskDetail WHERE TaskDetailKey = @cTaskdetailKey)) > 0
               BEGIN
                  UPDATE dbo.TaskDetail
                  SET ToLOC = @ToLOC,
                     FinalLOC = @FinalLOC,               
                     Message03 = 'UPDATE VNA',               
                     TransitCount = 1                                             -- Indicates that this is the first putaway hop
                  WHERE TaskDetailKey = @cTaskdetailKey
                     AND TaskDetail.TransitCount = '0'
                  --Generate a new task detail key
                  -- Create the second task to the VNA location only if it has the first hop to P6D to avoid an infinite task looping.
                  IF (SELECT COUNT(DISTINCT TaskDetail.TaskDetailKey) FROM TaskDetail WITH (NOLOCK) WHERE FromID = (SELECT TOP 1 FromID FROM TaskDetail WHERE TaskDetailKey = @cTaskdetailKey)) = 1
                  BEGIN
                     -- Init var
                     SET @nErrNo = 0
                     SET @cErrMsg = ''
                     -- Get new TaskDetailKey
                     SET @nSuccess = 0
                     EXECUTE dbo.nspg_getkey
                        'TASKDETAILKEY'
                        , 10
                        , @cNewTaskDetailKey OUTPUT
                        , @nSuccess          OUTPUT
                        , @nErrNo            OUTPUT
                        , @cErrMsg           OUTPUT
                     -- Insert the second putaway task to VNA location
                     INSERT INTO TaskDetail (TaskDetailKey, TaskType, Storerkey,FromLoc,LogicalFromLoc,FromID,ToLoc,PickMethod,Status,Priority,SourcePriority,UserPosition
                     ,StartTime,EndTime,SourceType,SourceKey,AddDate,AddWho,EditDate,EditWho,SystemQty,AreaKey,TransitCount,PendingMoveIn,QtyReplen,Message03)
                     SELECT @cNewTaskDetailKey, TaskType, Storerkey,ToLoc,ToLoc,FromID,FinalLOC,PickMethod,'0',Priority,SourcePriority,UserPosition
                     ,StartTime,EndTime,SourceType,SourceKey,AddDate,AddWho,EditDate,EditWho,SystemQty,AreaKey,'2',PendingMoveIn,QtyReplen,'2ND STEP VNA'
                     FROM TaskDetail WITH(NOLOCK)
                     WHERE TaskDetail.TaskDetailKey = @cTaskdetailKey
                  END
               END
               ELSE
               BEGIN
                  SET @nErrNo = 214151              
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --214151 Different COD
               END
            END
            ELSE IF @PAPath = 'WA'
            BEGIN
               IF (SELECT COUNT(DISTINCT PALLET.PalletKey) FROM PALLET WITH (NOLOCK) WHERE PalletKey = (SELECT TOP 1 FromID FROM TaskDetail WHERE TaskDetailKey = @cTaskdetailKey)) > 0
               BEGIN
                  UPDATE dbo.TaskDetail
                  SET ToLOC = @FinalLOC,
                     Message03 = 'UPDATE WA',
                     TransitCount = 1                                             -- Indicates that this is the first putaway hop
                  WHERE TaskDetailKey = @cTaskdetailKey
                  --AND TaskDetail.TransitCount = '0'
               END
            ELSE
            BEGIN
               SET @nErrNo = 214151              
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --214151 Different COD
            END
         END
         UPDATE rdt.rdtmobrec WITH (ROWLOCK) 
         SET V_String1 = @ToLOC
         WHERE Mobile = @nMobile
      END
   END
END

GOTO Quit

Quit:

END

GO