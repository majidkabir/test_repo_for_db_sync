SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_PrintToRDTSpooler                               */
/* Creation Date: 29-Apr-2014                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Print to RDT Spooler                                       */
/*                                                                      */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* PVCS Version: 1.9                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver. Purposes                                   */
/* 07-Jun-2016  NJOW01  1.0  Change @c_PrintData to NVARCAHR(MAX)       */  
/* 11-Sep-2016  Wan01   1.1  WMS-2970:ECOM PAcking print thru QCommander*/ 
/* 23-Oct-2017  Wan02   1.2  Raise error if Spooler Group, Port &       */
/*                           IPAddress Not Setup                        */      
/* 25-Oct-2017  SWT01   1.3  Include IP when insert TCP Q Task          */
/* 11-Nov-2017  Wan03   1.4  Skip QCommander Process By Storerconfig    */
/*                           Printerid                                  */
/* 30-OCT-2018  Wan04   1.5  Insert Function_ID to RDTPRINTJOB          */
/* 21-FEB-2019  Wan05   1.6  TCPSPOOLER                                 */  
/*                           WM-DEFAULT QCOMMANDER                      */  
/* 01-MAR-2018  Wan06   1.7  WM-Printing: Add Parm11-Parm20,Reportlineno*/  
/*                           WM-DEFAULT QCOMMANDER                      */   
/*                           WM-Fixed                                   */
/* 25-JUN-2020  Wan07   1.8  WMS-13491 - SG - PMI - Packing [CR]        */
/* 03-SEP-2021  WLChooi 1.9  WMS-17890 - Allow configure to use LABEL or*/
/*                           Paper Printer from Codelkup (WL01)         */
/* 07-SEP-2021  Wan08   2.0  LFWM-2993 - UAT - PH  Job is not triggered */
/*                           although report is successfully printed    */
/* 03-JUN-2021  Wan09   2.1  LFWM-2800 - RG UAT PB Report Print Preview */
/*                           SP & sharedrive for PDF Storage            */
/* 24-SEP-2021  Wan09   2.1  DevOps Combine Script                      */
/* 02-NOV-2022  NJOW02  2.2  if skip printer close the job (D11)        */
/************************************************************************/

