SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_TM_CycleCount_Alert                             */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Comfirm Pick                                                */
/*                                                                      */
/* Called from: TM CC UCC, SKU, SINGLE SCAN SP                          */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 17-11-2011 1.0  ChewKP   Created                                     */
/* 17-12-2012 1.1  James    Get storerkey if it is blank (james01)      */
/************************************************************************/

CREATE PROC [RDT].[rdt_TM_CycleCount_Alert] (
     @nMobile          INT
    ,@cCCKey           NVARCHAR( 10)
    ,@cStorerKey       NVARCHAR( 15)  
    ,@cLOC             NVARCHAR( 10)  
    ,@cID              NVARCHAR( 18)  
    ,@cSKU             NVARCHAR( 20) 
    ,@cUserName        NVARCHAR( 18)  
    ,@cModuleName      NVARCHAR( 30)
    ,@cActivity        NVARCHAR( 10)
    ,@cCCType          NVARCHAR( 10)
    ,@cTaskDetailKey   NVARCHAR( 10)
    ,@cLangCode        NVARCHAR( 3)
    ,@nErrNo           INT         OUTPUT
    ,@cErrMsg          NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
    
    
 )
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @b_success             INT
          , @n_err                 INT
          , @c_errmsg              NVARCHAR(250)
          , @nTranCount            INT
          , @bDebug                INT
          , @nSystemQty            INT
          , @c_NewLineChar         NVARCHAR( 2)
            -- ,@cStorerKey       NVARCHAR( 15)  
           
          , @nQty                  INT   
          , @c_AlertMessage      NVARCHAR( 255)
          , @cUCC                NVARCHAR( 20)
          , @cLot                NVARCHAR( 10)
          , @cCCSheetNo          NVARCHAR( 10)
          , @cTaskType           NVARCHAR( 10)
    
    -- (james01)
    -- Cycle count should only for 1 storer
    IF ISNULL(@cStorerKey, '') = ''
       SELECT TOP 1 @cStorerKey = StorerKey FROM dbo.CCDetail WITH (NOLOCK) WHERE CCSheetNo = @cTaskDetailKey

    SET @bDebug = 0
    SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10) 

    SET @nTranCount = @@TRANCOUNT
    

    
    BEGIN TRAN
    SAVE TRAN TM_CC_UCC_Alert
    
--    IF @cSKU = '' 
--    BEGIN
        
       DECLARE CursorAlertCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
       
       SELECT Qty, SystemQty, RefNo, SKU, Lot, CCSheetNo, ID 
       FROM dbo.CCDetail WITH (NOLOCK)
       WHERE CCKey      = @cCCKey
       --AND Status       < '9'
       --AND SKU          = @cSKU
       AND StorerKEy    = @cStorerKey 
       AND Loc          = @cLoc
       AND CCSheetNo    = @cTaskDetailKey
    
--    END
--    ELSE
--    BEGIN
--      DECLARE CursorAlertCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
--       
--       SELECT Qty, SystemQty, RefNo, SKU, Lot
--       FROM dbo.CCDetail WITH (NOLOCK)
--       WHERE CCKey      = @cCCKey
--       AND Status       IN ('0','5')
--       AND SKU          = @cSKU
--       AND StorerKEy    = @cStorerKey
--       AND Loc          = @cLoc
--       AND ID           = @cID
--       
--    END
   
    OPEN CursorAlertCC            
    
    FETCH NEXT FROM CursorAlertCC INTO @nQty, @nSystemQty, @cUCC, @cSKU, @cLot, @cCCSheetNo, @cID
    
    WHILE @@FETCH_STATUS <> -1            
    BEGIN   
        
        SET @cTaskType = ''
        
        SELECT @cTaskType = TaskType 
        FROM dbo.TaskDetail WITH (NOLOCK)
        WHERE TaskDetailKey = @cCCSheetNo 
        
        
            
        SET @c_AlertMessage = ' TaskType: ' + @cTaskType  +  @c_NewLineChar 
        
        IF @nSystemQty > @nQty 
        BEGIN
            IF @cCCType = 'UCC'
            BEGIN
                  SET @c_AlertMessage = RTRIM(@c_AlertMessage)  + 'ReasonCode : UCC Short' + @c_NewLineChar 
            END
            IF @cCCType = 'SKU' 
            BEGIN
                  SET @c_AlertMessage = RTRIM(@c_AlertMessage)  + 'ReasonCode : SKU Short' + @c_NewLineChar 
            END
            IF @cCCType = 'SINGLE'
            BEGIN
                  SET @c_AlertMessage = RTRIM(@c_AlertMessage)  + 'ReasonCode : SINGLE Short' + @c_NewLineChar 
            END
        END
        
        IF @nSystemQty < @nQty 
        BEGIN
            IF @cCCType = 'UCC'
            BEGIN
                  SET @c_AlertMessage = RTRIM(@c_AlertMessage)  + 'ReasonCode : UCC Extra' + @c_NewLineChar 
            END
            IF @cCCType = 'SKU' 
            BEGIN
                  SET @c_AlertMessage = RTRIM(@c_AlertMessage)  + 'ReasonCode : SKU Extra' + @c_NewLineChar 
            END
            IF @cCCType = 'SINGLE'
            BEGIN
                  SET @c_AlertMessage = RTRIM(@c_AlertMessage)  + 'ReasonCode : SINGLE Extra' + @c_NewLineChar 
            END
        END
        
        
        
        IF @nSystemQty <> @nQty 
        BEGIN
           EXEC nspLogAlert
                    @c_modulename       = @cModulename     
                  , @c_AlertMessage     = @c_AlertMessage   
                  , @n_Severity         = '5'       
                  , @b_success          = @b_success        
                  , @n_err              = @nErrNo            
                  , @c_errmsg           = @cErrMsg         
                  , @c_Activity	       = @cActivity	      
                  , @c_Storerkey	       = @cStorerkey	   
                  , @c_SKU	             = @cSKU	         
                  , @c_UOM	             = ''	         
                  , @c_UOMQty	          = ''	      
                  , @c_Qty	             = @nQty         
                  , @c_Lot	             = @cLot         
                  , @c_Loc	             = @cLoc	         
                  , @c_ID	             = @cID	            
                  , @c_TaskDetailKey	 = @cCCSheetNo
                  , @c_UCCNo	          = @cUCC
      
         END
         
    FETCH NEXT FROM CursorAlertCC INTO @nQty, @nSystemQty, @cUCC, @cSKU, @cLot, @cCCSheetNo, @cID
    
    END
    CLOSE CursorAlertCC            
    DEALLOCATE CursorAlertCC         
    
    
    
    GOTO Quit

    RollBackTran:
    ROLLBACK TRAN TM_CC_UCC_Alert
    CLOSE CursorAlertCC            
    DEALLOCATE CursorAlertCC   
    
    Quit:
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
          COMMIT TRAN TM_CC_UCC_Alert
END

GO