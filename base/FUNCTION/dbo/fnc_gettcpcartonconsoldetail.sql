SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE FUNCTION [dbo].[fnc_GetTCPCartonConsolDetail] (@nSerialNo INT)      
RETURNS @tCartonConsolDetail TABLE       
(      
    SerialNo         INT NOT NULL,      
    MessageNum       NVARCHAR(8)  NOT NULL,      
    MessageName      NVARCHAR(15) NOT NULL,      
    [LineNo]		 NVARCHAR(5)  NOT NULL,   
	 LPN				 NVARCHAR(20) NOT NULL, 
    GS1Label         NVARCHAR(20) NOT NULL,    
    [STATUS]         NVARCHAR(1)  NOT NULL 
)      
AS      
BEGIN    
   DECLARE @t_CartonConsolRecord TABLE (SeqNo INT, LineText NVARCHAR(512))      
    
   DECLARE @c_DataString NVARCHAR(4000)    
   DECLARE @n_Position   INT      
         , @c_RecordLine NVARCHAR(512)       
         , @c_LineText   NVARCHAR(512)      
         , @n_SeqNo      INT      
   
	-- SELECT ALL DATA
	IF @nSerialNo = 0
	BEGIN
		DECLARE CUR_OUTLOG CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
		SELECT REPLACE([Data],'<CR>', master.dbo.fnc_GetCharASCII(13)), SerialNo
		FROM   dbo.TCPSocket_OUTLog WITH (NOLOCK)    
		WHERE (Data Like '%CARTONCONSOL%')   
	END
	ELSE
	BEGIN
		DECLARE CUR_OUTLOG CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
		SELECT REPLACE([Data],'<CR>', master.dbo.fnc_GetCharASCII(13)), SerialNo
		FROM   dbo.TCPSocket_OUTLog WITH (NOLOCK)    
		WHERE  SerialNo    = @nSerialNo    
		AND    MessageType = 'SEND'  
		AND	(Data Like '%CARTONCONSOL%')   
	END  

    OPEN CUR_OUTLOG    
    
   FETCH NEXT FROM CUR_OUTLOG INTO @c_DataString, @nSerialNo
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
		SET @n_SeqNo = 1   
	       
		SET @c_DataString = @c_DataString + master.dbo.fnc_GetCharASCII(13)     
	                   
		SET @n_Position = CHARINDEX(master.dbo.fnc_GetCharASCII(13), @c_DataString)      
		WHILE @n_Position <> 0      
		BEGIN      
			 SET @c_RecordLine = LEFT(@c_DataString, @n_Position - 1)      
	      
			 INSERT INTO @t_CartonConsolRecord    
			 VALUES (@n_SeqNo, CAST(@c_RecordLine AS NVARCHAR(512)))    
	      
			 SET @c_DataString = STUFF(@c_DataString, 1, @n_Position  ,'')      
			 SET @n_Position = CHARINDEX(master.dbo.fnc_GetCharASCII(13), @c_DataString) 
			 SET @n_SeqNo = @n_SeqNo + 1     
		END      
	       
		DECLARE CUR_LINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
		SELECT SeqNo, LineText      
		FROM @t_CartonConsolRecord      
		ORDER BY SeqNo      
	      
		OPEN CUR_LINE      
	      
		FETCH NEXT FROM CUR_LINE INTO @n_SeqNo, @c_LineText      
		WHILE @@FETCH_STATUS <> -1      
		BEGIN      
			IF @n_SeqNo > 1      
			BEGIN      
				INSERT INTO @tCartonConsolDetail (SerialNo ,MessageNum ,MessageName, [LineNo], LPN, GS1Label, [Status])     
				SELECT ti.SerialNo,       
						ti.MessageNum,       
						ISNULL(RTRIM(SUBSTRING(ti.[Data],    1, 15)),'') AS MessageName,      
						ISNULL(RTRIM(SubString(@c_LineText,  1,  5)),'') AS [LineNo],      
						ISNULL(RTRIM(SubString(@c_LineText,  6, 20)),'') AS LPN,            
						ISNULL(RTRIM(SubString(@c_LineText, 26, 20)),'') AS GS1Label,    
						ti.[Status]      
			  FROM TCPSocket_OUTLog ti WITH (NOLOCK)      
			  WHERE ti.SerialNo = @nSerialNo       
			END             
			FETCH NEXT FROM CUR_LINE INTO @n_SeqNo, @c_LineText     
		END -- WHILE CUR_LINE

		DEALLOCATE CUR_LINE  
		DELETE FROM @t_CartonConsolRecord 

		FETCH NEXT FROM CUR_OUTLOG INTO @c_DataString, @nSerialNo
	END  -- WHILE CUR_OUTLOG
   RETURN      
END;

GO