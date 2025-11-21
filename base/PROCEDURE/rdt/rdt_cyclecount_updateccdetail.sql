SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_CycleCount_UpdateCCDetail                       */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Update CCDetail after confirmed items counted               */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 05-Jun-2006 1.0  MaryVong    Created                                 */
/* 20-May-2009 1.1  MaryVong    Allow empty CCSheetNo (MaryVong01)      */
/* 11-Aug-2016 1.2  James       SOS375049 - Update Loc.CycleCounter     */
/*                              Add Save Tran (james01)                 */
/* 01-Nov-2016 1.3  Leong       IN00187400 - Reset Counted_Cnt(x).      */
/* 31-May-2023 1.4  James       WMS-22615 Add UCCWithMultiSKU (james02) */
/************************************************************************/

CREATE   PROC [RDT].[rdt_CycleCount_UpdateCCDetail] (
   @cCCRefNo      NVARCHAR(10),
   @cCCSheetNo    NVARCHAR(10),
   @nCCCountNo    INT,
   @cCCDetailKey  NVARCHAR(10),
   @nQTY          INT,
   @cUserName     NVARCHAR(18),
   @cLangCode     VARCHAR (3),
   @nErrNo        INT          OUTPUT,
   @cErrMsg       NVARCHAR(20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT,
           @cStorerKey     NVARCHAR(15),
           @cLoc           NVARCHAR(10),
           @cFacility      NVARCHAR( 5),
           @cUCCWithMultiSKU  NVARCHAR( 1),
           @cUCC              NVARCHAR( 20),
           @cSKU              NVARCHAR( 20),
           @nFunc             INT

   SELECT 
      @nFunc = Func,
      @cStorerKey = StorerKey,
      @cUCC = V_UCC,
      @cSKU = V_SKU
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE UserName = @cUserName
   
   SET @cUCCWithMultiSKU = rdt.RDTGetConfig( @nFunc, 'UCCWithMultiSKU', @cStorerKey)
   
   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN CycleCountTran

   IF @cLangCode = 'Y' -- @cRecountFlag, IN00187400
   BEGIN
      DECLARE @cErrLangCode NVARCHAR(3)

      SET @cErrLangCode = ''
      SET @cLoc = @cCCDetailKey

      SELECT @cErrLangCode = ISNULL(RTRIM(Lang_Code),'')
      FROM rdt.RDTMobRec WITH (NOLOCK)
      WHERE UserName = @cUserName

      IF @nCCCountNo = 1
      BEGIN
         UPDATE dbo.CCDETAIL WITH (ROWLOCK)
         SET
            Counted_Cnt1  = CASE WHEN Counted_Cnt1 = '1' THEN '0' ELSE Counted_Cnt1 END,
            EditDate_Cnt1 = GETDATE(),
            EditWho_Cnt1  = @cUserName
         WHERE CCKey = @cCCRefNo
            AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND Loc = @cLoc
            AND Status < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 105051
            SET @cErrMsg = rdt.rdtgetmessage( 105051, @cErrLangCode, 'DSP') -- UpdCCDetFail
            GOTO RollBackTran
         END
      END

      IF @nCCCountNo = 2
      BEGIN
         UPDATE dbo.CCDETAIL WITH (ROWLOCK)
         SET
            Counted_Cnt2  = CASE WHEN Counted_Cnt2 = '1' THEN '0' ELSE Counted_Cnt2 END,
            EditDate_Cnt2 = GETDATE(),
            EditWho_Cnt2  = @cUserName
         WHERE CCKey = @cCCRefNo
            AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND Loc = @cLoc
            AND Status < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 105052
           SET @cErrMsg = rdt.rdtgetmessage( 105052, @cErrLangCode, 'DSP') -- UpdCCDetFail
            GOTO RollBackTran
         END
      END

      IF @nCCCountNo = 3
      BEGIN
         UPDATE dbo.CCDETAIL WITH (ROWLOCK)
         SET
            Counted_Cnt3  = CASE WHEN Counted_Cnt3 = '1' THEN '0' ELSE Counted_Cnt3 END,
            EditDate_Cnt3 = GETDATE(),
            EditWho_Cnt3  = @cUserName
         WHERE CCKey = @cCCRefNo
            AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND Loc = @cLoc
            AND Status < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 105053
            SET @cErrMsg = rdt.rdtgetmessage( 105053, @cErrLangCode, 'DSP') -- UpdCCDetFail
            GOTO RollBackTran
         END
      END
   END -- @cLangCode = 'Y'
   ELSE
   BEGIN
   	INSERT INTO traceinfo(tracename, timein, Col1, Col2, Col3) VALUES ('6101', GETDATE(), @cUCCWithMultiSKU, @cUCC, @cSKU)
   	IF @cUCCWithMultiSKU = '1' AND 
         EXISTS(SELECT 1 
                FROM dbo.UCC WITH (NOLOCK) 
                WHERE UCCNo = @cUCC 
                AND Storerkey = @cStorerKey 
                GROUP BY UCCNO 
                HAVING COUNT( SKU) > 1)
      BEGIN
         SELECT 
            @cLoc = Loc,
            @cCCDetailKey = CCDetailKey
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCKey = @cCCRefNo
         AND   RefNo = @cUCC
         AND   Sku = @cSKU
         INSERT INTO traceinfo(tracename, timein, Col1, Col2, Col3, Col4, Col5) VALUES ('6102', GETDATE(), @cCCRefNo, @cUCC, @cSKU, @cLoc, @cCCDetailKey)
      END
      ELSE
      BEGIN
         SELECT @cLoc = Loc
         FROM dbo.CCDetail WITH (NOLOCK)
         WHERE CCDetailKey = @cCCDetailKey
      END
      
      IF @nCCCountNo = 1
      BEGIN
         UPDATE dbo.CCDETAIL WITH (ROWLOCK)
         SET
            -- If update record with status = '4' (newly added), shd remain '4'
            -- Update status = '2' for existing record in CCDetail
            Status        = CASE WHEN Status = '0' THEN '2' ELSE Status END,
            QTY           = @nQTY,
            Counted_Cnt1  = '1',
            EditDate_Cnt1 = GetDate(),
            EditWho_Cnt1  = @cUserName
         WHERE CCKey = @cCCRefNo
            -- AND CCSheetNo = @cCCSheetNo
            AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
            AND CCDetailKey = @cCCDetailKey
            -- Allow update more than 1 time
            AND Status < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 62166
            SET @cErrMsg = rdt.rdtgetmessage( 62166, @cLangCode, 'DSP') -- Upd CCDET fail
            GOTO RollBackTran
         END
      END

      IF @nCCCountNo = 2
      BEGIN
         UPDATE dbo.CCDETAIL WITH (ROWLOCK)
         SET
            Status        = CASE WHEN Status = '0' THEN '2' ELSE Status END,
            QTY_Cnt2      = @nQTY,
            Counted_Cnt2  = '1',
            EditDate_Cnt2 = GetDate(),
            EditWho_Cnt2  = @cUserName
         WHERE CCKey = @cCCRefNo
            -- AND CCSheetNo = @cCCSheetNo
            AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
            AND CCDetailKey = @cCCDetailKey
            AND Status < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 62167
            SET @cErrMsg = rdt.rdtgetmessage( 62167, @cLangCode, 'DSP') -- Upd CCDET fail
            GOTO RollBackTran
         END
      END

      IF @nCCCountNo = 3
      BEGIN
         UPDATE dbo.CCDETAIL WITH (ROWLOCK)
         SET
            Status        = CASE WHEN Status = '0' THEN '2' ELSE Status END,
            QTY_Cnt3      = @nQTY,
            Counted_Cnt3  = '1',
            EditDate_Cnt3 = GetDate(),
            EditWho_Cnt3  = @cUserName
         WHERE CCKey = @cCCRefNo
            -- AND CCSheetNo = @cCCSheetNo
            AND CCSheetNo = CASE WHEN ISNULL(@cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END -- (MaryVong01)
            AND CCDetailKey = @cCCDetailKey
            AND Status < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 62168
            SET @cErrMsg = rdt.rdtgetmessage( 62168, @cLangCode, 'DSP') -- Upd CCDET fail
            GOTO RollBackTran
         END
      END

      -- (james01)
      -- Check if cckey + loc update before loc.cyclecounter
      -- Only need update loc.cyclecounter 1 time per cckey + loc
      IF NOT EXISTS ( SELECT 1 FROM dbo.CCDetail WITH (NOLOCK)
                      WHERE CCKey = @cCCRefNo
                      AND   Storerkey = @cStorerKey
                      AND   LOC = @cLoc
                      AND   StatusMsg = '1')
      BEGIN
         SELECT @cFacility = Facility
         FROM rdt.RDTMOBREC WITH (NOLOCK)
         WHERE UserName = @cUserName

         UPDATE dbo.LOC WITH (ROWLOCK) SET
            CycleCounter = ISNULL( CycleCounter, 0) + 1
         WHERE LOC = @cLoc
         AND   Facility = @cFacility

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 77722
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  -- UpdCounterFail
            GOTO RollBackTran
         END

         UPDATE TOP (1) dbo.CCDetail WITH (ROWLOCK) SET
            StatusMsg = '1'
         WHERE CCKey = @cCCRefNo
         AND   Storerkey = @cStorerKey
         AND   LOC = @cLoc
         AND   StatusMsg <> '1'
         AND   ( Qty + Qty_Cnt2 + Qty_Cnt3) > 0 -- something counted

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 77723
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  -- UpdCCDtlFail
            GOTO RollBackTran
         END
      END

   END

   GOTO QUIT

   RollBackTran:
    ROLLBACK TRAN CycleCountTran

   Quit:
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
          COMMIT TRAN CycleCountTran
END

GO