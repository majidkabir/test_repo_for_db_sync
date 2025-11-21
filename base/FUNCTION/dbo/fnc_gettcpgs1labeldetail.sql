SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE FUNCTION [dbo].[fnc_GetTCPGS1LabelDetail] (@nSerialNo INT)      
RETURNS @tGS1LabelDetail TABLE       
(      
    SerialNo         INT NOT NULL,      
    MessageNum       NVARCHAR(8)  NOT NULL,      
    MessageName      NVARCHAR(15) NOT NULL,  
    StorerKey		 NVARCHAR(15) NOT NULL,
    Facility		 NVARCHAR(5)  NOT NULL,
    DropID			 NVARCHAR(20) NOT NULL,
    LabelNo			 NVARCHAR(20) NOT NULL,
    BatchNo			 NVARCHAR(50) NOT NULL,
    [STATUS]         NVARCHAR(1)  NOT NULL            
)      
AS      
BEGIN    
   DECLARE @t_GS1LabelRecord TABLE (SeqNo INT, LineText NVARCHAR(512))      
    
   DECLARE @c_DataString NVARCHAR(4000)    
   DECLARE @n_Position   INT      
         , @c_RecordLine NVARCHAR(512)       
         , @c_LineText   NVARCHAR(512)      
         , @n_SeqNo      INT      
   
	DECLARE  @cMessageName NVARCHAR(15)
			 , @cStorerKey	 NVARCHAR(15)
			 , @cFacility	 NVARCHAR(5)
			 , @cDropID		 NVARCHAR(20)
			 , @cLabelNo	 NVARCHAR(20)
			 , @cBatchNo	 NVARCHAR(50)

	-- SELECT ALL DATA
	IF @nSerialNo = 0
	BEGIN
		DECLARE CUR_OUTLOG CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
		SELECT [Data], SerialNo, BatchNo
		FROM   dbo.TCPSocket_OUTLog WITH (NOLOCK)    
		WHERE (Data Like '%GS1LABEL%')   
	END
	ELSE
	BEGIN
		DECLARE CUR_OUTLOG CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
		SELECT [Data], SerialNo, BatchNo
		FROM   dbo.TCPSocket_OUTLog WITH (NOLOCK)    
		WHERE  SerialNo    = @nSerialNo    
		AND    MessageType = 'SEND'
		AND   (Data Like '%GS1LABEL%')   
	END  

    OPEN CUR_OUTLOG    
    
   FETCH NEXT FROM CUR_OUTLOG INTO @c_DataString, @nSerialNo, @cBatchNo
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
		SET @n_SeqNo = 1   
	       
		--SET @c_DataString = @c_DataString + master.dbo.fnc_GetCharASCII(13)     
	                   
		SET @n_Position = CHARINDEX('|', @c_DataString)      
		WHILE @n_Position <> 0      
		BEGIN      
			 SET @c_RecordLine = LEFT(@c_DataString, @n_Position - 1)      
	      
			 INSERT INTO @t_GS1LabelRecord    
			 VALUES (@n_SeqNo, CAST(@c_RecordLine AS NVARCHAR(512)))    
	      
			 SET @c_DataString = STUFF(@c_DataString, 1, @n_Position  ,'')      
			 SET @n_Position = CHARINDEX('|', @c_DataString) 
			 SET @n_SeqNo = @n_SeqNo + 1     
		END    

		INSERT INTO @t_GS1LabelRecord VALUES (@n_SeqNo, @cBatchNo)    
	       
		DECLARE CUR_LINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
		SELECT SeqNo, LineText      
		FROM @t_GS1LabelRecord      
		ORDER BY SeqNo      
	      
		OPEN CUR_LINE      
	      
		FETCH NEXT FROM CUR_LINE INTO @n_SeqNo, @c_LineText      
		WHILE @@FETCH_STATUS <> -1      
		BEGIN      
			IF @n_SeqNo = 1
			BEGIN
				SET @cMessageName = ISNULL(RTRIM(@c_LineText),'')
			END
			ELSE IF @n_SeqNo = 3
			BEGIN
				SET @cStorerKey = ISNULL(RTRIM(@c_LineText),'')
			END
			ELSE IF @n_SeqNo = 4
			BEGIN
				SET @cFacility = ISNULL(RTRIM(@c_LineText),'')
			END
			ELSE IF @n_SeqNo = 5
			BEGIN
				SET @cDropID = ISNULL(RTRIM(@c_LineText),'')
			END
			ELSE IF @n_SeqNo = 6
			BEGIN
				SET @cLabelNo = ISNULL(RTRIM(@c_LineText),'')
			END
			ELSE IF @n_SeqNo = 7
			BEGIN
				SET @cBatchNo = ISNULL(RTRIM(@c_LineText),'')
			END
			FETCH NEXT FROM CUR_LINE INTO @n_SeqNo, @c_LineText     
		END -- WHILE CUR_LINE

		INSERT INTO @tGS1LabelDetail (SerialNo ,MessageNum ,MessageName, StorerKey,Facility    
					  ,DropID, LabelNo, BatchNo, [Status])     
		SELECT t.SerialNo, t.MessageNum, @cMessageName, @cStorerKey, @cFacility,       
				@cDropID, @cLabelNo, @cBatchNo, t.[Status]      
	   FROM TCPSocket_OUTLog t WITH (NOLOCK)      
	   WHERE t.SerialNo = @nSerialNo   

		DEALLOCATE CUR_LINE  
		DELETE FROM @t_GS1LabelRecord 

		FETCH NEXT FROM CUR_OUTLOG INTO @c_DataString, @nSerialNo, @cBatchNo
	END  -- WHILE CUR_OUTLOG
   RETURN      
END;

GO