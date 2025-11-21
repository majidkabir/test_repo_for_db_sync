SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: WM.lsp_FlowThruAllocate_Wrapper                     */  
/* Creation Date: 09-OCT-2018                                            */  
/* Copyright: Maersk                                                     */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-1281 - Stored Procedures for Kitting functionalities    */
/*        :                                                              */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.2                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 12/29/2020  SWT01    1.1   Remove Duplicate Execute Login             */
/* 15-Jan-2021 Wan01    1.2   Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 26-Feb-2024 Wan02    1.3   UWP-14044 ASN support XDOCK allocation by  */
/*                            multiple externpokey per ASN               */
/*************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_FlowThruAllocate_Wrapper]
      @c_ReceiptKey           NVARCHAR(10)
    , @b_Success              INT=1 OUTPUT
    , @n_Err                  INT=0 OUTPUT
    , @c_ErrMsg               NVARCHAR(250)=''  OUTPUT
    , @c_UserName             NVARCHAR(128)=''
    , @n_ErrGroupKey          INT = 0           OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT

   DECLARE @c_TableName       NVARCHAR(50)= 'ReceiptDetail'
         , @c_SourceType      NVARCHAR(50)= 'lsp_FlowThruAllocate_Wrapper'

   DECLARE @n_Count           INT         = 0
         , @n_NoOfExternPOKey INT         = 0
         , @c_POKey           NVARCHAR(10)= ''
         , @c_POType          NVARCHAR(10)= ''
         , @c_ExternPOKey     NVARCHAR(30)= ''
         , @c_ExternStatus    NVARCHAR(30)= ''
         , @c_Facility        NVARCHAR(5) = ''
         , @c_Storerkey       NVARCHAR(15)= ''

         , @n_XDAlloc         BIT         = 0
         , @c_XDStrategyKey   NVARCHAR(10)= ''
         , @c_XDStrategyType  NVARCHAR(10)= ''

         , @c_XDFNZAutoAllocPickSO  NVARCHAR(30) = ''
         , @c_AutoXDAllocPrnGRN     NVARCHAR(30) = ''

         , @c_ModuleID              NVARCHAR(10) = ''
         , @c_ReportID              NVARCHAR(10) = ''

         , @CUR_ALC                 CURSOR                                          --(Wan02)
         , @CUR_PRN                 CURSOR                                          --(Wan02)

   DECLARE @t_rd                    TABLE                                           --(Wan02)
         ( RowID                    INT            NOT NULL IDENTITY(1,1)
         , ExternPOKey              NVARCHAR(30)   NOT NULL DEFAULT('')
         , POKey                    NVARCHAR(10)   NOT NULL DEFAULT('')
         , POType                   NVARCHAR(10)   NOT NULL DEFAULT('')
         , ExternStatus             NVARCHAR(10)   NOT NULL DEFAULT('')
         )                                                                          
     
   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName       --(Wan01) - START
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
   END                                   --(Wan01) - END
   
   BEGIN TRY                             --(Wan01) - START
      SET @n_Continue   = 1
      SET @c_TableName  = 'ReceiptDetail'
      SET @c_SourceType = 'lsp_FlowThruAllocate_Wrapper'

      SET @n_Count = 0
      SET @c_POKey = ''
      SET @c_ExternPOKey = ''

      INSERT INTO @t_RD ( ExternPOKey, POKey, POType, ExternStatus )                --(Wan02)
      SELECT RD.ExternPOKey, rd.pokey, p.potype, p.ExternStatus 
      FROM RECEIPTDETAIL RD WITH (NOLOCK) 
      JOIN PO p WITH (NOLOCK) ON rd.pokey = p.pokey
      WHERE RD.ReceiptKey = @c_ReceiptKey 

      SELECT @n_Count = COUNT(1)
            ,@n_NoOfExternPOKey = COUNT(DISTINCT RD.ExternPOKey)
            ,@c_POKey       = ISNULL(MIN(RD.POKey),'')
            ,@c_ExternPOKey = CASE WHEN COUNT(DISTINCT RD.ExternPOKey) > 1 THEN '' ELSE ISNULL(MIN(RD.ExternPOKey),'') END
      FROM @t_RD RD --WITH (NOLOCK)                                                --(Wan02)
      --WHERE RD.ReceiptKey = @c_ReceiptKey                                        --(Wan02)

      IF @n_Count = 0
      BEGIN
         SET @n_continue = 3   
         SET @n_err = 555051
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                       + ': There is No record in the Detail. (lsp_FlowThruAllocate_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_ReceiptKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = ''
            ,  @n_err2        = @n_err
            ,  @c_errmsg2     = @c_errmsg
            ,  @b_Success     = @b_Success   OUTPUT
            ,  @n_err         = @n_err       OUTPUT
            ,  @c_errmsg      = @c_errmsg                                           --(Wan02)
      END   

      SET @c_Facility   = ''
      SET @c_Storerkey  = ''

      SELECT @c_Facility = R.Facility
            ,@c_Storerkey= R.Storerkey
      FROM RECEIPT R WITH (NOLOCK)
      WHERE R.ReceiptKey = @c_ReceiptKey 

      ---------------------------------------------------------------------------------------------
      -- Check XDFinalizeAutoAllocatePickSO, exec isp_XDOCKFinalizeAutoAllocate if not error START)
      ---------------------------------------------------------------------------------------------
      BEGIN TRY
         SET @c_XDFNZAutoAllocPickSO = ''
         EXEC nspGetRight
            @c_Facility = @c_Facility
         ,  @c_Storerkey= @c_Storerkey
         ,  @c_Sku      = ''
         ,  @c_Configkey= 'XDFinalizeAutoAllocatePickSO'
         ,  @b_Success  = @b_Success               OUTPUT
         ,  @c_Authority= @c_XDFNZAutoAllocPickSO  OUTPUT
         ,  @n_Err      = @n_Err                   OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg                OUTPUT  

      END TRY

      BEGIN CATCH
         SET @n_continue = 3
         SET @n_err = 555052
         SET @c_ErrMsg  = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                        + ': Error Executing nspGetRight - XDFinalizeAutoAllocatePickSO. (lsp_FlowThruAllocate_Wrapper)'
                        + ' (' + @c_ErrMsg + ')'
      END CATCH

      IF @b_success = 0 OR @n_Err <> 0        
      BEGIN        
         SET @n_Continue = 3      
         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_ReceiptKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = ''
            ,  @n_err2        = @n_err
            ,  @c_errmsg2     = @c_errmsg
            ,  @b_Success     = @b_Success   OUTPUT
            ,  @n_err         = @n_err       OUTPUT
            ,  @c_errmsg      = @c_errmsg                                           --(Wan02)
      END 

      IF @c_XDFNZAutoAllocPickSO = '1'
      BEGIN
         ---------------------------------------------------------------
         -- EXIT SP IF ERROR BEORE Execute isp_XDOCKFinalizeAutoAllocate
         ---------------------------------------------------------------
         IF @n_Continue = 3
         BEGIN
            GOTO EXIT_SP
         END

         BEGIN TRY 
            EXEC isp_XDOCKFinalizeAutoAllocate
                    @c_ReceiptKey  = @c_ReceiptKey
                  , @b_Success     = @b_Success   OUTPUT
                  , @n_Err         = @n_Err       OUTPUT
                  , @c_ErrMsg      = @c_ErrMsg    OUTPUT

         END TRY

         BEGIN CATCH
            IF (XACT_STATE()) = -1  
            BEGIN
               ROLLBACK TRAN
            END

            WHILE @@TRANCOUNT < @n_StartTCNT
            BEGIN
               BEGIN TRAN
            END

            SET @n_err = 555053
            SET @c_ErrMsg   = ERROR_MESSAGE()    
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                           + ': Error Executing isp_XDOCKFinalizeAutoAllocate. (lsp_FlowThruAllocate_Wrapper)'
                           + ' (' + @c_ErrMsg + ')'
         END CATCH

         IF @b_success = 0 OR @n_Err <> 0        
         BEGIN        
            SET @n_Continue = 3  
            GOTO EXIT_SP
         END 

         GOTO EXIT_SP
      END
      ---------------------------------------------------------------------------------------------
      -- Check XDFinalizeAutoAllocatePickSO, exec isp_XDOCKFinalizeAutoAllocate if not error END)
      ---------------------------------------------------------------------------------------------

      --IF @n_NoOfExternPOKey > 0                                                   --(Wan02)-START
      --BEGIN
      --   SET @n_continue = 3   
      --   SET @n_err = 555054
      --   SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
      --                  + ': More than 1 PO found. (lsp_FlowThruAllocate_Wrapper)'

      --   EXEC [WM].[lsp_WriteError_List] 
      --         @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
      --      ,  @c_TableName   = @c_TableName
      --      ,  @c_SourceType  = @c_SourceType
      --      ,  @c_Refkey1     = @c_ReceiptKey
      --      ,  @c_Refkey2     = ''
      --      ,  @c_Refkey3     = ''
      --      ,  @n_err2        = @n_err
      --      ,  @c_errmsg2     = @c_errmsg
      --      ,  @b_Success     = @b_Success   OUTPUT
      --      ,  @n_err         = @n_err       OUTPUT
      --      ,  @c_errmsg      = @c_errmsg    OUTPUT 
      --END                                                                         

      SET @c_ExternStatus = ''
      SET @c_POType = ''
      SELECT TOP 1 
             @c_ExternStatus = rd.ExternStatus
            --,@c_POType = PO.[POType] 
      FROM @t_RD RD   
      --WHERE POKey = @c_POKey 
      WHERE rd.ExternStatus = '9'                                                   --(Wan02)-END
   
      IF @c_ExternStatus ='9'
      BEGIN
         SET @n_XDAlloc = 1
      END 
   
      IF @n_XDAlloc = 0
      BEGIN
         SET @c_XDStrategyKey = ''
         SELECT @c_XDStrategyKey = S.XDockStrategyKey
         FROM STORER S WITH (NOLOCK)
         WHERE S.Storerkey = @c_Storerkey

         SET @c_XDStrategyType = ''
         SELECT @c_XDStrategyType = ISNULL(RTRIM(XS.[Type]),'')
         FROM XDOCKSTRATEGY XS WITH (NOLOCK)
         WHERE XS.XDockStrategyKey = @c_XDStrategyKey      

         IF @c_XDStrategyType = '02'
         BEGIN      
            SET @n_XDAlloc = 1
         END
      END

      IF @n_XDAlloc = 0
      BEGIN
         SET @n_continue = 3   
         SET @n_err = 555055
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                        + 'Only Closed PO can be proceed for Allocation. (lsp_FlowThruAllocate_Wrapper)'

         EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
            ,  @c_TableName   = @c_TableName
            ,  @c_SourceType  = @c_SourceType
            ,  @c_Refkey1     = @c_ReceiptKey
            ,  @c_Refkey2     = ''
            ,  @c_Refkey3     = ''
            ,  @n_err2        = @n_err
            ,  @c_errmsg2     = @c_errmsg
            ,  @b_Success     = @b_Success   OUTPUT
            ,  @n_err         = @n_err       OUTPUT
            ,  @c_errmsg      = @c_errmsg                                           --(Wan02)
      END

      ---------------------------------------------------------------
      -- EXIT SP IF ERROR BEORE Execute isp_XDOCKFinalizeAutoAllocate
      ---------------------------------------------------------------
      IF @n_continue = 3 
      BEGIN
         GOTO EXIT_SP
      END

      SET @CUR_ALC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                        --(Wan02) - START
      SELECT rd.[ExternPOkey] 
      FROM @t_RD rd 
      WHERE rd.ExternStatus NOT IN ('CANC') 
      GROUP BY rd.[ExternPOkey] 
      ORDER BY MIN(rd.RowID)

      OPEN @CUR_ALC

      FETCH NEXT FROM @CUR_ALC INTO @c_externpokey

      WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
      BEGIN
         BEGIN TRY
            EXEC nsp_xdockorderprocessing 
                     @c_externpokey = @c_externpokey
                  ,  @c_storerkey   = @c_storerkey
                  ,  @c_docarton    = 'Y' 
                  ,  @c_doroute     = 'N' 
                  ,  @c_facility    = @c_Facility

         END TRY

         BEGIN CATCH
            IF (XACT_STATE()) = -1  
            BEGIN
               ROLLBACK TRAN
            END

            WHILE @@TRANCOUNT < @n_StartTCNT
            BEGIN
               BEGIN TRAN
            END

            SET @n_continue = 3                                            
            SET @n_err = 555056
            SET @c_ErrMsg = ERROR_MESSAGE()                                         --(Wan02)
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                          + ': ' + @c_ErrMsg + '. (lsp_FlowThruAllocate_Wrapper)'   --(Wan02)

            EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
               ,  @c_TableName   = @c_TableName
               ,  @c_SourceType  = @c_SourceType
               ,  @c_Refkey1     = @c_ReceiptKey
               ,  @c_Refkey2     = ''
               ,  @c_Refkey3     = ''
               ,  @n_err2        = @n_err
               ,  @c_errmsg2     = @c_errmsg
               ,  @b_Success     = @b_Success   OUTPUT
               ,  @n_err         = @n_err       OUTPUT
               ,  @c_errmsg      = @c_errmsg                                        --(Wan02)

            GOTO EXIT_SP
         END CATCH
         FETCH NEXT FROM @CUR_ALC INTO @c_externpokey
      END
      CLOSE @CUR_ALC
      DEALLOCATE @CUR_ALC

      SET @CUR_PRN = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT rd.potype 
      FROM @t_RD rd 
      WHERE rd.ExternStatus NOT IN ('CANC') 
      GROUP BY rd.potype
      ORDER BY MIN(rd.RowID)

      OPEN @CUR_PRN

      FETCH NEXT FROM @CUR_PRN INTO @c_POType

      WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
      BEGIN
         IF @c_POType IN ('5', '6', '8', '8A')
         BEGIN
            BEGIN TRY
               SET @c_AutoXDAllocPrnGRN = ''
               EXEC nspGetRight
                  @c_Facility = @c_Facility
               ,  @c_Storerkey= @c_Storerkey
               ,  @c_Sku      = ''
               ,  @c_Configkey= 'PRINT_GRN_WHEN_ALLOCATE'
               ,  @b_Success  = @b_Success            OUTPUT
               ,  @c_Authority= @c_AutoXDAllocPrnGRN  OUTPUT
               ,  @n_Err      = @n_Err                OUTPUT
               ,  @c_ErrMsg   = @c_ErrMsg             OUTPUT  
            END TRY

            BEGIN CATCH
               SET @n_err = 555057
               SET @c_ErrMsg = ERROR_MESSAGE()    
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                             + ': Error Executing nspGetRight - PRINT_GRN_WHEN_ALLOCATE. (lsp_FlowThruAllocate_Wrapper)'
                             + ' (' + @c_ErrMsg + ')'
            END CATCH

            IF @b_success = 0 OR @n_Err <> 0        
            BEGIN        
               SET @n_Continue = 3 
                                
               EXEC [WM].[lsp_WriteError_List] 
                     @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                  ,  @c_TableName   = @c_TableName
                  ,  @c_SourceType  = @c_SourceType
                  ,  @c_Refkey1     = @c_ReceiptKey
                  ,  @c_Refkey2     = ''
                  ,  @c_Refkey3     = ''
                  ,  @n_err2        = @n_err
                  ,  @c_errmsg2     = @c_errmsg
                  ,  @b_Success     = @b_Success   OUTPUT
                  ,  @n_err         = @n_err       OUTPUT
                  ,  @c_errmsg      = @c_errmsg                
               GOTO EXIT_SP
            END 

            IF @c_AutoXDAllocPrnGRN = '1'
            BEGIN
               SET  @c_ModuleID = 'ReceiptX'
               IF @c_POType IN ('5', '6')
               BEGIN
                  EXEC [WM].[lsp_WM_Get_ReportID]                       
                        @c_ModuleID   = @c_ModuleID
                     ,  @c_Storerkey  = @c_Storerkey
                     ,  @c_Facility   = @c_Facility
                     ,  @c_ReportType = 'GRNXDOCK'
                     ,  @c_ReportID   = @c_ReportID OUTPUT               
               END

               IF @c_POType IN ('8', '8A')
               BEGIN
                  EXEC [WM].[lsp_WM_Get_ReportID]                       
                        @c_ModuleID   = @c_ModuleID
                     ,  @c_Storerkey  = @c_Storerkey
                     ,  @c_Facility   = @c_Facility
                     ,  @c_ReportType = 'GRNFLTHRU'
                     ,  @c_ReportID   = @c_ReportID OUTPUT              
               END

               IF @c_ReportID <> ''
               BEGIN
                  EXEC [WM].[lsp_WM_Print_Report]
                    @c_ModuleID           = @c_ModuleID
                  , @c_ReportID           = @c_ReportID
                  , @c_Storerkey          = @c_Storerkey
                  , @c_Facility           = @c_Facility
                  , @c_UserName           = ''
                  , @c_ComputerName       = ''
                  , @c_PrinterID          = ''
                  , @n_NoOfCopy           = 1
                  , @c_IsPaperPrinter     = 'Y'
                  , @c_KeyValue1          = @c_ReceiptKey
                  , @c_KeyValue2          = ''
                  , @c_KeyValue3          = ''
                  , @c_KeyValue4          = ''
                  , @c_KeyValue5          = ''
                  , @c_KeyValue6          = ''
                  , @c_KeyValue7          = ''
                  , @c_KeyValue8          = ''
                  , @c_KeyValue9          = ''
                  , @c_KeyValue10         = ''       
                  , @c_KeyValue11         = ''
                  , @c_KeyValue12         = ''
                  , @c_KeyValue13         = ''
                  , @c_KeyValue14         = ''
                  , @c_KeyValue15         = ''
                  , @c_ExtendedParmValue1 = ''
                  , @c_ExtendedParmValue2 = ''
                  , @c_ExtendedParmValue3 = ''
                  , @c_ExtendedParmValue4 = ''
                  , @c_ExtendedParmValue5 = ''
                  , @b_Success            = @b_Success   OUTPUT
                  , @n_Err                = @n_Err       OUTPUT
                  , @c_ErrMsg             = @c_ErrMsg    OUTPUT

                  IF @b_Success = 0 OR @n_Err <> 0
                  BEGIN
                     SET @n_Continue = 3

                     SET @n_err = 555058
                     SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                                    + 'Error Executing lsp_WM_Print_Report. (lsp_FlowThruAllocate_Wrapper)'

                     EXEC [WM].[lsp_WriteError_List] 
                        @i_iErrGroupKey= @n_ErrGroupKey OUTPUT
                     ,  @c_TableName   = @c_TableName
                     ,  @c_SourceType  = @c_SourceType
                     ,  @c_Refkey1     = @c_ReceiptKey
                     ,  @c_Refkey2     = ''
                     ,  @c_Refkey3     = ''
                     ,  @n_err2        = @n_err
                     ,  @c_errmsg2     = @c_errmsg
                     ,  @b_Success     = @b_Success   OUTPUT
                     ,  @n_err         = @n_err       OUTPUT
                     ,  @c_errmsg      = @c_errmsg     
                  END
               END
            END
         END
         FETCH NEXT FROM @CUR_PRN INTO @c_POType
      END 
      CLOSE @CUR_PRN
      DEALLOCAte @CUR_PRN                                                           --(Wan02) - END
   END TRY
   BEGIN CATCH
    SET @n_Continue = 3 
    SET @c_ErrMsg   = ERROR_MESSAGE()
    GOTO EXIT_SP
   END CATCH                              --(Wan01) - END
            
   EXIT_SP:  
   IF (XACT_STATE()) = -1                                                           --(Wan02) 
   BEGIN
      ROLLBACK TRAN
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_FlowThruAllocate_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   REVERT  
END -- End Procedure

GO