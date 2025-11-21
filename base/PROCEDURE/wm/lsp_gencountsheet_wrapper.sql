SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*****************************************************************************/
/* Stored Procedure: lsp_GenCountSheet_Wrapper                               */
/* Creation Date: 14-MAR-2018                                                */
/* Copyright: LFL                                                            */
/* Written by: Wan                                                           */
/*                                                                           */
/* Purpose: LFWM-263 - Stored Procedures for Release 2 Feature -             */
/*          Inventory  Cycle Count  Stock Take Parameters                    */
/*                                                                           */
/* Called By:                                                                */
/*                                                                           */
/*                                                                           */
/* Version: 1.3                                                              */
/*                                                                           */
/* Data Modifications:                                                       */
/*                                                                           */
/* Updates:                                                                  */
/* Date        Author   Ver   Purposes                                       */
/* 2021-02-05  mingle01 1.1   Add Big Outer Begin try/Catch                  */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()    */
/* 2021-12-02  Wan01    1.2   WMS-18332 - [TW]LOR_CycleCount_CR              */
/*             Wan01    1.2   DevOps Combine Script                          */
/* 2022-06-15  SPChin   1.3   JSM-70416 Revise logic                         */
/* 2023-04-07  TanWLeong1.4   JSM-121612 To overcome Insert cannot be        */
/*                            nested issue  --rmt01                          */
/* 2023-12-26  Calvin   1.5   JSM-199728 Set Rowcount to EXEC (CLVN01)       */
/* 2025-02-28  SG01     1.6   UWP-30341 - Add check for CCDetail Transaction */
/*************************************************************************/     
CREATE   PROCEDURE [WM].[lsp_GenCountSheet_Wrapper]    
   @c_StockTakeKey         NVARCHAR(10)  
