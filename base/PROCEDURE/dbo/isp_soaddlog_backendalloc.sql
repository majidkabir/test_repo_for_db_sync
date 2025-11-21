SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_SOADDLOG_BackEndAlloc                          */  
/* Creation Date: 02-Aug-2013                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purpose: Schedule to run on Backend for new Orders where SOADDLOG    */  
/*          and BackEndAllocSOAddLog StorerConfig turn ON.              */  
/*                                                                      */  
/* Called By: SQL Schedule Job                                          */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 6.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/* 27-Jul-2017  TLTING 1.1 SET Option                                   */
/************************************************************************/  
CREATE PROC [dbo].[isp_SOADDLOG_BackEndAlloc]
( 
  @b_Debug           INT = 0    
)
AS 
BEGIN
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  

   DECLARE @c_SourceType      NVARCHAR(1)  
         , @c_ActionFlag      NVARCHAR(18)  
         , @n_Continue        INT  
         , @n_err             INT  
         , @c_ErrMsg          CHAR (255)  
         , @b_Success         INT  
         , @c_TranLogKey      NVARCHAR(10)  
         , @c_OrderStatus     NVARCHAR(1)  
         , @c_TransmitFlag    NVARCHAR(10)  
         , @c_sValue          CHAR(10)    
         , @n_StartCnt        INT  
         , @c_ExecStatements  NVARCHAR(4000)  
         , @c_UpStatus        NVARCHAR(1)  
         , @c_EmailMsg        NVARCHAR(max)    
         , @c_OrderKey        NVARCHAR(10)  
         , @c_RecipientList   NVARCHAR(215)  
         , @c_EmailSubject    NVARCHAR(80)  
         , @c_SQLSelect       NVARCHAR(max)  
         , @n_RecCount        INT  
         , @c_StorerKey       NVARCHAR(15) 
         , @c_AutoScanOut     NVARCHAR(10)
     
   SET @b_Success = 1
   SET @n_err = 0
   
   IF ISNULL(OBJECT_ID('tempdb..#B'),'') <> ''  
   BEGIN  
      DROP TABLE #B  
   END  
  
   CREATE TABLE #B ( SeqNo  INT IDENTITY(1,1) NOT NULL  
                   , ErrMsg NVARCHAR(1000) NULL )  
  
   -- Set parameter values  
   SELECT @n_StartCnt = @@TRANCOUNT  
  
   SELECT @n_Continue = 1  
  
   IF @n_Continue = 1 OR @n_Continue = 2  
   BEGIN  
      SELECT @c_OrderKey = SPACE(10)  
  
      DECLARE Cur_BackendAllocation CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT TRANSMITLOG3.key1, 
             ActionFlag = CASE WHEN ISNULL(CLK.Code,'') = '' THEN 'SKIP' ELSE 'ALLOC' END,
             TRANSMITLOG3.transmitlogkey,
             TRANSMITLOG3.transmitflag, 
             SC.SValue, 
             ISNULL(CLK.Short, 'N')    
      FROM TRANSMITLOG3 WITH (NOLOCK) 
      JOIN StorerConfig SC WITH (NOLOCK) ON SC.StorerKey = TRANSMITLOG3.key3 AND SC.ConfigKey = 'BackEndAllocSOAddLog' AND SC.SValue IN ('1','2') 
      JOIN ORDERS SO WITH (NOLOCK) ON SO.StorerKey = TRANSMITLOG3.Key3 AND SO.OrderKey = TRANSMITLOG3.Key1
      LEFT OUTER JOIN CODELKUP CLK WITH (NOLOCK) ON CLK.Code = SO.[Type] AND CLK.LISTNAME = 'BckEndAlc' AND CLK.StorerKey = SO.StorerKey 
      WHERE TRANSMITLOG3.tablename = 'SOADDLOG' 
      AND   TRANSMITLOG3.TransmitBatch = '' 
  
      OPEN Cur_BackendAllocation  
      FETCH NEXT FROM Cur_BackendAllocation INTO @c_OrderKey, @c_ActionFlag, @c_TranLogKey, @c_TransmitFlag, @c_sValue, @c_AutoScanOut
  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         IF @c_ActionFlag = 'SKIP' 
         BEGIN
            SET @c_UpStatus = '9'
            GOTO FETCH_NEXT
         END
         
         SET @c_EmailMsg = ''  
         SET @c_SQLSelect = ''  
         SET @c_EmailSubject = ''  
  
         SELECT @c_UpStatus = '9' , @c_ErrMsg = ''  
  
         IF @b_debug = 1  
         BEGIN  
            SELECT @c_SourceType '@c_SourceType', @c_OrderKey '@c_OrderKey'  
         END  
  
         SET @c_OrderStatus = ''  
         SET @n_RecCount = 0  
         SET @c_ExecStatements = N'SELECT @c_OrderStatus = ORDERS.Status '  
                                +'FROM ORDERS WITH (NOLOCK) ' + CHAR(13)  
                                +'WHERE Orderkey = @c_OrderKey '  

         SET @c_EmailSubject = 'Backend Allocation Alert For OrderKey: ' + @c_OrderKey  

         SET @c_SQLSelect = N'SELECT @n_RecCount = COUNT(1) FROM PICKHEADER WITH (NOLOCK) ' +  
                             'WHERE Orderkey = @c_OrderKey '  
  
  
         IF @b_debug = 1  
         BEGIN  
            SELECT @c_ExecStatements  
         END  
  
         EXEC sp_executesql @c_SQLSelect, N'@n_RecCount INT OUTPUT, @c_OrderKey NVARCHAR(10) ',  
                            @n_RecCount OUTPUT, @c_OrderKey  
  
         EXEC sp_executesql @c_ExecStatements, N'@c_OrderStatus NVARCHAR(1) OUTPUT, @c_OrderKey NVARCHAR(10) ',  
                            @c_OrderStatus OUTPUT, @c_OrderKey  
  
         IF ISNULL(RTRIM(@c_OrderStatus),'') = ''  
         BEGIN  
            SELECT @c_UpStatus = '5' ,  
                   @c_ErrMsg = 'Shipment Order: '  
                              + RTRIM(@c_OrderKey) + '. Does not exist! '  
            SELECT @c_EmailMsg = @c_ErrMsg  
         END  
         ELSE  
         IF ISNULL(@n_RecCount, 0) > 0  
         BEGIN  
            SELECT @c_UpStatus = '9' ,  
                   @c_ErrMsg = 'Shipment Order: ' + RTRIM(@c_OrderKey) + '. Pick Slip Printed, No Allocation Allow.'  
            SELECT @c_EmailMsg = @c_ErrMsg  
         END  
         ELSE  -- @c_OrderStatus >= 2 No Require Allocation  
         IF ISNULL(RTRIM(@c_OrderStatus),'') = '2'  
         BEGIN  
            SELECT @c_UpStatus = '9' ,  
                   @c_ErrMsg = 'Shipment Order: ' + RTRIM(@c_OrderKey) + ' is Fully Allocated!'  
            SELECT @c_EmailMsg = @c_ErrMsg  
         END  
         ELSE  -- @c_OrderStatus >= 2 No Require Allocation  
         IF ISNULL(RTRIM(@c_OrderStatus),'') IN ('3','4')  
         BEGIN  
            SELECT @c_UpStatus = '9',  
                   @c_ErrMsg = 'Shipment Order: ' + RTRIM(@c_OrderKey) + ' is Pick In Progress!'  
            SELECT @c_EmailMsg = @c_ErrMsg  
         END  
         ELSE  -- @c_OrderStatus >= 2 No Require Allocation  
         IF ISNULL(RTRIM(@c_OrderStatus),'') IN ('5','6','7','8')  
         BEGIN  
            SELECT @c_UpStatus = '9',  
                   @c_ErrMsg = 'Shipment Order: ' + RTRIM(@c_OrderKey) + ' already Pick Confirmed!'  
            SELECT @c_EmailMsg = @c_ErrMsg  
         END  
         ELSE  
         IF ISNULL(RTRIM(@c_OrderStatus),'') = '9'  
         BEGIN  
            SELECT @c_UpStatus = '9',  
                   @c_ErrMsg = 'Shipment Order: ' + RTRIM(@c_OrderKey) + ' already Shipped!'  
            SELECT @c_EmailMsg = @c_ErrMsg  
         END  
         ELSE  -- @c_OrderStatus <= 1 and Require Allocation  
         BEGIN  
            IF @b_debug = 1  
            BEGIN  
               SELECT @c_OrderKey 'Allocating Orderkey'  
            END  

            EXEC nsp_OrderProcessing_Wrapper @c_OrderKey, '', 'N', 'N', ''  

            IF @@ERROR <> 0  
            BEGIN  
               SELECT @n_Continue = 3  

               IF @b_debug = 1  
               BEGIN  
                  SELECT @c_OrderKey 'Allocation Orders Failed'  
               END  
               -- Update Status to Failed  

               SELECT @c_UpStatus = '5'  

               IF PATINDEX('%No Orders To Process%', @c_errmsg) > 0  
               BEGIN  
                  SELECT @c_EmailMsg = 'Order No: ' +  RTRIM(@c_OrderKey) + '. No Orders To Process! ' + RTRIM(@c_errmsg) + CHAR(13)  
               END  
               ELSE  
                  SELECT @c_EmailMsg = 'Order No: ' +  RTRIM(@c_OrderKey) + '. Allocation Failed! ' + RTRIM(@c_errmsg) + CHAR(13)  
            END  
            ELSE -- IF @@ERROR = 0 --This parameter is nor pass out to this calling  
            BEGIN  
               SET @c_StorerKey = ''  
               SET @c_OrderStatus = ''  
               SELECT @c_OrderStatus = Status  
                    , @c_StorerKey = StorerKey  
               FROM   ORDERS WITH (NOLOCK)  
               WHERE  OrderKey = @c_OrderKey  

               IF @c_OrderStatus = '1'  
               BEGIN  
                  SELECT @c_UpStatus = '9' ,@c_ErrMsg = 'OrderKey: ' +  RTRIM(@c_OrderKey) + ': Partial Allocated!' + CHAR(13)  
               END  
               ELSE IF @c_OrderStatus = '2'  
               BEGIN  
                  SELECT @c_UpStatus = '9' ,@c_ErrMsg = 'OrderKey: ' +  RTRIM(@c_OrderKey) + ': Fully Allocated!' + CHAR(13)  
               END  
               ELSE IF @c_OrderStatus = '0'  
               BEGIN  
                  SELECT @c_UpStatus = '5' ,@c_ErrMsg = 'OrderKey: ' +  RTRIM(@c_OrderKey) + ': Not Allocated!' + CHAR(13)  
               END  
               ELSE  
               BEGIN  
                  SELECT @c_UpStatus = 'E' ,@c_ErrMsg = 'OrderKey: ' +  RTRIM(@c_OrderKey) + ': Allocation Failed with un-known reason. Please check with Administrator!' + CHAR(13)  
               END  
               SELECT @c_EmailMsg = @c_EmailMsg + 'StorerKey: ' + RTRIM(@c_StorerKey) + ', ' + RTRIM(@c_ErrMsg)  
            END   -- @@ERROR = 0  
         END  
  
         FETCH_NEXT:  
         
         -- Update Transmitlog3
         BEGIN TRAN  
         
         IF @c_sValue = '1'
         BEGIN
            UPDATE TRANSMITLOG3 WITH (ROWLOCK) 
               SET transmitbatch = CASE WHEN @c_UpStatus = '9' AND @c_ActionFlag = 'ALLOC' THEN 'SUCCESS'
                                        WHEN @c_UpStatus = '9' AND @c_ActionFlag = 'SKIP'  THEN 'SKIP'
                                        WHEN @c_UpStatus = '5' THEN 'NOT ALLOC'
                                        WHEN @c_UpStatus = 'E' THEN 'ERROR'
                                   END, 
                                   Transmitflag = '9'
            WHERE transmitlogkey = @c_TranLogKey             
         END
         ELSE
         BEGIN
            UPDATE TRANSMITLOG3 WITH (ROWLOCK) 
               SET transmitbatch = CASE WHEN @c_UpStatus = '9' AND @c_ActionFlag = 'ALLOC' THEN 'SUCCESS'
                                        WHEN @c_UpStatus = '9' AND @c_ActionFlag = 'SKIP'  THEN 'SKIP'
                                        WHEN @c_UpStatus = '5' THEN 'NOT ALLOC'
                                        WHEN @c_UpStatus = 'E' THEN 'ERROR'
                                   END 
            WHERE transmitlogkey = @c_TranLogKey                         
         END
  
         IF @@ERROR <> 0  
            BREAK  
  
         IF @c_AutoScanOut = 'Y' AND @c_UpStatus = '9' AND @c_ActionFlag = 'ALLOC' 
         BEGIN
            UPDATE PICKDETAIL 
               SET [Status] = '5'
            WHERE OrderKey = @c_OrderKey 
            AND [Status] < '5'
            IF @@ERROR <> 0  
               BREAK                 
         END
         
         COMMIT TRAN  
  
         IF LEN(@c_EmailMsg) > 0  
         BEGIN  
            INSERT INTO #B (ErrMsg)  
            VALUES (@c_EmailMsg)  
         END  
  
         FETCH NEXT FROM Cur_BackendAllocation INTO @c_OrderKey, @c_ActionFlag, @c_TranLogKey, @c_TransmitFlag, @c_sValue, @c_AutoScanOut  
      END   -- While Cur_BackendAllocation CURSOR  
      CLOSE Cur_BackendAllocation  
      DEALLOCATE Cur_BackendAllocation  
  
      IF EXISTS (SELECT 1 FROM #B WITH (NOLOCK)  
                 WHERE ISNULL(RTRIM(ErrMsg),'') <> '')  
      BEGIN  
         SET @c_RecipientList = ''  
  
         SELECT TOP 1 
               @c_RecipientList = ISNULL(LONG,'')  
         FROM   CODELKUP WITH (NOLOCK)  
         WHERE  LISTNAME = 'USEREMAIL'  
  
         IF LEN(@c_RecipientList) = 0  
         BEGIN  
            SET @c_RecipientList = ''  
         END  
  
         IF LEN(@c_RecipientList) > 0  
         BEGIN  
            DECLARE @tableHTML NVARCHAR(MAX);  
            SET @tableHTML =  
                N'<STYLE TYPE="text/css"> ' + CHAR(13) +  
                N'<!--' + CHAR(13) +  
                N'TR{font-family: Arial; font-size: 10pt;}' + CHAR(13) +  
                N'TD{font-family: Arial; font-size: 9pt;}' + CHAR(13) +  
                N'H3{font-family: Arial; font-size: 12pt;}' + CHAR(13) +  
                N'BODY{font-family: Arial; font-size: 9pt;}' + CHAR(13) +  
                N'--->' + CHAR(13) +  
                N'</STYLE>' + CHAR(13) +  
                N'<H3>Batch Allocation Alert</H3>' +  
                N'<BODY><P ALIGN="LEFT">Please check the following records:</P></BODY>' +  
                N'<TABLE BORDER="1" CELLSPACING="0" CELLPADDING="3">' +  
                N'<TR BGCOLOR=#3BB9FF><TH>No</TH><TH>Alert Message</TH></TR>' +  
                CAST ( ( SELECT TD = SeqNo, '',  
                                'TD/@align' = 'Left',  
                                TD = ErrMsg, ''  
                         FROM #B WITH (NOLOCK)  
                    FOR XML PATH('TR'), TYPE  
                ) AS NVARCHAR(MAX) ) +  
                N'</TABLE>' ;  
  
            EXEC msdb.dbo.sp_send_dbmail  
                 @recipients  = @c_RecipientList,  
                 @subject     = 'Backend Allocation Alert',  
                 @body        = @tableHTML,  
                 @body_format = 'HTML';  
         END  
      END  
  
      IF ISNULL(OBJECT_ID('tempdb..#B'),'') <> ''  
      BEGIN  
         DROP TABLE #B  
      END  
   END   -- IF @n_Continue = 1 OR @n_Continue=2  
END -- Procedure 

GO