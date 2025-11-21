SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_Pack_Unpickpack_Wrapper                         */  
/* Creation Date: 2021-12-24                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-3259 - UAT RG  Unpack function and pack management      */
/*        : changes                                                      */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2021-12-24  Wan      1.0   Created.                                   */
/* 2021-12-24  Wan      1.0   DevOps Script Combine                      */
/* 2022-01-28  Wan      1.0   #LFWM3259-Defect-Pack Header should not be */
/*                            deleted                                    */ 
/*************************************************************************/   
CREATE PROCEDURE [WM].[lsp_Pack_Unpickpack_Wrapper]  
      @c_PickSlipNo           NVARCHAR(10)  
   ,  @c_LabelNo              NVARCHAR(20)   
   ,  @b_Success              INT            = 1   OUTPUT   
   ,  @n_Err                  INT            = 0   OUTPUT
   ,  @c_Errmsg               NVARCHAR(255)  = ''  OUTPUT
   ,  @c_UserName             NVARCHAR(128)  = ''
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue                    INT = 1
         , @n_StartTCnt                   INT = @@TRANCOUNT 
         
         , @n_Cnt                         INT = 0
         , @c_Facility                    NVARCHAR(5) = ''
         , @c_Storerkey                   NVARCHAR(15)= ''
         
         , @c_Orderkey                    NVARCHAR(10)= ''
         , @c_Loadkey                     NVARCHAR(10)= ''
         , @c_ReportID                    NVARCHAR(10)= ''
         
         , @c_SQL                         NVARCHAR(1000) = ''
         , @c_SQLParms                    NVARCHAR(1000) = ''
         
         , @c_AssignPackLabelToOrdCfg     NVARCHAR(30) = ''
         , @c_PickLabelColumn             NVARCHAR(60) = ''
         , @c_PickDet_InsertLog           NVARCHAR(30) = ''
         
         , @c_Pickdetailkey               NVARCHAR(10) = ''             --#LFWM3259

         , @CUR_UNALLOC                   CURSOR
         
   DECLARE @t_Pickdetail   TABLE ( PickDetailKey   NVARCHAR(10) NOT NULL DEFAULT('') PRIMARY KEY )   
                                  
   DECLARE @RPTURL         TABLE  
         (  RowNo          INT            NOT NULL DEFAULT(0)  PRIMARY KEY  
         ,  ReportID       NVARCHAR(10)   NOT NULL DEFAULT ('')  
         ,  DetailRowID    BIGINT         NOT NULL DEFAULT(0)  
         ,  REPORT_URL     NVARCHAR(4000) NOT NULL DEFAULT ('')  
         )   
                 
   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_Err = 0 

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
   
   SELECT @c_Orderkey = ph.Orderkey
         ,@c_Loadkey = ph.Loadkey
   FROM dbo.PackHeader AS ph WITH (NOLOCK)
   WHERE ph.PickSlipNo = @c_PickSlipNo
   
   IF @c_Orderkey = ''
   BEGIN
      SELECT TOP 1 @c_Facility = o.Facility
            , @c_Storerkey = o.StorerKey
      FROM dbo.LoadPlanDetail AS lpd WITH (NOLOCK)
      JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = lpd.OrderKey
      WHERE lpd.LoadKey = @c_Loadkey
      ORDER BY lpd.LoadLineNumber
   END
   ELSE
   BEGIN
      SELECT TOP 1 @c_Facility = o.Facility
            , @c_Storerkey = o.StorerKey
      FROM dbo.ORDERS AS o WITH (NOLOCK)
      WHERE o.OrderKey = @c_OrderKey
   END
      
   SELECT @c_AssignPackLabelToOrdCfg = fgr.Authority
         ,@c_PickLabelColumn = fgr.Option2
   FROM dbo.fnc_GetRight2( @c_Facility, @c_Storerkey, '', 'AssignPackLabelToOrdCfg') AS fgr
   
   IF @c_AssignPackLabelToOrdCfg IN ('0', '') 
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 560251
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) + ': Unpickpack Abort. StorerConfig ''AssignPackLabelToOrdCfg'' not turn on'
                    + '. LabelNo not update pickdetail. (lsp_Pack_Unpickpack_Wrapper)'
      GOTO EXIT_SP
   END 
   
   SELECT @c_PickDet_InsertLog = dbo.fnc_GetRight( @c_Facility, @c_Storerkey, '', 'PickDet_InsertLog') 
   
   IF @c_PickDet_InsertLog = '0'
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 560252
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) + ': Unpickpack Abort. StorerConfig ''PickDet_InsertLog'' not turn on to keep original unpick location'
                    + '. LabelNo not update pickdetail. (lsp_Pack_Unpickpack_Wrapper)'
      GOTO EXIT_SP
   END 
   
   SELECT TOP 1 @c_ReportID = w.ReportID
   FROM WMREPORT AS w WITH (NOLOCK) 
   JOIN dbo.WMREPORTDETAIL AS w2 WITH (NOLOCK) ON w.ReportID = w2.ReportID
   WHERE w.ModuleID = 'PACK'
   AND w.ReportType = 'UnPickLoc'
   AND w2.PrintType = 'LOGIREPORT'
   AND w2.Storerkey = @c_Storerkey
   ORDER BY w2.RowID
      
   IF @c_ReportID = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 560253
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) + ': No Logi Report setup to print UnPickLoc Report. (lsp_Pack_Unpickpack_Wrapper)'
      GOTO EXIT_SP      
   END
            
   SET @c_SQL = N'SELECT p.PickdetailKey FROM dbo.PICKDETAIL AS p WITH (NOLOCK) WHERE p.Storerkey = @c_Storerkey'
               + CASE WHEN @c_PickLabelColumn = 'CASEID' THEN ' AND p.CaseID = @c_LabelNo' ELSE ' AND p.DropID = @c_LabelNo' END
                 
   SET @c_SQLParms = N'@c_Storerkey NVARCHAR(15)'
                   + ',@c_LabelNo   NVARCHAR(20)'
                   
   INSERT INTO @t_Pickdetail ( PickDetailKey )
   EXEC sp_ExecuteSQL @c_SQL
                     ,@c_SQLParms
                     ,@c_Storerkey
                     ,@c_LabelNo                
   
   SELECT TOP 1 @n_Cnt = 1 FROM @t_Pickdetail    
              
   IF @n_Cnt = 0
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 560254
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) + ': Unpickpack Abort. LabelNo Not found in PickDetail. (lsp_Pack_Unpickpack_Wrapper)'
      GOTO EXIT_SP
   END 
   
   BEGIN TRAN

   BEGIN TRY
      EXEC  WM.lsp_Pack_Unpack_Wrapper  
            @c_PickSlipNo  = @c_PickSlipNo  
         ,  @c_LabelNo     = @c_LabelNo 
         ,  @b_Success     = @b_Success   OUTPUT   
         ,  @n_err         = @n_err       OUTPUT   
         ,  @c_errmsg      = @c_errmsg    OUTPUT 
         ,  @c_UserName    = @c_UserName
      
      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3        
         GOTO EXIT_SP
      END

      --#LFWM3259 - START
      IF NOT EXISTS ( SELECT 1 FROM dbo.PackDetail AS pd WITH (NOLOCK) WHERE pd.PickSlipNo = @c_PickSlipNo )
      BEGIN
         DELETE FROM dbo.PackHeader WITH (ROWLOCK) WHERE PickSlipNo = @c_PickSlipNo
         
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @c_Errmsg = ERROR_MESSAGE()        
            SET @n_err = 560257
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) + ': Delete Packheader fail. (lsp_Pack_Unpickpack_Wrapper)'
                          + ' (' + @c_Errmsg + ')'
            GOTO EXIT_SP
         END
      END
      
      SET @CUR_UNALLOC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT tp.Pickdetailkey FROM @t_Pickdetail tp
      ORDER BY tp.Pickdetailkey

      OPEN @CUR_UNALLOC

      FETCH NEXT FROM @CUR_UNALLOC INTO @c_Pickdetailkey 

      WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN ( 1,2 )
      BEGIN
         EXEC WM.lsp_Unallocation_Wrapper
               @c_Storerkey      = @c_Storerkey      
            ,  @c_Pickdetailkey  = @c_Pickdetailkey 
            ,  @c_Orderkey       = ''      
            ,  @c_OrderLineNumber= '' 
            ,  @c_Loadkey        = ''       
            ,  @c_Wavekey        = ''       
            ,  @c_Sku            = ''       
            ,  @b_Success        = @b_Success   OUTPUT 
            ,  @n_Err            = @n_Err       OUTPUT
            ,  @c_ErrMsg         = @c_ErrMsg    OUTPUT
            ,  @c_UserName       = @c_UserName
            ,  @c_UnAllocateFrom = ''

         IF @b_Success = 0
         BEGIN
            SET @n_Continue = 3
            GOTO EXIT_SP 
         END

         FETCH NEXT FROM @CUR_UNALLOC INTO @c_Pickdetailkey
      END
      CLOSE @CUR_UNALLOC
      DEALLOCATE @CUR_UNALLOC

      --DELETE FROM p WITH (ROWLOCK)
      --FROM @t_Pickdetail tp
      --JOIN PICKDETAIL AS p ON tp.PickDetailKey = p.PickDetailKey
        
      --IF @@ERROR <> 0
      --BEGIN
      --   SET @n_Continue = 3
      --   SET @c_ErrMsg = ERROR_MESSAGE()
      --   SET @n_err = 560255
      --   SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) + ': Delete Pickdetail fail. (lsp_Pack_Unpickpack_Wrapper)'
      --                 + '( ' + @c_ErrMsg + ' )'
      --   GOTO EXIT_SP
      --END 
      --#LFWM3259 - END
      
      INSERT INTO @RPTURL
          (   RowNo
          ,   ReportID
          ,   DetailRowID
          ,   REPORT_URL
          )
      EXEC [WM].[lsp_WM_Print_Report]  
           @c_ModuleID           = 'PACK' 
         , @c_ReportID           = @c_ReportID
         , @c_Storerkey          = @c_Storerkey  
         , @c_Facility           = @c_Facility
         , @c_UserName           = @c_UserName
         , @c_ComputerName       = ''   
         , @c_PrinterID          = ''  
         , @n_NoOfCopy           = 1  
         , @c_IsPaperPrinter     = 'Y'  
         , @c_KeyValue1          = @c_Storerkey 
         , @c_KeyValue2          = @c_LabelNo
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
         , @c_PrintSource        = 'JReport' 
         , @b_SCEPreView         = 0         
         , @c_JobIDs             = '' 

      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         GOTO EXIT_SP
      END

      IF EXISTS (SELECT 1 FROM @RPTURL)  
      BEGIN  
         SELECT RowNo, ReportID, DetailRowID, Report_URL FROM @RPTURL  
      END  
      ELSE
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 560256
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) + ': Unpickpack Completed Without Report URL Return. Please check LOGI Report Setup. (lsp_Pack_Unpickpack_Wrapper)'
         GOTO EXIT_SP         
      END
            
      IF @c_ErrMsg = ''
      BEGIN
         SET @c_Errmsg = 'Unpickpack Completed.'
      END
      
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE() + '. (lsp_Pack_Unpickpack_Wrapper)'
      GOTO EXIT_SP
   END CATCH

   EXIT_SP:
      
   IF (XACT_STATE()) = -1  
   BEGIN
      SET @n_Continue = 3 
      ROLLBACK TRAN
   END  
   
   IF @n_Continue = 3   
   BEGIN
      SET @b_Success = 0
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_Pack_Unpickpack_Wrapper'
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
END  

GO