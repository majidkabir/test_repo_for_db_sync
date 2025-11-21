SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: WMS                                                 */
/* Creation Date:                                                       */     
/* Copyright: LFLogistics                                               */
/* Written by:                                                          */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: FinalizeIQC                                                 */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.2                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2021-01-15  Wan01    1.1   Add Big Outer Begin try/Catch             */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/*                      1.1   Fixed Uncommitable Transaction             */
/* 2022-06-16  Wan02    1.2   LFWM-3512 - PROD & UAT - HK  11376 & 1158  */
/*                            SCE InventoryQC issue                      */
/* 2022-06-16  Wan02    1.2   DevOps Combine Script                      */
/************************************************************************/
CREATE PROCEDURE [WM].[lsp_FinalizeIQC_Wrapper]
      @c_QC_Key NVARCHAR(10)
    , @c_QCLineNo NVARCHAR(5)=''   
    , @b_Success INT=1 OUTPUT
    , @n_Err INT=0 OUTPUT
    , @c_ErrMsg NVARCHAR(250)='' OUTPUT
    , @n_WarningNo INT = 0       OUTPUT
    , @c_ProceedWithWarning CHAR(1) = 'N' 
    , @c_UserName NVARCHAR(128)=''
    , @n_ErrGroupKey INT = 0 OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
       
   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName        --(Wan01) - START
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT
    
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
                
      EXECUTE AS LOGIN = @c_UserName        
   END                                    --(Wan01) - END

   BEGIN TRY
      DECLARE @n_err2                  int 
            , @n_continue              int   
            , @n_StartTCnt             INT = @@TRANCOUNT                                 
            , @c_StorerKey             NVARCHAR(15) 
            , @c_Facility              NVARCHAR(5) 
            , @c_FinalizeFlag          NVARCHAR(1)
            , @c_OriginalQCLineNo      NVARCHAR(5)

            , @c_TableName             NVARCHAR(50)
            , @c_SourceKey             NVARCHAR(15) 
            , @c_SourceType            NVARCHAR(30) 

            , @c_FinalizeIQC           NVARCHAR(10) = '' 
            
            , @n_TotalQCToQty          INT            = 0         --(Wan02)
            , @n_SystemQty             INT            = 0         --(Wan02)    
            , @c_FromLot               NVARCHAR(10)   = ''        --(Wan02) 
            , @c_FromLoc               NVARCHAR(10)   = ''        --(Wan02) 
            , @c_FromID                NVARCHAR(18)   = ''        --(Wan02)
            
      --(Wan02) - START                                                          
      IF OBJECT_ID('tempdb..#TMP_QCD','u') IS NOT NULL
      BEGIN
         DROP TABLE #TMP_QCD;
      END
      
      CREATE TABLE #TMP_QCD 
      (  QC_Key   NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  QCLineNo NVARCHAR(5)    NOT NULL DEFAULT('') PRIMARY KEY 
      ,  FromLot  NVARCHAR(10)   NOT NULL DEFAULT('') 
      ,  FromLoc  NVARCHAR(10)   NOT NULL DEFAULT('')   
      ,  FromID   NVARCHAR(18)   NOT NULL DEFAULT('')            
      )
      --(Wan02) - END
      
      SET @n_continue   = 1
      SET @c_TableName = 'InventoryQCDetail'
      SET @c_SourceType = 'lsp_FinalizeIQC_Wrapper'
      SET @n_ErrGroupKey = 0
      SET @c_OriginalQCLineNo = @c_QCLineNo

      -- Validation before finalize
      DECLARE @c_IQCStatus NVARCHAR(10)
    
      IF @c_QCLineNo <> ''
      BEGIN
         INSERT INTO #TMP_QCD (QC_Key, QCLineNo, FromLot, FromLoc, FromID)                   --(Wan02) 
         SELECT iqd.QC_Key, iqd.QCLineNo, iqd.FromLot, iqd.FromLoc, iqd.FromID FROM dbo.InventoryQCDetail AS iqd WITH (NOLOCK) 
         WHERE iqd.QC_Key = @c_QC_Key
         AND iqd.QCLineNo = @c_QCLineNo
         
         SELECT @c_FinalizeFlag = IQC.FinalizeFlag, 
               @c_StorerKey = IQC.StorerKey, 
               @c_Facility  = IQC.From_Facility
            , @c_IQCStatus = RTRIM(IQCD.Status)
         FROM InventoryQC AS IQC WITH(NOLOCK)
         JOIN InventoryQCDetail IQCD WITH (NOLOCK) ON IQCD.QC_Key = IQC.QC_Key and IQCD.QCLineNo = @c_QCLineNo
         WHERE IQC.QC_Key = @c_QC_Key

      END
      ELSE
      BEGIN
         INSERT INTO #TMP_QCD (QC_Key, QCLineNo, FromLot, FromLoc, FromID)                   --(Wan02) 
         SELECT iqd.QC_Key, iqd.QCLineNo, iqd.FromLot, iqd.FromLoc, iqd.FromID FROM dbo.InventoryQCDetail AS iqd WITH (NOLOCK) 
         WHERE iqd.QC_Key = @c_QC_Key
         
         SET @c_IQCStatus = ''
         SELECT @c_FinalizeFlag = IQC.FinalizeFlag, 
                  @c_StorerKey = IQC.StorerKey, 
                  @c_Facility  = IQC.From_Facility  
         FROM InventoryQC AS IQC WITH(NOLOCK)
         WHERE IQC.QC_Key = @c_QC_Key          
      END

      IF @c_FinalizeFlag = 'Y'
      BEGIN
         SET @n_continue = 3
         SET @n_err = 551701
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': The Selected IQC Has Been Finalized. Not Allow To Finalize. (lsp_FinalizeIQC_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey = @n_ErrGroupKey output,
               @c_TableName   = @c_TableName,
               @c_SourceType  = @c_SourceType,
               @c_Refkey1     = @c_QC_Key,
               @c_Refkey2     = @c_QCLineNo,
               @c_Refkey3     = '',
               @n_err2        = @n_err,
               @c_errmsg2     = @c_errmsg,
               @b_Success     = @b_Success   OUTPUT,
               @n_err         = @n_err       ,
               @c_errmsg      = @c_errmsg     

         GOTO EXIT_SP
      END
      ELSE IF @c_IQCStatus is NULL
      BEGIN
         SET @n_continue = 3
         SET @n_err = 551702
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': QC_Key Or QC Line No Not Exists! (lsp_FinalizeIQC_Wrapper)'


         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey = @n_ErrGroupKey output,
               @c_TableName   = @c_TableName,
               @c_SourceType  = @c_SourceType,
               @c_Refkey1     = @c_QC_Key,
               @c_Refkey2     = @c_QCLineNo,
               @c_Refkey3     = '',
               @n_err2        = @n_err,
               @c_errmsg2     = @c_errmsg,
               @b_Success     = @b_Success   OUTPUT ,
               @n_err         = @n_err       ,
               @c_errmsg      = @c_errmsg       

         GOTO EXIT_SP      
      END

      SELECT @c_FinalizeIQC = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'FinalizeIQC')

      IF @c_FinalizeIQC <> '1'
      BEGIN 
         SET @n_continue =3
         SET @n_err = 551706
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Storer Not Set to enable finalize IQC. (lsp_FinalizeIQC_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey = @n_ErrGroupKey output 
            ,  @c_TableName   = @c_TableName 
            ,  @c_SourceType  = @c_SourceType 
            ,  @c_Refkey1     = @c_QC_Key 
            ,  @c_Refkey2     = '' 
            ,  @c_Refkey3     = '' 
            ,  @n_err2        = @n_err 
            ,  @c_errmsg2     = @c_errmsg 
            ,  @b_Success     = @b_Success   OUTPUT 
            ,  @n_err         = @n_err       
            ,  @c_errmsg      = @c_errmsg    

         GOTO EXIT_SP 
      END
 
      -- Pre Finalize Validation from exceed
      IF EXISTS(SELECT 1 FROM InventoryQCDetail AS IQC WITH(NOLOCK)
                  WHERE IQC.QC_Key = @c_QC_Key 
                  AND   IQC.ToQty <= 0 
                  AND   IQC.QCLineNo = CASE WHEN ISNULL(RTRIM(@c_QCLineNo),'') = '' THEN IQC.QCLineNo ELSE @c_QCLineNo END)
      BEGIN
         SET @n_continue =3
         SET @n_err = 551703
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': To Qty is required for finalize! (lsp_FinalizeIQC_Wrapper)'


         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey = @n_ErrGroupKey output,
               @c_TableName   = @c_TableName,
               @c_SourceType  = @c_SourceType,
               @c_Refkey1     = @c_QC_Key,
               @c_Refkey2     = @c_QCLineNo,
               @c_Refkey3     = '',
               @n_err2        = @n_err,
               @c_errmsg2     = @c_errmsg,
               @b_Success     = @b_Success OUTPUT,
               @n_err         = @n_err ,
               @c_errmsg      = @c_errmsg 

         GOTO EXIT_SP 
      END
      IF EXISTS(SELECT 1 FROM InventoryQCDetail AS IQC WITH(NOLOCK)
                  WHERE IQC.QC_Key = @c_QC_Key 
                  AND   (IQC.ToLOC ='' OR IQC.ToLoc IS NULL) 
                  AND   IQC.QCLineNo = CASE WHEN ISNULL(RTRIM(@c_QCLineNo),'') = '' THEN IQC.QCLineNo ELSE @c_QCLineNo END)
      BEGIN
         SET @n_continue =3
         SET @n_err = 551704
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': To Loc Cannot be BLANK! (lsp_FinalizeIQC_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey = @n_ErrGroupKey output,
               @c_TableName   = @c_TableName,
               @c_SourceType  = @c_SourceType,
               @c_Refkey1     = @c_QC_Key,
               @c_Refkey2     = @c_QCLineNo,
               @c_Refkey3     = '',
               @n_err2        = @n_err,
               @c_errmsg2     = @c_errmsg,
               @b_Success     = @b_Success OUTPUT,
               @n_err         = @n_err ,
               @c_errmsg      = @c_errmsg 

         GOTO EXIT_SP 
      END  
      
      SELECT TOP 1 
             @c_FromLot = iqd.FromLot
            ,@c_FromLoc = iqd.FromLoc
            ,@c_FromID  = iqd.FromID
            ,@n_TotalQCToQty = SUM(iqd.ToQty)
            ,@n_SystemQty    = ISNULL(ltlci.Qty - ltlci.QtyAllocated - ltlci.QtyPicked,0)
      FROM dbo.InventoryQCDetail AS iqd WITH (NOLOCK)
      LEFT OUTER JOIN dbo.LOTxLOCxID AS ltlci WITH (NOLOCK) ON  ltlci.Lot = iqd.FromLot
                                                            AND ltlci.Loc = iqd.FromLoc  
                                                            AND ltlci.ID  = iqd.FromID   
      WHERE iqd.QC_Key = @c_QC_Key
      AND iqd.[Status] < '9' 
      AND EXISTS (SELECT 1 FROM #TMP_QCD AS tq WHERE tq.QC_Key = iqd.QC_Key AND tq.FromLot = iqd.FromLot 
                  AND tq.FromLoc = iqd.FromLoc AND tq.FromID = iqd.FromID)
      GROUP BY iqd.QC_Key, iqd.FromLot, iqd.FromLoc, iqd.FromID, ISNULL(ltlci.Qty - ltlci.QtyAllocated - ltlci.QtyPicked,0)
      
      --IF EXISTS (
      --            SELECT 1
      --            FROM INVENTORYQCDETAIL IQCD WITH (NOLOCK)
      --            WHERE IQCD.QC_key = @c_QC_Key
      --            AND   ( IQCD.QCLineNo = @c_QCLineNo OR ISNULL(RTRIM(@c_QCLineNo),'') = '' )
      --            AND   IQCD.Qty > (   SELECT ISNULL(SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked),0)
      --                                 FROM LOTxLOCxID LLI WITH (NOLOCK)
      --                                 WHERE LLI.Lot = IQCD.FromLot
      --                                 AND   LLI.Loc = IQCD.FromLoc
      --                                 AND   LLI.ID  = IQCD.FromID
      --                              )
      --         )
      
      IF @n_TotalQCToQty > @n_SystemQty
      BEGIN
         SET @n_continue =3                                                             
         SET @n_Err     = 551705
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_Err)
                        + ': Inadequate system available Qty to Move found. Lot: ' + @c_FromLot
                        + ', Loc: ' + @c_FromLoc + ', ID#: ' + @c_FromID 
                        + ', Qty To Move: ' + CONVERT(NVARCHAR(10), @n_TotalQCToQty) + ', System Available Qty: ' + CONVERT(NVARCHAR(10), @n_SystemQty)                         
                        + '. (lsp_FinalizeIQC_Wrapper) |' + @c_FromLot + '|'+ @c_FromLoc + '|'+ @c_FromID  + '|'+ CONVERT(NVARCHAR(10), @n_TotalQCToQty)
                        + '|' + CONVERT(NVARCHAR(10), @n_SystemQty)  

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey = @n_ErrGroupKey output,
               @c_TableName   = @c_TableName,
               @c_SourceType  = @c_SourceType,
               @c_Refkey1     = @c_QC_Key,
               @c_Refkey2     = @c_QCLineNo,
               @c_Refkey3     = '',
               @n_err2        = @n_err,
               @c_errmsg2     = @c_errmsg,
               @b_Success     = @b_Success OUTPUT,
               @n_err         = @n_err ,
               @c_errmsg      = @c_errmsg 

         GOTO EXIT_SP 
      END                  
  
      IF @n_continue = 1
      BEGIN
         BEGIN TRY
            EXEC ispFinalizeIQC
               @c_qc_key  = @c_QC_Key,
               @b_Success = @b_Success OUTPUT,
               @n_err     = @n_err     OUTPUT,
               @c_ErrMsg  = @c_ErrMsg  OUTPUT         
         END TRY 
         BEGIN CATCH
            IF @n_err = 0 
            BEGIN
               IF @@TRANCOUNT > @n_StartTCnt
               BEGIN
                  ROLLBACK TRAN
               END 
               SET  @n_continue = 3
               SELECT @n_err = ERROR_NUMBER(), 
                      @c_ErrMsg = ERROR_MESSAGE()

               GOTO EXIT_SP
            END
         END CATCH      
      END
   END TRY                                --(Wan01) - START
   BEGIN CATCH
      SET @n_continue = 3
      SET @c_ErrMsg   = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH                              --(Wan01) - END         
   EXIT_SP:       

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      
      IF (XACT_STATE()) = -1     --(Wan01) - START  
      BEGIN  
         ROLLBACK TRAN;  
      END;                       --(Wan01) - END 
            
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_FinalizeIQC_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN 
      BEGIN TRAN
   END

   REVERT  
END -- End Procedure

GO