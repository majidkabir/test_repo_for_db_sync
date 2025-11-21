SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_845CloseSP01                                          */
/* Copyright      : LF Logistics                                              */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 17-09-2021 1.2  Chermaine   WMS-17896 Create                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_845CloseSP01] (
   @nMobile     INT,
   @nFunc       INT, 
	@cLangCode	 NVARCHAR( 3),
	@cUserName   NVARCHAR( 15), 
	@cFacility   NVARCHAR( 5), 
   @cStorerKey  NVARCHAR( 15),
   @cOrgUCCNo   NVARCHAR( 20), 
   @cUCCType    NVARCHAR( 10), 
   @nVariance   INT, 
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nRowCount   INT
   DECLARE @nRowRef     INT
   DECLARE @nOrgRowRef  INT
   DECLARE @cNewUCCNo   NVARCHAR(20)
   DECLARE @cSKU        NVARCHAR(20)
   DECLARE @nQTY        INT
   DECLARE @nOrgQTY     INT
   DECLARE @cExternKey  NVARCHAR(20)
   
   DECLARE @nTranCount	INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_845CloseSP01 -- For rollback or commit only our own transaction

   -- Loop audit log
   DECLARE @curLog CURSOR
   SET @curLog = CURSOR FOR 
      SELECT RowRef, NewUCCNo, SKU, QTY, ExternKey
      FROM rdt.rdtUCCPreRCVAuditLog WITH (NOLOCK)
      WHERE OrgUCCNo = @cOrgUCCNo
         AND StorerKey = @cStorerKey
   OPEN @curLog
   FETCH NEXT FROM @curLog INTO @nRowRef, @cNewUCCNo, @cSKU, @nQTY, @cExternKey
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @nOrgQTY = 0
      IF @cUCCType = 'CIQ'
      BEGIN
         -- Get new UCC info
         SELECT TOP 1 
            @nOrgRowRef = UCC_RowRef
         FROM UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cNewUCCNo
            AND SKU = @cSKU
         SET @nRowCount = @@ROWCOUNT 

         -- Existing SKU
         IF @nRowCount = 1
         BEGIN
            -- Top up QTY
            UPDATE UCC SET 
               QTY = QTY + @nQTY
               --SourceKey = @nOrgRowRef, 
               --SourceType = 'UCCPreRCVAudit' 
            WHERE UCC_RowRef = @nOrgRowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 176051
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UCC Fail
               GOTO RollBackTran
            END
         END
      END
      
      IF @cUCCType = 'RDM'
      BEGIN
         -- Get original UCC info
         SELECT TOP 1 
            @nOrgRowRef = UCC_RowRef
         FROM UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cOrgUCCNo
            AND SKU = @cSKU
         SET @nRowCount = @@ROWCOUNT 
      
         -- Existing SKU
         IF @nRowCount = 1
         BEGIN
            -- Overwrite QTY
            UPDATE UCC SET 
               QTY = @nQTY--, 
               --SourceKey = @nOrgRowRef, 
               --SourceType = 'UCCPreRCVAudit' 
            WHERE UCC_RowRef = @nOrgRowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 176052
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UCC Fail
               GOTO RollBackTran
            END
         END
      END

      -- New SKU 
      IF @nRowCount = 0
      BEGIN
         -- Insert UCC
         INSERT INTO UCC (UCCNo, StorerKey, SKU, QTY, Status, ExternKey, SourceKey, SourceType, 
            Userdefined01, Userdefined02, Userdefined03, Userdefined04, Userdefined05, Userdefined06, Userdefined07, Userdefined08, Userdefined09, Userdefined10)
         SELECT TOP 1 @cNewUCCNo, @cStorerKey, @cSKU, @nQTY, '0', @cExternKey, @nRowRef, 'UCCPreRCVAudit', 
            Userdefined01, Userdefined02, Userdefined03, Userdefined04, Userdefined05, Userdefined06, Userdefined07, Userdefined08, Userdefined09, Userdefined10
         FROM UCC WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cOrgUCCNo
         ORDER BY CASE WHEN SKU = @cSKU THEN 1 ELSE 2 END
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 176053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS UCC Fail
            GOTO RollBackTran
         END
      END
      
      -- Update Log
      UPDATE rdt.rdtUCCPreRCVAuditLog WITH (ROWLOCK) SET
         Status = '9'
      WHERE RowRef = @nRowRef
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 176054
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Log Fail
         GOTO RollBackTran
      END
      
      -- Update Log
      UPDATE rdt.rdtPreReceiveSort WITH (ROWLOCK) SET
         QTY = @nQTY
      WHERE UCCNo = @cNewUCCNo
      AND SKU = @cSKU
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 176055
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD Log Fail
         GOTO RollBackTran
      END
      
      FETCH NEXT FROM @curLog INTO @nRowRef, @cNewUCCNo, @cSKU, @nQTY, @cExternKey
   END

  
   -- Update original UCC
   IF @cUCCType = 'RDM'
   BEGIN
      ---- UCC data contain the SKU, but physical not exist. Mark as invalid
      --UPDATE UCC SET 
      --   --Status = '1', 
      --   UCCNo = LEFT( RTRIM( UCCNo) + 'E', 20)
      --WHERE StorerKey = @cStorerKey 
      --   AND UCCNo = @cOrgUCCNo
      --   AND SourceType <> 'UCCPreRCVAudit'
      --IF @@ERROR <> 0
      --BEGIN
      --   SET @nErrNo = 176056
      --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UCC Fail
      --   GOTO RollBackTran
      --END

      -- Get UCC info
      DECLARE @nSKUCnt INT
      SELECT @nSKUCnt = COUNT( DISTINCT SKU) 
      FROM UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey 
         AND UCCNo = @cOrgUCCNo
      
      -- Update various marker
      UPDATE UCC SET 
         -- UCC sorting location
         UserDefined02 = 
            CASE 
               WHEN @nSKUCnt = 1 THEN '2'   -- Single SKU
               WHEN @nSKUCnt > 1 THEN '1'   -- Multi SKU
               ELSE UserDefined02
            END 
         ,UserDefined03 = CASE WHEN @nVariance = 1 THEN 'Y' ELSE UserDefined03 END -- Variance marker
      WHERE StorerKey = @cStorerKey 
         AND UCCNo = @cOrgUCCNo
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 176057
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD UCC Fail
         GOTO RollBackTran
      END
   END
      
   COMMIT TRAN rdt_845CloseSP01

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '3', -- Picking
      @cUserID       = @cUserName,
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerkey,
      @cRefNo1       = @cOrgUCCNo, 
      @cRefNo2       = 'CLOSE'

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_845CloseSP01
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO