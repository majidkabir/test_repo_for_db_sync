SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_CycleCount_UpdateCCDetail_V7                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 06-May-2019 1.0  James       WMS-8649 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_CycleCount_UpdateCCDetail_V7] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cCCRefNo      NVARCHAR(10),
   @cCCSheetNo    NVARCHAR(10),
   @nCCCountNo    INT,
   @cCCDetailKey  NVARCHAR(10),
   @nQTY          INT,
   @nErrNo        INT          OUTPUT,
   @cErrMsg       NVARCHAR(20) OUTPUT  -- screen limitation, 20 char max
) AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT,
           @cLoc           NVARCHAR(10),
           @cUserName      NVARCHAR(18)

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN CycleCountTran

  SELECT @cStorerKey = StorerKey, 
          @cLoc = Loc 
   FROM dbo.CCDetail WITH (NOLOCK)
   WHERE CCDetailKey = @cCCDetailKey

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

   GOTO QUIT

   RollBackTran:
    ROLLBACK TRAN CycleCountTran

   Quit:
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
          COMMIT TRAN CycleCountTran
END

GO