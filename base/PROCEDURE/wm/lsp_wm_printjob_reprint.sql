SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: lsp_WM_PrintJob_Reprint                                 */
/* Creation Date: 04-APR-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-228:View My Print Jobs                                 */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-02-10  mingle01 1.1   Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2023-05-02  Wan01    1.2   LFWM-3913 - Ship Reference Enhancement -  */
/*                            Print Interface Document                  */
/*                            DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [WM].[lsp_WM_PrintJob_Reprint]
           @n_JobID     INT
         , @b_Success   INT            OUTPUT
         , @n_Err       INT            OUTPUT
         , @c_ErrMsg    NVARCHAR(255)  OUTPUT
         , @c_UserName  NVARCHAR(128)  = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT
         , @n_Continue              INT 

         , @c_ReportID              NVARCHAR(10)      = ''
         , @c_Storerkey             NVARCHAR(15)      = ''
         , @n_NoOfParms             INT               = 0
         , @c_ReportTemplate        NVARCHAR(4000)    = ''
         , @c_Parm1                 NVARCHAR(60)      = ''
         , @c_Parm2                 NVARCHAR(60)      = ''
         , @c_Parm3                 NVARCHAR(60)      = ''
         , @c_Parm4                 NVARCHAR(60)      = ''
         , @c_Parm5                 NVARCHAR(60)      = ''
         , @c_Parm6                 NVARCHAR(60)      = ''
         , @c_Parm7                 NVARCHAR(60)      = ''
         , @c_Parm8                 NVARCHAR(60)      = ''
         , @c_Parm9                 NVARCHAR(60)      = ''
         , @c_Parm10                NVARCHAR(60)      = ''
         , @c_Parm11                NVARCHAR(60)      = ''
         , @c_Parm12                NVARCHAR(60)      = ''
         , @c_Parm13                NVARCHAR(60)      = ''
         , @c_Parm14                NVARCHAR(60)      = ''
         , @c_Parm15                NVARCHAR(60)      = ''
         , @c_Parm16                NVARCHAR(60)      = ''
         , @c_Parm17                NVARCHAR(60)      = ''
         , @c_Parm18                NVARCHAR(60)      = ''
         , @c_Parm19                NVARCHAR(60)      = ''
         , @c_Parm20                NVARCHAR(60)      = ''
         , @c_Printer               NVARCHAR(30)      = ''
         , @n_NoOfCopy              INT               = 1
         , @c_PrintData             NVARCHAR(MAX)     = ''                          --(Wan01)
         , @c_JobType               NVARCHAR(30)      = ''  
         , @b_SCEPreview            BIT               = 0                           --(Wan01)
         , @c_ReportLineNo          NVARCHAR(5)       = ''                          --(Wan01)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

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
   
   --(mingle01) - START
   BEGIN TRY

      IF EXISTS(  SELECT 1
                  FROM RDT.RDTPrintJob WITH (NOLOCK)
                  WHERE JobID = @n_JobID
                  --AND JobStatus NOT IN ('E', '9')
               )
      BEGIN
         SET @n_Err = 553001
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_ErrMsg = 'Job #:' + RTRIM(CONVERT(NVARCHAR(10), @n_JobID)) 
                       + ' has not printed yet or print in progress.'
                       + ' Job Reprint Abort.(lsp_WM_PrintJob_Reprint)'
                       + ' |' + RTRIM(CONVERT(NVARCHAR(10), @n_JobID)) 
         GOTO EXIT_SP
      END
      
      SELECT  
            @c_ReportID  = ReportID         
         ,  @c_Storerkey = Storerkey           
         ,  @n_Noofparms = Noofparms 
         ,  @c_ReportTemplate= DataWindow          
         ,  @c_Parm1     = Parm1             
         ,  @c_Parm2     = Parm2             
         ,  @c_Parm3     = Parm3             
         ,  @c_Parm4     = Parm4             
         ,  @c_Parm5     = Parm5           
         ,  @c_Parm6     = Parm6             
         ,  @c_Parm7     = Parm7            
         ,  @c_Parm8     = Parm8             
         ,  @c_Parm9     = Parm9             
         ,  @c_Parm10    = Parm10  
         ,  @c_Parm11    = Parm11             
         ,  @c_Parm12    = Parm12             
         ,  @c_Parm13    = Parm13             
         ,  @c_Parm14    = Parm14             
         ,  @c_Parm15    = Parm15           
         ,  @c_Parm16    = Parm16             
         ,  @c_Parm17    = Parm17            
         ,  @c_Parm18    = Parm18             
         ,  @c_Parm19    = Parm19             
         ,  @c_Parm20    = Parm20                    
         ,  @c_Storerkey = Storerkey           
         ,  @c_Printer   = Printer
         ,  @n_Noofcopy  = Noofcopy                  
         ,  @c_PrintData = PrintData             
         ,  @c_JobType   = JobType   
         ,  @b_SCEPreview= IIF(PDFPreview= 'Y', 1,0)                                --(Wan01)
         ,  @c_ReportLineNo = ReportLineNo                                          --(Wan01)                                    
      FROM RDT.RDTPRINTJOB_LOG WITH(NOLOCK)
      WHERE JobID = @n_JobID

      BEGIN TRY
         --EXEC  isp_PrintToRDTSpooler                      
         --      @c_ReportType     = @c_ReportID         
         --   ,  @c_Storerkey      = @c_Storerkey           
         --   ,  @n_Noofparam      = @n_Noofparms           
         --   ,  @c_Param01        = @c_Parm1             
         --   ,  @c_Param02        = @c_Parm2             
         --   ,  @c_Param03        = @c_Parm3             
         --   ,  @c_Param04        = @c_Parm4             
         --   ,  @c_Param05        = @c_Parm5           
         --   ,  @c_Param06        = @c_Parm6             
         --   ,  @c_Param07        = @c_Parm7            
         --   ,  @c_Param08        = @c_Parm8             
         --   ,  @c_Param09        = @c_Parm9             
         --   ,  @c_Param10        = @c_Parm10             
         --   ,  @n_Noofcopy       = @n_Noofcopy            
         --   ,  @c_UserName       = @c_UserName           
         --   ,  @c_Facility       = ''            
         --   ,  @c_PrinterID      = @c_Printer           
         --   ,  @c_Datawindow     = @c_ReportTemplate          
         --   ,  @c_IsPaperPrinter = 'Y'      
         --   ,  @c_JobType        = @c_JobType         
         --   ,  @c_PrintData      = @c_PrintData        
         --   ,  @b_success        = @b_success   OUTPUT    
         --   ,  @n_err            = @n_err       OUTPUT    
         --   ,  @c_errmsg         = @c_errmsg    OUTPUT 
         --   ,  @n_Function_ID    = 999    -- Print From WMS Setup
         --   ,  @b_PrintFromWM    = 1
         --   ,  @c_Param11        = @c_Parm11             
         --   ,  @c_Param12        = @c_Parm12             
         --   ,  @c_Param13        = @c_Parm13             
         --   ,  @c_Param14        = @c_Parm14             
         --   ,  @c_Param15        = @c_Parm15           
         --   ,  @c_Param16        = @c_Parm16             
         --   ,  @c_Param17        = @c_Parm17            
         --   ,  @c_Param18        = @c_Parm18             
         --   ,  @c_Param19        = @c_Parm19             
         --   ,  @c_Param20        = @c_Parm20  
         --   
         EXEC [WM].[lsp_WM_SendPrintJobToProcessApp] 
               @c_ReportID       = @c_ReportID      
            ,  @c_ReportLineNo   = @c_ReportLineNo 
            ,  @c_Storerkey      = @c_Storerkey     
            ,  @c_Facility       = ''      
            ,  @n_NoOfParms      = @n_NoOfParms     
            ,  @c_Parm1          = @c_Parm1             
            ,  @c_Parm2          = @c_Parm2             
            ,  @c_Parm3          = @c_Parm3             
            ,  @c_Parm4          = @c_Parm4             
            ,  @c_Parm5          = @c_Parm5           
            ,  @c_Parm6          = @c_Parm6             
            ,  @c_Parm7          = @c_Parm7            
            ,  @c_Parm8          = @c_Parm8             
            ,  @c_Parm9          = @c_Parm9             
            ,  @c_Parm10         = @c_Parm10  
            ,  @c_Parm11         = @c_Parm11             
            ,  @c_Parm12         = @c_Parm12             
            ,  @c_Parm13         = @c_Parm13             
            ,  @c_Parm14         = @c_Parm14             
            ,  @c_Parm15         = @c_Parm15           
            ,  @c_Parm16         = @c_Parm16             
            ,  @c_Parm17         = @c_Parm17            
            ,  @c_Parm18         = @c_Parm18             
            ,  @c_Parm19         = @c_Parm19             
            ,  @c_Parm20         = @c_Parm20           
            ,  @n_Noofcopy       = @n_Noofcopy       
            ,  @c_PrinterID      = @c_Printer       
            ,  @c_IsPaperPrinter = 'Y' 
            ,  @c_ReportTemplate = @c_ReportTemplate
            ,  @c_PrintData      = @c_PrintData    
            ,  @c_PrintType      = @c_JobType      
            ,  @c_UserName       = @c_UserName       
            ,  @b_SCEPreView     = @b_SCEPreView       
            ,  @n_JobID          = @n_JobID           OUTPUT   
            ,  @b_success        = @b_success         OUTPUT 
            ,  @n_err            = @n_err             OUTPUT 
            ,  @c_errmsg         = @c_errmsg          OUTPUT
         --(Wan01) - END   
      END TRY
      BEGIN CATCH
         SET @n_err = 553002
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing lsp_WM_SendPrintJobToProcessApp. (lsp_WM_PrintJob_Reprint)'
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
   --(mingle01) - END 

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WM_PrintJob_Reprint'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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