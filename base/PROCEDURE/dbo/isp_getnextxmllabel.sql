SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_GetNextXMLLabel                                */  
/* Creation Date: 24-Mar-2011                                           */  
/* Copyright: IDS                                                       */  
/* Written by: SHONG                                                    */  
/*                                                                      */  
/* Purpose: Getting XML Message from XML_Message Table                  */  
/*                                                                      */  
/*                                                                      */  
/* Called By: SQL Jobs                                                  */  
/*                                                                      */  
/* Parameters:                                                          */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 1.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver. Purposes                                  */  
/*                                                                      */  
/************************************************************************/  
CREATE PROC [dbo].[isp_GetNextXMLLabel] (     
   @cBatchNo    NVARCHAR(20),    
   @cXMLLabel   NVARCHAR(MAX) OUTPUT,    
   @cServerIP   NVARCHAR(20)   OUTPUT,    
   @nServerPort INT OUTPUT )    
AS    
BEGIN    
   DECLARE @nRowID BigINT    
  
   -- TraceInfo    
   DECLARE    @c_starttime    datetime,    
              @c_endtime      datetime,    
              @c_step1        datetime,    
              @c_step2        datetime,    
              @c_step3        datetime,    
              @c_step4        datetime,    
              @c_step5        datetime    
  
   SET @c_starttime = getdate()    
   SET @c_step1 = GETDATE()  
       
   SELECT TOP 1     
      @nRowID = RowID,    
      @cXMLLabel = xm.XML_Message,     
      @cServerIP = xm.Server_IP,     
      @nServerPort = Xm.Server_Port     
   FROM XML_Message xm WITH (NOLOCK)    
   WHERE STATUS = '0'    
   ORDER BY RowID     
   IF @@ROWCOUNT > 0    
   BEGIN    
      SET @c_step1 = GETDATE() - @c_step1  
  
      SET @c_step2 = GETDATE()  
  
      UPDATE XML_Message WITH (ROWLOCK)   
      SET STATUS = '9', EditDate=GETDATE()    
      WHERE RowID = @nRowID     
      AND STATUS = '0'       
  
      SET @c_step2 = GETDATE() - @c_step2      
  
   END    
   ELSE    
   BEGIN    
      SET @cXMLLabel = ''    
      SET @cServerIP = ''    
      SET @nServerPort = 0           
   END    
   SET @c_endtime = GETDATE()   
   
--   INSERT INTO TraceInfo(TraceName, TimeIn, [TimeOut], [TotalTime],   
--                         Step1, Step2, Step3, Step4, Step5, Col1) VALUES    
--    ('isp_GetNextXMLLabel'      
--    ,@c_starttime, @c_endtime    
--    ,CONVERT(CHAR(12),@c_endtime-@c_starttime ,114)    
--    ,CONVERT(CHAR(12),@c_step1,114)     
--    ,CONVERT(CHAR(12),@c_step2,114)     
--    ,''     
--    ,''     
--    ,''  
--    ,@cBatchNo)    
       
END -- procedure

GO