SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_TPP_PrintToTPServer                             */
/* Creation Date: 2-Aug-2021                                            */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Print to Trade Partner Print Server                        */
/*                                                                      */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver. Purposes                                   */
/* 05-Nov-2021 CSCHONG  1.1  Devops scripts combine                     */
/* 08-Nov-2021 CSCHONG  1.2  WMS-18065 support UPS print (CS01)         */
/* 22-Dec-2012  CSCHONG 1.1  WMS-18125 extend UDF03,UDF04 length (CS01) */  
/************************************************************************/ 

CREATE   PROC [dbo].[isp_TPP_PrintToTPServer] (
   @c_Module            NVARCHAR(20) = '', --PACKING, EPACKING
   @c_ReportType        NVARCHAR(10) = '', --UCCLABEL,
   @c_Storerkey         NVARCHAR(15)='', --Optional, if empty get from pickslip or rdtuser
   @c_Facility          NVARCHAR(5)='',  --Optional, if empty get from pickslip or rdtuser
   @c_UserName          NVARCHAR(128)= '', --optional, if empty get from current db user
   @c_PrinterID         NVARCHAR(10)='', --optional
   @c_IsPaperPrinter    NVARCHAR(5)='N', --optional Y/N
   @c_KeyFieldName      NVARCHAR(30)='PICKSLIPNO',  --key field name on @c_Parm01. default is pickslipno
   @c_Parm01            NVARCHAR(30)='',  --e.g. pickslip no / orderkey
   @c_Parm02            NVARCHAR(30)='',  --e.g. from carton no
   @c_Parm03            NVARCHAR(30)='',  --e.g. to carton no
   @c_Parm04            NVARCHAR(30)='',
   @c_Parm05            NVARCHAR(30)='',
   @c_Parm06            NVARCHAR(30)='',
   @c_Parm07            NVARCHAR(30)='',
   @c_Parm08            NVARCHAR(30)='',
   @c_Parm09            NVARCHAR(500)='',
   @c_Parm10            NVARCHAR(4000) ='',
   @c_SourceType        NVARCHAR(30) = '', --print from which function
   @c_PrintMethod       NVARCHAR(10) = 'TPP', --CS01    
   @c_ContinueNextPrint NVARCHAR(5) = 'Y' OUTPUT, -- Y=Continue next print N=Not continue next print mode like Bartender, Logireport, PDF and Datawindow
   @b_success           INT OUTPUT,
   @n_err               INT OUTPUT,
   @c_errmsg            NVARCHAR(255) OUTPUT  
   )   
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF     

   DECLARE @n_starttcnt    INT,
           @n_continue     INT,
           @c_SQL          NVARCHAR(4000)
           
   DECLARE @c_APP_DB_Name         NVARCHAR(20)=''                                   
          ,@c_DataStream          VARCHAR(10)=''                                    
          ,@n_ThreadPerAcct       INT=0                                             
          ,@n_ThreadPerStream     INT=0                                             
          ,@n_MilisecondDelay     INT=0                                             
          ,@c_IP                  NVARCHAR(20)=''                                   
          ,@c_PORT                NVARCHAR(5)=''                                    
          ,@c_IniFilePath         NVARCHAR(200)=''                                  
          ,@c_TaskType            NVARCHAR(1)=''                                    
          ,@n_Priority            INT = 0                               
          ,@c_Command             NVARCHAR(1024)                
          ,@c_CmdType             NVARCHAR(10)
          ,@c_Printer             NVARCHAR(128)
          ,@n_ContinueNextPrint   NVARCHAR(5)
          ,@c_PrePrint_StoredProc NVARCHAR(30)
          ,@c_TPPrint_StoredProc  NVARCHAR(30)         
          ,@c_SkipPrint           NVARCHAR(5)    
          ,@c_Shipperkey          NVARCHAR(15)
          ,@n_FromCartonNo        INT = 0         
          ,@n_ToCartonNo          INT = 0    
          ,@n_CartonNo            INT 
          ,@c_CartonNo            NVARCHAR(30)
          ,@c_Pickslipno          NVARCHAR(10)      
          ,@c_PrintByCarton       NVARCHAR(5)
          ,@n_JobNo               BIGINT                               
          ,@c_JobNo               NVARCHAR(10)
          ,@c_UDF01               NVARCHAR(200)          
          ,@c_UDF02               NVARCHAR(200)          
          ,@c_UDF03               NVARCHAR(4000)    --CS01      
          ,@c_UDF04               NVARCHAR(4000)    --CS01      
          ,@c_UDF05               NVARCHAR(4000)         
          ,@c_Orderkey            NVARCHAR(10) 
          ,@c_Platform            NVARCHAR(30)
          ,@c_TrackingNo          NVARCHAR(40)
          ,@c_CurrOrderkey        NVARCHAR(10)
                
   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = '', @c_PrintByCarton = 'Y' 

    --CS01 START
     IF ISNULL(@c_PrintMethod,'') = ''
     BEGIN
         SET @c_PrintMethod = 'TPP'
     END

    --CS01 END
   
   --Get Shipperkey
   IF @n_continue IN(1,2)
   BEGIN    
        IF @c_KeyFieldName = 'ORDERKEY'
        BEGIN
          SELECT @c_Orderkey = @c_Parm01
          
           SELECT TOP 1 @c_Pickslipno = PickHeaderkey
           FROM PICKHEADER (NOLOCK)
           WHERE Orderkey = @c_Parm01
        END   
        ELSE 
        BEGIN --picklipno
          SELECT @c_Orderkey = Orderkey
          FROM PACKHEADER (NOLOCK)
          WHERE Pickslipno = @c_Parm01               
          
          SELECT @c_PickslipNo = @c_Parm01
        END
           
      SELECT @c_Shipperkey = O.Shipperkey,
             @c_Platform = O.ECOM_Platform
      FROM ORDERS O (NOLOCK) 
      WHERE O.Orderkey = @c_Orderkey
      
      IF @c_PrintMethod = 'TPP' AND ISNULL(@c_Shipperkey,'') = ''   --CS01
         GOTO EXIT_SP                
   END   
   
   --Initialization
   IF @n_continue IN(1,2)
   BEGIN       
      --Storerkey   
      IF ISNULL(@c_Storerkey,'') = ''
      BEGIN
         SELECT @c_Storerkey = O.Storerkey
         FROM ORDERS O (NOLOCK) 
         WHERE O.Orderkey = @c_Orderkey

         IF ISNULL(@c_Storerkey,'') = '' 
         BEGIN
            SELECT TOP 1 @c_Storerkey = DefaultStorer
            FROM RDT.RDTUser (NOLOCK)
            WHERE UserName = @c_UserName
         END
      END   
      
      --Facility         
      IF ISNULL(@c_Facility,'') = ''
      BEGIN        
         SELECT @c_Facility = O.Facility
         FROM ORDERS O (NOLOCK) 
         WHERE O.Orderkey = @c_Orderkey
 
         IF ISNULL(@c_Facility,'') = '' 
         BEGIN
            SELECT TOP 1 @c_Facility = DefaultFacility
            FROM RDT.RDTUser (NOLOCK)
            WHERE UserName = @c_UserName
         END
      END      
   END 
      
   --TP Print
   IF @n_continue IN(1,2)
   BEGIN
        SET @c_PrePrint_StoredProc = ''
        SET @c_TPPrint_StoredProc = ''
        
        --Get shipper config
        SELECT @c_TPPrint_StoredProc = TPPrint_StoredProc,
               @c_PrePrint_StoredProc = PrePrint_StoredProc,
               @c_UDF01 = UDF01,       
               @c_UDF02 = UDF02,       
               @c_UDF03 = UDF03,       
               @c_UDF04 = UDF04,       
               @c_UDF05 = UDF05
        FROM TPPRINTCONFIG (NOLOCK)
        WHERE Storerkey = @c_Storerkey
        AND Shipperkey = CASE WHEN ISNULL(@c_Shipperkey,'') <> '' THEN @c_Shipperkey ELSE Shipperkey END      --CS01
        AND Module = @c_Module
        AND ReportType = CASE WHEN ISNULL(@c_ReportType,'') <> '' THEN @c_ReportType ELSE ReportType END
        AND Platform = CASE WHEN ISNULL(@c_Platform,'') <> '' THEN @c_Platform ELSE Platform END             --CS01
        AND ActiveFlag = '1'
                    
        --Start printing              
        IF  ISNULL(@c_TPPrint_StoredProc,'') <> '' 
        BEGIN
         DECLARE @tbl_job TABLE (JobNo BIGINT)        
         SELECT @c_ContinueNextPrint = 'N'
         SELECT @c_SkipPrint = 'N'                 
                  
          IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_TPPrint_StoredProc) AND type = 'P')
          BEGIN
            SELECT @n_Continue = 3    
            SELECT @n_Err = 63510    
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ ': Invalid Stored Proc Name: ' + RTRIM(@c_TPPrint_StoredProc)+ ' (isp_TPP_PrintToTPServer)'
            GOTO EXIT_SP                                 
          END       

          --Username
         IF ISNULL(@c_UserName,'') = ''
            SET @c_UserName = SUSER_SNAME()
          
         --RDT Printer ID
         IF ISNULL(@c_PrinterID,'') = ''
         BEGIN
            IF @c_IsPaperPrinter = 'Y'
            BEGIN
               SELECT TOP 1 @c_PrinterID = U.DefaultPrinter_Paper
               FROM RDT.RDTUser U (NOLOCK)
               JOIN RDT.RDTPrinter P (NOLOCK) ON U.DefaultPrinter_Paper = P.PrinterID
               WHERE U.UserName = @c_UserName
            END
            ELSE
            BEGIN
               SELECT TOP 1 @c_PrinterID = U.DefaultPrinter
               FROM RDT.RDTUser U (NOLOCK)
               JOIN RDT.RDTPrinter P (NOLOCK) ON U.DefaultPrinter = P.PrinterID
               WHERE U.UserName = @c_UserName
            END
         END
                    
         --Printer path
         SELECT @c_Printer = WinPrinter
         FROM RDT.RDTPRINTER (NOLOCK)
         WHERE PrinterID = @c_PrinterID        
          
          --Custom Pre Print         
          IF  ISNULL(@c_PrePrint_StoredProc,'') <> ''
           BEGIN                 
             IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_PrePrint_StoredProc) AND type = 'P')
             BEGIN
               SELECT @n_Continue = 3    
               SELECT @n_Err = 63520    
               SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ ': Invalid Stored Proc Name: ' + RTRIM(@c_PrePrint_StoredProc)+ ' (isp_TPP_PrintToTPServer)'
               GOTO EXIT_SP                                 
             END           

            SET @c_SQL = N'EXEC ' + RTRIM(@c_PrePrint_StoredProc)                                                      
                            + N' @c_Module=@c_Module'                     
                            + N',@c_ReportType=@c_ReportType'
                            + N',@c_Storerkey=@c_Storerkey'                               
                            + N',@c_Facility=@c_Facility'                               
                            + N',@c_Shipperkey=@c_Shipperkey'                            
                            + N',@c_SourceType=@c_SourceType'               
                            + N',@c_Platform=@c_Platform'          
                            + N',@c_KeyFieldName=@c_KeyFieldName'                         
                            + N',@c_Parm01=@c_Parm01 OUTPUT'                                     
                            + N',@c_Parm02=@c_Parm02 OUTPUT'                                     
                            + N',@c_Parm03=@c_Parm03 OUTPUT'                                     
                            + N',@c_Parm04=@c_Parm04 OUTPUT'                                     
                            + N',@c_Parm05=@c_Parm05 OUTPUT'                                       
                            + N',@c_Parm06=@c_Parm06 OUTPUT'                                   
                            + N',@c_Parm07=@c_Parm07 OUTPUT'                                       
                            + N',@c_Parm08=@c_Parm08 OUTPUT'                                    
                            + N',@c_Parm09=@c_Parm09 OUTPUT'                                      
                            + N',@c_Parm10=@c_Parm10 OUTPUT'                                     
                            + N',@c_UDF01=@c_UDF01 OUTPUT'                                   
                            + N',@c_UDF02=@c_UDF02 OUTPUT'                                   
                            + N',@c_UDF03=@c_UDF03 OUTPUT'                                   
                            + N',@c_UDF04=@c_UDF04 OUTPUT'                                   
                            + N',@c_UDF05=@c_UDF05 OUTPUT'   
                            + N',@c_Printerid= @c_Printerid OUTPUT' 
                            + N',@c_Printer= @c_Printer OUTPUT'
                            + N',@c_ContinueNextPrint=@c_ContinueNextPrint OUTPUT '          
                            + N',@c_SkipPrint=@c_SkipPrint OUTPUT '                         
                            + N',@b_success=@b_success OUTPUT'                                                                   
                            + N',@n_err=@n_err OUTPUT'                                                                           
                            + N',@c_errmsg=@c_errmsg OUTPUT'                       
                                  
            EXEC sp_executesql @c_SQL,
                  N'@c_Module NVARCHAR(20), @c_ReportType NVARCHAR(10), @c_Storerkey NVARCHAR(15), @c_Facility NVARCHAR(5), @c_Shipperkey NVARCHAR(15), @c_SourceType NVARCHAR(30), @c_Platform NVARCHAR(30), @c_KeyFieldName NVARCHAR(30),
                    @c_Param01 NVARCHAR(30) OUTPUT, @c_Param02 NVARCHAR(30) OUTPUT, @c_Param03 NVARCHAR(30) OUTPUT, @c_Param04 NVARCHAR(30) OUTPUT, @c_Param05 NVARCHAR(30) OUTPUT, 
                    @c_Param06 NVARCHAR(30) OUTPUT, @c_Param07 NVARCHAR(30) OUTPUT, @c_Param08 NVARCHAR(30) OUTPUT, @c_Param09 NVARCHAR(500) OUTPUT, @c_Param10 NVARCHAR(4000) OUTPUT,
                    @c_UDF01 NVARCHAR(200) OUTPUT, @c_UDF02 NVARCHAR(200) OUTPUT, @c_UDF03 NVARCHAR(4000) OUTPUT, @c_UDF04 NVARCHAR(4000) OUTPUT, @c_UDF05 NVARCHAR(4000) OUTPUT, 
                    @c_Printerid NVARCHAR(10) OUTPUT,@c_Printer NVARCHAR(128) OUTPUT, @c_ContinueNextPrint NVARCHAR(5) OUTPUT ,@c_SkipPrint NVARCHAR(5) OUTPUT, @n_Success INT OUTPUT, @n_Err INT OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'                    
                  ,@c_Module        
                  ,@c_ReportType
                  ,@c_Storerkey
                  ,@c_Facility
                  ,@c_Shipperkey
                  ,@c_SourceType
                  ,@c_Platform
                  ,@c_KeyFieldName OUTPUT
                  ,@c_Parm01 OUTPUT   
                  ,@c_Parm02 OUTPUT   
                  ,@c_Parm03 OUTPUT   
                  ,@c_Parm04 OUTPUT   
                  ,@c_Parm05 OUTPUT   
                  ,@c_Parm06 OUTPUT   
                  ,@c_Parm07 OUTPUT   
                  ,@c_Parm08 OUTPUT   
                  ,@c_Parm09 OUTPUT   
                  ,@c_Parm10 OUTPUT   
                  ,@c_Printer OUTPUT
                  ,@c_ContinueNextPrint OUTPUT
                  ,@c_SkipPrint OUTPUT
                  ,@b_success OUTPUT
                  ,@n_err OUTPUT       
                  ,@c_errmsg OUTPUT
            
            IF @b_Success <> 1
            BEGIN
               SELECT @n_continue = 3
               GOTO EXIT_SP
            END                        
          
            IF @c_SkipPrint = 'Y'
               GOTO EXIT_SP                                                                                                                                                                                                                                                  
          END  
          
         IF ISNULL(@c_Printer,'') = ''
         BEGIN
            SELECT @n_Continue = 3    
            SELECT @n_Err = 63530    
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ ': Invalid RDT Printer ID Setup:' + RTRIM(ISNULL(@c_PrinterID,'')) + ' of UserID:' + RTRIM(ISNULL(@c_UserName,'')) + ' (isp_TPP_PrintToTPServer)'
            GOTO EXIT_SP
         END                                           
                   
          --Get Qcommander configuration        
         SELECT @c_APP_DB_Name         = APP_DB_Name --TPPRINT
               ,@c_DataStream          =  CASE WHEN ISNULL(DataStream,'') = ''  AND @c_PrintMethod = 'TPP'  THEN 'TPPRINT' ELSE DataStream END    
               ,@n_ThreadPerAcct       = ThreadPerAcct
               ,@n_ThreadPerStream     = ThreadPerStream
               ,@n_MilisecondDelay     = MilisecondDelay
               ,@c_IP                  = IP
               ,@c_PORT                = PORT
               ,@c_IniFilePath         = CASE WHEN ISNULL(IniFilePath,'') = '' THEN 'C:\COMObject\GenericTCPSocketClient\config.ini' ELSE IniFilePath END  
               ,@c_CmdType             = CASE WHEN ISNULL(CmdType,'') = '' AND @c_PrintMethod = 'TPP' THEN 'WSK' ELSE CmdType END     
               ,@c_TaskType            = CASE WHEN ISNULL(TaskType,'') = '' THEN 'O' ELSE TaskType END
               ,@n_Priority            = ISNULL([Priority],0) 
         FROM  QCmd_TransmitlogConfig WITH (NOLOCK)
         WHERE TableName = CASE WHEN @c_PrintMethod = 'TPP' THEN 'TPPRINT' ELSE 'UPS' END
         AND [App_Name] = 'WMS'
         AND StorerKey  = 'ALL'   
         
         IF  @@ROWCOUNT = 0
         BEGIN 
            SELECT @n_Continue = 3    
            SELECT @n_Err = 63540    
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ ': QCmd_TransmitlogConfig Not Setup. (isp_TPP_PrintToTPServer)'
            GOTO EXIT_SP                     
         END    

           --Get carton no
           IF ISNUMERIC(@c_Parm02) = 1
            SET @n_FromCartonNo = CAST(@c_Parm02 AS INT)
         
         IF ISNUMERIC(@c_Parm03) = 1
            SET @n_ToCartonNo = CAST(@c_Parm03 AS INT)
         ELSE
            SET @n_ToCartonNo = @n_FromCartonNo
            
         IF @n_FromCartonNo = @n_ToCartonNo OR @n_FromCartonNo = 0
            SET @c_PrintByCarton = 'N'
                                                   
         IF @c_PrintByCarton = 'Y'  --Default send to print method
         BEGIN  
            DECLARE CUR_CARTONS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
               SELECT PKD.CartonNo, ISNULL(PIF.TrackingNo,''), PKH.Orderkey
               FROM PACKHEADER PKH (NOLOCK) 
               JOIN PACKDETAIL PKD (NOLOCK) ON PKH.Pickslipno = PKD.Pickslipno
               LEFT JOIN PACKINFO PIF (NOLOCK) ON PKD.Pickslipno = PIF.Pickslipno AND PKD.CartonNo = PIF.CartonNo
               WHERE PKH.Pickslipno = @c_Pickslipno
               AND PKD.CartonNo BETWEEN @n_FromCartonNo AND @n_ToCartonNo
               GROUP BY PKD.CartonNo, PIF.TrackingNo, PKH.Orderkey
               ORDER BY PKD.CartonNo
            
            OPEN CUR_CARTONS                                                                        
                                                                                           
            FETCH NEXT FROM CUR_CARTONS INTO @n_CartonNo , @c_TrackingNo, @c_CurrOrderkey             
                                                                                           
            WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)             
            BEGIN               
                SET @c_CartonNo = LTRIM(RTRIM(CAST(@n_CartonNo AS NVARCHAR)))         
                DELETE FROM @tbl_job
                
                 --Create print job
                 INSERT INTO TPPRINTJOB (Module, ReportType, Storerkey, PrinterID,Printer, Shipperkey, Status, Message, KeyFieldName,
                                        Parm01, Parm02, Parm03, Parm04, Parm05, Parm06, Parm07, Parm08, Parm09, Parm10,
                                        UDF01, UDF02, UDF03, UDF04, UDF05, SourceType, Platform)
               OUTPUT INSERTED.JobNo INTO @tbl_Job
               VALUES (@c_Module, @c_ReportType, @c_Storerkey,@c_Printerid, @c_Printer, @c_Shipperkey, '0', '', @c_KeyFieldName,
                      @c_Parm01, @c_CartonNo, @c_CartonNo, @c_Parm04, @c_Parm05, @c_Parm06, @c_Parm07, @c_Parm08, @c_Parm09, @c_Parm10,
                      @c_UDF01, @c_UDF02, @c_UDF03, @c_UDF04, @c_UDF05, @c_SourceType, @c_Platform)                                  
                                        
               SELECT @n_JobNo = JobNo FROM @tbl_Job
               SELECT @c_JobNo = RTRIM(LTRIM(CAST(@n_JobNo AS NVARCHAR)))
                                                                            
               --set command to excute TP printing
               SET @c_Command = N'EXEC ' + RTRIM(@c_TPPrint_StoredProc)          
                              + N' @n_JobNo='+ RTRIM(ISNULL(@c_JobNo,''))         
                              --+ N',@b_success=' + CAST(@b_success AS NVARCHAR) --+ ' OUTPUT'
                              --+ N',@n_err=' + CAST(@n_err AS NVARCHAR) --+ ' OUTPUT'            
                              --+ N',@c_errmsg=' + CAST(ISNULL(@c_errmsg,'') AS NVARCHAR) --+ ' OUTPUT' 
               
               --submit Qcommander task  (websocket_inlog  application:QCMD_WSK)
               EXEC isp_QCmd_SubmitTaskToQCommander   
                               @cTaskType         = @c_TaskType -- D=By Datastream, T=Transmitlog, O=Others         
                             , @cStorerKey        = @c_StorerKey                                              
                             , @cDataStream       = @c_DataStream 
                             , @cCmdType          = @c_CmdType                                                    
                             , @cCommand          = @c_Command                                                
                             , @cTransmitlogKey   = @c_JobNo                                           
                             , @nThreadPerAcct    = @n_ThreadPerAcct                                                  
                             , @nThreadPerStream  = @n_ThreadPerStream                                                        
                             , @nMilisecondDelay  = @n_MilisecondDelay                                                        
                             , @nSeq              = 1                         
                             , @cIP               = @c_IP                                           
                             , @cPORT             = @c_PORT                                                  
                             , @cIniFilePath      = @c_IniFilePath         
                             , @cAPPDBName        = @c_APP_DB_Name                                                 
                             , @bSuccess          = @b_Success OUTPUT    
                             , @nErr              = @n_Err OUTPUT    
                             , @cErrMsg           = @c_ErrMsg OUTPUT
                             , @nPriority         = @n_Priority                        
                
                IF @n_Err <> 0 AND ISNULL(@c_ErrMsg,'') <> ''
                BEGIN
                   SELECT @n_continue = 3
                END
                            
                FETCH NEXT FROM CUR_CARTONS INTO @n_CartonNo , @c_TrackingNo, @c_CurrOrderkey                      
             END
             CLOSE CUR_CARTONS
             DEALLOCATE CUR_CARTONS        
          END
          ELSE
          BEGIN
              --Create print job
              INSERT INTO TPPRINTJOB (Module, ReportType, Storerkey,PrinterID, Printer, Shipperkey, Status, Message, KeyFieldName,
                                     Parm01, Parm02, Parm03, Parm04, Parm05, Parm06, Parm07, Parm08, Parm09, Parm10,
                                     UDF01, UDF02, UDF03, UDF04, UDF05, SourceType, Platform)
            OUTPUT INSERTED.JobNo INTO @tbl_Job
            VALUES (@c_Module, @c_ReportType, @c_Storerkey, @c_Printerid,@c_Printer, @c_Shipperkey, '0', '', @c_KeyFieldName,
                   @c_Parm01, @c_Parm02, @c_Parm03, @c_Parm04, @c_Parm05, @c_Parm06, @c_Parm07, @c_Parm08, @c_Parm09, @c_Parm10,
                   @c_UDF01, @c_UDF02, @c_UDF03, @c_UDF04, @c_UDF05, @c_SourceType, @c_Platform)                                  
                                     
            SELECT @n_JobNo = JobNo FROM @tbl_Job
            SELECT @c_JobNo = RTRIM(LTRIM(CAST(@n_JobNo AS NVARCHAR)))
                                                                         
            --set command to excute TP printing
            SET @c_Command = N'EXEC ' + RTRIM(@c_TPPrint_StoredProc)          
                           + N' @n_JobNo='+ RTRIM(ISNULL(@c_JobNo,''))         
                           --+ N',@b_success=' + CAST(@b_success AS NVARCHAR) --+ ' OUTPUT'
                           --+ N',@n_err=' + CAST(@n_err AS NVARCHAR) --+ ' OUTPUT'            
                           --+ N',@c_errmsg=' + CAST(ISNULL(@c_errmsg,'') AS NVARCHAR) --+ ' OUTPUT' 
            
            --submit Qcommander task
            EXEC isp_QCmd_SubmitTaskToQCommander   
                            @cTaskType         = @c_TaskType -- D=By Datastream, T=Transmitlog, O=Others         
                          , @cStorerKey        = @c_StorerKey                                              
                          , @cDataStream       = @c_DataStream 
                          , @cCmdType          = @c_CmdType                                                    
                          , @cCommand          = @c_Command                                                
                          , @cTransmitlogKey   = @c_JobNo                                           
                          , @nThreadPerAcct    = @n_ThreadPerAcct                                                  
                          , @nThreadPerStream  = @n_ThreadPerStream                                                        
                          , @nMilisecondDelay  = @n_MilisecondDelay                                                        
                          , @nSeq              = 1                         
                          , @cIP               = @c_IP                                           
                          , @cPORT             = @c_PORT                                                  
                          , @cIniFilePath      = @c_IniFilePath         
                          , @cAPPDBName        = @c_APP_DB_Name                                                 
                          , @bSuccess          = @b_Success OUTPUT    
                          , @nErr              = @n_Err OUTPUT    
                          , @cErrMsg           = @c_ErrMsg OUTPUT
                          , @nPriority         = @n_Priority                        
             
             IF @n_Err <> 0 AND ISNULL(@c_ErrMsg,'') <> ''
             BEGIN
                SELECT @n_continue = 3
             END           
          END
        END                  
   END

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_TPP_PrintToTPServer"
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