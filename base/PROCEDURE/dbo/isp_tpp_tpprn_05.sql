SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: isp_TPP_TPPRN_05                                    */
/* Creation Date: 08-APR-2022                                           */
/* Copyright: LF                                                        */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose:  WMS-19394 [CN]TM CLOUD Printing For EcomPacking_CR         */
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
/* 08-APR-2022  CSCHONG 1.0  Devops scripts combine                     */
/* 22-JUL-2023  CSCHONG 1.1  WMS-23026 add filter on print job task(CS01)*/
/************************************************************************/ 

CREATE   PROC [dbo].[isp_TPP_TPPRN_05] (
   @n_JobNo             BIGINT
   --@b_success           INT OUTPUT,
   --@n_err               INT OUTPUT,
   --@c_errmsg            NVARCHAR(255) OUTPUT  
   )   
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF     

   DECLARE @n_starttcnt      INT,
           @n_continue       INT,
           @c_SQL            NVARCHAR(4000),
           @b_success        INT,
           @n_err            INT,
           @c_errmsg         NVARCHAR(255),
           @c_SQL03          NVARCHAR(4000)                             

                             
   DECLARE @n_FromCartonNo   INT = 0,
           @n_ToCartonNo     INT = 0,
           @n_CartonNo       INT,
           @c_TrackingNo     NVARCHAR(40),
           @c_PrintData      NVARCHAR(MAX),
           @c_WebSocketURL   NVARCHAR(200) = '',
           @c_RequestString  NVARCHAR(MAX),  
           @c_Status         NVARCHAR(10),
           @c_Message        NVARCHAR(2000),
           @n_RowRef         INT,
           @c_Orderkey       NVARCHAR(10),
           @c_CurrOrderkey   NVARCHAR(10),
           @c_Pickslipno     NVARCHAR(10),  
           @c_Module         NVARCHAR(20), --PACKING, EPACKING
           @c_ReportType     NVARCHAR(10), --UCCLABEL,
           @c_Storerkey      NVARCHAR(15), 
           @c_Printer        NVARCHAR(128), 
           @c_ShipperKey     NVARCHAR(15),    
           @c_KeyFieldName   NVARCHAR(30)='PICKSLIPNO', 
           @c_Parm01         NVARCHAR(30)='',  --e.g. pickslip no
           @c_Parm02         NVARCHAR(30)='',  --e.g. from carton no
           @c_Parm03         NVARCHAR(30)='',  --e.g. to carton no
           @c_Parm04         NVARCHAR(30)='',
           @c_Parm05         NVARCHAR(30)='',
           @c_Parm06         NVARCHAR(30)='',
           @c_Parm07         NVARCHAR(30)='',
           @c_Parm08         NVARCHAR(30)='',
           @c_Parm09         NVARCHAR(500)='',
           @c_Parm10         NVARCHAR(4000)='',
           @c_UDF01          NVARCHAR(200)='',          
           @c_UDF02          NVARCHAR(200)='',         
           @c_UDF03          NVARCHAR(4000)='',         
           @c_UDF04          NVARCHAR(4000)='',          
           @c_UDF05          NVARCHAR(4000)='',          
           @c_SourceType     NVARCHAR(30) = '', --print from which function    
           @c_Platform       NVARCHAR(30)='',       
           @c_UserName       NVARCHAR(128)= '',
           @c_SqlOutput      NVARCHAR(max) = '',     
           @c_sqlparm        NVARCHAR(max),           
           @c_SqlOutput03    NVARCHAR(max) = '',      
           @c_SqlOutput05    NVARCHAR(max) = '',     
           @c_GetPrintData   NVARCHAR(MAX) = '',     
           @c_PrnContent     NVARCHAR(4000)=''       
   
   DECLARE @c_Printername   NVARCHAR(128) 
          ,@c_PrinterID     NVARCHAR(10) 
          ,@c_cmdstart      NVARCHAR(100)
          ,@c_RequestID     NVARCHAR(10)
          ,@c_version       NVARCHAR(100)
          ,@c_content       NVARCHAR(MAX)
          ,@c_contentdata   NVARCHAR(500)
          ,@c_TemplathURL   NVARCHAR(500)
          ,@cKeyname        NVARCHAR(30) 
          ,@c_nCounter      NVARCHAR(25)
          ,@c_PrnServerIP   NVARCHAR(50) = ''
          ,@c_PrnServerPort NVARCHAR(10) = ''
          ,@c_jsoncmd       NVARCHAR(MAX)
          ,@c_CloseContent  NVARCHAR(4000) = ''
          ,@c_JobStatus     NVARCHAR(10)     --CS01

   
   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_success = 1, @n_err = 0
   SELECT @c_Message = '', @c_Status = '9' 
   
   --Initialization
   IF @n_continue IN(1,2)
   BEGIN
     SELECT @c_Module=Module, @c_ReportType=ReportType, @c_Storerkey=Storerkey,@c_PrinterID=PrinterID, @c_Printer=Printer, 
               @c_Shipperkey=Shipperkey, @c_KeyFieldName=KeyFieldName,                                       
               @c_Parm01=Parm01, @c_Parm02=Parm02, @c_Parm03=Parm03, @c_Parm04=Parm04, @c_Parm05=Parm05, 
               @c_Parm06=Parm06, @c_Parm07=Parm07, @c_Parm08=Parm08, @c_Parm09=Parm09, @c_Parm10=Parm10,        
               @c_UDF01=UDF01, @c_UDF02=UDF02, @c_UDF03=UDF03, @c_UDF04=UDF04, @c_UDF05=UDF05, @c_SourceType=SourceType,
               @c_Platform=Platform ,@c_JobStatus = Status   --CS01
        FROM TPPRINTJOB (NOLOCK)
        WHERE JobNo = @n_JobNo               
      --  AND Status <> '9'        --CS01            

       --CS01 start
       IF @c_JobStatus = '9'
       BEGIN
          GOTO EXIT_SP
       END  
       -- CS01 end                        
        
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
                                                                                                                        
      IF ISNUMERIC(@c_Parm02) = 1
         SET @n_FromCartonNo = CAST(@c_Parm02 AS INT)
      
      IF ISNUMERIC(@c_Parm03) = 1
         SET @n_ToCartonNo = CAST(@c_Parm03 AS INT)
      ELSE
         SET @n_ToCartonNo = @n_FromCartonNo


          SET @c_Printername = LEFT(@c_printer ,CHARINDEX(',' ,@c_printer + ',') -1) 

            IF ISNULL(@c_UserName,'') = ''
            SET @c_UserName = SUSER_SNAME()

       IF ISNULL(@c_PrinterID,'') = ''
        BEGIN
         SET @n_continue = 3  
         SET @n_err = 68010     
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                        + ': TPP Printer Group not setup for printer : ' + @c_printer + ' with platform' + @c_Platform + ' (isp_TPP_TPPRN_05)'
         SET @c_Status = '5'
         SET @c_Message = RTRIM(ISNULL(@c_Message,'')) + @c_ErrMsg + ' '                                

        END

        SELECT TOP 1 @c_PrnServerIP = TPPGRP.IPAddress
                   ,@c_PrnServerPort =TPPGRP.PortNo
        FROM dbo.TPPRINTERGROUP TPPGRP WITH (NOLOCK)
        JOIN rdt.RDTPrinter RP WITH (NOLOCK) ON RP.TPPrinterGroup = TPPGRP.TPPrinterGroup
        WHERE RP.Printerid= @c_printerid
        AND TPPGRP.PrinterPlatform = @c_Platform

        IF ISNULL(@c_PrnServerIP,'') = '' OR ISNULL(@c_PrnServerPort,'') = ''
        BEGIN
         SET @n_continue = 3  
         SET @n_err = 68010     
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                        + ': TPP Printer Group not setup for printer : ' + @c_printerid + ' with platform' + @c_Platform + ' (isp_TPP_TPPRN_05)'
         SET @c_Status = '5'
         SET @c_Message = RTRIM(ISNULL(@c_Message,'')) + @c_ErrMsg + ' '                                

        END
        ELSE
        BEGIN
              SET @c_WebSocketURL = 'ws://' + @c_PrnServerIP +':'+ @c_PrnServerPort
        END


        SET @c_cmdstart = 'print'
        SET @c_version = '1.0'
        SET @c_TemplathURL = @c_UDF02
        SET @cKeyname = 'TPPRINT'        

         
      CREATE TABLE #TMP_SENDREQUEST (RowID INT IDENTITY(1,1), WebSocketURL NVARCHAR(200), RequestString NVARCHAR(MAX))   
   END   
        
   IF @n_continue IN(1,2)
   BEGIN
        IF @n_FromCartonNo = 0
        BEGIN
         DECLARE CUR_CARTONS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT ROW_NUMBER() OVER(ORDER BY rowref), TrackingNo, @c_Orderkey
            FROM CARTONTRACK (NOLOCK)              
            WHERE LabelNo = @c_Orderkey
        END
        ELSE
        BEGIN
         DECLARE CUR_CARTONS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
            SELECT PKD.CartonNo, ISNULL(PIF.TrackingNo,''), PKH.Orderkey
            FROM PACKHEADER PKH (NOLOCK) 
            JOIN PACKDETAIL PKD (NOLOCK) ON PKH.Pickslipno = PKD.Pickslipno
            LEFT JOIN PACKINFO PIF (NOLOCK) ON PKD.Pickslipno = PIF.Pickslipno AND PKD.CartonNo = PIF.CartonNo
            WHERE PKH.Pickslipno = @c_Parm01
            AND PKD.CartonNo BETWEEN @n_FromCartonNo AND @n_ToCartonNo
            GROUP BY PKD.CartonNo, PIF.TrackingNo, PKH.Orderkey
            ORDER BY PKD.CartonNo
        END 
                 
      OPEN CUR_CARTONS
                                                                                     
      FETCH NEXT FROM CUR_CARTONS INTO @n_CartonNo, @c_TrackingNo, @c_CurrOrderkey
      
      IF @@FETCH_STATUS <> 0
      BEGIN
         SET @n_continue = 3  
         SET @n_err = 68010     
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                        + ': Unable to find print record for Job No: ' +RTRIM(CAST(@n_JobNo AS NVARCHAR)) + ' (isp_TPP_TPPRN_05)'
         SET @c_Status = '5'
         SET @c_Message = RTRIM(ISNULL(@c_Message,'')) + @c_ErrMsg + ' '                                
      END
                                                                                     
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)             
      BEGIN       
          SET @c_PrintData = ''

           EXECUTE nspg_getkey
                   @cKeyname ,
                   10,
                   @c_nCounter        Output ,
                   @b_success      = @b_success output,
                   @n_err          = @n_err output,
                   @c_errmsg       = @c_errmsg output,
                   @b_resultset    = 0,
                   @n_batch        = 1
           
          IF ISNULL(@c_nCounter ,'') = '' 
          BEGIN
            SET @n_continue = 3  
            SET @n_err = 68010     
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                           + ': Get RequestID fail for Order# ' + RTRIM(@c_CurrOrderkey) + ' Carton# ' + RTRIM(CAST(@n_CartonNo AS NVARCHAR)) + ' (isp_TPP_TPPRN_05)'
            SET @c_Status = '5'
            SET @c_Message = RTRIM(ISNULL(@c_Message,'')) + @c_ErrMsg + ' '                                
          END
          ELSE
          BEGIN
               SET @c_RequestID = @c_nCounter
          END    
          
          --Get Print Data
          IF ISNULL(@c_TrackingNo,'') <> ''
          BEGIN
              SELECT @n_RowRef = RowRef, @c_PrintData = PrintData
              FROM CARTONTRACK (NOLOCK)  
              WHERE TrackingNo = @c_TrackingNo
              AND LabelNo = @c_CurrOrderkey        
          END
          
          IF ISNULL(@c_PrintData,'') = ''
          BEGIN
              SELECT TOP 1 @n_RowRef = RowRef, @c_PrintData = PrintData 
              FROM CARTONTRACK (NOLOCK)  
              WHERE LabelNo = @c_CurrOrderkey
              ORDER BY RowRef                      
          END
          
          IF ISNULL(@c_PrintData,'') = ''
          BEGIN
            SET @n_continue = 3  
            SET @n_err = 68010     
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))   
                           + ': Unable to find tracking# for Order# ' + RTRIM(@c_CurrOrderkey) + ' Carton# ' + RTRIM(CAST(@n_CartonNo AS NVARCHAR)) + ' (isp_TPP_TPPRN_05)'
            SET @c_Status = '5'
            SET @c_Message = RTRIM(ISNULL(@c_Message,'')) + @c_ErrMsg + ' '                                
          END

           SET @c_GetPrintData =@c_PrintData         
          
          --Prepare print command from printdata          
           --SELECT  @c_PrintData '@c_PrintData'       
          --SET @c_WebSocketURL
          --SET @c_RequestString 
          
         IF @n_continue IN (1,2) AND @c_Status = 9 
         BEGIN
                   SET @c_CloseContent = ''
                   SET @c_contentdata = ''
                   SET @c_SqlOutput = ''      
                   SET @c_SQL = @c_UDF05      
                   SET @c_SqlOutput03 = ''    
                   SET @c_SQL03 = @c_UDF03    
                   SET @c_SqlOutput05 = ''   

                   IF ISNULL(@c_TemplathURL,'') <> '' --ISNULL(@c_contentdata,'') <> ''    
                   BEGIN
                          --SET  @c_CloseContent  = ',{"data": { "value":'  + '"' +  @c_contentdata + '"' + ',}, "templateURL": '+ '"' +  @c_TemplathURL + '"' + '}'    

                          SET @c_SQLParm =  N' @c_Orderkey     NVARCHAR(20)'
                                       +  ',@c_TrackingNo      NVARCHAR(20)'
                                       + ' ,@n_CartonNo        INT         '
                                       +  ',@c_SqlOutput       NVARCHAR(MAX) OUTPUT'

                           EXEC sp_ExecuteSQL @c_SQL
                                             ,@c_SQLParm
                                             , @c_Orderkey
                                             ,@c_TrackingNo
                                             ,@n_CartonNo
                                             ,@c_SqlOutput        OUTPUT

                         SET @c_SqlOutput05 = @c_SqlOutput         
                         SET @c_SqlOutput = ''

                         EXEC sp_ExecuteSQL @c_SQL03
                                             ,@c_SQLParm
                                            , @c_Orderkey
                                             ,@c_TrackingNo
                                             ,@n_CartonNo
                                             ,@c_SqlOutput        OUTPUT 

                          

                         IF ISNULL(@c_SqlOutput,'') <> ''
                         BEGIN
                             --SET @c_GetPrintData = REPLACE(@c_PrintData,'}','') + ','

                              SET @c_SqlOutput03 = '"addData": ' + @c_SqlOutput + '} '
                              SET @c_GetPrintData = LEFT(@c_PrintData,LEN(@c_PrintData)-1) + ',' + @c_SqlOutput03
                         END

                         SET @c_contentdata = @c_SqlOutput05
 
                         SET  @c_CloseContent = ',{"data":' + @c_contentdata + ',"templateURL": ' +'"' + @c_TemplathURL + '"' + '}'   
                   END 

                SET @c_RequestString = N'{"cmd": ' + '"' + @c_cmdstart + '"' + ', "requestID":' + '"' + @c_RequestID + '"' + ', "version":' + '"' + @c_version + '"' + ', "task": {"taskID":'  + '"' + @c_nCounter + '"' + 
                                      ',"preview": false, "printer": '  + '"' + @c_printer + '"' + ', "previewType": "pdf", "firstDocumentNumber": 1, "totalDocumentCount": 1 , "documents": [{ "documentID":'
                                     + '"' + @c_trackingno + '"' + ',"contents": [ ' + @c_GetPrintData + @c_CloseContent + '] }] } }'    
           
         
                IF NOT EXISTS(SELECT 1 FROM dbo.TPPRINTCMDLOG WITH (NOLOCK) WHERE JobNo = @n_JobNo AND CartonNo = @n_CartonNo)
                BEGIN
                --Create print job
                 INSERT INTO dbo.TPPRINTCMDLOG
                 (
                     JobNo,
                     CartonNo,
                     PrintCMD,
                     PrintServerIP,
                     PrintServerPort  
                 )
                 VALUES
                 (   @n_JobNo,         -- JobNo - bigint
                     @n_CartonNo,      -- CartonNo - int
                     @c_RequestString,        --printcmd
                     @c_PrnServerIP,          --print server ip  
                     @c_PrnServerPort         --Print server port
                     ) 
             END
         END


          --Send TS Print request
          INSERT INTO #TMP_SENDREQUEST (WebSocketURL, RequestString)
          VALUES (@c_WebSocketURL, ISNULL(@c_RequestString,''))
          
      FETCH NEXT FROM CUR_CARTONS INTO @n_CartonNo, @c_TrackingNo, @c_CurrOrderkey                   
      END
      CLOSE CUR_CARTONS
      DEALLOCATE CUR_CARTONS
   END      
   
   --update job status and message.
   UPDATE TPPRINTJOB WITH (ROWLOCK)
   SET Status = @c_Status,
       Message = @c_Message
   WHERE JobNo = @n_JobNo
   
   --Send TS Print request
   SELECT WebSocketURL, RequestString
   FROM #TMP_SENDREQUEST
   ORDER BY RowID
    
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_TPP_TPPRN_05"
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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