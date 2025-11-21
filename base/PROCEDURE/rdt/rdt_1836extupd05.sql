SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/**************************************************************************/
/* Store procedure: rdt_1836ExtUpd05                                      */
/* Copyright      : Maersk                                                */    
/* Client         : Levis USA                                             */    
/* Purpose        : update pick task from status H -> 0                   */
/*                                                                        */
/* Modifications log:                                                     */
/*                                                                        */
/* Date         Author    Ver.    Purposes                                */
/* 2024-12-04   YYS027    1.0.0   FCR-1489 Created                        */  
/**************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1836ExtUpd05]
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cTaskdetailKey  NVARCHAR( 10),
   @cFinalLOC       NVARCHAR( 10),
   @nErrNo          INT             OUTPUT,
   @cErrMsg         NVARCHAR( 20)   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cTaskKey          NVARCHAR( 10)
   DECLARE @cTaskType         NVARCHAR( 10)
   DECLARE @cCaseID           NVARCHAR( 20)
   DECLARE @cStorerKey        NVARCHAR( 15)
   DECLARE @cPickDetailKey    NVARCHAR( 15)
   DECLARE @cWaveKey          NVARCHAR( 10)
   --DECLARE @cTDWaveKey        NVARCHAR( 10)
   DECLARE @cFacility         NVARCHAR( 5)
   --DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cLot              NVARCHAR( 10)
   DECLARE @cLoc              NVARCHAR( 10)
   --DECLARE @cId               NVARCHAR( 10)
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @nQty              INT
   --DECLARE @nPDQty            INT
   --DECLARE @nBalQty           INT
   --DECLARE @curTask           CURSOR
   --DECLARE @curPD             CURSOR
   --DECLARE @curCPK            CURSOR
   DECLARE @cAreakey          NVARCHAR(20)
   DECLARE @cFromLOC          NVARCHAR( 10)
   DECLARE @cSuggToLOC        NVARCHAR( 10)
   DECLARE @cSuggFinalLoc     NVARCHAR( 10)
   --DECLARE @nQty              INT
   DECLARE @cRefTaskKey       NVARCHAR( 10)

   SELECT @cFacility = FACILITY
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- TM Replen From
   IF @nFunc = 1836
   BEGIN
      IF @nStep = 1 -- Final Loc
      BEGIN
         IF @nInputKey = '1'
         BEGIN
            -- FCR-1489 FN1836, is depends on FCR-1157 FN1764
            --    the replenishment is RPF, (FCR-1157) If the RPF task finalloc where SKUXLOC.LocationType = 'PICK' and Loc.locationcategory=â€™selvingâ€™,create an ASRPT task
            --    FCR-1157 FN1764, is replenish to drop down from storage location
            --    FCR-1489 FN1836, is replenish to put goods to pick-face-location
            --    two steps, will completed the replenish-operation.
            --------------------------------------------------------------------------------------------------------------------------------------------------
            --Object 1  - Release pick task when the corresponding replenishment task has been completed  in this SP)
            --Once the user scans the final location in Fn 1836 (ASTRPT), the related ASTCPK task status should be changed from â€˜H' to '0â€™.
            --    update is based RefTaskKey
            --Object 2  - called before rdt_TM_Assist_ReplenTo_Confirm, so place codes in rdt_1836ConfirmSP04
            --Once override happened:
            --    Delete the PendingMoveIN for the suggested location in LotxLocxID table  ---(yys027), not delete, the correct one, is to set zero for PendingMoveIN
            --    Create a record for (scanned loc)  in lotxloxlocid.  (to void PK issue, all qty fields are zero if not existed)
            --    Update the pickdetail.Loc with the new overridden location where Taskdetail.PickDetailKey for ASTCPK task will hold Pickdetail.PickDetailKey.
            --    Update the Taskdetail.FromLoc for the ASTCPK task and TaskDetail.ToLoc for the ASTRPT task.

            -- Get task info
            SELECT
               @cTaskType     = TaskType,
               @cStorerKey    = Storerkey,
               @cWaveKey      = WaveKey,
               @cAreakey      = Areakey,
               @cCaseID       = CaseID,    
               @cFromLOC      = FromLOC,    
               @cSuggToLOC    = ToLOC,
               @cSuggFinalLoc = finalloc,
               @cSKU          = Sku,
               @cLot          = Lot,
               @nQty          = Qty,   
               @cRefTaskKey   = RefTaskKey
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskdetailKey = @cTaskdetailKey


            IF ISNULL(@cRefTaskKey,'')<>'' AND @cTaskType = 'ASTRPT'
            BEGIN
               --Object 1 : task status should be changed from â€˜H' to '0â€™
               UPDATE dbo.TaskDetail WITH (ROWLOCK) SET [status]='0' 
                  WHERE StorerKey=@cStorerKey AND  RefTaskKey=@cRefTaskKey AND TaskType ='ASTCPK' AND [status]='H'
            END
         END
      END
   END

   GOTO Quit

Quit:

END

GO