,  @c_GenType              CHAR(1)      = 'N'   -- B:Blank, N:Normal, U:UCC  
,  @c_BlankCSheetHideLoc   CHAR(1)      = ''  
,  @n_BlankCSheetNoOfPage  INT          = 0  
,  @b_Success              INT          = 1   OUTPUT     
,  @n_Err                  INT          = 0   OUTPUT  
,  @c_Errmsg               NVARCHAR(255)= ''  OUTPUT  
,  @n_WarningNo            INT          = 0   OUTPUT  
,  @c_ProceedWithWarning   CHAR(1)      = 'N'   
,  @c_UserName             NVARCHAR(128)= ''  
AS    
BEGIN    
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue        INT = 1  
         , @n_StartTCnt       INT = @@TRANCOUNT  
  
         , @n_Count           INT = 0   
         , @c_CCSheetNo_Min   NVARCHAR(10) = ''  
         , @c_CCSheetNo_Max   NVARCHAR(10) = ''  
         , @c_CountNo         CHAR(1)      = '1'  
   , @n_rowcount        INT = 0             
           
  
   --CREATE TABLE #TMP_CC        --rmt01
   --      (  DataCount INT )    --rmt01
  
   SET @b_Success = 1  
   SET @c_ErrMsg = ''  
  
   SET @n_Err = 0   
  
   --(mingle01) - START     
   IF SUSER_SNAME() <> @c_UserName  
   BEGIN  
      EXEC [WM].[lsp_SetUser]   
               @c_UserName = @c_UserName  OUTPUT  
            ,  @n_Err      = @n_Err       OUTPUT  
            ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT  
    
      IF @n_Err <> 0   
      BEGIN  
         GOTO EXIT_SP  
      END  
  
      EXECUTE AS LOGIN = @c_UserName  
   END  
   --(mingle01) - END  
  
   BEGIN TRAN     --(Wan01)  
   --(mingle01) - START  
   BEGIN TRY   
  
      IF @c_GenType = 'B'  
      BEGIN  
         IF @c_BlankCSheetHideLoc = 'Y' AND ISNULL(@n_BlankCSheetNoOfPage, 0) = 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_err = 552401  
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Please Key-in No Of Blank Count Sheet. (lsp_GenCountSheet_Blank_Wrapper)'  
            GOTO EXIT_SP        
         END   
      END  
      ELSE  
      BEGIN  
         SET @n_Count = 0  
   
                 
         IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1   
         BEGIN  
            BEGIN TRY   
            --  TRUNCATE TABLE #TMP_CC                              --rmt01
            --   INSERT INTO #TMP_CC (DataCount)       --JSM-70416  --rmt01    
               --EXECUTE ispCheckOutstandingOrders      --JSM-70416      --(CLVN01)   
               EXECUTE @n_rowcount = ispCheckOutstandingOrders      --(CLVN01)    
                  @c_StockTakeKey = @c_StockTakeKey           
               ,  @c_CountNo = @c_CountNo   
            --select @@rowcount                   --rmt01     --(CLVN01)
            --set @n_rowcount = @@rowcount            --rmt01 --(CLVN01)
            --select @n_rowcount as nfirstcount       --rmt01 --(CLVN01)
              
     
              -- SELECT TOP 1 @n_Count = ISNULL(DataCount, 0)       --rmt01
              -- FROM #TMP_CC WITH (NOLOCK)           --JSM-70416   --rmt01
            END TRY  
  
            BEGIN CATCH  
               SET @n_err = 552402  
               SET @c_ErrMsg = ERROR_MESSAGE()  
               SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ispCheckOutstandingOrders. (lsp_GenCountSheet_Wrapper)'  
                              + '( ' + @c_errmsg + ' )'  
            END CATCH      
                     
            IF @b_success = 0 OR @n_Err <> 0          
            BEGIN          
               SET @n_continue = 3        
               GOTO EXIT_SP  
            END          
 
       
	         --@n_Count > 0  --rmt01
           IF @n_rowcount > 0   
           BEGIN  
              SET @n_continue  = 3  
              SET @c_ErrMsg= 'Warning !' + CONVERT(NVARCHAR(10),/*@n_Count*/@n_rowcount) + ' Outstanding record(s) found! Please close all the Shipment Orders before you proceed. ' + CHAR(13)   
                             + 'Warning, System will generate Count Sheet even with Outstanding record(s) being found ! '  
                             + 'Are you sure you want to proceed?'  
              SET @n_WarningNo = 1  
              GOTO EXIT_SP  
     
            END  
         END  
      END  
  
      SET @n_rowcount = 0--@n_Count = 0  
      BEGIN TRY  
       -- TRUNCATE TABLE #TMP_CC --JSM-70416  
        -- INSERT INTO #TMP_CC (DataCount)  
         EXECUTE ispCheckCCkey          
          @c_StockTakeKey = @c_StockTakeKey  
       --select @@rowcount as last  
    --set @n_rowcount = @@rowcount    
      END TRY  
  
      BEGIN CATCH  
         SET @n_err = 552403  
         SET @c_ErrMsg = ERROR_MESSAGE()  
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ispCheckCCkey. (lsp_GenCountSheet_Wrapper)'  
                        + '( ' + @c_errmsg + ' )'  
      END CATCH      
                     
      IF @b_success = 0 OR @n_Err <> 0          
      BEGIN          
         SET @n_continue = 3        
         GOTO EXIT_SP  
      END          
  
      --IF (SELECT DataCount FROM #TMP_CC) > 0   --rmt01
      IF EXISTS ( SELECT COUNT(DISTINCT CCKey) FROM CCDETAIL (NOLOCK) WHERE CCKey = @c_StockTakeKey HAVING COUNT(DISTINCT CCKey) > 0) -- SG01
      BEGIN
          SET @n_continue = 3
          SET @n_err = 552404
          SET @c_ErrMsg = 'CCDetail Transaction Found ! Regeneration Not Allow.'

          GOTO EXIT_SP
      END
  
      IF @c_GenType = 'B'  
      BEGIN  
         BEGIN TRY        
         EXECUTE ispGenBlankSheet          
            @c_StockTakeKey = @c_StockTakeKey           
         END TRY  
  
         BEGIN CATCH  
            SET @n_err = 552405  
            SET @c_ErrMsg = ERROR_MESSAGE()  
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ispGenBlankSheet. (lsp_GenCountSheet_Blank_Wrapper)'  
                           + '( ' + @c_errmsg + ' )'  
         END CATCH      
                     
         IF @b_success = 0 OR @n_Err <> 0          
         BEGIN          
            SET @n_continue = 3        
            GOTO EXIT_SP  
         END    
      END  
  
      IF @c_GenType = 'N'  
      BEGIN  
         BEGIN TRY        
            EXECUTE ispGenCountSheet          
               @c_StockTakeKey = @c_StockTakeKey           
         END TRY  
  
         BEGIN CATCH  
            SET @n_err = 552406  
            SET @c_ErrMsg = ERROR_MESSAGE()  
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ispGenCountSheet. (lsp_GenCountSheet_Wrapper)'  
                           + '( ' + @c_errmsg + ' )'  
         END CATCH      
                    
         IF @b_success = 0 OR @n_Err <> 0          
         BEGIN          
            SET @n_continue = 3        
            GOTO EXIT_SP  
         END          
      END  
  
      IF @c_GenType = 'U'  
      BEGIN  
         BEGIN TRY        
            EXECUTE ispCheckUCCBal          
               @c_StockTakeKey = @c_StockTakeKey           
         END TRY  
  
         BEGIN CATCH  
            SET @n_err = 552407  
            SET @c_ErrMsg = ERROR_MESSAGE()  
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ispCheckUCCBal. (lsp_GenCountSheet_UCC_Wrapper)'  
                           + '( ' + @c_errmsg + ' )'  
         END CATCH      
                     
         IF @b_success = 0 OR @n_Err <> 0          
         BEGIN          
            SET @n_continue = 3        
            GOTO EXIT_SP  
         END          
  
         SET @n_rowcount = 0   --rmt01
		 set @n_Count = 0  
         SELECT TOP 1 @n_Count = 1  
         FROM STOCKTAKEERRORREPORT WITH (NOLOCK)  
         WHERE StockTakeKey = @c_StockTakeKey  
  
         IF @n_Count > 0   
         BEGIN  
            SET @n_continue = 3      
            SET @n_err = 552408  
            SET @c_ErrMsg = 'UCC Qty Not Tally With LOTXLOCXID. Please Refer to STOCKTAKEERRORREPORT. (lsp_GenCountSheet_UCC_Wrapper)'  
        
            GOTO EXIT_SP  
         END  
  
         BEGIN TRY        
            EXECUTE ispGenCountSheetByUCC          
               @c_StockTakeKey = @c_StockTakeKey           
         END TRY  
  
         BEGIN CATCH  
            SET @n_err = 552409  
            SET @c_ErrMsg = ERROR_MESSAGE()  
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing ispGenCountSheetByUCC. (lsp_GenCountSheet_UCC_Wrapper)'  
                           + '( ' + @c_errmsg + ' )'  
         END CATCH      
                     
         IF @b_success = 0 OR @n_Err <> 0          
         BEGIN          
            SET @n_continue = 3        
            GOTO EXIT_SP  
         END          
      END  
  
      SET @n_Count = 0  
      SELECT @c_CCSheetNo_Min = ISNULL(MIN(CCSheetNo),'')  
            ,@c_CCSheetNo_Max = ISNULL(MAX(CCSheetNo),'')   
            ,@n_Count = COUNT(1)  
      FROM CCDETAIL WITH (NOLOCK)  
      WHERE cckey = @c_StockTakeKey  
  
      IF @n_Count > 0   
      BEGIN  
         SET @c_ErrMsg = 'Cycle Count Ref #: ' + @c_StockTakeKey + CHAR(13)  
                       + 'Count Sheet # From: '+ @c_CCSheetNo_Min + ' To ' + @c_CCSheetNo_Max + CHAR(13)  
                       + 'Generate Successfully'    
        
         GOTO EXIT_SP  
      END  
  
   END TRY  
  
   BEGIN CATCH  
      SET @n_Continue = 3  
      SET @c_ErrMsg = ERROR_MESSAGE()  
      GOTO EXIT_SP  
   END CATCH  
   --(mingle01) - END  
EXIT_SP:   
   IF (XACT_STATE()) = -1     --(Wan01) - START    
   BEGIN    
      SET @n_Continue=3  
      ROLLBACK TRAN;    
   END;                       --(Wan01) - END   
     
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt         --(Wan01)  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_GenCountSheet_Wrapper'  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
  
      SET @n_WarningNo = 0  
   END  
  
   REVERT        
END    


GO