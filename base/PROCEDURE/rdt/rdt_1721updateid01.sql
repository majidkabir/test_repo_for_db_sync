SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1721UpdateId01                                */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Called from: rdtfnc_Pallet_Move                                      */
/*                                                                      */
/* Purpose: Check ID                                                    */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2024-07-16  1.0  CYU027   FCR-575                                    */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1721UpdateId01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cID            NVARCHAR( 40),
   @cToLOC         NVARCHAR( 40),
   @cLocationCategory VARCHAR( 10),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   DECLARE    @cDropID_Status   NVARCHAR( 10)
   DECLARE    @nTranCount       INT
   DECLARE    @cFromLOC         NVARCHAR( 40)


   -- Get DropID status from Codelkup table because
   -- user can move pallet anywhere. Location type determine
   -- DropID status
   SELECT @cDropID_Status = ISNULL(Code, '0')
   FROM dbo.CodeLkUp WITH (NOLOCK)
   WHERE ListName = 'SHIPSTATUS'
     AND   Short = @cLocationCategory

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN UPD_DROPID

   SELECT TOP 1 @cFromLOC = Loc
          FROM PalletDetail
   WHERE PalletKey = @cID

   IF @@ROWCOUNT > 0
   BEGIN
      -- Update DropID
      -- If Codelkup is not setup then use existing DropID status
      UPDATE PalletDetail WITH (ROWLOCK) SET
        [Status] = CASE WHEN ISNULL(@cDropID_Status, '') = '' THEN '0' ELSE @cDropID_Status END,
        LOC = @cToLOC,
        EditWho = 'rdt.' + sUser_sName(),
        EditDate = GETDATE()
      WHERE PalletKey = @cID
   END


   IF @@ERROR <> 0
   BEGIN
      ROLLBACK TRAN UPD_DROPID
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN UPD_DROPID

      SET @nErrNo = 219304
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd PalletDetail fail
      GOTO Quit
   END
--
--    UPDATE LOTxLOCxID WITH (ROWLOCK) SET
--       Loc = @cToLOC,
--       EditWho = SUSER_SNAME(),
--       EditDate = GETDATE()
--    WHERE ID = @cID AND StorerKey = @cStorerKey

   EXECUTE rdt.rdt_Move
           @nMobile     = @nMobile,
           @cLangCode   = @cLangCode,
           @nErrNo      = @nErrNo  OUTPUT,
           @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
           @cSourceType = 'rdt_1721UpdateId01',
           @cStorerKey  = @cStorerKey,
           @cFacility   = @cFacility,
           @cFromLOC    = @cFromLOC,
           @cToLOC      = @cToLOC,
           @cFromID     = @cID,
           @cToID       = NULL,  -- NULL means not changing ID
           @nFunc       = @nFunc


--    IF EXISTS(
--       SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
--       WHERE ID = @cID AND StorerKey = @cStorerKey
--    )
--    BEGIN
--
--       IF OBJECT_ID('tempdb..#LOTxLOCxID','U') IS NOT NULL
--       BEGIN
--          DROP TABLE #LOTxLOCxID;
--       END
--
--       CREATE TABLE #LOTxLOCxID
--       (
--          [Lot] [nvarchar] (10) ,
--          [Loc] [nvarchar] (10) ,
--          [Id] [nvarchar] (18) ,
--          [StorerKey] [nvarchar] (15),
--          [Sku] [nvarchar] (20) ,
--          [Qty] [int] ,
--          [QtyAllocated] [int] ,
--          [QtyPicked] [int] ,
--          [QtyExpected] [int] ,
--          [QtyPickInProcess] [int] ,
--          [PendingMoveIN] [int],
--          [ArchiveQty] [int],
--          [ArchiveDate] [datetime] ,
--          [TrafficCop] [nvarchar] ,
--          [ArchiveCop] [nvarchar],
--          [QtyReplen] [int] ,
--          [EditWho] [nvarchar] (128),
--          [EditDate] [datetime]
--       )
--
--       INSERT #LOTxLOCxID (Lot,Loc,Id,StorerKey,Sku,Qty,QtyAllocated,QtyPicked,QtyExpected,QtyPickInProcess,PendingMoveIN,ArchiveQty,ArchiveDate,TrafficCop,ArchiveCop,QtyReplen)
--       SELECT Lot,Loc,Id,StorerKey,Sku,Qty,QtyAllocated,QtyPicked,QtyExpected,QtyPickInProcess,PendingMoveIN,ArchiveQty,ArchiveDate,TrafficCop,ArchiveCop,QtyReplen
--       FROM LOTxLOCxID
--       WHERE ID = @cID AND StorerKey = @cStorerKey
--
--       DECLARE  @curLOT [nvarchar] (10) ,
--                @curLoc [nvarchar] (10) ,
--                @curID [nvarchar] (18)
--       DECLARE  CUR_LLI CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
--
--       SELECT Lot,Loc,Id FROM #LOTxLOCxID
--       OPEN CUR_LLI
--       FETCH NEXT FROM CUR_LLI INTO @curLOT, @curLoc, @curID
--       WHILE @@FETCH_STATUS <> -1
--       BEGIN
--
--          INSERT LOTxLOCxID (Lot,Loc,Id,StorerKey,Sku,Qty,QtyAllocated,QtyPicked,QtyExpected,QtyPickInProcess,PendingMoveIN,ArchiveQty,ArchiveDate,TrafficCop,ArchiveCop,QtyReplen,EditWho,EditDate)
--          SELECT Lot,@cToLOC,Id,StorerKey,Sku,Qty,QtyAllocated,QtyPicked,QtyExpected,QtyPickInProcess,PendingMoveIN,ArchiveQty,ArchiveDate,TrafficCop,ArchiveCop,QtyReplen,SUSER_SNAME(),GETDATE()
--          FROM #LOTxLOCxID
--          WHERE LOT =  @curLOT AND LOC = @curLoc AND ID = @curID
--
--          UPDATE PICKDETAIL WITH (ROWLOCK) SET
--                                              LOC = @cToLOC,
--                                              EditWho = SUSER_SNAME(),
--                                              EditDate = GETDATE()
--          WHERE Lot=@curLOT AND Loc=@curLoc AND Id=@curID AND StorerKey = 'LVSUSA'
--
--          DELETE FROM LOTxLOCxID WHERE LOT =  @curLOT AND LOC = @curLoc AND ID = @curID
--
--
--          FETCH NEXT FROM CUR_LLI INTO @curLOT, @curLoc, @curID
--       END
--
--       CLOSE CUR_LLI
--       DEALLOCATE CUR_LLI
--    END


   IF @nErrNo <> 0
   BEGIN
      ROLLBACK TRAN UPD_DROPID
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN UPD_DROPID

      SET @nErrNo = 219305
      SET @cErrMsg = @cErrMsg -- Upd LOTxLOCxID fail
      GOTO Quit
   END


   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN UPD_DROPID

   Quit:


END

GO