SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_SortationByTrackingID                           */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_SortationByTrackingID                            */    
/*                                                                      */    
/* Purpose: Insert TrackingID                                           */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2020-03-12  1.0  James    WMS-12360. Created                         */  
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_SortationByTrackingID] (    
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cParentTrackID   NVARCHAR( 20),
   @cChildTrackID    NVARCHAR( 1000),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cType            NVARCHAR( 20),
   @nErrNo           INT          OUTPUT,    
   @cErrMsg          NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max    
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @cTrackingIDKey NVARCHAR( 10)
   DECLARE @nTranCount     INT
   DECLARE @nCaseCnt       INT
   DECLARE @nRowCount      INT
   DECLARE @curClosePlt    CURSOR

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_SortationByTrackingID  
   
   SELECT @nCaseCnt = PACK.CaseCnt
   FROM dbo.SKU SKU WITH (NOLOCK)
   JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey)
   WHERE SKU.StorerKey = @cStorerKey
   AND   SKU.Sku = @cSKU

   IF @cType = 'NEW'
   BEGIN
      INSERT INTO dbo.TrackingID ( TrackingID, StorerKey, SKU, UOM, QTY, [Status], ParentTrackingID) VALUES
      ( @cChildTrackID, @cStorerKey, @cSKU, '6', @nCaseCnt, '0', @cParentTrackID)
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 149401
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS TRACKID ERR
         GOTO RollBackTran
      END
   END
   
   IF @cType = 'CLOSEPALLET'
   BEGIN
      SET @curClosePlt = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TrackingIDKey
      FROM dbo.TrackingID WITH (NOLOCK)
      WHERE StorerKey = StorerKey
      AND   ParentTrackingID = @cParentTrackID
      AND   [Status] = '0'
      OPEN @curClosePlt
      FETCH NEXT FROM @curClosePlt INTO @cTrackingIDKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE dbo.TrackingID SET 
            [Status] = '1' -- 1 = pallet closed
         WHERE TrackingIDKey = @cTrackingIDKey
         
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 149402
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD TRACKID ERR
            GOTO RollBackTran
         END
      
         FETCH NEXT FROM @curClosePlt INTO @cTrackingIDKey
      END
   END

   IF @cType = 'REVERSALCHILD'
   BEGIN
      SELECT @cTrackingIDKey = TrackingIDKey
      FROM dbo.TrackingID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ParentTrackingID = @cParentTrackID
      AND   TrackingID = @cChildTrackID
      AND   [Status] = '0'
      
      DELETE FROM dbo.TrackingID WHERE TrackingIDKey = @cTrackingIDKey
      SET @nRowCount = @@ROWCOUNT

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 149403
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DEL TRACKID ERR
         GOTO RollBackTran
      END

      IF @nRowCount <> 1
      BEGIN
         SET @nErrNo = 149404
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DEL TRACKID ERR
         GOTO RollBackTran
      END
   END

   IF @cType = 'REVERSALPALLET'
   BEGIN
      DECLARE @cReversePallet CURSOR
      SET @cReversePallet = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TrackingIDKey
      FROM dbo.TrackingID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ParentTrackingID = @cParentTrackID
      AND   [Status] = '0'
      OPEN @cReversePallet
      FETCH NEXT FROM @cReversePallet INTO @cTrackingIDKey
      WHILE @@FETCH_STATUS = 0
      BEGIN
         DELETE FROM dbo.TrackingID WHERE TrackingIDKey = @cTrackingIDKey

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 149405
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- DEL TRACKID ERR
            GOTO RollBackTran
         END
         
         FETCH NEXT FROM @cReversePallet INTO @cTrackingIDKey
      END
   END
      
   GOTO Quit  
  
   RollBackTran:  
      ROLLBACK TRAN rdt_SortationByTrackingID  
  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN rdt_SortationByTrackingID  

Fail:    
END    

GO