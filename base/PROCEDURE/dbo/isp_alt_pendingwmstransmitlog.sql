SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/****************************************************************************/
/* Stored Procedure: isp_alt_PendingWMSTransmitlog                          */
/* Creation Date: 2-Apr-2010                                                */
/* Copyright: IDS                                                           */
/* Written by: KHLim                                                        */
/*                                                                          */
/* Purpose: Check Pending Transmitlo, alert in an email                     */
/*                                                                          */
/*                                                                          */
/* Called BY: ALT - SQL Job Email Alert                                     */
/*                                                                          */
/* PVCS Version: 1.2                                                        */
/*                                                                          */
/* Version: 5.4                                                             */
/*                                                                          */
/* Data ModIFications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date         Author  Ver Purposes                                        */
/* 9 Oct 2013   TLTING  1.2 Add (Nolock) to reduce table blocking           */
/*                                                                          */
/****************************************************************************/

CREATE PROC [dbo].[isp_alt_PendingWMSTransmitlog] 
  @cRecipientList NVARCHAR(max), 
  @cTable        NVARCHAR(60) = '',
  @cCheckPeriod int  
AS
BEGIN 
   SET NOCOUNT ON
   SET ANSI_NULLS OFF 
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF 

   DECLARE @tableHTML  NVARCHAR(MAX) ;
   DECLARE @emailSubject NVARCHAR(MAX) ;
   DECLARE @Mailitem_id  int 

   DECLARE @cStartDate nvarchar(20), 
           @cEndDate   nvarchar(20)

   SET @cStartDate = Convert(nvarchar(20), GetDate(), 112)
   SET @cEndDate   = Convert(nvarchar(20), GetDate(), 112) + ' 23:59:59'

   SET @emailSubject = 'WMS Transmitlog Pending ' + @cTable + ' Table (LIVE) ' +  @@servername +
     ' Time' +
      Ltrim(substring( convert(varchar(22), Getdate(), 120) , 12, len(convert(varchar(22), Getdate(), 120))))

   DECLARE @t_Result Table (
      td  NVARCHAR(max)
      )
      
   DECLARE @c_SQL NVARCHAR(max)

   SET  @c_SQL = N' Select ''Transmitlogkey ['' + RTRIM(TransmitlogKey) + 
                  ''] TableName ['' + RTRIM(TableName) + 
                  ''] Transmitflag = ['' + RTRIM(Transmitflag) + ''] pending for ['' +
                  convert(varchar(10), DATEDIFF ( mi  , editdate , getdate() )) + ''] Mins. ''
                  FROM  ' + @cTable + master.dbo.fnc_GetCharASCII(13) + ' with (NOLOCK) ' +
                  'Where transmitflag = ''1''
                  and DATEDIFF ( mi  , editdate , getdate() ) >= ' + CONVERT(varchar(20), @cCheckPeriod) +
                  ' ORDER BY TransmitlogKey '

   INSERT INTO @t_Result
   EXEC (@c_SQL)

   IF EXISTS(SELECT 1 FROM @t_Result)
   BEGIN
      SET @tableHTML = 
          N'<H4>Please check on the following pending WMS '+ @cTable +' Table </H4>' + 
          N'<table border="0">' +
             N'<tr><th> </th></tr>' +    
             CAST ( ( Select td =  td
                     FROM  @t_Result

            FOR XML PATH('tr'), TYPE 
          ) AS NVARCHAR(MAX) ) +
          N'</table>'  ;

      EXEC msdb.dbo.sp_send_dbmail 
          @recipients=@cRecipientList,
          @subject = @emailSubject ,
          @body = @tableHTML,
          @body_format = 'HTML',
          @mailitem_id = @Mailitem_id OUTPUT;

      SELECT @Mailitem_id 
   END -- Records Exists

END -- Procedure


GO