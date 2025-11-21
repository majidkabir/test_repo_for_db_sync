SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

 
/************************************************************************/
/* Stored Procedure: isp_BackEnd_PrintToteme_ShipLbl                    */
/* CreatiON Date:  02-SEP-2021                                          */  
/* Copyright: IDS                                                       */  
/* Written by:  CSCHONG                                                 */  
/* Purpose: WMS-17759 [KR] TOTEME Shipping Label PB Report new (exceed) */
/* Called By: SQL Schedule Job  BEJ - Backend print Ship label (TOTEME) */
/* Updates:                                                             */
/* Date         Author       Purposes                                   */
/* 28-OCT-2021  CSCHONG      Devops Scripts Combine                     */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_BackEnd_PrintToteme_ShipLbl]
      @c_StorerKey NVARCHAR(15) = ''
     ,@b_debug    INT = 0

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT = 1,
           @n_cnt             INT = 0,
           @n_err             INT = 0,
           @c_ErrMsg          NvarCHAR (255) = '',
           @n_RowCnt          INT = 0,
           @b_success         INT = 0,
           @c_MBOLKey         NVARCHAR(10) = '',
           @d_Editdate        Datetime,
           @f_status          INT = '',
           @n_StartTran       INT = 0,
           @c_getstorerkey    NVARCHAR(20),
           @c_orderkey        NVARCHAR(20),
           @c_userid          NVARCHAR(20), 
           @c_SpoolerGroup    NVARCHAR(20),
           @c_DefaultPrn      NVARCHAR(20),
           @c_IPAddress       NVARCHAR(40),               
           @c_PortNo          NVARCHAR(5),           
           @c_Command         NVARCHAR(1024),           
           @c_IniFilePath     NVARCHAR(200),
           @c_PrintJobName    NVARCHAR(50),
           @c_ReportType      NVARCHAR(10),
           @c_datawindow      NVARCHAR(50),
           @c_jobtype         NVARCHAR(50),
           @c_JobStatus       NVARCHAR(1) ,
           @c_TargetDB        NVARCHAR(20),
           @n_JobID           INT,    
           @c_JobID           NVARCHAR(10),
           @c_ExtOrdkey       NVARCHAR(50),
           @c_PDFfilename     NVARCHAR(80),
           @n_Mobile          INT,
           @c_Facility        NVARCHAR(10),
           @c_DataReceived    NVARCHAR(4000)  
 
                 
        
   SET @n_StartTran = @@TRANCOUNT
   SET @n_continue=1
   SET @c_userid = SUSER_SNAME()
   SET @c_DefaultPrn ='PDF_LABEL'
   SET @c_PrintJobName = 'BackEnd_PrintToteme_ShipLbl'
   SET @c_ReportType = 'BEJSHIPLBL'
   SET @c_datawindow = 'r_dw_print_shiplabel_totte_rdt'
   SET @c_jobtype ='TCPSPOOLER'
   SET @c_JobStatus = '0'
   SET @c_TargetDB = DB_NAME() 

   SELECT @c_SpoolerGroup = ISNULL(RTRIM(P.SpoolerGroup),'')
         FROM rdt.rdtPrinter P WITH (NOLOCK)
         WHERE P.PrinterID = @c_DefaultPrn

    SELECT 
            @c_IPAddress = IPAddress 
         ,  @c_PortNo = PortNo
         ,  @c_Command = Command
         ,  @c_IniFilePath = IniFilePath
      FROM rdt.rdtSpooler WITH (NOLOCK)
      WHERE SpoolerGroup = @c_SpoolerGroup
  
      DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT OH.Storerkey,OH.OrderKey,OH.ExternOrderKey,OH.Facility
      FROM dbo.Orders OH WITH (NOLOCK)
      WHERE OH.storerkey = @c_StorerKey
      AND OH.shipperkey = 'LOTTE'
      AND ISNULL(OH.printdocdate,'') = ''
      AND OH.TrackingNo <> '' AND OH.M_Address1 <> ''
      ORDER BY OH.Storerkey,OH.OrderKey

   OPEN CUR1
   FETCH NEXT FROM CUR1 INTO @c_getstorerkey , @c_orderkey,@c_ExtOrdkey,@c_Facility
    
   SELECT @f_status = @@FETCH_STATUS
   WHILE @f_status <> -1
   BEGIN 
 
      SELECT @n_continue =1
      IF @b_debug = 1
      BEGIN
      	PRINT '' 
         PRINT 'orderkey - ' + @c_orderkey  
      END
       
      SET @c_PDFfilename = ''

      IF EXISTS(SELECT 1 FROM RDT.RDTPrintJob AS PJ WITH(NOLOCK) WHERE PJ.storerkey = @c_StorerKey AND PJ.Parm1 = @c_StorerKey AND PJ.Parm2 = @c_orderkey AND PJ.jobstatus = '9')
      OR EXISTS(SELECT 1 FROM RDT.RDTPrintJob_log AS PJL WITH(NOLOCK) WHERE PJL.storerkey = @c_StorerKey AND PJL.Parm1 = @c_StorerKey AND PJL.Parm2 = @c_orderkey AND PJL.jobstatus = '9')
      BEGIN       	
        BEGIN TRAN             
            UPDATE Orders WITH (ROWLOCK)
            SET orders.printdocdate = GETDATE(),  
                Editdate = GETDATE()
            WHERE storerkey = @c_StorerKey
            AND orderkey = @c_orderkey

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0 OR @n_cnt = 0
            BEGIN
               SELECT @n_continue = 3, @c_errmsg = 'Fail to Update Orders!'
               ROLLBACK TRAN
               GOTO QUIT_SP 
            END
            ELSE
            BEGIN
               WHILE @@TRANCOUNT > 0
               BEGIN
                  COMMIT TRAN
                  GOTO FETXH_NEXT   
               END
            END
      END
      ELSE
      BEGIN

         IF NOT EXISTS (SELECT 1 FROM RDT.RDTMOBREC (NOLOCK) WHERE UserName = @c_UserId)    
         --IF NOT EXISTS (SELECT 1 FROM RDT.RDTMOBREC (NOLOCK) WHERE storerkey = @c_StorerKey AND facility = ISNULL(@c_Facility,''))   
         BEGIN  
            SELECT @n_Mobile = ISNULL(MAX(Mobile),0) + 1  
            FROM RDT.RDTMOBREC (NOLOCK)  
                
            INSERT INTO RDT.RDTMOBREC (Mobile, UserName,Lang_Code,Storerkey, Facility, Printer, ErrMsg, Inputkey)  
            VALUES (@n_Mobile, @c_UserId,'ENG', @c_Storerkey, ISNULL(@c_Facility,''), ISNULL(@c_DefaultPrn,''),'',0)  
        
            IF @@ERROR <> 0   
            BEGIN    
               SELECT @n_Continue = 3      
               SELECT @n_Err = 63520      
               SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error On Table RDT.RDTMOBREC (isp_BackEnd_PrintToteme_ShipLbl)'  
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
                  Printer = ISNULL(@c_DefaultPrn,'')  
              WHERE Mobile = @n_Mobile  
  
            IF @@ERROR <> 0   
            BEGIN    
               SELECT @n_Continue = 3      
               SELECT @n_Err = 63530      
               SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update Error On Table RDT.RDTMOBREC (ispPKBT04)'  
               GOTO QUIT_SP                            
            END    
         END 

           SET @c_PDFfilename = @c_ExtOrdkey +'.PDF'
           IF NOT EXISTS(SELECT 1 FROM RDT.RDTPrintJob AS PJ WITH(NOLOCK) WHERE PJ.storerkey = @c_StorerKey AND PJ.Parm1 = @c_StorerKey AND PJ.Parm2 = @c_orderkey AND PJ.jobstatus IN ('0'))
           BEGIN  
           INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms  
                              , Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10  
                              , Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, Storerkey,ExportFileName, Function_ID)  
           VALUES(@c_PrintJobName, @c_ReportType, @c_JobStatus, @c_datawindow, '2'  
                  ,@c_StorerKey, @c_orderkey, '', '', '', '', '', '', '', ''   
                  ,@c_DefaultPrn, 1, @n_Mobile, @c_TargetDB  
                 , '', @c_jobtype, @c_Storerkey,@c_PDFfilename, '999')  
  
         SET @n_JobID     = SCOPE_IDENTITY()      
         SET @c_JobID     = CAST( @n_JobID AS NVARCHAR( 10))   
  
            IF @@ERROR <> 0   
            BEGIN    
               SELECT @n_Continue = 3      
               SELECT @n_Err = 63540      
               SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Insert Error On Table RDT.RDTPrintJob (ispPKBT04)'  
               GOTO QUIT_SP                            
            END    
  
              -- Send TCP socket message    
               EXEC isp_QCmd_SendTCPSocketMsg    
                  @cApplication  = @c_jobtype,    
                  @cStorerKey    = @c_StorerKey,    
                  @cMessageNum   = @c_JobID,    
                  @cData         = @c_JobID,    
                  @cIP           = @c_IPAddress,    
                  @cPORT         = @c_PortNo,    
                  @cIniFilePath  = @c_IniFilePath,    
                  @cDataReceived = @c_DataReceived OUTPUT,
                  @bSuccess      = @b_Success      OUTPUT, 
                  @nErr          = @n_err          OUTPUT, 
                  @cErrMsg       = @c_ErrMsg       OUTPUT      

               IF @n_err <> 0
               BEGIN
                  GOTO QUIT_SP
               END

          
          END
          IF EXISTS (SELECT 1 FROM RDT.RDTPrintJob_Log WITH (NOLOCK) WHERE jobid = @n_JobID AND Parm1 = @c_StorerKey AND Parm2 = @c_orderkey AND  jobstatus = '9')
          BEGIN
                     BEGIN TRAN             
                     UPDATE Orders WITH (ROWLOCK)
                     SET orders.printdocdate = GETDATE(),  
                         Editdate = GETDATE()
                     WHERE storerkey = @c_StorerKey
                     AND orderkey = @c_orderkey

                     SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                     IF @n_err <> 0 OR @n_cnt = 0
                     BEGIN
                        SELECT @n_continue = 3, @c_errmsg = 'Fail to Update Orders!'
                        ROLLBACK TRAN
                        GOTO QUIT_SP 
                     END
                     ELSE
                     BEGIN
                        WHILE @@TRANCOUNT > 0
                        BEGIN
                           COMMIT TRAN
                           GOTO FETXH_NEXT   
                        END
                     END
                   END 
      END
   
      IF @b_debug = 1
      BEGIN
         PRINT 'Print Shipping label orderkey - ' + @c_orderkey
      END 
      
      FETXH_NEXT:

      FETCH NEXT FROM CUR1 INTO @c_getstorerkey , @c_orderkey,@c_ExtOrdkey,@c_Facility
       
      SELECT @f_status = @@FETCH_STATUS
   END -- While

   CLOSE CUR1
   DEALLOCATE CUR1
   
  QUIT_SP:
   /* #INCLUDE <SPTPA01_2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_BackEnd_PrintToteme_ShipLbl"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END



GO