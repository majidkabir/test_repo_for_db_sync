SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/      
/* Stored Procedure: ispCartonTrack                                     */      
/* Creation Date: 24-May-2010                                           */      
/* Copyright: IDS                                                       */      
/* Written by: LIM KAH HWEE                                             */      
/*                                                                      */      
/* Purpose: Cartan Track for CN                                         */      
/*                                                                      */      
/*                                                                      */      
/* Called By: ALT - CartonTrack                                         */      
/*                                                                      */      
/* PVCS Version: 1.0                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author Ver Purposes                                     */   
/*                                                                      */      
/************************************************************************/      
      
CREATE PROC [dbo].[ispCartonTrack]      
(
  @recipientList NVARCHAR(max),
  @ccRecipientList NVARCHAR(max)
)
AS      
BEGIN    
    
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_WARNINGS ON 
SET ANSI_NULLS ON
SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @textHTML       NVARCHAR(MAX),
           @bodyText       NVARCHAR(MAX), 
           @cSQL           NVARCHAR(MAX),
           @nFG            INT,
           @nFE            INT,
           @emailSubject   NVARCHAR(MAX), 
           @cDate          NVARCHAR(20)

   SET @cDate = Convert(VARCHAR(10), DateAdd(day, -2, getdate()), 103)   
   SET @emailSubject = 'Carton Track ' + @cDate

   SELECT @nFG = COUNT(1) FROM CartonTrack WITH (nolock)
   WHERE CarrierName = 'FedEx' AND KeyName = 'FedExGround' AND LabelNo = ''

   SELECT @nFE = COUNT(1) FROM CartonTrack WITH (nolock)
   WHERE CarrierName = 'FedEx' AND KeyName = 'FedExExpress' AND LabelNo = ''

IF @nFG < 10000 OR @nFG < 1000
BEGIN

   IF @nFG < 10000
   BEGIN
      SET @bodyText = 'Available tracking no (FedExGround) is less than 10000 = ' + CAST(@nFG AS NVARCHAR(10));
   END

   IF @nFG < 1000
   BEGIN
      SET @bodyText = @bodyText + 
              '<br><br>Available tracking no (FedExExpress) is less than 1000 = ' + CAST(@nFE AS NVARCHAR(10));
   END

   EXEC msdb.dbo.sp_send_dbmail 
    @recipients      = @recipientList,
    @copy_recipients = @ccRecipientList,
    @subject         = @emailSubject,
    @body            = @bodyText,
    @body_format     = 'HTML' ; 

END

set nocount off 
END -- procedure

GO