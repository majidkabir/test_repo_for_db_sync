SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE FUNCTION [dbo].[fnc_GetGS1Label] (@cLabelNo NVARCHAR(20))  
RETURNS @tGS1Label TABLE
(  LabelNo         NVARCHAR(20),
   DropID          NVARCHAR(20),
   MessageNum      NVARCHAR(10),
   SerialNo        INT,
   BatchNo         NVARCHAR(60),
   BTW_Format      NVARCHAR(50), 
   Acknowledge     NVARCHAR(10),
   AddDate         DATETIME
)   
AS
BEGIN

   DECLARE @cMessageNum   NVARCHAR(10), 
           @nSerialNo     INT,
           @cBatchNo      NVARCHAR(60),
           @cDropID       NVARCHAR(20),
           @cAcknowledge  NVARCHAR(10),
           @dAddDate      DATETIME

   SET @nSerialNo = 0
   SET @cMessageNum = ''

   SELECT TOP 1 
      @nSerialNo = ISNULL(to1.SerialNo,0)
     ,@cMessageNum = ISNULL(to1.MessageNum,'') 
     ,@cBatchNo    = ISNULL(to1.BatchNo,'') 
     ,@dAddDate    = to1.AddDate 
   FROM TCPSocket_OUTLog to1 WITH (NOLOCK)
   WHERE to1.MessageType = 'SEND'
   AND to1.LabelNo = @cLabelNo 
   ORDER BY to1.SerialNo DESC
   IF ISNULL(RTRIM(@cMessageNum),'') <> ''
   BEGIN 
   	SELECT TOP 1 
   	   @cDropID = DropID 
   	FROM PackDetail pd WITH (NOLOCK)
   	WHERE pd.LabelNo = @cLabelNo 
   END
   	
   IF ISNULL(RTRIM(@cMessageNum),'') = ''
   BEGIN
	   SELECT TOP 1 
         @nSerialNo   = ISNULL(to1.SerialNo,0)
        ,@cMessageNum = ISNULL(to1.MessageNum,'')
        ,@cBatchNo    = ISNULL(to1.BatchNo,'')       
        ,@cDropID     = dbo.fnc_GetDelimitedColumn(to1.[Data],'|', 5)
        ,@dAddDate    = to1.AddDate
      FROM TCPSocket_OUTLog to1 WITH (NOLOCK)
      WHERE to1.MessageType = 'SEND'
      AND dbo.fnc_GetDelimitedColumn(to1.[Data],'|', 6) = @cLabelNo 
      AND to1.[Data] LIKE 'GS1LABEL%'  
      ORDER BY to1.SerialNo DESC 
   END 

   IF ISNULL(RTRIM(@cMessageNum),'') = ''
   BEGIN
   	SET @cDropID = @cLabelNo
   	
	   SELECT TOP 1 
         @nSerialNo   = ISNULL(to1.SerialNo,0)
        ,@cMessageNum = ISNULL(to1.MessageNum,'')
        ,@cBatchNo    = ISNULL(to1.BatchNo,'')      
        ,@cLabelNo    = dbo.fnc_GetDelimitedColumn(to1.[Data],'|', 6)
        ,@dAddDate    = to1.AddDate
      FROM TCPSocket_OUTLog to1 WITH (NOLOCK)
      WHERE to1.MessageType = 'SEND'
      AND dbo.fnc_GetDelimitedColumn(to1.[Data],'|', 5) = @cDropID 
      AND to1.[Data] LIKE 'GS1LABEL%'  
      ORDER BY to1.SerialNo DESC 
   END 

   IF ISNULL(RTRIM(@cBatchNo),'') <> ''
   BEGIN
   	IF EXISTS(SELECT 1 FROM TCPSocket_OUTLog to1 WITH (NOLOCK)
   	          WHERE to1.MessageNum = @cMessageNum 
   	          AND   to1.MessageType = 'RECEIVE'
   	          AND   to1.[Data] LIKE 'ACK%')
   	BEGIN
   		SET @cAcknowledge = 'ACK'
   	END
   	ELSE
   	BEGIN
   		SET @cAcknowledge = 'NAK'
   	END
   		
   	INSERT INTO @tGS1Label(LabelNo, DropID, MessageNum, SerialNo, BatchNo, BTW_Format,Acknowledge, AddDate)
	   SELECT  @cLabelNo, 
	           @cDropID, 
	           @cMessageNum AS MessageNum,
	           @nSerialNo AS SerialNo,
	           @cBatchNo  AS BatchNo, 
	           SUBSTRING(XML_Message,
              CHARINDEX('AF="',XML_Message, 1) + 4,
              CHARINDEX('.btw',XML_Message, 1) - (CHARINDEX('AF="',XML_Message, 1))), 
              @cAcknowledge,
              @dAddDate 
	   FROM XML_Message xm WITH (NOLOCK)
	   WHERE xm.BatchNo = @cBatchNo 
	   AND LEFT(XML_Message, 5) = '%BTW%'  
	   ORDER BY xm.RowID
   END
--   ELSE
--   BEGIN
--   	INSERT INTO @tGS1Label(LabelNo, DropID, MessageNum, SerialNo, BatchNo, BTW_Format) 
--   	VALUES('','','',0,'','')
--   END
  
   RETURN
END

GO