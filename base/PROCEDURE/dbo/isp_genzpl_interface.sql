SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GenZPL_interface                               */
/* Creation Date:  02-Jun-2022                                          */
/* Copyright: LFL                                                       */
/* Written by: CHONGCS                                                  */
/*                                                                      */
/* Purpose: WMS-19785 [KR] VC ZPL Ship label Generate Logic             */
/*                                                                      */
/* Called By: IML                                                       */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 02-Jun-2022  CSCHONG   1.0   Devops Scripts Combine                  */
/************************************************************************/ 
              
CREATE PROC [dbo].[isp_GenZPL_interface] (              
    @c_StorerKey    NVARCHAR( 15)      
   ,@c_Facility     NVARCHAR( 5)                       
   ,@c_ReportType   NVARCHAR( 10)              
   ,@c_Param01      NVARCHAR(250)   
   ,@c_Param02      NVARCHAR(250) 
   ,@c_Param03      NVARCHAR(250) 
   ,@c_Param04      NVARCHAR(250) 
   ,@c_Param05      NVARCHAR(250)      
   ,@c_SourceType   NVARCHAR(30)='IML'
   ,@c_ZPLCode      NVARCHAR(MAX) OUTPUT   
   ,@b_success      INT           OUTPUT          
   ,@n_err          INT           OUTPUT              
   ,@c_errmsg       NVARCHAR(250) OUTPUT                          
)              
AS              
BEGIN              
   SET NOCOUNT ON              
   SET QUOTED_IDENTIFIER OFF              
   SET ANSI_NULLS OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF                            
            
   DECLARE @c_PrnTemplate    NVARCHAR( MAX)='',              
           @c_PrnTemplateSP  NVARCHAR( 80)='', 
           @c_JobType        NVARCHAR( 10),              
           @c_JobStatus      NVARCHAR( 1),                  
           @n_Continue       INT,  
           @n_starttcnt      INT,
           @c_SQL            NVARCHAR(MAX),            
           @c_SQLParam       NVARCHAR(2000)               
                                           
   SELECT @n_starttcnt=@@TRANCOUNT, @n_Continue = 1, @b_success = 1, @n_err = 0, @c_Errmsg = '', @c_ZPLCode = ''
                    
   -- Get report info              
   IF ISNULL(@c_Facility,'') <> ''
   BEGIN
	   SELECT TOP 1 @c_PrnTemplate   = ISNULL( PrintTemplate, ''),              
				          @c_PrnTemplateSP = ISNULL( PrintTemplateSP, '')                          
	   FROM rdt.rdtReport WITH (NOLOCK)              
	   WHERE StorerKey = @c_StorerKey              
	   AND ReportTYpe = @c_ReportType     
	   AND (Facility = @c_Facility OR ISNULL(Facility,'') = '')                 
	   ORDER BY Facility DESC              	
   END
   ELSE
   BEGIN
	   SELECT TOP 1 @c_PrnTemplate   = ISNULL( PrintTemplate, ''),              
				          @c_PrnTemplateSP = ISNULL( PrintTemplateSP, '')                          
	   FROM rdt.rdtReport WITH (NOLOCK)              
	   WHERE StorerKey = @c_StorerKey              
	   AND ReportTYpe = @c_ReportType     
	   ORDER BY Facility              	   	
   END
              
   -- Check report              
   IF @@ROWCOUNT = 0              
   BEGIN              
       SET @n_Continue = 3  
       SET @n_err      = 84000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+  'Report type: ' + RTRIM(@c_ReportType) +' is not setup for storerkey ' + RTRIM(@c_StorerKey) + ' (isp_GenZPL_interface)'          
   END           
   ELSE IF ISNULL(@c_PrnTemplate,'') = ''
   BEGIN
       SET @n_Continue = 3  
       SET @n_err      = 84010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+  'PrintTemplate is not setup for Report type: ' + RTRIM(@c_ReportType) +' storerkey: ' + RTRIM(@c_StorerKey) + ' (isp_GenZPL_interface)'          
   END      
   ELSE IF ISNULL(@c_PrnTemplateSP,'') = ''
   BEGIN
       SET @n_Continue = 3  
       SET @n_err      = 84020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
       SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+  'PrintTemplateSP is not setup for Report type: ' + RTRIM(@c_ReportType) +' storerkey: ' + RTRIM(@c_StorerKey) + ' (isp_GenZPL_interface)'          
   END      
              
   -- ZPL print              
   IF @n_continue IN(1,2)      
   BEGIN              
      IF @@TRANCOUNT = 0
         BEGIN TRAN
   	
      -- Execute SP to merge data and template, output print data as ZPL code              
      SET @c_SQL = 'EXEC ' + RTRIM( @c_prnTemplateSP) +              
         ' @c_StorerKey, @c_facility,@c_ReportType,' +               
         ' @c_Param01, @c_Param02, @c_Param03, @c_Param04, @c_Param05, ' +              
         ' @c_PrnTemplate , @c_ZPLCode OUTPUT,@b_success OUTPUT, @n_Err OUTPUT, @c_ErrMSG OUTPUT '              
              
      SET @c_SQLParam =                          
         '@c_StorerKey       NVARCHAR( 15),  ' +       
         '@c_Facility        NVARCHAR( 15),  ' +    
         '@c_ReportType      NVARCHAR( 15),  ' +               
         '@c_Param01         NVARCHAR( 250),  ' +              
         '@c_Param02         NVARCHAR( 250),  ' +              
         '@c_Param03         NVARCHAR( 250),  ' +              
         '@c_Param04         NVARCHAR( 250),  ' +              
         '@c_Param05         NVARCHAR( 250),  ' +                          
         '@c_PrnTemplate     NVARCHAR( MAX), ' +              
         '@c_ZPLCode         NVARCHAR( MAX) OUTPUT, ' +     
         '@b_success         INT            OUTPUT, ' +          
         '@n_Err             INT            OUTPUT, ' +              
         '@c_ErrMsg          NVARCHAR( 250)  OUTPUT  '              
              
      EXEC sp_ExecuteSQL @c_SQL, @c_SQLParam,              
                         @c_StorerKey, @c_facility, @c_ReportType,            
                         @c_Param01, @c_Param02, @c_Param03, @c_Param04, @c_Param05,              
                         @c_PrnTemplate , @c_ZPLCode OUTPUT,@b_success  OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT       
              
      IF @n_Err <> 0 
      BEGIN 
      	SET @n_continue = 3
      END
      ELSE
      BEGIN            
         SET @c_JobType = 'GENZPL'              
         SET @c_JobStatus = '9' -- Not trigger RDTSpooler              
                      
         -- Insert print job              
         INSERT INTO rdt.rdtPrintJob (              
            JobName, ReportID, JobStatus, Datawindow, NoOfParms, Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, StorerKey,               
            Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10, Function_ID)              
         VALUES(              
            @c_ReportType, @c_ReportType, @c_JobStatus, @c_SourceType, 0, '', 1, '', DB_NAME(), @c_ZPLCode, @c_JobType, @c_StorerKey,               
            @c_Param01 , @c_Param02, @c_Param03, @c_Param04 , @c_Param05, '', '', '', '', '', '')              
                                
         IF @@ERROR <> 0   
         BEGIN    
            SELECT @n_Continue = 3      
            SELECT @n_Err = 84030      
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error On Table RDT.RDTPrintJob (isp_GenZPL_interface)'  
         END                           
      END
   END               
                                                                           
Quit_SP:              

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
   ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'isp_GenZPL_interface'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
      BEGIN
         SELECT @b_success = 1
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
         RETURN
      END                   
END      

GO