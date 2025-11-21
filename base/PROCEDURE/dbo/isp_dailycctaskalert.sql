SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_DailyCCTaskAlert                               */  
/* Creation Date: 13-Jun-2012                                           */  
/* Copyright: IDS                                                       */  
/* Written by: James Wong                                               */  
/*                                                                      */  
/* Purpose: SOS#241825 - Send daily CC task alert                       */  
/*                                                                      */  
/*                                                                      */  
/* Called By: ??                                                        */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_DailyCCTaskAlert]    
(  
   @cStorerKey       NVARCHAR(15) = '',
   @n_Err            INT            OUTPUT,
   @c_ErrMsg         NVARCHAR(250)   OUTPUT 
)  
AS  
BEGIN  
  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
  
   DECLARE  @cBody         NVARCHAR(MAX),    
            @cSubject      NVARCHAR(255),  
            @cDate         NVARCHAR(20),  
            @c_MessageName NVARCHAR(15),  
            @n_Recipient   NVARCHAR(125), 
            @b_debug       INT

   SET @b_debug = 0
   SET @cDate = CONVERT(CHAR(10), getdate(), 103)  
   SET @cSubject = 'DAILY CC TASK ALERT - ' + @cDate  
  
   CREATE TABLE #TASKALERT  
   ( TASKDETAILKEY      NVARCHAR(10),   
     TASKTYPE           NVARCHAR(10),   
     STORERKEY          NVARCHAR(15),  
     SKU                NVARCHAR(20),  
     QTY                INT,  
     FROMLOC            NVARCHAR(10),  
     FROMID             NVARCHAR(18),  
     PRIORITY           NVARCHAR(10),  
     TASKDATE           DATETIME
   )    
  
   -- Create temp table to store all possible user.  
   CREATE TABLE #RecipientTemp  
   ( Recipient NVARCHAR(125))  
  
   INSERT INTO #RecipientTemp  
   select UDF01 FROM CODELKUP WITH (NOLOCK)   
   WHERE ListName = 'Alerting'
      AND Code  = 'CCAlertEmail'
   AND ISNULL(UDF01, '') <> ''   
   AND UDF01 NOT IN (SELECT Recipient FROM #RecipientTemp WITH (NOLOCK))  
   UNION  
   select UDF02 FROM CODELKUP WITH (NOLOCK)   
   WHERE ListName = 'Alerting'
      AND Code  = 'CCAlertEmail'
   AND ISNULL(UDF02, '') <> ''  
   AND UDF02 NOT IN (SELECT Recipient FROM #RecipientTemp WITH (NOLOCK))  
   UNION  
   select UDF03 FROM CODELKUP WITH (NOLOCK)   
   WHERE ListName = 'Alerting'
      AND Code  = 'CCAlertEmail'
   AND ISNULL(UDF03, '') <> ''   
   AND UDF03 NOT IN (SELECT Recipient FROM #RecipientTemp WITH (NOLOCK))  
   UNION  
   select UDF04 FROM CODELKUP WITH (NOLOCK)   
   WHERE ListName = 'Alerting'
      AND Code  = 'CCAlertEmail'
   AND ISNULL(UDF04, '') <> ''   
   AND UDF04 NOT IN (SELECT Recipient FROM #RecipientTemp WITH (NOLOCK))  
   UNION  
   select UDF05 FROM CODELKUP WITH (NOLOCK)   
   WHERE ListName = 'Alerting'
      AND Code  = 'CCAlertEmail'
   AND ISNULL(UDF05, '') <> ''   
   AND UDF05 NOT IN (SELECT Recipient FROM #RecipientTemp WITH (NOLOCK))  

   SET @n_Err = @@ERROR  
   IF @n_Err <> 0  
   BEGIN  
      SELECT @n_Err = 70001  
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error Insert into #RecipientTemp Table. (isp_DailyCCTaskAlert)'  
                       + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'  
      GOTO Quit  
   END  

   IF NOT EXISTS (SELECT 1 FROM #RecipientTemp)
   BEGIN
      SELECT @n_Err = 70002  
      SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': No Recipient setup for email alert. (isp_DailyCCTaskAlert)'  
                       + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'  
      GOTO Quit  
   END
   
   INSERT INTO #TASKALERT  
   (TASKDETAILKEY, TASKTYPE, STORERKEY, SKU, QTY, FROMLOC, FROMID, PRIORITY, TASKDATE)
   SELECT TaskdetailKey, TaskType, StorerKey, SKU, Qty, FROMLOC, ISNULL(FROMID, ''), Priority, AddDate
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskType = 'CC'
      AND Status = '0'
      AND StartTime < GETDATE() 
      AND StorerKey = CASE WHEN ISNULL(@cStorerKey, '') = '' THEN StorerKey ELSE @cStorerKey END

   IF @b_debug = 1
   BEGIN
      PRINT '#RecipientTemp'
      SELECT * FROM #RecipientTemp
      
      PRINT '#TASKALERT'
      SELECT * FROM #TASKALERT
   END
   
   IF NOT EXISTS (SELECT 1 FROM #TASKALERT)
   BEGIN
      GOTO Quit
   END
   
   -- Send email by user  
   WHILE EXISTS (SELECT 1 FROM #RecipientTemp WITH (NOLOCK))  
   BEGIN  
      SELECT TOP 1 @n_Recipient = Recipient   
      FROM #RecipientTemp WITH (NOLOCK)  

      IF EXISTS (SELECT 1 FROM #TASKALERT)  
      BEGIN  
         SET @cBody = '<table border="1" cellspacing="0" cellpadding="5">' +  
             '<tr bgcolor=silver><th>TASKDETAILKEY</th><th>TASK TYPE</th><th>STORER</th>' + 
             '<th>SKU</th><th>QTY</th><th>LOCATION</th><th>PALLET ID</th>' +
             '<th>PRIORITY</th><th>TASK GENERATED DATE</th></tr>'+ master.dbo.fnc_GetCharASCII(13) +  
             CAST ( ( SELECT td = ISNULL(CAST(TaskdetailKey AS NVARCHAR(10)),''), '',  
                             td = ISNULL(CAST(TaskType AS NVARCHAR(10)),''), '',    
                             td = ISNULL(CAST(STORERKEY AS NVARCHAR(15)),''), '',   
                             td = ISNULL(CAST(SKU AS NVARCHAR(20)),''), '',   
                             td = ISNULL(CAST(QTY AS NVARCHAR(5)),''), '',   
                             td = ISNULL(CAST(FROMLOC AS NVARCHAR(10)),''), '',   
                             td = ISNULL(CAST(FROMID AS NVARCHAR(18)),''), '',   
                             td = ISNULL(CAST(PRIORITY AS NVARCHAR(10)),''), '',   
                             td = ISNULL(CONVERT(VARCHAR(30), TASKDate, 120),'')  
                      FROM #TASKALERT WITH (NOLOCK)  
                 FOR XML PATH('tr'), TYPE     
             ) AS NVARCHAR(MAX) ) + '</table>' ;   
      END  

      EXEC msdb.dbo.sp_send_dbmail   
         @recipients      = @n_Recipient,  
         @copy_recipients = NULL,  
         @subject         = @cSubject,  
         @body            = @cBody,  
         @body_format     = 'HTML' ;  

      SET @n_Err = @@ERROR  
      IF @n_Err <> 0  
      BEGIN  
         SELECT @n_Err = 70003  
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error executing sp_send_dbmail. (isp_DailyCCTaskAlert)'  
                          + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'  
         GOTO Quit  
      END  

      DELETE FROM #RecipientTemp  
      WHERE Recipient = @n_Recipient  
        
      SET @n_Err = @@ERROR  
      IF @n_Err <> 0  
      BEGIN  
         SELECT @n_Err = 70004  
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_Err)+': Error delete from #RecipientTemp Table. (isp_DailyCCTaskAlert)'  
                          + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@n_Err),'') + ' )'  
         GOTO Quit  
      END  

   END -- WHILE EXISTS (SELECT 1 FROM #RecipientTemp WITH (NOLOCK))  
  
Quit:    
   IF @n_Err <> 0  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_DailyCCTaskAlert'   
  
   IF OBJECT_ID('tempdb..#TASKALERT','u') IS NOT NULL  
      DROP TABLE #TASKALERT;  
  
   IF OBJECT_ID('tempdb..#RecipientTemp','u') IS NOT NULL  
      DROP TABLE #RecipientTemp  
  
END -- Procedure  

GO