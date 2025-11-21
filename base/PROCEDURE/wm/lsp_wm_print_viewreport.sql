SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: lsp_WM_Print_ViewReport                                 */
/* Creation Date: 02-FEB-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-183:List of Labels, Document Print and Reports to be   */
/*          considered & DB procedute Details for the same              */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-02-25  Wan01    1.1   Add Big Outer Try/Catch                   */ 
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2021-06-03  Wan02    1.2   LFWM-2800 - RG UAT PB Report Print Preview*/
/*                            SP & sharedrive for PDF Storage           */
/* 2021-09-24  Wan02    1.2   DevOps Combine Script                     */
/* 2023-02-27  Wan03    1.3   LFWM-3913 - Ship Reference Enhancement -  */
/*                            Print Interface Document                  */
/************************************************************************/
CREATE   PROC [WM].[lsp_WM_Print_ViewReport]
           @c_ModuleID           NVARCHAR(30)  = 'ViewReport'
         , @c_ReportID           NVARCHAR(10)
         , @c_UserName           NVARCHAR(128) 
         , @c_PrinterID          NVARCHAR(30)
         , @n_NoOfCopy           INT            = 1
         , @c_IsPaperPrinter     NCHAR(1)       = 'Y'
         , @c_ParmValue1         NVARCHAR(60)
         , @c_ParmValue2         NVARCHAR(60)   = ''
         , @c_ParmValue3         NVARCHAR(60)   = ''
         , @c_ParmValue4         NVARCHAR(60)   = ''
         , @c_ParmValue5         NVARCHAR(60)   = ''
         , @c_ParmValue6         NVARCHAR(60)   = ''
         , @c_ParmValue7         NVARCHAR(60)   = ''
         , @c_ParmValue8         NVARCHAR(60)   = ''
         , @c_ParmValue9         NVARCHAR(60)   = ''
         , @c_ParmValue10        NVARCHAR(60)   = ''         
         , @c_ParmValue11        NVARCHAR(60)   = ''
         , @c_ParmValue12        NVARCHAR(60)   = ''
         , @c_ParmValue13        NVARCHAR(60)   = ''
         , @c_ParmValue14        NVARCHAR(60)   = ''
         , @c_ParmValue15        NVARCHAR(60)   = ''
         , @c_ParmValue16        NVARCHAR(60)   = ''
         , @c_ParmValue17        NVARCHAR(60)   = ''
         , @c_ParmValue18        NVARCHAR(60)   = ''
         , @c_ParmValue19        NVARCHAR(60)   = ''
         , @c_ParmValue20        NVARCHAR(60)   = ''
         , @b_Success            INT            OUTPUT
         , @n_Err                INT            OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT
         , @b_SCEPreView         INT            = 0          --(Wan02)-- 1:If call from Preview Button
         , @c_JobIDs             NVARCHAR(50)   = ''  OUTPUT --(Wan02)-- Standard with module report where by return multiple jobs ID. View Report only return 1 Jobid
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT
         , @n_Continue              INT 
         , @n_FunctionID            INT               = 999

         , @n_NoOfParms             INT               = 0
         , @c_Storerkey             NVARCHAR(15)      = ''
         , @c_Facility              NVARCHAR(5)       = ''
         , @c_ReportTemplate        NVARCHAR(4000)    = ''
         , @c_SCEPrintType          NVARCHAR(30)      = ''
         
         , @n_JobID                 INT               = 0   --(Wan02)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   SET @c_JobIDs   = ''    --(Wan02)

   SET @n_Err = 0 
   --(Wan01) - START
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
   
   BEGIN TRY
      IF @n_NoOfCopy = 0  SET @n_NoOfCopy = '1'

      SELECT @c_ReportTemplate = ISNULL(RTRIM(VR.rpt_datawindow),'')
            ,@c_SCEPrintType = ISNULL(RTRIM(VR.SCEPrintType),'')
      FROM dbo.PBSRPT_REPORTS VR  WITH (NOLOCK)
      WHERE VR.Rpt_ID = @c_ReportID

      SELECT @n_NoOfParms = COUNT(1)
      FROM dbo.PBSRPT_PARMS VP  WITH (NOLOCK)
      WHERE VP.Rpt_ID = @c_ReportID

      IF @n_NoOfParms > 20
      BEGIN
         SET @n_err = 554351
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': View Report parameters more than 20. (lsp_WM_Print_ViewReport)'
         GOTO EXIT_SP
      END 

      SELECT TOP 1 @c_Storerkey = DefaultStorer
               ,   @c_Facility  = DefaultFacility
      FROM RDT.RDTUser (NOLOCK)
      WHERE UserName = @c_UserName

      IF @c_SCEPrintType = ''
      BEGIN
         SET @c_SCEPrintType = 'TCPSPOOLER'
      END

      BEGIN TRY
         --(Wan03) - START
         --EXEC  isp_PrintToRDTSpooler                      
         --      @c_ReportType     = @c_ReportID         
         --   ,  @c_Storerkey      = @c_Storerkey           
         --   ,  @n_Noofparam      = @n_Noofparms           
         --   ,  @c_Param01        = @c_ParmValue1             
         --   ,  @c_Param02        = @c_ParmValue2             
         --   ,  @c_Param03        = @c_ParmValue3             
         --   ,  @c_Param04        = @c_ParmValue4             
         --   ,  @c_Param05        = @c_ParmValue5           
         --   ,  @c_Param06        = @c_ParmValue6             
         --   ,  @c_Param07        = @c_ParmValue7            
         --   ,  @c_Param08        = @c_ParmValue8             
         --   ,  @c_Param09        = @c_ParmValue9             
         --   ,  @c_Param10        = @c_ParmValue10             
         --   ,  @n_Noofcopy       = @n_Noofcopy            
         --   ,  @c_UserName       = @c_UserName           
         --   ,  @c_Facility       = @c_Facility            
         --   ,  @c_PrinterID      = @c_PrinterID           
         --   ,  @c_Datawindow     = @c_ReportTemplate          
         --   ,  @c_IsPaperPrinter = 'Y'      
         --   ,  @c_JobType        = @c_SCEPrintType          
         --   ,  @c_PrintData      = ''        
         --   ,  @b_success        = @b_success   OUTPUT    
         --   ,  @n_err            = @n_err       OUTPUT    
         --   ,  @c_errmsg         = @c_errmsg    OUTPUT 
         --   ,  @n_Function_ID    = 999    -- Print From WMS Setup
         --   ,  @c_Param11        = @c_ParmValue11             
         --   ,  @c_Param12        = @c_ParmValue12             
         --   ,  @c_Param13        = @c_ParmValue13             
         --   ,  @c_Param14        = @c_ParmValue14             
         --   ,  @c_Param15        = @c_ParmValue15           
         --   ,  @c_Param16        = @c_ParmValue16             
         --   ,  @c_Param17        = @c_ParmValue17            
         --   ,  @c_Param18        = @c_ParmValue18             
         --   ,  @c_Param19        = @c_ParmValue19             
         --   ,  @c_Param20        = @c_ParmValue20          --(Wan02)
         --   ,  @c_ReportLineNo   = ''
         --   ,  @b_SCEPreView     = @b_SCEPreView           --(Wan02)
         --   ,  @n_JobID          = @n_JobID       OUTPUT   --(Wan02) 
         
         EXEC [WM].[lsp_WM_SendPrintJobToProcessApp] 
               @c_ReportID       = @c_ReportID      
            ,  @c_ReportLineNo   = ''  
            ,  @c_Storerkey      = @c_Storerkey     
            ,  @c_Facility       = @c_Facility      
            ,  @n_NoOfParms      = @n_NoOfParms     
            ,  @c_Parm1          = @c_ParmValue1             
            ,  @c_Parm2          = @c_ParmValue2             
            ,  @c_Parm3          = @c_ParmValue3             
            ,  @c_Parm4          = @c_ParmValue4             
            ,  @c_Parm5          = @c_ParmValue5           
            ,  @c_Parm6          = @c_ParmValue6             
            ,  @c_Parm7          = @c_ParmValue7            
            ,  @c_Parm8          = @c_ParmValue8             
            ,  @c_Parm9          = @c_ParmValue9             
            ,  @c_Parm10         = @c_ParmValue10  
            ,  @c_Parm11         = @c_ParmValue11             
            ,  @c_Parm12         = @c_ParmValue12             
            ,  @c_Parm13         = @c_ParmValue13             
            ,  @c_Parm14         = @c_ParmValue14             
            ,  @c_Parm15         = @c_ParmValue15           
            ,  @c_Parm16         = @c_ParmValue16             
            ,  @c_Parm17         = @c_ParmValue17            
            ,  @c_Parm18         = @c_ParmValue18             
            ,  @c_Parm19         = @c_ParmValue19             
            ,  @c_Parm20         = @c_ParmValue20           
            ,  @n_Noofcopy       = @n_Noofcopy       
            ,  @c_PrinterID      = @c_PrinterID      
            ,  @c_IsPaperPrinter = @c_IsPaperPrinter 
            ,  @c_ReportTemplate = @c_ReportTemplate
            ,  @c_PrintData      = ''      
            ,  @c_PrintType      = @c_SCEPrintType      
            ,  @c_UserName       = @c_UserName       
            ,  @b_SCEPreView     = @b_SCEPreView       
            ,  @n_JobID          = @n_JobID           OUTPUT   
            ,  @b_success        = @b_success         OUTPUT 
            ,  @n_err            = @n_err             OUTPUT 
            ,  @c_errmsg         = @c_errmsg          OUTPUT
         --(Wan03) - END  
         SET @c_JobIDs = CONVERT(NVARCHAR, @n_JobID)
      END TRY
      BEGIN CATCH
         SET @n_err = 554352
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing lsp_WM_SendPrintJobToProcessApp. (lsp_WM_Print_ViewReport)'
                        + '( ' + @c_errmsg + ' )'
      END CATCH
      
      IF @b_Success = 0 OR @n_Err <> 0
      BEGIN
         SET @n_Continue=3 
         SET @c_errmsg = @c_errmsg
         GOTO EXIT_SP 
      END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(Wan01)  - END
EXIT_SP:
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WM_Print_ViewReport'
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
END -- procedure

GO