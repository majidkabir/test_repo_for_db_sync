SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Trigger: ispMBOLINVITF01                                             */    
/* Creation Date: 29-Jul-2019                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose: PH MBOL Module in Exceed                                    */    
/*                                                                      */    
/*        :                                                             */    
/* Called By:                                                           */    
/*          :                                                           */    
/*        :                                                             */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver   Purposes                                  */    
/* 27-May-2020 CSCHONG  1.1   WMS-13469 add filter (CS01)               */ 
/* 2023-04-20  Wan01    1.1   LFWM-3913-Ship Reference Enhancement-Print*/
/*                            Interface Document                        */
/*                            DevOps Combine Script                     */
/************************************************************************/    
CREATE   PROCEDURE [dbo].[ispMBOLINVITF01]    
      @c_Parm01      NVARCHAR(50)         
  ,   @c_Parm02      NVARCHAR(50)=''    
  ,   @c_Parm03      NVARCHAR(50)=''    
  ,   @c_Parm04      NVARCHAR(50)=''    
  ,   @c_Parm05      NVARCHAR(50)=''    
  ,   @b_Success     INT  = 1 OUTPUT      
  ,   @n_Err         INT  = 0 OUTPUT      
  ,   @c_ErrMsg      NVARCHAR(255) = '' OUTPUT
  ,   @c_PrinterID   NVARCHAR(30)  = ''                                             --(Wan01)     
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
         , @c_userid          NVARCHAR(128)                                         --(Wan01) 
         --, @c_PrinterID       NVARCHAR(20)                                        --(Wan01)     
         , @c_Storerkey       NVARCHAR(20)     
         , @c_ExternReason    NVARCHAR(50)    
         , @c_PrintFlag       NVARCHAR(10)    
         , @c_InvoiceStatus   NVARCHAR(50)    
         , @c_IsSupervisor    NVARCHAR(10)
         , @c_GetStorerkey    NVARCHAR(20)           --CS01
                                                                  
   DECLARE @c_Upd_MbolKey        NVARCHAR(10)    
         , @c_Upd_MbolLineNumber NVARCHAR(5)    
                              
   SET @n_err = 0    
   SET @b_success = 1    
   SET @c_errmsg = ''    
   SET @n_continue = 1    
   SET @n_starttcnt = @@TRANCOUNT    
   SET @c_SpoolerGroup = ''     
   SET @c_userid = SUSER_SNAME()    
   SET @c_PrintFlag = 'N'    
   SET @c_IsSupervisor = 'N'    
   SET @c_InvoiceStatus = ''   
   SET @c_GetStorerkey = ''       --CS01 

 --CS01 START
 SELECT  TOP 1 @c_GetStorerkey = ORDERS.Storerkey       
   FROM  ORDERS (NOLOCK)     
   JOIN MbolDetail MB (NOLOCK) ON ORDERS.orderkey = MB.orderkey    
   WHERE MB.Mbolkey = @c_Parm01
