SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_PrintToRDTSpooler_Wrapper                               */
/* Creation Date: 19-SEP-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#361901 ECOM-PrintToRDTSpooler                           */
/*        : WMS Print Report to RDTSpooler to increase printing         */
/*        : performance                                                 */
/* Called By:  nep_n_cst_print_util.of_printtordtspooler                */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver  Purposes                                 */
/* 21-11-2018   CSCHONG   1.0  WMS-6807 D1MPackingList                  */
/* 19-09-2019   WLChooi   1.1  Filter by Facility (WL01)                */
/************************************************************************/
CREATE PROC [dbo].[isp_PrintToRDTSpooler_Wrapper] 
            @c_Storerkey      NVARCHAR(15)                                          
         ,  @c_ReportType     NVARCHAR(10)                                           
         ,  @c_Datawindow     NVARCHAR(40) = ''                                           
         ,  @n_Noofparam      INT          = 0                                           
         ,  @c_Param01        NVARCHAR(20) = ''                                          
         ,  @c_Param02        NVARCHAR(20) = ''                                         
         ,  @c_Param03        NVARCHAR(20) = ''                                         
         ,  @c_Param04        NVARCHAR(20) = ''                                         
         ,  @c_Param05        NVARCHAR(20) = ''                                         
         ,  @c_Param06        NVARCHAR(20) = ''                                         
         ,  @c_Param07        NVARCHAR(20) = ''                                          
         ,  @c_Param08        NVARCHAR(20) = ''                                         
         ,  @c_Param09        NVARCHAR(20) = ''                                         
         ,  @c_Param10        NVARCHAR(20) = ''                                         
         ,  @c_UserID         NVARCHAR(18) = ''                                           
         ,  @c_Facility       NVARCHAR(5)  = ''
         ,  @c_IsPaperPrinter NVARCHAR(5)  = 'N'                                                       
         ,  @c_PrinterID      NVARCHAR(10) = '' 
         ,  @n_Noofcopy       INT          = 1                 
         ,  @c_PrintData      NVARCHAR(MAX)= ''                                        
         ,  @c_JobType        NVARCHAR(10) = 'DATAWINDOW'                                       
         ,  @b_Success        INT          = 0  OUTPUT                                           
         ,  @n_err            INT          = 0  OUTPUT                                           
         ,  @c_errmsg         NVARCHAR(255)= '' OUTPUT     
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
          
         , @n_RecCnt          INT
		 , @c_SPCode          NVARCHAR(50)     --CS01
		 , @c_SQL             NVARCHAR(MAX)    --CS01
		 , @c_GetDatawindow   NVARCHAR(40)

   SET @n_StartTCnt= @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @b_Success  = 1
   SET @n_RecCnt = 0 
   SET @c_datawindow = ''
   SET @c_SPCode     = ''          --CS01
 
   SELECT TOP 1 @c_datawindow = ISNULL(DataWindow,'')  
             ,  @n_RecCnt  = 1
   FROM RDT.RDTReport (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND ReportType = @c_ReportType
   AND Function_ID = 999               -- Print From WMS Setup
   AND (Facility = @c_Facility OR Facility = '') --WL01
   ORDER BY Facility DESC                        --WL01

    --CS01 Start

   SELECT @c_SPCode = sVALUE   
   FROM   StorerConfig WITH (NOLOCK)   
   WHERE  StorerKey = @c_StorerKey  
   AND    ConfigKey = 'GetReportName_SP'    

   IF ISNULL(@c_SPCode,'') <> ''
   BEGIN

    IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')  
      BEGIN  
      SET @n_Continue = 3    
      SET @n_Err = 31211  
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)    
                     + ': Storerconfig GetReportName_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))  
                     + '). (isp_PrintToRDTSpooler_Wrapper)'    
      GOTO QUIT_SP  
    END  
  
  
   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_Storerkey, @c_Datawindow,@c_Param01, @c_Param02, @c_GetDatawindow OUTPUT'  
  
   EXEC sp_executesql @c_SQL   
      ,  N'@c_Storerkey NVARCHAR(20), @c_Datawindow NVARCHAR(40),@c_Param01 NVARCHAR(20), @c_Param02 NVARCHAR(20), @c_GetDatawindow NVARCHAR(40) OUTPUT'   
	  ,  @c_Storerkey
	  ,  @c_Datawindow
      ,  @c_Param01  
      ,  @c_Param02     
      ,  @c_GetDatawindow  OUTPUT  


	  SET @c_Datawindow = @c_GetDatawindow
   
   END 

   --CS01 End
   
   IF @n_RecCnt = 0 
   BEGIN
      SET @b_Success = 2               -- Continue to Print from WMS
      GOTO QUIT_SP
   END


   EXEC  isp_PrintToRDTSpooler                      
         @c_ReportType     = @c_ReportType          
      ,  @c_Storerkey      = @c_Storerkey           
      ,  @n_Noofparam      = @n_Noofparam           
      ,  @c_Param01        = @c_Param01             
      ,  @c_Param02        = @c_Param02             
      ,  @c_Param03        = @c_Param03             
      ,  @c_Param04        = @c_Param04             
      ,  @c_Param05        = @c_Param05             
      ,  @c_Param06        = @c_Param06             
      ,  @c_Param07        = @c_Param07             
      ,  @c_Param08        = @c_Param08             
      ,  @c_Param09        = @c_Param09             
      ,  @c_Param10        = @c_Param10             
      ,  @n_Noofcopy       = @n_Noofcopy            
      ,  @c_UserName       = @c_UserID           
      ,  @c_Facility       = @c_Facility            
      ,  @c_PrinterID      = @c_PrinterID           
      ,  @c_Datawindow     = @c_Datawindow          
      ,  @c_IsPaperPrinter = @c_IsPaperPrinter      
      ,  @c_JobType        = @c_JobType             
      ,  @c_PrintData      = @c_PrintData           
      ,  @b_success        = @b_success   OUTPUT    
      ,  @n_err            = @n_err       OUTPUT    
      ,  @c_errmsg         = @c_errmsg    OUTPUT 
      ,  @n_Function_ID    = 999    -- Print From WMS Setup

   IF @b_success = 0 
   BEGIN 
      SET @n_Continue=3 
      SET @n_err = 60010
      SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': Error Executing isp_PrintToRDTSpooler. '
                    + '( ' + @c_errmsg + ' ). (isp_PrintToRDTSpooler_Wrapper)'
      GOTO QUIT_SP 
   END

QUIT_SP:
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PrintToRDTSpooler_Wrapper'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO