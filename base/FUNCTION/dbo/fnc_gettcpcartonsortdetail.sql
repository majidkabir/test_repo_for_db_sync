SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: fnc_GetTCPCartonSortDetail                         */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 05-04-2012   Shong         Initial                                   */
/************************************************************************/ 
CREATE FUNCTION [dbo].[fnc_GetTCPCartonSortDetail] (@nSerialNo INT)        
RETURNS @tCartonSortDetail TABLE         
(        
    SerialNo         INT NOT NULL,        
    MessageNum       VARCHAR(8)  NOT NULL, 
    NoOfTry          INT NOT NULL,       
    STATUS           VARCHAR(1)  NOT NULL,
    InMsgType        VARCHAR(15) NOT NULL,
    LaneNumber       VARCHAR(10) NOT NULL,
    SequenceNumber   VARCHAR(10) NOT NULL,
    GS1Label         VARCHAR(20) NOT NULL,      
    Weight           VARCHAR(8)  NOT NULL,
    ErrMsg           VARCHAR(400)   NOT NULL,
    AddDate          DATETIME    NOT NULL,
    AddWho           VARCHAR(215)   NOT NULL,
    EditDate         DATETIME    NOT NULL
)        
AS        
BEGIN      
   DECLARE @t_CartonSortRecord TABLE (SeqNo INT, LineText VARCHAR(512))        
      
   DECLARE @c_DataString NVARCHAR(4000)      
   DECLARE @n_Position   INT        
         , @c_RecordLine VARCHAR(512)         
         , @c_LineText   VARCHAR(512)        
         , @n_SeqNo      INT        
     
 -- SELECT ALL DATA  
 IF @nSerialNo = 0  
 BEGIN  
  DECLARE CUR_INLOG CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
  SELECT [Data], SerialNo  
  FROM   dbo.TCPSocket_INLog WITH (NOLOCK)      
  WHERE (Data Like '%CARTONSORT%')     
 END  
 ELSE  
 BEGIN  
  DECLARE CUR_INLOG CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
  SELECT [Data], SerialNo  
  FROM   dbo.TCPSocket_INLog WITH (NOLOCK)      
  WHERE  SerialNo    = @nSerialNo      
 END    
  
    OPEN CUR_INLOG      
      
   FETCH NEXT FROM CUR_INLOG INTO @c_DataString, @nSerialNo  
   WHILE @@FETCH_STATUS <> -1      
   BEGIN      
  SET @n_SeqNo = 1     
          
  SET @c_DataString = @c_DataString + CHAR(13)       
                      
  SET @n_Position = CHARINDEX(CHAR(13), @c_DataString)        
  WHILE @n_Position <> 0        
  BEGIN        
    SET @c_RecordLine = LEFT(@c_DataString, @n_Position - 1)        
         
    INSERT INTO @t_CartonSortRecord      
    VALUES (@n_SeqNo, CAST(@c_RecordLine AS VARCHAR(512)))      
         
    SET @c_DataString = STUFF(@c_DataString, 1, @n_Position  ,'')        
    SET @n_Position = CHARINDEX(CHAR(13), @c_DataString)   
    SET @n_SeqNo = @n_SeqNo + 1       
  END        
          
  DECLARE CUR_LINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
  SELECT SeqNo, LineText        
  FROM @t_CartonSortRecord        
  ORDER BY SeqNo        
         
  OPEN CUR_LINE        
         
  FETCH NEXT FROM CUR_LINE INTO @n_SeqNo, @c_LineText        
  WHILE @@FETCH_STATUS <> -1        
  BEGIN        
   IF @n_SeqNo >= 1        
   BEGIN        
    INSERT INTO @tCartonSortDetail (SerialNo,
      MessageNum,
      NoOfTry,
      Status,
      InMsgType,
      LaneNumber,
      SequenceNumber,
      GS1Label,
      Weight,
      ErrMsg,
      AddDate,
      AddWho,
      EditDate)       
    SELECT ti.SerialNo,
      ti.MessageNum,
      ti.NoOfTry,
      ti.Status,
      RTRIM(SubString(Data,   1,  15)) AS InMsgType,
      ISNULL(RTRIM(SubString(Data,  24,  10)),'') AS LaneNumber,
      ISNULL(RTRIM(SubString(Data,  34,  10)),'') AS SequenceNumber,
      ISNULL(RTRIM(SubString(Data,  44,  20)),'') AS GS1Label,
      ISNULL(RTRIM(SubString(Data,  64,   8)),'') AS Weight,
      ErrMsg,
      AddDate,
      AddWho,
      EditDate
     FROM TCPSocket_INLog ti WITH (NOLOCK)        
     WHERE ti.SerialNo = @nSerialNo         
   END               
   FETCH NEXT FROM CUR_LINE INTO @n_SeqNo, @c_LineText       
  END -- WHILE CUR_LINE  
  
  DEALLOCATE CUR_LINE    
  DELETE FROM @t_CartonSortRecord   
  
  FETCH NEXT FROM CUR_INLOG INTO @c_DataString, @nSerialNo  
 END  -- WHILE CUR_INLOG  
   RETURN        
END;  

GO