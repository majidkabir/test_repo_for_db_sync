SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: rdt_SplitUCC                                        */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_SplitUCC                                         */    
/*                                                                      */    
/* Purpose: Create new ucc                                              */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2022-12-05  1.0  James    WMS-21186. Created                         */  
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_SplitUCC] (    
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cType          NVARCHAR( 10),   -- FULL/PARTIAL/ADDLOG/DELLOG    
   @cFromUCC       NVARCHAR( 20),
   @cToUCC         NVARCHAR( 20),
   @cSKU           NVARCHAR( 20),    
   @nQTY           INT,
   @cToID          NVARCHAR( 18),
   @cToLOC         NVARCHAR( 10),
   @tSplitUCC      VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @cLot        NVARCHAR( 10),
           @cUserName   NVARCHAR( 18),
           @cTempLOC    NVARCHAR( 10),
           @cTempSKU    NVARCHAR( 20),
           @cFromLOC    NVARCHAR( 10),
           @cFromID     NVARCHAR( 18),
           @cExternKey  NVARCHAR( 20),
           @nTempQty    INT,
           @curUCCLog   CURSOR,
           @curAddLog   CURSOR,
           @curDelLog   CURSOR,
           @nRowRef     INT,
           @cDoNotCopyExternKey  NVARCHAR( 1)
   
   DECLARE @ndebug   INT = 0
   
   SELECT @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   DECLARE @nTranCount INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_SplitUCC  
   
   IF @cType = 'FULL'
   BEGIN
	   UPDATE dbo.UCC WITH (ROWLOCK)
	   SET UCCNo = @cToUCC
	   WHERE UCCNo = @cFromUCC 
	   AND Status = '1'
	      
	   IF @@ERROR <> 0 
	   BEGIN
	      SET @nErrNo = 87301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdUCCFail'
         GOTO RollBackTran
	   END
   END
   
   IF @cType = 'PARTIAL'
   BEGIN
   	SET @cDoNotCopyExternKey = rdt.rdtGetConfig( @nFunc, 'DoNotCopyExternKey', @cStorerKey)
   	
   	IF EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
   	            WHERE Storerkey = @cStorerKey
   	            AND   UCCNo = @cToUCC
   	            AND   ID <> @cToID)
      BEGIN
         SET @nErrNo = 87308
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCCInOtherPlt'
         GOTO RollBackTran
      END 
	         
   	SET @curUCCLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   	SELECT SKU, SUM( Qty)
   	FROM rdt.rdtUCC WITH (NOLOCK)
   	WHERE StorerKey = @cStorerKey
   	AND   UCCNo = @cToUCC
   	AND   AddWho = @cUserName
   	GROUP BY SKU
   	OPEN @curUCCLog
   	FETCH NEXT FROM @curUCCLog INTO @cTempSKU, @nTempQty
   	WHILE @@FETCH_STATUS = 0
   	BEGIN
   	   SELECT TOP 1 
   	      @cLot = Lot, 
   	      @cTempLOC = Loc,
   	      @cExternKey = ExternKey,
	         @cFromLOC = Loc, 
	         @cFromID = Id
   	   FROM dbo.UCC WITH (NOLOCK)
   	   WHERE Storerkey = @cStorerKey
   	   AND   UCCNo = @cFromUCC
   	   AND   SKU = @cTempSKU
   	   AND   [Status] = '1'
   	   ORDER BY 1
   	   
   	   IF @cDoNotCopyExternKey = '1'
   	      SET @cExternKey = ''

   	   -- User do not key in To Loc
   	   IF @nStep = 4
   	      SET @cToLOC = @cTempLOC

	      -- Move invetory
         EXECUTE rdt.rdt_Move
            @nMobile     	= @nMobile,
            @cLangCode   	= @cLangCode,
            @nErrNo      	= @nErrNo  OUTPUT,
            @cErrMsg     	= @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
            @cSourceType 	= 'rdt_SplitUCC',
            @cStorerKey  	= @cStorerKey,
            @cFacility   	= @cFacility,
            @cFromLOC    	= @cFromLOC,
            @cToLOC      	= @cToLOC,
            @cFromID     	= @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
            @cToID       	= @cToID,       -- NULL means not changing ID. Blank consider a valid ID
            @cSKU        	= @cTempSKU,
            @nQTY        	= @nTempQTY,
			   @nFunc   		= @nFunc
			
			IF @nErrNo <> 0
			   GOTO RollBackTran
   	   
   	   -- Insert new UCC
   	   IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                         WHERE Storerkey = @cStorerKey
   	                   AND   UCCNo = @cToUCC
   	                   AND   SKU = @cTempSKU
   	                   AND   Id = @cToID)
         BEGIN
 	         INSERT INTO dbo.UCC (UCCNo, Storerkey, ExternKey, SKU, qty, Lot, Loc, Id, STATUS, AddWho, AddDate) VALUES
 	         (@cToUCC, @cStorerKey, @cExternKey, @cTempSKU, @nTempQTY, @cLot, @cToLOC, @cToID, '1', @cUserName, GETDATE())

	         IF @@ERROR <> 0 
	         BEGIN
	            SET @nErrNo = 87302
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsUCCFail'
               GOTO RollBackTran
	         END      
         END
         ELSE
         BEGIN
            UPDATE dbo.UCC SET 
               Qty = Qty + @nTempQTY, 
               EditWho = SUSER_SNAME(), 
               EditDate = GETDATE()
            WHERE Storerkey = @cStorerKey
            AND   UCCNo = @cToUCC
            AND   SKU = @cTempSKU
            AND   Id = @cToID
            
	         IF @@ERROR <> 0 
	         BEGIN
	            SET @nErrNo = 87303
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdUCCFail'
               GOTO RollBackTran
	         END
	         
	         --SELECT * FROM UCC (NOLOCK) WHERE Storerkey = @cStorerKey
          --  AND   UCCNo = @cToUCC
          --  AND   SKU = @cTempSKU
          --  AND   Id = @cToID
         END
         
	      IF @ndebug = 1
	      BEGIN
	         SELECT @cStorerKey '@cStorerKey', @cFacility '@cFacility', @cFromLOC '@cFromLOC', @cToLOC '@cToLOC'
	         SELECT @cFromID '@cFromID', @cToID '@cToID', @cTempSKU '@cTempSKU', @nTempQTY '@nTempQTY'
	      END
	      
	  --    -- Move invetory
   --      EXECUTE rdt.rdt_Move
   --         @nMobile     	= @nMobile,
   --         @cLangCode   	= @cLangCode,
   --         @nErrNo      	= @nErrNo  OUTPUT,
   --         @cErrMsg     	= @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max
   --         @cSourceType 	= 'rdt_SplitUCC',
   --         @cStorerKey  	= @cStorerKey,
   --         @cFacility   	= @cFacility,
   --         @cFromLOC    	= @cFromLOC,
   --         @cToLOC      	= @cToLOC,
   --         @cFromID     	= @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
   --         @cToID       	= @cToID,       -- NULL means not changing ID. Blank consider a valid ID
   --         @cSKU        	= @cTempSKU,
   --         @nQTY        	= @nTempQTY,
			--   @nFunc   		= @nFunc
			
			--IF @nErrNo <> 0
			--   GOTO RollBackTran

         -- Deduct from original ucc
         UPDATE dbo.UCC SET 
            Qty = Qty - @nTempQty, 
            EditWho = SUSER_SNAME(), 
            EditDate = GETDATE()
         WHERE Storerkey = @cStorerKey
         AND   UCCNo = @cFromUCC
         AND   SKU = @cTempSKU

	      IF @@ERROR <> 0 
	      BEGIN
	         SET @nErrNo = 87304
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdUCCFail'
            GOTO RollBackTran
	      END

	      FETCH NEXT FROM @curUCCLog INTO @cTempSKU, @nTempQty
	   END
   END
   
   IF @cType = 'ADDLOG'
   BEGIN
   	IF NOT EXISTS( SELECT 1 FROM RDT.RDTUCC WITH (NOLOCK)
   	               WHERE StorerKey = @cStorerKey
   	               AND   UCCNo = @cToUCC
   	               AND   SKU = @cSKU
   	               AND   AddWho = @cUserName)
      BEGIN
         INSERT INTO rdt.RDTUCC(UCCNo, StorerKey, SKU, QTY) VALUES 
         (@cToUCC, @cStorerKey, @cSKU, @nQTY)
         
         IF @@ERROR <> 0
	      BEGIN
	         SET @nErrNo = 87305
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Add Log Fail'
            GOTO RollBackTran
	      END      
      END
      ELSE
      BEGIN
      	SET @curAddLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      	SELECT RowRef
      	FROM rdt.RDTUCC WITH (NOLOCK)
      	WHERE StorerKey = @cStorerKey
    	   AND   UCCNo = @cToUCC
    	   AND   SKU = @cSKU
         AND   AddWho = @cUserName
         OPEN @curAddLog
         FETCH NEXT FROM @curAddLog INTO @nRowRef
         WHILE @@FETCH_STATUS = 0
         BEGIN
    	      UPDATE RDT.RDTUCC SET 
    	         Qty = Qty + @nQTY
    	      WHERE RowRef = @nRowRef
         
            IF @@ERROR <> 0
	         BEGIN
	            SET @nErrNo = 87304
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd Log Fail'
               GOTO RollBackTran
	         END
	         
	         FETCH NEXT FROM @curAddLog INTO @nRowRef
	      END      
      END
   END
   
   IF @cType = 'DELLOG'
   BEGIN
      IF EXISTS ( SELECT 1 FROM rdt.RDTUCC WITH (NOLOCK)
                  WHERE AddWho = @cUserName)
      BEGIN
      	SET @curDelLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      	SELECT RowRef
      	FROM rdt.RDTUCC WITH (NOLOCK)
      	WHERE AddWho = @cUserName
      	OPEN @curDelLog
      	FETCH NEXT FROM @curDelLog INTO @nRowRef
      	WHILE @@FETCH_STATUS = 0
      	BEGIN
      		DELETE FROM rdt.RDTUCC WHERE RowRef = @nRowRef
      		
      		IF @@ERROR <> 0
      		BEGIN
               SET @nErrNo = 87305    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Clear Log Fail    
               GOTO RollBackTran    
      		END
      		
      		FETCH NEXT FROM @curDelLog INTO @nRowRef
      	END
      END
   END

   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_SplitUCC  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  
    
END    

GO