SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1820ExtUpd01                                    */
/* Purpose: For ASRS pallet call out. Need generate TM task to          */
/*          respective loc.                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-04-20 1.0  James      SOS315031. Created                        */
/* 2016-06-08 1.1  Leong      IN00067551 - Bug Fix.                     */
/************************************************************************/

CREATE PROC [RDT].[rdt_1820ExtUpd01] (
   @nMobile          INT,
   @nFunc            INT,
   @nStep            INT,
   @nInputKey        INT,
   @cLangCode        NVARCHAR( 3),
   @cStorerkey       NVARCHAR( 15),
   @cToLOC           NVARCHAR( 10),
   @cCCRefNo         NVARCHAR( 10),
   @cCCSheetNo       NVARCHAR( 10),
   @nCCCountNo       INT,
   @nAfterStep       INT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @nStartTCnt        INT,
           @bSuccess          INT,
           @bDebug            INT,
           @cNTaskDetailKey   NVARCHAR( 10),
           @cCCLogicalLoc     NVARCHAR( 18),
           @cFacility         NVARCHAR( 5),
           @cLOCCategory      NVARCHAR( 10),
           @cFromLOC          NVARCHAR( 10),
           @cID               NVARCHAR( 18),
           @cToInductLoc      NVARCHAR( 10),
           @cPutawayZone      NVARCHAR( 10),
           @cGTMFinalLoc      NVARCHAR( 10),
           @cGTMTOLoc         NVARCHAR( 10),
           @cPallet_LOCCat    NVARCHAR( 10)

   SELECT @cFacility = Facility FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   SELECT @cLOCCategory = LocationCategory, @cPutawayZone = PutawayZone
   FROM dbo.LOC WITH (NOLOCK)
   WHERE Facility = @cFacility
   AND   LOC = @cToLOC

   SET @nStartTCnt = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1820ExtUpd01

   SET @nErrNo = 0
   IF @nStep = 2 AND @nInputKey = 1
   BEGIN
      --INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3, COL4) VALUES
      --('1820', GETDATE(), @cStorerKey, @cCCRefNo, @cCCSheetNo, @nCCCountNo)
      DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT DISTINCT ID
      FROM dbo.CCDetail WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   CCKey = @cCCRefNo
      AND   CCSheetNo = @cCCSheetNo
      AND   [Status] < '9' -- no need filter status [0] as it includes count #2 & #3 as well!?
      AND   ISNULL( ID, '') <> ''
      -- count #1 include every ccdetail; count #2 & #3 only include ccdetail with variance only
      AND   1 = CASE WHEN @nCCCountNo = 1 THEN 1
                     WHEN @nCCCountNo = 2 THEN CASE WHEN ( Qty - SystemQty) <> 0 THEN 1 ELSE 0 END
                     WHEN @nCCCountNo = 3 THEN CASE WHEN ( Qty_Cnt2 - SystemQty) <> 0 THEN 1 ELSE 0 END
                ELSE 0 END
      OPEN CUR_LOOP
      FETCH NEXT FROM CUR_LOOP INTO @cID
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM dbo.TaskDetail WITH (NOLOCK)
                     WHERE DropID = @cCCRefNo
                     AND   FromID = @cID
                     AND   TaskType = 'ASRSCC'
                     AND   [Status] = '9'
                     AND   1 = CASE WHEN @nCCCountNo = 1 AND TransitCount = '1' THEN 1
                                    WHEN @nCCCountNo = 2 AND TransitCount = '2' THEN 1
                                    WHEN @nCCCountNo = 3 AND TransitCount = '3' THEN 1
                               ELSE 0 END)

         BEGIN
            SET @nErrNo = 53751
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'TASK EXISTS'
            CLOSE CUR_LOOP
            DEALLOCATE CUR_LOOP
            GOTO Quit
         END

         -- 1 ID 1 LOC?
         SELECT TOP 1 @cFromLOC = LOC
         FROM dbo.LOTxLOCxID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ID = @cID
         AND  Qty > 0 -- IN00067551

         -- Generate TaskDetailKey
         SET @bSuccess = 1

         EXECUTE nspg_getkey
         'TaskDetailKey'
         , 10
         , @cNTaskDetailKey  OUTPUT
         , @bSuccess         OUTPUT
         , @nErrNo           OUTPUT
         , @cErrMsg          OUTPUT

         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 53752
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'GetTaskKeyFail'
            CLOSE CUR_LOOP
            DEALLOCATE CUR_LOOP
            GOTO Quit
         END

         IF @cLOCCategory = 'STAGING'
         BEGIN
            -- Get the outbound lane loc
            SELECT TOP 1 @cToInductLoc = LOC
            FROM dbo.LOC WITH (NOLOCK)
            WHERE LocationCategory = 'ASRSOUTST'
            AND   PutawayZone = @cPutawayZone
            AND   Facility = @cFacility
            ORDER BY 1

            IF NOT EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cTOLoc AND LocationCategory = 'STAGING')
               SELECT TOP 1 @cTOLoc = LLI.LOC
               FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
               JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
               WHERE LLI.StorerKey = @cStorerKey
               AND   LLI.ID = @cID
               AND   LOC.LocationCategory = 'STAGING'

            INSERT INTO TaskDetail
              (TaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,Qty,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc
              ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide
              ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey
              ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, SystemQty, FinalLOC, TransitCount)
              VALUES
              (@cNTaskDetailKey
               ,'ASRSCC'      -- TaskType
               ,@cStorerkey
               ,''            -- SKU
               ,''            -- Lot
               ,''            -- UOM
               ,0             -- UOMQty
               ,0             -- Qty
               ,@cFromLOC     -- FromLoc
               ,''            -- LogicalFromLoc
               ,@cID          -- FromID
               ,@cToInductLoc -- ToLoc
               ,''            -- LogicalToLoc
               ,''            -- ToID
               ,''            -- Caseid
               ,'CC'          -- PickMethod
               ,'0'           -- STATUS
               ,''            -- StatusMsg
               ,'5'           -- Priority
               ,''            -- SourcePriority
               ,''            -- Holdkey
               ,''            -- UserKey
               ,''            -- UserPosition
               ,''            -- UserKeyOverRide
               ,GETDATE()     -- StartTime
               ,GETDATE()     -- EndTime
               ,'rdt_1820ExtUpd01'   -- SourceType
               ,@cCCSheetNo   -- SourceKey
               ,''            -- PickDetailKey
               ,''            -- OrderKey
               ,''            -- OrderLineNumber
               ,''            -- ListKey
               ,''            -- WaveKey
               ,''            -- ReasonKey
               ,''            -- Message01
               ,''            -- Message02
               ,''            -- Message03
               ,''            -- RefTaskKey
               ,''            -- LoadKey
               ,''            -- AreaKey
               ,@cCCRefNo     -- DropID
               ,0             -- SystemQty
               ,@cTOLoc
               ,@nCCCountNo)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 53753
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsCCTaskFail'
               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP
               GOTO Quit
            END

            IF @bDebug = 1
            BEGIN
               SELECT '@cTaskDetailKey', @cNTaskDetailKey
            END

            SELECT TOP 1 @cPallet_LOCCat = LOC.LocationCategory
            FROM dbo.LotxLocxID LLI WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.LOC = LOC.LOC
            WHERE LLI.ID = @cID
            AND  (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED) > 0
            AND   LOC.Facility = @cFacility

            IF @cPallet_LOCCat NOT IN ('STAGING', 'ASRS')
            BEGIN
               SET @nErrNo = 53756
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'IDNotInASRSLoc'
               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP
               GOTO Quit
            END

            IF @cPallet_LOCCat = 'ASRS'
            BEGIN
               --Send message to WCS to swap the existing task for OLD pallet to NEW pallet
               --Start Call WCS message.
               SET @nErrNo = 0

               EXEC isp_TCP_WCS_MsgProcess
                  @c_MessageName    = 'MOVE'
                , @c_MessageType    = 'SEND'
                , @c_OrigMessageID  = ''
                , @c_PalletID       = @cID
                , @c_FromLoc        = @cFromLOC
                , @c_ToLoc          = @cToInductLoc
                , @c_Priority       = '5'
                , @c_UD1            = ''
                , @c_UD2            = ''
                , @c_UD3            = ''
                , @c_TaskDetailKey  = @cNTaskDetailKey
                , @n_SerialNo       = ''
                , @b_debug          = 0
                , @b_Success        = @bSuccess    OUTPUT
                , @n_Err            = @nErrNo      OUTPUT
                , @c_ErrMsg         = @cErrMsg     OUTPUT

               IF @nErrNo <> 0
               BEGIN
                  SET @nErrNo = 53754
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SEND WCS FAIL
                  CLOSE CUR_LOOP
                  DEALLOCATE CUR_LOOP
                  GOTO Quit
               END
            END
         END
         ELSE IF @cLOCCategory = 'ASRSGTM'
         BEGIN
            IF NOT EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK)
                            WHERE LOC = @cTOLoc
                            AND   LocationCategory = 'ASRSGTM'
                            AND   LogicalLocation = 'A')
            BEGIN
               SELECT TOP 1 @cGTMFinalLoc = LOC
               FROM dbo.Loc WITH (NOLOCK)
               WHERE LocationCategory = 'ASRSGTM'
               AND   LogicalLocation = 'A'
            END
            ELSE
               SET @cGTMFinalLoc = @cTOLoc

            SELECT TOP 1 @cGTMTOLoc = LOC
            FROM dbo.Loc WITH (NOLOCK)
            WHERE LocationCategory = 'ASRSGTM'
            AND   LocationGroup = 'GTMLOOP'

            INSERT INTO TaskDetail
              (TaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,Qty,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc
              ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide
              ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey
              ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, SystemQty, FinalLOC, TransitCount)
              VALUES
              (@cNTaskDetailKey
               ,'ASRSCC'      -- TaskType
               ,@cStorerkey
               ,''            -- SKU
               ,''            -- Lot
               ,''            -- UOM
               ,0             -- UOMQty
               ,0             -- Qty
               ,@cFromLOC     -- FromLoc
               ,''            -- LogicalFromLoc
               ,@cID          -- FromID
               ,@cGTMTOLoc    -- ToLoc
               ,''            -- LogicalToLoc
               ,''            -- ToID
               ,''            -- Caseid
               ,'CC'          -- PickMethod
               ,'0'           -- STATUS
               ,''            -- StatusMsg
               ,'5'           -- Priority
               ,''            -- SourcePriority
               ,''            -- Holdkey
               ,''            -- UserKey
               ,''            -- UserPosition
               ,''            -- UserKeyOverRide
               ,GETDATE()     -- StartTime
               ,GETDATE()     -- EndTime
               ,'rdt_1820ExtUpd01'   -- SourceType
               ,@cCCSheetNo   -- SourceKey
               ,''            -- PickDetailKey
               ,''            -- OrderKey
               ,''            -- OrderLineNumber
               ,''            -- ListKey
               ,''            -- WaveKey
               ,''            -- ReasonKey
               ,''            -- Message01
               ,''            -- Message02
               ,''            -- Message03
               ,''            -- RefTaskKey
               ,''            -- LoadKey
               ,''            -- AreaKey
               ,@cCCRefNo     -- DropID
               ,0             -- SystemQty
               ,@cGTMFinalLoc
               ,@nCCCountNo)

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 53755
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsCCTaskFail'
               CLOSE CUR_LOOP
               DEALLOCATE CUR_LOOP
               GOTO Quit
            END

            IF @bDebug = 1
            BEGIN
               SELECT '@c_TaskDetailKey', @cNTaskDetailKey
            END
         END

         FETCH NEXT FROM CUR_LOOP INTO @cID
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

   Quit:
   IF @nErrNo <> 0  -- Error Occured - Process And Return
      ROLLBACK TRAN rdt_1820ExtUpd01

   WHILE @@TRANCOUNT > @nStartTCnt -- Commit until the level we started
      COMMIT TRAN rdt_1820ExtUpd01

GO