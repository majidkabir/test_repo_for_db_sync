SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_610ExtUpd01                                     */  
/*                                                                      */  
/* Purpose: When piece scanning, user choose end count then update the  */  
/*          current loc as all counted                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2022-01-06  1.0  James       WMS-18486. Created                      */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_610ExtUpd01] (  
   @nMobile        INT,  
   @nFunc          INT,  
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,  
   @nAfterStep     INT,  
   @nInputKey      INT,  
   @cFacility      NVARCHAR( 5),  
   @cStorerKey     NVARCHAR( 15),  
   @cCCRefNo       NVARCHAR( 10),  
   @cCCSheetNo     NVARCHAR( 10),  
   @nCCCountNo     INT,  
   @cZone1         NVARCHAR( 10),  
   @cZone2         NVARCHAR( 10),  
   @cZone3         NVARCHAR( 10),  
   @cZone4         NVARCHAR( 10),  
   @cZone5         NVARCHAR( 10),  
   @cAisle         NVARCHAR( 10),  
   @cLevel         NVARCHAR( 10),  
   @cLOC           NVARCHAR( 10),  
   @cID            NVARCHAR( 18),    
   @cUCC           NVARCHAR( 20),  
   @cSKU           NVARCHAR( 20),  
   @nQty           INT,  
   @cLottable01    NVARCHAR( 18),    
   @cLottable02    NVARCHAR( 18),    
   @cLottable03    NVARCHAR( 18),    
   @dLottable04    DATETIME,    
   @dLottable05    DATETIME,   
   @tExtUpdate     VariableTable READONLY,     
   @nErrNo         INT           OUTPUT,   
   @cErrMsg        NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cOptAction        NVARCHAR( 1)  
   DECLARE @cUserName         NVARCHAR( 18)  
   DECLARE @cCCDetailKey      NVARCHAR( 10)  
   DECLARE @nTranCount        INT  
   DECLARE @cur_EndCount      CURSOR  
     
   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN rdt_610ExtUpd01  
     
   IF @nStep = 23  
   BEGIN  
      IF @nInputKey = 1  
      BEGIN  
         SELECT @cOptAction = I_Field01,  
                @cUserName   = UserName  
         FROM rdt.RDTMOBREC WITH (NOLOCK)  
         WHERE Mobile = @nMobile  
           
         IF @cOptAction <> '2'  
            GOTO Quit  
           
         SELECT @nCCCountNo = FinalizeStage + 1  
         FROM dbo.StockTakeSheetParameters WITH (NOLOCK)  
         WHERE StockTakeKey = @cCCRefNo  
  
         SET @cur_EndCount = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT CCDetailKey  
         FROM dbo.CCDetail WITH (NOLOCK)  
         WHERE CCKey = @cCCRefNo  
         AND   (( @cCCSheetNo = '') OR ( CCSheetNo =  @cCCSheetNo))   
         AND   LOC = @cLOC  
         AND   1 = CASE  
                   WHEN @nCCCountNo = 1 AND Counted_Cnt1 = 0 THEN 1  
                   WHEN @nCCCountNo = 2 AND Counted_Cnt2 = 0 THEN 1  
                   WHEN @nCCCountNo = 3 AND Counted_Cnt3 = 0 THEN 1  
                   ELSE 0 END  
         ORDER BY CCDetailKey  
         OPEN @cur_EndCount  
         FETCH NEXT FROM @cur_EndCount INTO @cCCDetailKey  
         WHILE (@@FETCH_STATUS = 0)  
         BEGIN  
            IF @nCCCountNo = 1  
            BEGIN  
               UPDATE dbo.CCDETAIL WITH (ROWLOCK) SET  
                  Counted_Cnt1  = '1',  
                  EditDate_Cnt1 = GETDATE(),  
                  EditWho_Cnt1  = @cUserName  
               WHERE CCDetailKey = @cCCDetailKey  
  
               IF @@ERROR <> 0  
                  GOTO RollBackTran  
            END  
  
            IF @nCCCountNo = 2  
            BEGIN  
               UPDATE dbo.CCDETAIL WITH (ROWLOCK) SET  
                  Counted_Cnt2  = '1',  
                  EditDate_Cnt2 = GETDATE(),  
                  EditWho_Cnt2  = @cUserName  
               WHERE CCDetailKey = @cCCDetailKey  
                 
               IF @@ERROR <> 0  
                  GOTO RollBackTran  
            END  
  
            IF @nCCCountNo = 3  
            BEGIN  
               UPDATE dbo.CCDETAIL WITH (ROWLOCK) SET  
                  Counted_Cnt3  = '1',  
                  EditDate_Cnt3 = GETDATE(),  
                  EditWho_Cnt3  = @cUserName  
               WHERE CCDetailKey = @cCCDetailKey  
                 
               IF @@ERROR <> 0  
                  GOTO RollBackTran  
            END  
              
            FETCH NEXT FROM @cur_EndCount INTO @cCCDetailKey  
         END  
      END    
   END  
  
   GOTO QUIT  
  
   RollBackTran:  
      ROLLBACK TRAN rdt_610ExtUpd01  
  
   Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN rdt_610ExtUpd01  
  
   Fail:  
  
END  

GO