--CS01 END
    
    
   SELECT @c_FilePath = Long,     
          @c_PrintFilePath = Notes,    
          @c_ReportType = Code2    
   FROM dbo.CODELKUP WITH (NOLOCK)       
   WHERE LISTNAME = 'PrtbyShipK'  
   AND Storerkey = @c_GetStorerkey      --CS01      
   And Code2='INVPRNPDF'               -- CS01      
    
   IF ISNULL(@c_FilePath ,'')='' --OR @c_NSQLValue <> '1'    
   BEGIN    
      SELECT @n_continue = 3    
      SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)    
            ,@n_err = 60011        
      SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+    
             ': PDF Image Server Not Yet Setup/Enable In Codelkup Config. (ispMBOLINVITF01)'+' ( '+' SQLSvr MESSAGE='+    
             ISNULL(RTRIM(@c_errmsg) ,'')+' ) '    
      GOTO QUIT_SP     
   END    
    
   IF OBJECT_ID('tempdb..#DirPDFTree') IS NULL    
   BEGIN    
      CREATE TABLE #DirPDFTree    
      (   Id               INT IDENTITY(1 ,1)    
         ,SubDirectory     NVARCHAR(255)    
         ,Depth            SMALLINT    
         ,FileFlag         BIT -- 0=folder 1=file    
      )    
   END   
     
   IF @c_PrinterID = ''                                                             --(Wan01) 
   BEGIN     
      SELECT TOP 1 @c_Facility = DefaultFacility    
                  ,@c_PrinterID = DefaultPrinter    
      FROM RDT.RDTUser (NOLOCK)       
      WHERE UserName = @c_userid    
   END                                                                              --(Wan01) 
    
   SET @c_SpoolerGroup = ''    
   SELECT @c_WinPrinter = WinPrinter      
         ,@c_SpoolerGroup = ISNULL(RTRIM(SpoolerGroup),'')     
   FROM rdt.rdtPrinter WITH (NOLOCK)      
   WHERE PrinterID =  @c_PrinterID     
    
   --PRINT '@c_PrinterID:' + @c_PrinterID    
        
   IF @c_SpoolerGroup=''    
   BEGIN    
      SET @n_Continue = 3          
      SET @n_Err = 63545         
      SET @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_Err)+': Spooler Group Not Setup for printerid: '+RTRIM(@c_PrinterID)     
         +' (ispMBOLINVITF01)'        
      GOTO QUIT_SP    
   END    
    
   SELECT @c_IPAddress   = IPAddress    
         ,@c_PortNo      = PortNo    
         ,@c_Command     = Command    
         ,@c_IniFilePath = IniFilePath    
   FROM   rdt.rdtSpooler WITH (NOLOCK)    
   WHERE  SpoolerGroup = @c_SpoolerGroup        
        
   IF CHARINDEX(',' , @c_WinPrinter) > 0     
   BEGIN    
      SET @c_PrinterName = LEFT( @c_WinPrinter , (CHARINDEX(',' , @c_WinPrinter) - 1) )        
   END    
   ELSE    
   BEGIN    
      SET @c_PrinterName =  @c_WinPrinter     
   END          
    
   SET ANSI_NULLS ON      
   SET ANSI_WARNINGS ON      
    
   EXEC isp_CheckSupervisorRole      
        @c_username  = @c_userid      
       ,@c_Flag     = @c_IsSupervisor OUTPUT      
       ,@b_Success  = @b_success      OUTPUT        
       ,@n_Err      = @n_err          OUTPUT        
       ,@c_ErrMsg   = @c_errmsg       OUTPUT        
       
   SET ANSI_NULLS OFF      
   SET ANSI_WARNINGS OFF     
          
   SET @c_DocType = ''    
       
   DECLARE @c_MbolKey nvarchar(10)    
       
   DECLARE CUR_MBOLDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT  ORDERS.Storerkey    
          ,MB.ExternReason    
          ,MAX(ISNULL(MB.InvoiceStatus,'0'))    
   FROM  ORDERS (NOLOCK)     
   JOIN MbolDetail MB (NOLOCK) ON ORDERS.orderkey = MB.orderkey    
   WHERE MB.Mbolkey = @c_Parm01    
   AND MB.ExternReason > ''     
   AND MB.ExternReason IS NOT NULL     
   GROUP BY ORDERS.Storerkey    
           ,MB.ExternReason    
       
   OPEN CUR_MBOLDETAIL    
       
   FETCH FROM CUR_MBOLDETAIL INTO @c_Storerkey, @c_ExternReason, @c_InvoiceStatus    
       
   WHILE @@FETCH_STATUS = 0    
   BEGIN        
        
    IF ISNULL(@c_InvoiceStatus,'0') <> '0'        
   BEGIN    
        SET @c_PrintFlag = 'Y'    
      END    
      ELSE     
      BEGIN    
         SET @c_PrintFlag = 'N'     
      END    
          
      -- PRINT '@c_PrintFlag: ' + @c_PrintFlag    
    
      IF @c_PrintFlag = 'Y' AND @c_IsSupervisor <> 'Y'    
      BEGIN    
         --SELECT @n_continue = 3    
         --SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60015       
         --SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+':PDF had printed. Not allow to reprint for non supervisor user (ispMBOLINVITF01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         GOTO FETCH_NEXT     
      END    
          
      TRUNCATE TABLE #DirPDFTree    
      INSERT INTO #DirPDFTree (SubDirectory, Depth, FileFlag)    
      EXEC xp_dirtree_admin @c_FilePath, 2, 1    --folder, depth 0=all(default) 1..x, 0=not list file(default) 1=list file     
    
      SET @c_FileName = ''    
      SELECT TOP 1 @c_FileName = SubDirectory    
      FROM   #DirPDFTree    
      WHERE  SubDirectory LIKE @c_ExternReason +'%'    
          
      IF ISNULL(@c_FileName ,'')='' --OR @c_NSQLValue <> '1'    
      BEGIN    
            --SELECT @n_continue = 3    
            --SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)    
            --      ,@n_err = 60003    
           
            --SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+': PDF filename with ExternReason: '+@c_ExternReason+    
            --      ' not found. (ispMBOLINVITF01)'+' ( '+' SQLSvr MESSAGE='+ISNULL(RTRIM(@c_errmsg) ,'')+' ) '           
            GOTO FETCH_NEXT      
      END        
    
      SET @c_PrintCommand = '"'+@c_PrintFilePath+'" /t "'+@c_FilePath+'\'+@c_FileName+'" "'+@c_PrinterName+'"'      
    
      SET @c_JobStatus = '9'      
      SET @c_PrintJobName = 'PRINT_'+@c_ReportType    
      SET @c_TargetDB = DB_NAME()      
       
      BEGIN TRAN      
      
      IF NOT EXISTS (SELECT 1    
             FROM   RDT.RDTMOBREC (NOLOCK)    
             WHERE  UserName = @c_UserId)    
      BEGIN    
          SELECT @n_Mobile = ISNULL(MAX(Mobile) ,0)+1    
          FROM   RDT.RDTMOBREC (NOLOCK)      
        
          INSERT INTO RDT.RDTMOBREC    
            ( Mobile       ,UserName    ,Storerkey    
             ,Facility     ,Printer     ,ErrMsg    
             ,Inputkey    
            )    
          VALUES    
            (    
              @n_Mobile ,@c_UserId    ,@c_Storerkey    
             ,ISNULL(@c_Facility ,'') ,ISNULL(@c_PrinterID ,'') ,'WMS'    
             ,0    
            )      
        
          IF @@ERROR<>0    
          BEGIN    
              SELECT @n_Continue = 3          
              SELECT @n_Err = 63520          
              SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_Err)+': Insert Error On Table RDT.RDTMOBREC (ispMBOLINVITF01)'     
              GOTO QUIT_SP    
          END    
      END    
      ELSE    
      BEGIN    
         SELECT TOP 1 @n_Mobile = Mobile    
         FROM   RDT.RDTMOBREC (NOLOCK)    
         WHERE  UserName = @c_UserId      
        
         UPDATE RDT.RDTMOBREC WITH (ROWLOCK)    
         SET    Storerkey = @c_Storerkey    
               ,Facility = ISNULL(@c_Facility ,'')    
               ,Printer = ISNULL(@c_PrinterID ,'')    
         WHERE  Mobile = @n_Mobile      
        
         IF @@ERROR<>0    
         BEGIN    
            SELECT @n_Continue = 3          
            SELECT @n_Err = 63530          
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_Err)+': Update Error On Table RDT.RDTMOBREC (ispMBOLINVITF01)'     
            GOTO QUIT_SP    
         END    
      END     
          
      INSERT INTO RDT.RDTPrintJob    
        (    
          JobName      ,ReportID    ,JobStatus    
         ,Datawindow   ,NoOfParms   ,Parm1    
         ,Parm2        ,Parm3       ,Parm4    
         ,Parm5        ,Parm6       ,Parm7    
         ,Parm8        ,Parm9       ,Parm10     
         ,Printer      ,NoOfCopy    ,Mobile    
         ,TargetDB     ,PrintData   ,JobType    
         ,Storerkey    ,Function_ID    
        )    
      VALUES    
        (    
          @c_PrintJobName  ,@c_ReportType   ,@c_JobStatus    
         ,''               ,'1'             ,@c_Parm01    
         ,@c_Parm02        ,@c_Parm03       ,''    
         ,''               ,''              ,''    
         ,''               ,''              ,''     
         ,@c_PrinterID     ,1               ,@n_Mobile    
         ,@c_TargetDB      ,@c_PrintCommand   ,'QCOMMANDER'    
         ,@c_Storerkey     ,'999'    
        )      
      
        SET @n_JobID = SCOPE_IDENTITY()          
        SET @c_JobID       = CAST( @n_JobID AS NVARCHAR( 10))       
      
        IF @@ERROR <> 0       
        BEGIN        
           SELECT @n_Continue = 3          
           SELECT @n_Err = 63540          
           SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error On Table RDT.RDTPrintJob (ispMBOLINVITF01)'      
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
              SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error QCommander Task (ispMBOLINVITF01)'      
              GOTO QUIT_SP          
           END      
         
           --set @c_PrintCommand "C:\Program Files\Foxit Software\Foxit Reader\Foxit Reader.exe" /t "C:\TEMP\534423_20190506022239.pdf" "CN_18354_ZebraGK888t_TEST"'    
           -- <STX>CMD|855377|CNWMS|D:\RDTSpooler\rdtprint.exe 2668351<ETX>      
           SET @c_PrintData =       
              '<STX>' +       
                 'CMD|' +       
                 CAST( @n_QueueID AS NVARCHAR( 20)) + '|' +       
                 DB_NAME() + '|' +       
                 @c_PrintCommand +       
              '<ETX>'      
        END -- IF @c_Application = 'QCOMMANDER'      
      
      -- Call Qcommander     
      --  select @c_PrintData '@c_PrintData'    
    
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
      ELSE    
      BEGIN    
          IF ISNULL(@c_InvoiceStatus,'') = '' OR ISNUMERIC(@c_InvoiceStatus) <> 1      
           SET @c_InvoiceStatus = '1'    
          ELSE     
          BEGIN    
             SET @c_InvoiceStatus = CAST(@c_InvoiceStatus AS INT) + 1       
          END    
                        
          DECLARE CUR_UPD_MBOLDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
          SELECT MB.MbolKey, MB.MbolLineNumber    
          FROM MbolDetail MB (NOLOCK)      
            JOIN ORDERS (NOLOCK) ON ORDERS.orderkey = MB.orderkey    
            WHERE MB.ExternReason = @c_ExternReason     
            AND ORDERS.StorerKey = @c_Storerkey     
            AND MB.ExternReason IS NOT NULL    
              
          OPEN CUR_UPD_MBOLDETAIL    
              
          FETCH FROM CUR_UPD_MBOLDETAIL INTO @c_Upd_MbolKey, @c_Upd_MbolLineNumber    
              
          WHILE @@FETCH_STATUS = 0    
          BEGIN                 
             UPDATE MBOLDETAIL WITH (ROWLOCK)    
              SET InvoiceStatus = @c_InvoiceStatus    
              ,EditWho = SUSER_NAME()    
                  ,EditDate= GETDATE()    
                  ,TrafficCop = NULL    
           WHERE MBOLKey = @c_Upd_MbolKey     
           AND MbolLineNumber = @c_Upd_MbolLineNumber    
    
           SET @n_err = @@ERROR    
               IF @n_err <> 0    
               BEGIN    
                  SET @n_Continue = 3    
                  GOTO QUIT_SP    
               END    
           FETCH FROM CUR_UPD_MBOLDETAIL INTO @c_Upd_MbolKey, @c_Upd_MbolLineNumber    
          END -- While CUR_UPD_MBOLDETAIL    
              
          CLOSE CUR_UPD_MBOLDETAIL    
          DEALLOCATE CUR_UPD_MBOLDETAIL    
       END      
      
         QCMD_END:                    
                
      FETCH_NEXT:    
    FETCH FROM CUR_MBOLDETAIL INTO @c_Storerkey, @c_ExternReason, @c_InvoiceStatus    
   END    
       
   CLOSE CUR_MBOLDETAIL    
   DEALLOCATE CUR_MBOLDETAIL    
    -- END    
    
   SET @b_success = 2    
                          
   QUIT_SP:    
    
      IF OBJECT_ID('tempdb..#DirPDFTree') IS NOT NULL     
      DROP TABLE #DirPDFTree    
    
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ispMBOLINVITF01"    
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
END  -- Procedure 
SET QUOTED_IDENTIFIER OFF 

GO