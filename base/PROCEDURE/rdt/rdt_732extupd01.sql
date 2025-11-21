SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_732ExtUpd01                                     */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Upd qty if system qty <> qty (based on count no)            */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 18-08-2016  1.0  James       SOS370878. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_732ExtUpd01]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cCCKey       NVARCHAR( 10) 
   ,@cCCSheetNo   NVARCHAR( 10) 
   ,@cCountNo     NVARCHAR( 1)  
   ,@cLOC         NVARCHAR( 10) 
   ,@cSKU         NVARCHAR( 20) 
   ,@nQTY         INT
   ,@cOption      NVARCHAR( 1)  
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount     INT,
           @cCCDetailKey   NVARCHAR( 10)

   SET @nTranCount = @@TRANCOUNT  

   BEGIN TRAN  
   SAVE TRAN CycleCountTran  
   
   IF @nStep = 1 -- CCKey, CCSheetNo
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @cCountNo IN ( '2', '3')
         BEGIN
            -- When in count 2 & 3 (only), look for loc which have variance
            -- and reset the qty to recount the whole loc
            DECLARE CUR_UPDCC CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT DISTINCT LOC 
            FROM dbo.CCDetail WITH (NOLOCK) 
            WHERE CCKey = @cCCKey
            AND CCSheetNo = CASE WHEN ISNULL( @cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
            AND Storerkey = @cStorerkey
            AND 1 = CASE WHEN @cCountNo = '2' AND SystemQty <> Qty AND Counted_Cnt2 = 0 AND FinalizeFlag_Cnt2 <> 'Y' THEN 1 
                         WHEN @cCountNo = '3' AND SystemQty <> Qty_cnt2 AND Counted_Cnt3 = 0 AND FinalizeFlag_Cnt3 <> 'Y' THEN 1
                    ELSE 0 END
            ORDER BY 1
            OPEN CUR_UPDCC
            FETCH NEXT FROM CUR_UPDCC INTO @cLOC
            WHILE @@FETCH_STATUS <> -1 
            BEGIN
               DECLARE CUR_UPDCCDtl CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
               SELECT CCDetailKey
               FROM dbo.CCDetail WITH (NOLOCK) 
               WHERE CCKey = @cCCKey
               AND   CCSheetNo = CASE WHEN ISNULL( @cCCSheetNo, '') = '' THEN CCSheetNo ELSE @cCCSheetNo END
               AND   Storerkey = @cStorerkey
               AND   LOC = @cLOC
               AND 1 = CASE WHEN @cCountNo = '2' AND Counted_Cnt2 = 0 AND FinalizeFlag_Cnt2 <> 'Y' THEN 1 
                            WHEN @cCountNo = '3' AND Counted_Cnt3 = 0 AND FinalizeFlag_Cnt3 <> 'Y' THEN 1
                       ELSE 0 END
               ORDER BY 1
               OPEN CUR_UPDCCDtl
               FETCH NEXT FROM CUR_UPDCCDtl INTO @cCCDetailKey
               WHILE @@FETCH_STATUS <> -1 
               BEGIN
                  UPDATE dbo.CCDetail WITH (ROWLOCK) SET 
                     Qty_Cnt2 = CASE WHEN @cCountNo = '2' THEN 0 ELSE Qty_Cnt2 END, 
                     Qty_Cnt3 = CASE WHEN @cCountNo = '3' THEN 0 ELSE Qty_Cnt3 END  
                  WHERE CCDetailKey = @cCCDetailKey 

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 102951  
                     SET @cErrMsg = rdt.rdtgetmessage(@nErrNo, @cLangCode, 'DSP')  -- Reset LOC Fail  
                     GOTO RollBackTran    
                  END

                  FETCH NEXT FROM CUR_UPDCCDtl INTO @cCCDetailKey
               END
               CLOSE CUR_UPDCCDtl
               DEALLOCATE CUR_UPDCCDtl

               FETCH NEXT FROM CUR_UPDCC INTO @cLOC
            END
            CLOSE CUR_UPDCC
            DEALLOCATE CUR_UPDCC
         END   -- @cCountNo IN ( '2', '3')
      END   -- @nInputKey = 1
   END   -- @nStep = 1

   GOTO QUIT  

   RollBackTran:  
    ROLLBACK TRAN CycleCountTran  
  
   Quit:  
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started  
          COMMIT TRAN CycleCountTran  
END

GO