CREATE PROC [dbo].[isp_PrintToRDTSpooler] ( 
   @c_ReportType     NVARCHAR(10), 
   @c_Storerkey      NVARCHAR(15),
   @b_success        INT OUTPUT,
   @n_err            INT OUTPUT,
   @c_errmsg         NVARCHAR(255) OUTPUT,
   @n_Noofparam      INT = 0,
   @c_Param01        NVARCHAR(30)='',        --(Wan08) - Fixed Truncate Value
   @c_Param02        NVARCHAR(30)='',        --(Wan08) - Fixed Truncate Value
   @c_Param03        NVARCHAR(30)='',        --(Wan08) - Fixed Truncate Value
   @c_Param04        NVARCHAR(30)='',        --(Wan08) - Fixed Truncate Value
   @c_Param05        NVARCHAR(30)='',        --(Wan08) - Fixed Truncate Value
   @c_Param06        NVARCHAR(30)='',        --(Wan08) - Fixed Truncate Value
   @c_Param07        NVARCHAR(30)='',        --(Wan08) - Fixed Truncate Value
   @c_Param08        NVARCHAR(30)='',        --(Wan08) - Fixed Truncate Value
   @c_Param09        NVARCHAR(30)='',        --(Wan08) - Fixed Truncate Value
   @c_Param10        NVARCHAR(30)='',        --(Wan08) - Fixed Truncate Value
   @n_Noofcopy       INT = 1, --optional
   @c_UserName       NVARCHAR(128)='', --optional
   @c_Facility       NVARCHAR(5)='',  --optional
   @c_PrinterID      NVARCHAR(10)='', --optional
   @c_Datawindow     NVARCHAR(40)='', --optional
   @c_IsPaperPrinter NVARCHAR(5)='N', --optional
   @c_JobType        NVARCHAR(10)='DATAWINDOW', --optional (DATAWINDOW / COMMAND / DIRECTPRN / QCOMMANDER / BARTENDER / TCPSPOOLER)
   @c_PrintData      NVARCHAR(MAX)='' --optional apply for DIRECTPRN -- up to 8000
  ,@n_Function_ID    INT      = 0      --Optional
  ,@b_PrintFromWM    BIT      = 0      --(Wan06) 
  ,@c_Param11        NVARCHAR(30)=''   --(Wan06)(Wan08) - Fixed Truncate Value 
  ,@c_Param12        NVARCHAR(30)=''   --(Wan06)(Wan08) - Fixed Truncate Value 
  ,@c_Param13        NVARCHAR(30)=''   --(Wan06)(Wan08) - Fixed Truncate Value 
  ,@c_Param14        NVARCHAR(30)=''   --(Wan06)(Wan08) - Fixed Truncate Value 
  ,@c_Param15        NVARCHAR(30)=''   --(Wan06)(Wan08) - Fixed Truncate Value 
  ,@c_Param16        NVARCHAR(30)=''   --(Wan06)(Wan08) - Fixed Truncate Value 
  ,@c_Param17        NVARCHAR(30)=''   --(Wan06)(Wan08) - Fixed Truncate Value 
  ,@c_Param18        NVARCHAR(30)=''   --(Wan06)(Wan08) - Fixed Truncate Value 
  ,@c_Param19        NVARCHAR(30)=''   --(Wan06)(Wan08) - Fixed Truncate Value 
  ,@c_Param20        NVARCHAR(30)=''   --(Wan06)(Wan08) - Fixed Truncate Value 
  ,@c_ReportLineNo   NVARCHAR(5)=''    --(Wan06) 
  ,@b_SCEPreView     INT        = 0          --(Wan09)
  ,@n_JobID          INT        = 0 OUTPUT   --(Wan09)
   )   
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF     

   DECLARE
      @n_starttcnt    INT,
      @n_continue     INT, 
      @b_debug        INT,    
      @c_TargetDB     NVARCHAR(20),
      @n_Mobile       INT,
      @c_PrintJobName NVARCHAR(50)
   --,  @n_JobID        INT                    --(Wan01) --(Wan09)
   ,  @n_QueueID      INT                    --(Wan01)
   ,  @c_ProcessType  NVARCHAR(15)           --(Wan01)
   ,  @c_SpoolerGroup NVARCHAR(20)           --(Wan01)
   ,  @c_IPAddress    NVARCHAR(40)           --(Wan01)
   ,  @c_PortNo       NVARCHAR(5)            --(Wan01)
   ,  @c_Command      NVARCHAR(1024)         --(Wan01)   
   ,  @c_IniFilePath  NVARCHAR(200)          --(Wan01)
   ,  @c_DataReceived NVARCHAR(4000)         --(Wan01)

   ,  @c_SkipQCmdByPrinter NVARCHAR(50)      --(Wan03)
   ,  @c_SpoolerPrinterID  NVARCHAR(50)      --(Wan03)

   ,  @c_Application       NVARCHAR(30)      --(Wan05) = ''
   ,  @c_JobID             NVARCHAR(10)      --(Wan05) = ''

   ,  @n_Retry             INT = 1           --(Wan07) 
   
   ,  @c_RdtPrintType      NVARCHAR(30) = '' --(WL01)
   
   ,  @c_PDFPreview        CHAR(1)      = 'N'--(Wan09)
   ,  @c_CountryPDFFolder  NVARCHAR(30) = '' --(Wan09)
   ,  @c_PDFPreviewServer  NVARCHAR(30) = '' --(Wan09)

   SET @n_starttcnt = @@TRANCOUNT
   SET @n_continue = 1
   SET @b_success = 0
   SET @n_err = 0
   SET @c_errmsg  = ''   
   SET @b_debug = 0
   SET @c_SpoolerGroup = ''                                          --(Wan01)
   
   IF ISNULL(@c_JobType,'') = ''
      SET @c_JobType = 'DATAWINDOW'

   --IF ISNULL(@c_PrintData,'') = ''                                 --(Wan06) 
   --   SET @c_PrintData = 'WMS'                                     --(Wan06)
   
   IF ISNULL(@c_UserName,'') = ''
      SET @c_UserName = SUSER_SNAME()
      
   IF @b_SCEPreView = 1 SET @c_PrinterID = ''                           --(Wan09)

   IF ISNULL(@c_Facility,'') = ''
   BEGIN
      SELECT TOP 1 @c_Facility = DefaultFacility
      FROM RDT.RDTUser (NOLOCK)
      WHERE UserName = @c_UserName
   END

   --WL01 S
   SELECT @c_RdtPrintType = ISNULL(CL.Short,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.LISTNAME = 'RDTPRNTYPE'
   AND CL.Code = @c_ReportType
   AND CL.Long = @c_Datawindow
   AND CL.Storerkey = @c_Storerkey
   AND (CL.code2 = @c_Facility OR CL.code2 = '')
   ORDER BY CASE WHEN CL.code2 = '' THEN 2 ELSE 1 END

   IF @c_RdtPrintType = 'LABEL'
   BEGIN
      SET @c_IsPaperPrinter = 'N'
   END
   ELSE IF @c_RdtPrintType = 'PAPER'
   BEGIN
      SET @c_IsPaperPrinter = 'Y'
   END
   --WL01 E

   --(Wan06) - START
   SET @c_TargetDB = DB_NAME()
   SET @c_ProcessType = @c_JobType                                   
   IF @b_PrintFromWM = 0   -- NOT PRINT FROM WM 
   BEGIN
      SET @c_ProcessType = ''                                        --(Wan06)
      SELECT TOP 1 
                 @c_datawindow = CASE WHEN ISNULL(@c_DataWindow,'') = ''  
                                      THEN ISNULL(DataWindow,'') 
                                      ELSE @c_Datawindow 
                                      END                            --(Wan06)
               , @c_TargetDB   = ISNULL(TargetDB,'')
               , @c_ProcessType= ISNULL(RTRIM(ProcessType), '')      --(Wan01)
      FROM RDT.RDTReport (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND ReportType  = @c_ReportType
      AND (Facility   = @c_Facility OR Facility = '')                --(Wan01)
      AND (Function_ID= @n_Function_ID OR Function_ID = 0)           --(Wan01)
      ORDER BY Facility DESC, Function_ID DESC                       --(Wan01)

      IF @c_ProcessType IN (  'BARTENDER' ,'BARTENDERPRTSEQ' ) 
      BEGIN
         GOTO EXIT_SP
      END

      IF ISNULL(@c_DataWindow,'') = ''   
      BEGIN
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63500    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ ': RDTSpooler Datawindow Not Found For ReportType:' + RTRIM(ISNULL(@c_ReportType,'')) + ' Storer:' + RTRIM(ISNULL(@c_Storerkey,'')) + ' (isp_PrintToRDTSpooler)'
         GOTO EXIT_SP
      END

      IF ISNULL(@c_ProcessType,'') = ''   
      BEGIN
         SET @c_ProcessType = @c_JobType 
      END
      ELSE
      BEGIN
         SET @c_JobType = @c_ProcessType  
      END

      IF @c_ProcessType IN ( 'DATAWINDOW' )
      BEGIN
         IF ISNULL(@c_PrintData,'') = ''  
         BEGIN
            SET @c_PrintData = 'WMS'
         END
      END
   END
   --(Wan06) - END
      
   SET @c_PrintJobName = 'PRINT_' + @c_ReportType
   
   IF ISNULL(@c_PrinterID,'') = ''
   BEGIN
      IF @b_SCEPreView = 1    --(Wan09) - START
      BEGIN
         SET @c_PDFPreview = 'Y'
         
         SELECT 
               @c_PDFPreviewServer  = SValue  
            ,  @c_CountryPDFFolder  = ISNULL(Option1,'')          
         FROM StorerConfig (NOLOCK)  
         WHERE ConfigKey='PDFPreviewServer'  
         AND Storerkey = 'ALL'  
         
         IF @c_PDFPreviewServer = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 63505
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': PDFPreviewServer Not Setup.'
            GOTO EXIT_SP
         END
         
         IF @c_CountryPDFFolder = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 63506
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Country PDF Folder for Preview not Setup.'
            GOTO EXIT_SP
         END
         
         SET @c_SpoolerGroup = ''
         SELECT @c_SpoolerGroup = rs.SpoolerGroup
         FROM RDT.rdtSpooler AS rs  WITH (NOLOCK) 
         WHERE rs.IPAddress = @c_PDFPreviewServer
         
         IF @c_SpoolerGroup = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 63507
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': SpoolerGroup not Setup.'
            GOTO EXIT_SP
         END
         
         SELECT TOP 1 @c_PrinterID = rp.PrinterID   
         FROM rdt.RDTPrinter AS rp WITH (NOLOCK)
         LEFT JOIN rdt.RDTPrintJob AS rpj WITH (NOLOCK) ON rp.PrinterID = rpj.Printer
         WHERE rp.SpoolerGroup = @c_SpoolerGroup
         GROUP BY rp.PrinterID
         ORDER BY COUNT(rpj.Printer) 
               ,  rp.PrinterID  
      END
      ELSE
      BEGIN
        IF @c_IsPaperPrinter = 'Y'
        BEGIN
           SELECT TOP 1 @c_PrinterID = U.DefaultPrinter_Paper
                       ,@c_SpoolerGroup = ISNULL(RTRIM(P.SpoolerGroup),'')   --(Wan01)
           FROM RDT.RDTUser U (NOLOCK)
           JOIN RDT.RDTPrinter P (NOLOCK) ON U.DefaultPrinter_Paper = P.PrinterID
           WHERE U.UserName = @c_UserName
        END
        ELSE
        BEGIN
           SELECT TOP 1 @c_PrinterID = U.DefaultPrinter
                     ,  @c_SpoolerGroup = ISNULL(RTRIM(P.SpoolerGroup),'')   --(Wan01)
           FROM RDT.RDTUser U (NOLOCK)
           JOIN RDT.RDTPrinter P (NOLOCK) ON U.DefaultPrinter = P.PrinterID
           WHERE U.UserName = @c_UserName
        END
     END                     --(Wan09) - END
   END
        
   IF ISNULL(@c_PrinterID,'') = ''
   BEGIN
      SELECT @n_Continue = 3    
      SELECT @n_Err = 63510    
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ ': RDTSpooler Default Printer Not Setup For User:' + RTRIM(ISNULL(@c_UserName,'')) + ' (isp_PrintToRDTSpooler)'
      GOTO EXIT_SP
   END
   
   BEGIN TRAN

   IF NOT EXISTS (SELECT 1 FROM RDT.RDTMOBREC (NOLOCK) WHERE UserName = @c_UserName)  
   BEGIN
      --(Wan07) - START -- Handle Multiuser Insert at the same that hit primary key error
      SET @n_Retry = 1

      WHILE @n_Retry <= 3 
      BEGIN
         SELECT @n_Mobile = ISNULL(MAX(Mobile),0) + 1
         FROM RDT.RDTMOBREC (NOLOCK)
          
         BEGIN TRY     
            INSERT INTO RDT.RDTMOBREC (Mobile, UserName, Storerkey, Facility, Printer, ErrMsg, Inputkey)
            VALUES (@n_Mobile, @c_UserName, @c_Storerkey, ISNULL(@c_Facility,''), ISNULL(@c_PrinterID,''),'WMS',0)
         END TRY

         BEGIN CATCH
            SET @n_Err = @@ERROR
         END CATCH

         IF @n_Err = 0
         BEGIN 
            BREAK
         END

         SET @n_Retry = @n_Retry + 1
      END
      --(Wan07) - END -- Handle Multiuser Insert at the same that hit primary key error

      IF @n_Err <> 0    --(Wan07)
      BEGIN  
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63520    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error On Table RDT.RDTMOBREC (isp_PrintToRDTSpooler)'
         GOTO EXIT_SP                          
      END  
   END
   ELSE
   BEGIN
        SELECT TOP 1 @n_Mobile = Mobile
        FROM RDT.RDTMOBREC (NOLOCK) 
        WHERE UserName = @c_UserName
        
        UPDATE RDT.RDTMOBREC WITH (ROWLOCK)
        SET Storerkey = @c_Storerkey,
            Facility = ISNULL(@c_Facility,''),
            Printer = ISNULL(@c_PrinterID,'')
        WHERE Mobile = @n_Mobile

      IF @@ERROR <> 0 
      BEGIN  
         SELECT @n_Continue = 3    
         SELECT @n_Err = 63530    
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update Error On Table RDT.RDTMOBREC (isp_PrintToRDTSpooler)'
         GOTO EXIT_SP                          
      END  
   END

   --(Wan04) - START
   INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms
                              , Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10
                              , Parm11, Parm12, Parm13, Parm14, Parm15, Parm16, Parm17, Parm18, Parm19, Parm20                      --(Wan06)
                              , ReportLineNo                                                                                        --(Wan06)
                              , Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, Storerkey, Function_ID
                              , PDFPreview                                                                                          --(Wan09)
                              )
   VALUES(@c_PrintJobName, @c_ReportType, '0', @c_DataWindow, @n_Noofparam
         ,@c_Param01, @c_Param02, @c_Param03, @c_Param04, @c_Param05, @c_Param06, @c_Param07, @c_Param08, @c_Param09, @c_Param10
         ,@c_Param11, @c_Param12, @c_Param13, @c_Param14, @c_Param15, @c_Param16, @c_Param17, @c_Param18, @c_Param19, @c_Param20    --(Wan06)
         ,@c_ReportLineNo                                                                                                           --(Wan06)
         ,@c_PrinterId, @n_Noofcopy, @n_Mobile, @c_TargetDB
         ,@c_PrintData, @c_JobType, @c_Storerkey, @n_Function_ID
         ,@c_PDFPreview                                                                                                             --(Wan09)         
         )
   --(Wan04) - END

   SET @n_JobID = SCOPE_IDENTITY()        --(Wan01)

   IF @@ERROR <> 0 
   BEGIN  
      SELECT @n_Continue = 3    
      SELECT @n_Err = 63540    
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error On Table RDT.RDTPrintJob (isp_PrintToRDTSpooler)'
      GOTO EXIT_SP                          
   END  

   --(Wan01) - START
   IF @c_JobType IN ( 'QCOMMANDER', 'TCPSPOOLER' )
   BEGIN
      --(Wan05) - START
      SET @c_Application = @c_ProcessType
      SET @c_JobID       = CAST( @n_JobID AS NVARCHAR( 10))
      SET @c_PrintData   = @c_JobID
      --(Wan05) - END

      --(Wan03) - START
      SET @b_Success = 1
      SET @c_SkipQCmdByPrinter = ''
      EXEC nspGetRight      
            @c_Facility  = @c_Facility     
         ,  @c_StorerKey = @c_StorerKey      
         ,  @c_sku       = NULL      
         ,  @c_ConfigKey = 'SkipQCmdByPrinter'      
         ,  @b_Success   = @b_Success              OUTPUT      
         ,  @c_authority = @c_SkipQCmdByPrinter    OUTPUT      
         ,  @n_err       = @n_err                  OUTPUT      
         ,  @c_errmsg    = @c_errmsg               OUTPUT
         ,  @c_Option1   = @c_SpoolerPrinterID     OUTPUT

      IF @b_Success <> 1
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 63541
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err)  
                     + ': Error Executing nspGetRight. (PrinterSkipQCommander)'  
         GOTO EXIT_SP
      END

      IF @c_SkipQCmdByPrinter = '1' AND @c_PrinterID IN (SELECT Value FROM STRING_SPLIT(@c_SpoolerPrinterID,','))  --NJOW02
         --@c_PrinterID = @c_SpoolerPrinterID
      BEGIN
      	 --NJOW02
      	 UPDATE rdt.RDTPrintJob WITH (ROWLOCK)
      	 SET JobStatus = '9',
      	     PrintData = 'SKIPPRINTER'
      	 WHERE JobId = @n_JobID
      	       	   
         GOTO QCMD_END
      END
      --(Wan03) - END

      --Get Spooler Group 
      IF @c_SpoolerGroup = '' 
      BEGIN
         SELECT @c_SpoolerGroup = ISNULL(RTRIM(P.SpoolerGroup),'')
         FROM rdt.rdtPrinter P WITH (NOLOCK)
         WHERE P.PrinterID = @c_PrinterID
      END

      IF @c_SpoolerGroup = ''
      BEGIN
         SET @n_Continue = 3    
         SET @n_Err = 63545   
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Spooler Group Not Setup for printid: ' + RTRIM(@c_PrinterID) + ' (isp_PrintToRDTSpooler)'
         GOTO EXIT_SP    
      END

      -- Get spooler info
      SET @c_IPAddress = ''
      SET @c_PortNo    = ''
      SET @c_Command   = ''
      SET @c_IniFilePath = ''

      SELECT 
            @c_IPAddress = IPAddress 
         ,  @c_PortNo = PortNo
         ,  @c_Command = Command
         ,  @c_IniFilePath = IniFilePath
      FROM rdt.rdtSpooler WITH (NOLOCK)
      WHERE SpoolerGroup = @c_SpoolerGroup

      --(Wan02) - START
      IF @@ROWCOUNT = 0 OR @c_IPAddress = '' OR @c_PortNo = '' OR @c_Command = '' OR @c_IniFilePath = ''
      BEGIN
         SET @n_Continue = 3    
         SET @n_Err = 63546   
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Spooler Group Not Setup. (isp_PrintToRDTSpooler)'
         GOTO EXIT_SP   
      END
      --(Wan02) - END      

      --(Wan05) - START
      IF @c_Application = 'QCOMMANDER'
      BEGIN
         SET @c_Command = @c_Command + ' ' + @c_JobID
         
         -- Insert task 
         -- SWT01
         INSERT INTO TCPSocket_QueueTask (CmdType, Cmd, StorerKey, Port, TargetDB, IP, TransmitLogKey) 
         VALUES ('CMD', @c_Command, @c_StorerKey, @c_PortNo, DB_NAME(), @c_IPAddress, @c_JobID )  

         SET @n_QueueID = SCOPE_IDENTITY()

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3    
            SET @n_Err = 63550   
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error QCommander Task (isp_PrintToRDTSpooler)'
            GOTO EXIT_SP    
         END
   
         -- <STX>CMD|855377|CNWMS|D:\RDTSpooler\rdtprint.exe 2668351<ETX>
         SET @c_PrintData = 
            '<STX>' + 
               'CMD|' + 
               CAST( @n_QueueID AS NVARCHAR( 20)) + '|' + 
               DB_NAME() + '|' + 
               @c_Command + 
            '<ETX>'
      END
      --(Wan05) - END

      -- Call Qcommander
      EXEC isp_QCmd_SendTCPSocketMsg
            @cApplication  = @c_Application
         ,  @cStorerKey    = @c_StorerKey 
         ,  @cMessageNum   = @c_JobID
         ,  @cData         = @c_PrintData
         ,  @cIP           = @c_IPAddress 
         ,  @cPORT         = @c_PortNo 
         ,  @cIniFilePath  = @c_IniFilePath 
         ,  @cDataReceived = @c_DataReceived OUTPUT
         ,  @bSuccess      = @b_Success      OUTPUT 
         ,  @nErr          = @n_err          OUTPUT 
         ,  @cErrMsg       = @c_ErrMsg       OUTPUT

      IF @n_err <> 0
      BEGIN
         GOTO EXIT_SP
      END
      
      QCMD_END:                  --(Wan03)
   END
   --(Wan01) - END

   EXIT_SP:
   
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0     
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt 
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_PrintToRDTSpooler"
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