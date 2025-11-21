SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_TM_ShortPick_TaskAlert                         */  
/* Creation Date: 14-Aug-2014                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purpose: SOS#318403 - Sending Email Alert when TMDET.Reason = SHORT  */  
/*                                                                      */  
/*                                                                      */  
/* Called By: Backend SQL Job                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author     Purposes                                     */  
/* 03-Sep-2013  Shong      Group Message if redundance                  */
/************************************************************************/  
  
CREATE PROC [dbo].[isp_TM_ShortPick_TaskAlert]    
(  
   @cStorerKey       NVARCHAR(15) = '',
   @cReasonKey       NVARCHAR(10) = '',
   @nErr             INT            OUTPUT,
   @cErrMsg          NVARCHAR(250)  OUTPUT 
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
   SET @cSubject = 'Short Pick Alert - ' + @cDate  
  
   CREATE TABLE #TASKALERT  
   ( TASKDETAILKEY      NVARCHAR(10),   
     UserId             NVARCHAR(18),   
     OrderKey           NVARCHAR(15),  
     SKU                NVARCHAR(20),
     SKUDesc            NVARCHAR(40),
     LOC                NVARCHAR(10),       
     QtyShort           INT,  
     TransDate          DATETIME )

  
   -- Create temp table to store all possible user.  
   CREATE TABLE #RecipientTemp  
   ( Recipient NVARCHAR(125))  
  
   INSERT INTO #RecipientTemp  
   select UDF01 FROM CODELKUP WITH (NOLOCK)   
   WHERE ListName = 'Alerting'
      AND Code  = 'PickAlertEmail'
   AND ISNULL(UDF01, '') <> ''   
   AND UDF01 NOT IN (SELECT Recipient FROM #RecipientTemp WITH (NOLOCK))  
   UNION  
   select UDF02 FROM CODELKUP WITH (NOLOCK)   
   WHERE ListName = 'Alerting'
      AND Code  = 'PickAlertEmail'
   AND ISNULL(UDF02, '') <> ''  
   AND UDF02 NOT IN (SELECT Recipient FROM #RecipientTemp WITH (NOLOCK))  
   UNION  
   select UDF03 FROM CODELKUP WITH (NOLOCK)   
   WHERE ListName = 'Alerting'
      AND Code  = 'PickAlertEmail'
   AND ISNULL(UDF03, '') <> ''   
   AND UDF03 NOT IN (SELECT Recipient FROM #RecipientTemp WITH (NOLOCK))  
   UNION  
   SELECT UDF04 FROM CODELKUP WITH (NOLOCK)   
   WHERE ListName = 'Alerting'
      AND Code  = 'PickAlertEmail'
   AND ISNULL(UDF04, '') <> ''   
   AND UDF04 NOT IN (SELECT Recipient FROM #RecipientTemp WITH (NOLOCK))  
   UNION  
   select UDF05 FROM CODELKUP WITH (NOLOCK)   
   WHERE ListName = 'Alerting'
      AND Code  = 'PickAlertEmail'
   AND ISNULL(UDF05, '') <> ''   
   AND UDF05 NOT IN (SELECT Recipient FROM #RecipientTemp WITH (NOLOCK))  

   SET @nErr = @@ERROR  
   IF @nErr <> 0  
   BEGIN  
      SELECT @nErr = 70001  
      SELECT @cErrMsg = 'NSQL'+CONVERT(CHAR(5),@nErr)+': Error Insert into #RecipientTemp Table. (isp_TM_ShortPick_TaskAlert)'  
                       + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@nErr),'') + ' )'  
      GOTO Quit  
   END  

   IF NOT EXISTS (SELECT 1 FROM #RecipientTemp)
   BEGIN
      SELECT @nErr = 70002  
      SELECT @cErrMsg = 'NSQL'+CONVERT(CHAR(5),@nErr)+': No Recipient setup for email alert. (isp_TM_ShortPick_TaskAlert)'  
                       + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@nErr),'') + ' )'  
      GOTO Quit  
   END
   
   INSERT INTO #TASKALERT ( TaskDetailKey, UserId, OrderKey, SKU, SKUDesc, LOC,
   QtyShort, TransDate)   
   SELECT TD.TaskdetailKey, TD.UserKey, TD.OrderKey, SKU.SKU, sku.DESCR, FROMLOC, 
   MAX(TD.SystemQty - TD.Qty) AS QtyShorted, MAX(TD.EditDate) AS EditDate 
   FROM dbo.TaskDetail TD WITH (NOLOCK) 
   JOIN SKU AS SKU WITH (NOLOCK) ON SKU.Storerkey = TD.Storerkey AND SKU.Sku = TD.Sku 
   JOIN ALERT AS a WITH (NOLOCK) ON A.TaskDetailKey = TD.TaskDetailKey 
   WHERE TD.TaskType = 'FPK'
     AND A.Status = '0'
     AND TD.StorerKey = CASE WHEN ISNULL(@cStorerKey, '') = '' THEN TD.StorerKey ELSE @cStorerKey END 
     AND (TD.SystemQty - TD.Qty) >0 
     AND TD.ReasonKey = @cReasonKey 
   GROUP BY TD.TaskdetailKey, TD.UserKey, TD.OrderKey, SKU.SKU, sku.DESCR, FROMLOC

   IF @b_debug = 1
   BEGIN
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
             '<tr bgcolor=silver><th>Task Key</th><th>Operator</th><th>Order No</th>' + 
             '<th>SKU</th><th>Description</th><th>Location</th><th>Qty Short</th>' +
             '<th>Trans Date</th></tr>'+ master.dbo.fnc_GetCharASCII(13) +  
             CAST ( ( SELECT td = ISNULL(CAST(TaskdetailKey AS NVARCHAR(10)),''), '',  
                             td = ISNULL(CAST(UserId AS NVARCHAR(15)),''), '',    
                             td = ISNULL(CAST(OrderKey AS NVARCHAR(10)),''), '',   
                             td = ISNULL(CAST(SKU AS NVARCHAR(20)),''), '',   
                             td = ISNULL(CAST(SKUDesc AS NVARCHAR(20)),''), '',   
                             td = ISNULL(CAST(LOC AS NVARCHAR(10)),''), '',   
                             td = ISNULL(CAST(QtyShort AS NVARCHAR(18)),''), '',   
                             td = ISNULL(CAST(TransDate AS NVARCHAR(12)),''), '' 
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

      SET @nErr = @@ERROR  
      IF @nErr <> 0  
      BEGIN  
         SELECT @nErr = 70003  
         SELECT @cErrMsg = 'NSQL'+CONVERT(CHAR(5),@nErr)+': Error executing sp_send_dbmail. (isp_TM_ShortPick_TaskAlert)'  
                          + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@nErr),'') + ' )'  
         GOTO Quit  
      END  

      DELETE FROM #RecipientTemp  
      WHERE Recipient = @n_Recipient  
        
      SET @nErr = @@ERROR  
      IF @nErr <> 0  
      BEGIN  
         SELECT @nErr = 70004  
         SELECT @cErrMsg = 'NSQL'+CONVERT(CHAR(5),@nErr)+': Error delete from #RecipientTemp Table. (isp_TM_ShortPick_TaskAlert)'  
                          + ' ( SQLSvr MESSAGE=' + ISNULL(RTRIM(@nErr),'') + ' )'  
         GOTO Quit  
      END  
      
      UPDATE ALERT 
      SET [Status] = '2'
      FROM ALERT 
      JOIN TaskDetail AS td WITH (NOLOCK) ON TD.TaskDetailKey = ALERT.TaskDetailKey 
      WHERE ALERT.[Status]='0'
      
   END -- WHILE EXISTS (SELECT 1 FROM #RecipientTemp WITH (NOLOCK))  
  
Quit:    
   IF @nErr <> 0  
      EXECUTE nsp_logerror @nErr, @cErrMsg, 'isp_TM_ShortPick_TaskAlert'   
  
   IF OBJECT_ID('tempdb..#TASKALERT','u') IS NOT NULL  
      DROP TABLE #TASKALERT;  
  
   IF OBJECT_ID('tempdb..#RecipientTemp','u') IS NOT NULL  
      DROP TABLE #RecipientTemp  
  
END -- Procedure  

GO