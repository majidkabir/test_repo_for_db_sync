SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_TCPProcess                                     */
/* Creation Date: 24-Mar-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: SHONG                                                    */
/*                                                                      */
/* Purpose: Writting to Bartender TCP Port for Direct Printing          */
/*                                                                      */
/*                                                                      */
/* Called By: 			                                                   */
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
/* 25-Jul-2011  SHONG    1.1  Bug Fixed                                 */
/************************************************************************/
CREATE PROC [dbo].[isp_TCPProcess]     
   @cBatchNo  NVARCHAR(20)    
AS    
BEGIN    
   SET NOCOUNT ON    
       
   DECLARE @Server   nvarchar(50)    
   DECLARE @DBName   nvarchar(50)  
    
   DECLARE @nStartTranCount int  
       
   DECLARE @cFormat      NVARCHAR(128),     
           @cPrinter     NVARCHAR(128),     
           @cPrevFormat  NVARCHAR(128),     
           @cPrevPrinter NVARCHAR(128),               
           @nRowID       BIGINT,    
           @cXMLMessage  NVARCHAR(MAX),     
           @nPos         INT,    
           @nStartPos    INT,     
           @nPrevRowID   BIGINT,     
           @b_Debug      INT    

   -- TraceInfo  
   DECLARE    @c_starttime    datetime,  
              @c_endtime      datetime,  
              @c_step1        datetime,  
              @c_step2        datetime,  
              @c_step3        datetime,  
              @c_step4        datetime,  
              @c_step5        datetime  
    
   SET @b_Debug = 0

   SET @c_starttime = getdate()  
   SET @c_step1 = GETDATE()
    
   SET @cPrevPrinter = ''    
   SET @cPrevFormat  = ''   
   SET @nStartTranCount = @@TRANCOUNT    
       
   WHILE @@TRANCOUNT > 0   
      COMMIT TRAN    

   BEGIN TRAN 

   DECLARE CUR_XML CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT xm.RowID, xm.XML_Message     
   FROM XML_Message xm (NOLOCK)     
   WHERE xm.BatchNo = @cBatchNo    
   AND ( xm.XML_Message LIKE '<?xml version%>' OR    
         xm.XML_Message LIKE '</labels%>' OR     
         xm.XML_Message LIKE'<labels%' )    
   AND Status = '0'
   ORDER BY xm.RowID    
       
   OPEN CUR_XML    
   
   SET @c_step1 = GETDATE() - @c_step1
   SET @c_step2 = GETDATE()   
   FETCH NEXT FROM CUR_XML INTO @nRowID, @cXMLMessage     
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      -- Get the Start Position for _Format    
      SET @nPos = CHARINDEX('_FORMAT', @cXMLMessage)    
      IF @nPos > 0     
      BEGIN    
         -- Get Start Position for " after Format    
         SET @nPos = CHARINDEX('"', @cXMLMessage, @nPos)    
    
         SET @nStartPos = @nPos + 1    
             
         -- Get Closing "    
         SET @nPos = CHARINDEX('"', @cXMLMessage, @nStartPos)     
          
         SET @cFormat = SUBSTRING(@cXMLMessage, @nStartPos, @nPos - @nStartPos)    
             
      END    
      SET @nPos = CHARINDEX('_PRINTERNAME', @cXMLMessage)    
      IF @nPos > 0     
      BEGIN    
         -- Get Start Position for " after Format    
         SET @nPos = CHARINDEX('"', @cXMLMessage, @nPos)    
    
         SET @nStartPos = @nPos + 1    
             
         -- Get Closing "    
         SET @nPos = CHARINDEX('"', @cXMLMessage, @nStartPos)     
          
         SET @cPrinter = SUBSTRING(@cXMLMessage, @nStartPos, @nPos - @nStartPos)    
      END        
      IF @b_Debug = 1    
      BEGIN    
         SELECT @cPrevPrinter '@cPrevPrinter', @cPrinter '@cPrinter',     
                 @cPrevFormat '@cPrevFormat', @cFormat '@cFormat'             
      END    
          
      IF @cPrevPrinter = @cPrinter AND @cPrevFormat = @cFormat    
      BEGIN    
         UPDATE XML_Message     
            SET STATUS = 'S'    
         WHERE RowID = @nRowID     
             
         SET @cPrevFormat = @cFormat    
         SET @cPrevPrinter = @cPrinter    
      END    
      ELSE    
      BEGIN    
        SELECT TOP 1 @nPrevRowID = RowID    
        FROM XML_Message xm (NOLOCK)    
        WHERE xm.BatchNo = @cBatchNo     
        AND xm.RowID < @nRowID           
        AND xm.XML_Message LIKE '</labels%>'    
        ORDER BY xm.RowID DESC    
            
        UPDATE XML_Message    
         SET [Status] = '0'    
        WHERE RowID BETWEEN @nPrevRowID AND @nPrevRowID + 1      
        -- AND XML_Message LIKE '</labels%>'     
        AND [Status] ='S'    
    
         SET @cPrevFormat = @cFormat    
         SET @cPrevPrinter = @cPrinter            
      END    
             
      IF @cPrevPrinter = '' AND @cPrinter IS NOT NULL    
         SET @cPrevPrinter = @cPrinter    
      IF @cPrevFormat = '' AND @cFormat IS NOT NULL    
         SET @cPrevFormat = @cFormat    
           
      FETCH NEXT FROM CUR_XML INTO @nRowID, @cXMLMessage    
   END    
   CLOSE CUR_XML    
   DEALLOCATE CUR_XML    

   IF @cXMLMessage = '</labels>'    
   BEGIN    
     UPDATE XML_Message    
      SET [Status] = '0'    
     WHERE RowID = @nRowID         
     AND XML_Message LIKE '</labels%>'           
   END    

   SET @c_step2 = GETDATE() - @c_step2
       
   WHILE @@TRANCOUNT > 0   
         COMMIT TRAN    

   SET @c_step3 = GETDATE()

   UPDATE XML_Message
      SET [Status] = '1'       
   WHERE BatchNo = @cBatchNo  
   AND   [Status] = '0'

   -- TODO: Set parameter values here.    
   SET @Server = @@ServerName    
   SET @DBName = db_name()    
    
   EXECUTE [master].[dbo].[isp_TCPWrite]     
      @cDBServer    =  @Server                
     ,@cDBName      =  @DBName             
     ,@cBatch       =  @cBatchNo  

   UPDATE XML_Message WITH (ROWLOCK)
      SET [Status] = '9'       
   WHERE BatchNo = @cBatchNo  
   AND   [Status] = '1'
   
   SET @c_step3 = GETDATE() - @c_step3
   SET @c_endtime = GETDATE() 
 
--   INSERT INTO TraceInfo(TraceName, TimeIn, [TimeOut], [TotalTime], 
--                         Step1, Step2, Step3, Step4, Step5, Col1) VALUES  
--    ('isp_TCPProcess'    
--    ,@c_starttime, @c_endtime  
--    ,CONVERT(CHAR(12),@c_endtime-@c_starttime ,114)  
--    ,CONVERT(CHAR(12),@c_step1,114)   
--    ,CONVERT(CHAR(12),@c_step2,114)   
--    ,CONVERT(CHAR(12),@c_step3,114)   
--    ,''   
--    ,''
--    ,@cBatchNo)  

   WHILE @@TRANCOUNT < @nStartTranCount   
      BEGIN TRAN 
   
END -- Procedure 

GO