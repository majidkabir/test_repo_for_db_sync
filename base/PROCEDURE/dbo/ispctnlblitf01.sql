SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ispCTNLBLITF01                                              */
/* Creation Date: 08-Jul-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-9396 THG Ecom Packing Module in Exceed                  */
/*                                                                      */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/*        :                                                             */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 09-Oct-2019 Shong    1.1   Enhancement and Performance Tuning			*/
/* 04-AUG-2020 CSCHONG  1.2   WMS-14454 - add storerkey filter (CS01)   */
/* 27-Mar-2023 WLChooi  1.3   WMS-22064 - Print for B2C only (WL01)     */
/* 27-Mar-2023 WLChooi  1.4   DevOps Combine Script                     */
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispCTNLBLITF01]
      @c_Pickslipno   NVARCHAR(10)     
  ,   @n_CartonNo_Min INT 
  ,   @n_CartonNo_Max INT 
  ,   @b_Success     INT           OUTPUT  
  ,   @n_Err         INT           OUTPUT  
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT
   
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_continue        INT 
         , @c_Orderkey        NVARCHAR(10)
         , @c_OrdType         NVARCHAR(30)
         , @c_DocType         NVARCHAR(10)
         , @c_ExtOrderkey     NVARCHAR(10)
         , @c_Shipperkey      NVARCHAR(15)

   DECLARE @c_ReportType      NVARCHAR( 10)
         , @c_ProcessType     NVARCHAR( 15)
         , @c_FilePath        NVARCHAR(100)       
         , @c_PrintFilePath   NVARCHAR(100)      
         , @c_PrintCommand    NVARCHAR(MAX)    
         , @c_WinPrinter      NVARCHAR(128)  
         , @c_PrinterName     NVARCHAR(100) 
         , @c_FileName        NVARCHAR( 50)     
         , @c_JobStatus       NVARCHAR( 1)    
         , @c_PrintJobName    NVARCHAR(50)
         , @c_TargetDB        NVARCHAR(20)
         , @n_Mobile          INT   
         , @c_SpoolerGroup    NVARCHAR(20)
         , @c_IPAddress       NVARCHAR(40)               
         , @c_PortNo          NVARCHAR(5)           
         , @c_Command         NVARCHAR(1024)            
         , @c_IniFilePath     NVARCHAR(200)  
         , @c_DataReceived    NVARCHAR(4000) 
         , @c_Facility        NVARCHAR(5) 
         , @c_Application     NVARCHAR(30)           
         , @n_JobID           INT    
         , @n_QueueID         INT 
         , @n_starttcnt       INT
         , @c_JobID           NVARCHAR(10) 
         , @c_PrintData       NVARCHAR(MAX) 
         , @c_userid          NVARCHAR(20) 
         , @c_PrinterID       NVARCHAR(20)   
         , @c_Storerkey       NVARCHAR(20) 
         , @n_IsExists        INT = 0  -- (SWT01)
         , @c_PDFFilePath     NVARCHAR(500) = ''
         , @c_ArchivePath     NVARCHAR(200) = ''
                                                              
   SET @n_err = 0
   SET @b_success = 1
   SET @c_errmsg = ''
   SET @n_continue = 1
   SET @n_starttcnt = @@TRANCOUNT
   SET @c_SpoolerGroup = '' 
   SET @c_userid = SUSER_SNAME()

   SELECT TOP 1 
       @c_Facility = DefaultFacility
      ,@c_PrinterID = DefaultPrinter
   FROM RDT.RDTUser (NOLOCK)   
   WHERE UserName = @c_userid


   SET @c_DocType = ''
   SELECT @c_Storerkey = ORDERS.StorerKey
        , @c_OrderKey = ORDERS.OrderKey 
        , @c_DocType = ORDERS.DocType 
        , @c_OrdType  = ORDERS.Type
        , @c_ExtOrderkey = ORDERS.ExternOrderKey
        , @c_Shipperkey = ORDERS.ShipperKey
   FROM PACKHEADER (NOLOCK)
   JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey
   WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo 

   --WL01 S
   IF @c_OrdType NOT IN ('B2C')
      GOTO QUIT_SP
   --WL01 E

   SELECT TOP 1  -- (SWT01)
          @c_FilePath = Long, 
          @c_PrintFilePath = Notes,
          @c_ReportType = Code2
   FROM dbo.CODELKUP WITH (NOLOCK)      
   WHERE LISTNAME = 'PrtbyShipK'  
   AND Storerkey = @c_Storerkey                  --CS01    
   --AND   Code = @c_ShipperKey 


   IF ISNULL(@c_FilePath,'') = '' --OR @c_NSQLValue <> '1'
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60011   
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) 
            + ': PDF Image Server Not Yet Setup/Enable In Codelkup Config. (ispCTNLBLITF01)' 
            + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      GOTO QUIT_SP
    END
   
    SET @n_IsExists = 0
    SET @c_PDFFilePath = @c_FilePath + '\THG_' + RTRIM(@c_ExtOrderkey) + '.PDF'
    SET @c_ArchivePath = @c_FilePath + '\Archive\THG_' + RTRIM(@c_ExtOrderkey) + '.PDF' 
    EXEC dbo.xp_fileexist @c_PDFFilePath, @n_IsExists OUTPUT
    IF @n_IsExists = 0
    BEGIN
    	 SET @c_PDFFilePath = @c_FilePath + '\Archive\THG_' + RTRIM(@c_ExtOrderkey) + '.PDF'
    	 SET @c_ArchivePath = '' 
    	 EXEC dbo.xp_fileexist @c_PDFFilePath, @n_IsExists OUTPUT 
    END
    
    IF @n_IsExists = 0 
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60003   
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': PDF filename with externorderkey: ' + @c_ExtOrderkey + ' not found. (ispCTNLBLITF01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
       GOTO QUIT_SP  --CS01
     END
     
       
     SELECT @c_WinPrinter = WinPrinter  
           ,@c_SpoolerGroup = ISNULL(RTRIM(SpoolerGroup),'') 
     FROM rdt.rdtPrinter WITH (NOLOCK)  
     WHERE PrinterID =  @c_PrinterID 

     IF CHARINDEX(',' , @c_WinPrinter) > 0 
     BEGIN
        SET @c_PrinterName = LEFT( @c_WinPrinter , (CHARINDEX(',' , @c_WinPrinter) - 1) )    
     END
     ELSE
     BEGIN
        SET @c_PrinterName =  @c_WinPrinter 
     END

     IF ISNULL(@c_ArchivePath,'') = ''
     BEGIN
         SET @c_PrintCommand = '"' + @c_PrintFilePath + '" /t "' + @c_PDFFilePath + '" "' + @c_PrinterName +  '"'     	
     END
     ELSE 
     BEGIN
     	  SET @c_PrintCommand = '"' + @c_PrintFilePath + '" /t "' + @c_PDFFilePath + '" "' + @c_PrinterName + '" "' + @c_ArchivePath + '"'     
     END
       

     SET @c_JobStatus = '9'  
     SET @c_PrintJobName = 'PRINT_' + @c_ReportType
     SET @c_TargetDB = DB_NAME()  

     IF @c_SpoolerGroup = ''  
     BEGIN  
        SET @n_Continue = 3      
        SET @n_Err = 63545     
        SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Spooler Group Not Setup for printerid: ' + RTRIM(@c_PrinterID) + ' (ispCTNLBLITF01)'  
        GOTO QUIT_SP      
     END 

     SELECT                               
           @c_IPAddress = IPAddress       
        ,  @c_PortNo = PortNo             
        ,  @c_Command = Command           
        ,  @c_IniFilePath = IniFilePath   
     FROM rdt.rdtSpooler WITH (NOLOCK)    
     WHERE SpoolerGroup = @c_SpoolerGroup 

  
      IF NOT EXISTS (SELECT 1 FROM RDT.RDTMOBREC (NOLOCK) WHERE UserName = @c_UserId)    
      BEGIN  
         SELECT @n_Mobile = ISNULL(MAX(Mobile),0) + 1  
         FROM RDT.RDTMOBREC (NOLOCK)  
                   
         INSERT INTO RDT.RDTMOBREC (Mobile, UserName, Storerkey, Facility, Printer, ErrMsg, Inputkey)  
         VALUES (@n_Mobile, @c_UserId, @c_Storerkey, ISNULL(@c_Facility,''), ISNULL(@c_PrinterID,''),'WMS',0)  
           
         IF @@ERROR <> 0   
         BEGIN    
            SELECT @n_Continue = 3      
            SELECT @n_Err = 63520      
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error On Table RDT.RDTMOBREC (ispCTNLBLITF01)'  
            GOTO QUIT_SP                            
         END    
      END  
      ELSE  
      BEGIN  
         SELECT TOP 1 @n_Mobile = Mobile  
         FROM RDT.RDTMOBREC (NOLOCK)   
         WHERE UserName = @c_UserId  
           
         UPDATE RDT.RDTMOBREC WITH (ROWLOCK)  
         SET Storerkey = @c_Storerkey,  
             Facility = ISNULL(@c_Facility,''),  
             Printer = ISNULL(@c_PrinterID,'')  
         WHERE Mobile = @n_Mobile  
  
         IF @@ERROR <> 0   
         BEGIN    
            SELECT @n_Continue = 3      
            SELECT @n_Err = 63530      
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update Error On Table RDT.RDTMOBREC (ispCTNLBLITF01)'  
            GOTO QUIT_SP                            
         END    
      END 
      
      INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms  
                              , Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10  
                              , Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, Storerkey, Function_ID)  
      VALUES(@c_PrintJobName, @c_ReportType, @c_JobStatus, '', '1'  
            ,@c_Pickslipno, @n_CartonNo_Min, @n_CartonNo_Max, '', '', '', '', '', '', ''  
            ,@c_PrinterID, 1, @n_Mobile, @c_TargetDB  
            , @c_PrintCommand, 'QCOMMANDER', @c_Storerkey, '999')  
  
      SET @n_JobID = SCOPE_IDENTITY()      
      SET @c_JobID = CAST( @n_JobID AS NVARCHAR( 10))   
  
      IF @@ERROR <> 0   
      BEGIN    
         SELECT @n_Continue = 3      
         SELECT @n_Err = 63540      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error On Table RDT.RDTPrintJob (ispCTNLBLITF01)'  
         GOTO QUIT_SP                            
      END    

   SET @c_Application = 'QCOMMANDER'

   IF @c_Application = 'QCOMMANDER'  
   BEGIN  
       SET @c_Command = @c_Command + ' ' + @c_JobID  
         
       -- Insert task   
       -- SWT01  
       INSERT INTO TCPSocket_QueueTask (CmdType, Cmd, StorerKey, Port, TargetDB, IP, TransmitLogKey,datastream)   
       VALUES ('CMD', @c_PrintCommand, @c_StorerKey, @c_PortNo, DB_NAME(), @c_IPAddress, @c_JobID,@c_Application )    
  
       SET @n_QueueID = SCOPE_IDENTITY()  
  
       IF @@ERROR <> 0  
       BEGIN  
          SET @n_Continue = 3      
          SET @n_Err = 63550     
          SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error QCommander Task (ispCTNLBLITF01)'  
          GOTO QUIT_SP      
       END  
     
       -- <STX>CMD|855377|CNWMS|D:\RDTSpooler\rdtprint.exe 2668351<ETX>  
       SET @c_PrintData =   
          '<STX>' +   
             'CMD|' +   
             CAST( @n_QueueID AS NVARCHAR( 20)) + '|' +   
             DB_NAME() + '|' +   
             @c_PrintCommand +   
          '<ETX>'  

       EXEC isp_QCmd_SendTCPSocketMsg  
             @cApplication  = 'QCOMMANDER'  
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
          GOTO QUIT_SP  
       END            
    END   
    -- Call Qcommander 
  
  QCMD_END:                  
  SET @b_success = 2         
                
  QUIT_SP:

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ispCTNLBLITF01"
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

SET QUOTED_IDENTIFIER OFF 

GO