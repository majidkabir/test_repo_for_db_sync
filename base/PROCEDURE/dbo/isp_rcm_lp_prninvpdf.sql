SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_LP_KewillFlagship                          */
/* Creation Date: 07-Jan-2020                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-11693 -[CN]Floship _add new button_Ecom Printing        */
/*                                                                      */
/* Called By: Load Plan Dymaic RCM configure at listname 'RCMConfig'    */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_RCM_LP_PRNINVPDF]
   @c_Loadkey NVARCHAR(10),   
   @b_success  int OUTPUT,
   @n_err      int OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30)=''
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_cnt int,
           @n_starttcnt int
           
   DECLARE @c_Facility NVARCHAR(5),
           @c_storerkey NVARCHAR(15)
   
   DECLARE @c_Pickslipno      NVARCHAR(10)
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
         , @c_Application     NVARCHAR(30)           
         , @n_JobID           INT    
         , @n_QueueID         INT 
         , @c_JobID           NVARCHAR(10) 
         , @c_PrintData       NVARCHAR(MAX) 
         , @c_OrdNotes2       NVARCHAR(150)   
         , @n_IsExists        INT = 0  
         , @c_PDFFilePath     NVARCHAR(500) = ''
         , @c_ArchivePath     NVARCHAR(200) = ''  
         , @c_defaultPrn      NVARCHAR(20) = ''
         , @c_defaultPaperprn NVARCHAR(20) = '' 
         , @n_ttlcarton       NVARCHAR(150) = 1 
         , @c_getstorerkey    NVARCHAR(20) = ''
         , @c_PackLFileName   NVARCHAR( 150)
         , @c_CLFileName      NVARCHAR( 150)
         , @c_PrnFileName     NVARCHAR( 150)
         , @n_counter         INT = 1
         , @c_userid          NVARCHAR(18)
         , @c_printerid       NVARCHAR(50)

      CREATE TABLE #TEMPPRINTPDFJOB (
      RowId            int identity(1,1),
      PrnFilename      NVARCHAR(50)
     ) 
              
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 

   SELECT @c_userid = suser_sname()

   SELECT TOP 1 @c_Facility = DefaultFacility
               ,@c_defaultPrn = defaultprinter
               ,@c_defaultPaperprn = defaultprinter_paper
   FROM RDT.RDTUser (NOLOCK)   
   WHERE UserName = @c_userid


   DECLARE CUR_ORDERLOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT ORDERS.OrderKey,ORDERS.DocType,ORDERS.Type
        ,   ORDERS.ExternOrderKey,ORDERS.ShipperKey,RTRIM(ORDERS.notes2)
        ,   CASE WHEN ISNULL(ORDERS.notes,'') <> '' AND ISNUMERIC(ORDERS.notes) = 1 THEN CONVERT(int,ORDERS.notes) else 0 END
        ,  ORDERS.Storerkey
   FROM  ORDERS (NOLOCK) 
   WHERE ORDERS.loadkey = @c_loadkey
   
   OPEN CUR_ORDERLOOP  
  
    FETCH NEXT FROM CUR_ORDERLOOP INTO @c_OrderKey,@c_DocType ,@c_OrdType ,@c_ExtOrderkey,@c_Shipperkey,@c_OrdNotes2,@n_ttlcarton,@c_getstorerkey
      
    WHILE @@FETCH_STATUS <> -1  
    BEGIN 

   IF @c_DocType = 'E' AND @n_ttlcarton > 1
   BEGIN

      SELECT @c_FilePath = Long, 
             @c_PrintFilePath = Notes,
             @c_ReportType = Code2
      FROM dbo.CODELKUP WITH (NOLOCK)      
      WHERE LISTNAME = 'PrtbyShipK'      
      AND   Code = @c_ShipperKey 


     IF ISNULL(@c_FilePath,'') = '' 
     BEGIN
        SELECT @n_continue = 3
        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60011   
        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': PDF Image Server Not Yet Setup/Enable In Codelkup Config. (isp_RCM_LP_PRNINVPDF)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      GOTO QUIT_SP
     END

    IF OBJECT_ID('tempdb..#DirPDFTree') IS NULL
      BEGIN      
         CREATE TABLE #DirPDFTree (
           Id int identity(1,1),
           SubDirectory nvarchar(255),
           Depth smallint,
           FileFlag bit  -- 0=folder 1=file
          )
         
         INSERT INTO #DirPDFTree (SubDirectory, Depth, FileFlag)
         EXEC xp_dirtree_admin @c_FilePath, 2, 1    --folder, depth 0=all(default) 1..x, 0=not list file(default) 1=list file 
       END  
       SELECT TOP 1 @c_CLFileName = SubDirectory
       FROM #DirPDFTree
       WHERE SubDirectory like 'courier_' + @c_ExtOrderkey + '%'     --CS01

      SELECT TOP 1 @c_PackLFileName = SubDirectory
       FROM #DirPDFTree
       WHERE SubDirectory like 'packlist_' + @c_ExtOrderkey + '%'     --CS01

          IF ISNULL(@c_CLFileName,'') = '' OR ISNULL(@c_PackLFileName,'') = ''
          BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60003   
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': PDF filename with externorderkey: ' + @c_ExtOrderkey + ' not found. (isp_RCM_LP_PRNINVPDF)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
        END

         INSERT INTO #TEMPPRINTPDFJOB(PrnFilename)
         VALUES(@c_PackLFileName)

         INSERT INTO #TEMPPRINTPDFJOB(PrnFilename)
         VALUES(@c_CLFileName)

   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
    SELECT DISTINCT PrnFilename   
    FROM   #TEMPPRINTPDFJOB 
    where PrnFilename like '%' + @c_ExtOrderkey + '%'
  
    OPEN CUR_RESULT   
     
    FETCH NEXT FROM CUR_RESULT INTO @c_PrnFileName    
     
    WHILE @@FETCH_STATUS <> -1  
    BEGIN 

    IF @c_PrnFileName like 'courier_%'
    BEGIN
       IF @c_OrdNotes2 = '4x6'
       BEGIN  
       
         SET @c_printerid = @c_defaultPrn
          
         SELECT @c_WinPrinter = WinPrinter  
              ,@c_SpoolerGroup = ISNULL(RTRIM(SpoolerGroup),'') 
          FROM rdt.rdtPrinter WITH (NOLOCK)  
          WHERE PrinterID =  @c_defaultPrn 
       END
       ELSE 
       --IF @c_OrdNotes2='A4'
       BEGIN

        SET @c_printerid = @c_defaultPaperprn

        SELECT @c_WinPrinter = WinPrinter  
               ,@c_SpoolerGroup = ISNULL(RTRIM(SpoolerGroup),'') 
         FROM rdt.rdtPrinter WITH (NOLOCK)  
         WHERE PrinterID =  @c_defaultPaperprn 
       END
   END
   ELSE
   BEGIN
      SELECT @c_WinPrinter = WinPrinter  
            ,@c_SpoolerGroup = ISNULL(RTRIM(SpoolerGroup),'') 
      FROM rdt.rdtPrinter WITH (NOLOCK)  
      WHERE PrinterID =  @c_defaultPaperprn 
   END

      IF CHARINDEX(',' , @c_WinPrinter) > 0 
      BEGIN
         SET @c_PrinterName = LEFT( @c_WinPrinter , (CHARINDEX(',' , @c_WinPrinter) - 1) )    
      END
      ELSE
      BEGIN
         SET @c_PrinterName =  @c_WinPrinter 
      END

      SET @c_PrintCommand = '"' + @c_PrintFilePath + '" /t "' + @c_FilePath + '\' + @c_PrnFileName + '" "' + @c_PrinterName + '"'  


       SET @c_JobStatus = '9'  
       SET @c_PrintJobName = 'PRINT_' + @c_ReportType
       SET @c_TargetDB = DB_NAME()  

      IF @c_SpoolerGroup = ''  
      BEGIN  
         SET @n_Continue = 3      
         SET @n_Err = 63545     
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Spooler Group Not Setup for printerid: ' 
                           + RTRIM(@c_defaultPrn) + ' Or Printerid :' + RTRIM(@c_defaultPaperprn) +' (isp_RCM_LP_PRNINVPDF)'  
         GOTO QUIT_SP      
      END 

       SELECT                               
            @c_IPAddress = IPAddress       
         ,  @c_PortNo = PortNo             
         ,  @c_Command = Command           
         ,  @c_IniFilePath = IniFilePath   
      FROM rdt.rdtSpooler WITH (NOLOCK)    
      WHERE SpoolerGroup = @c_SpoolerGroup 

   BEGIN TRAN  
  
   IF NOT EXISTS (SELECT 1 FROM RDT.RDTMOBREC (NOLOCK) WHERE UserName = @c_UserId)    
   BEGIN  
      SELECT @n_Mobile = ISNULL(MAX(Mobile),0) + 1  
      FROM RDT.RDTMOBREC (NOLOCK)  
                
      INSERT INTO RDT.RDTMOBREC (Mobile, UserName, Storerkey, Facility, Printer, ErrMsg, Inputkey)  
      VALUES (@n_Mobile, @c_UserId, @c_getstorerkey, ISNULL(@c_Facility,''), ISNULL(@c_PrinterID,''),'WMS',0)  
        
      IF @@ERROR <> 0   
      BEGIN    
         SELECT @n_Continue = 3      
         SELECT @n_Err = 63520      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error On Table RDT.RDTMOBREC (isp_RCM_LP_PRNINVPDF)'  
         GOTO QUIT_SP                            
      END    
   END  
   ELSE  
   BEGIN  
        SELECT TOP 1 @n_Mobile = Mobile  
        FROM RDT.RDTMOBREC (NOLOCK)   
        WHERE UserName = @c_UserId  
          
        UPDATE RDT.RDTMOBREC WITH (ROWLOCK)  
        SET Storerkey = @c_getstorerkey,  
            Facility = ISNULL(@c_Facility,''),  
            Printer = ISNULL(@c_PrinterID,'')  
        WHERE Mobile = @n_Mobile  
  
      IF @@ERROR <> 0   
      BEGIN    
         SELECT @n_Continue = 3      
         SELECT @n_Err = 63530      
         SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update Error On Table RDT.RDTMOBREC (isp_RCM_LP_PRNINVPDF)'  
         GOTO QUIT_SP                            
      END    
   END 

         INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms  
                              , Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10  
                              , Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, Storerkey, Function_ID)  
         VALUES(@c_PrintJobName, @c_ReportType, @c_JobStatus, '', '1'  
               ,@c_loadkey, @c_ExtOrderkey, @c_getstorerkey, '', '', '', '', '', '', '' 
             -- ,'', '', '', '', '', '', '', '', '', ''   
               ,@c_PrinterID, 1, @n_Mobile, @c_TargetDB  
              , @c_PrintCommand, 'QCOMMANDER', @c_getstorerkey, '999')  
  
   SET @n_JobID = SCOPE_IDENTITY()      
   SET @c_JobID       = CAST( @n_JobID AS NVARCHAR( 10))   
  

   IF @@ERROR <> 0   
   BEGIN    
      SELECT @n_Continue = 3      
      SELECT @n_Err = 63540      
      SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error On Table RDT.RDTPrintJob (isp_RCM_LP_PRNINVPDF)'  
      GOTO QUIT_SP                            
   END    

   SET @c_Application = 'QCOMMANDER'

   IF @c_Application = 'QCOMMANDER'  
      BEGIN  
         SET @c_Command = @c_Command + ' ' + @c_JobID  
           
         INSERT INTO TCPSocket_QueueTask (CmdType, Cmd, StorerKey, Port, TargetDB, IP, TransmitLogKey,datastream)   
         VALUES ('CMD', @c_PrintCommand, @c_getstorerkey, @c_PortNo, DB_NAME(), @c_IPAddress, @c_JobID,@c_Application )    
  
         SET @n_QueueID = SCOPE_IDENTITY()  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3      
            SET @n_Err = 63550     
            SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error QCommander Task (isp_RCM_LP_PRNINVPDF)'  
            GOTO QUIT_SP      
         END  
     
         SET @c_PrintData =   
            '<STX>' +   
               'CMD|' +   
               CAST( @n_QueueID AS NVARCHAR( 20)) + '|' +   
               DB_NAME() + '|' +   
               @c_PrintCommand +   
            '<ETX>'  
      END   
  
      EXEC isp_QCmd_SendTCPSocketMsg  
            @cApplication  = 'QCOMMANDER'  
         ,  @cStorerKey    = @c_getstorerkey   
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
  
      --QCMD_END:                  
 
    --END
   
     FETCH NEXT FROM CUR_RESULT INTO @c_PrnFileName    
     END
     CLOSE CUR_RESULT  
     DEALLOCATE CUR_RESULT 

    --END
  END
    
   
    FETCH NEXT FROM CUR_ORDERLOOP INTO @c_OrderKey,@c_DocType ,@c_OrdType ,@c_ExtOrderkey,@c_Shipperkey,@c_OrdNotes2,@n_ttlcarton,@c_getstorerkey
    END  
    CLOSE CUR_ORDERLOOP  
    DEALLOCATE CUR_ORDERLOOP   
   
    SET @b_success = 2
     
QUIT_SP: 
    
   IF OBJECT_ID('tempdb..#OriginalFileList') IS NOT NULL 
      DROP TABLE #OriginalFileList 
 
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
     execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_LP_PRNINVPDF'
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
      
        
END -- End PROC

GO