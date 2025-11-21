SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE FUNCTION [dbo].[fnc_GetTCPCartonCloseDetail]
(
	@nSerialNo INT
)
RETURNS @tCartonCloseDetail TABLE 
        (
            SerialNo INT NOT NULL
           ,MessageNum NVARCHAR(8) NOT NULL
           ,MessageName NVARCHAR(15) NOT NULL
           ,[LineNo] NVARCHAR(5) NOT NULL
           ,OrderKey NVARCHAR(10) NOT NULL
           ,OrderLineNumber NVARCHAR(5) NOT NULL
           ,ConsoOrderKey NVARCHAR(30) NOT NULL
           ,SKU NVARCHAR(20) NOT NULL
           ,QtyExpected INT NOT NULL
           ,Qty INT NOT NULL
           ,FromTote NVARCHAR(20) NOT NULL
           ,[STATUS] NVARCHAR(1) NOT NULL
           ,AddDate DATETIME NOT NULL
        )
AS
BEGIN
	DECLARE @t_CartonCloseRecord TABLE (SeqNo INT ,LineText NVARCHAR(512))      
	
	DECLARE @c_DataString NVARCHAR(MAX)    
	DECLARE @n_Position INT
	       ,@c_RecordLine NVARCHAR(512)
	       ,@c_LineText NVARCHAR(512)
	       ,@n_SeqNo INT 
	       ,@d_AddDate DATETIME
	
	-- SELECT ALL DATA  
	IF @nSerialNo=0
	BEGIN
	    DECLARE CUR_INLOG CURSOR LOCAL FAST_FORWARD READ_ONLY 
	    FOR
	        SELECT [Data]
	              ,SerialNo
	              ,AddDate
	        FROM   dbo.TCPSocket_INLog WITH (NOLOCK)
	        WHERE  (DATA LIKE 'CARTONCLOSE%')
	        AND    MessageType = 'RECEIVE'
	END
	ELSE
	BEGIN
	    DECLARE CUR_INLOG CURSOR LOCAL FAST_FORWARD READ_ONLY 
	    FOR
	        SELECT [Data]
	              ,SerialNo 
	              ,AddDate
	        FROM   dbo.TCPSocket_INLog WITH (NOLOCK)
	        WHERE  SerialNo = @nSerialNo
	        AND    MessageType = 'RECEIVE'
	END 
	
	OPEN CUR_INLOG 
	
	FETCH NEXT FROM CUR_INLOG INTO @c_DataString, @nSerialNo,@d_AddDate 
	WHILE @@FETCH_STATUS<>-1
	BEGIN
	    SET @n_SeqNo = 1   
	    
	    SET @c_DataString = @c_DataString + master.dbo.fnc_GetCharASCII(13)     
	    
	    SET @n_Position = CHARINDEX(master.dbo.fnc_GetCharASCII(13) ,@c_DataString)      
	    WHILE @n_Position<>0
	    BEGIN
	        SET @c_RecordLine = LEFT(@c_DataString ,@n_Position- 1)      
	        
	        INSERT INTO @t_CartonCloseRecord
	        VALUES
	          (
	            @n_SeqNo
	           ,CAST(@c_RecordLine AS NVARCHAR(512))
	          )      
	        
	        SET @c_DataString = STUFF(@c_DataString ,1 ,@n_Position ,'')      
	        SET @n_Position = CHARINDEX(master.dbo.fnc_GetCharASCII(13) ,@c_DataString)      
	        SET @n_SeqNo = @n_SeqNo+1
	    END      
	    
	    DECLARE CUR_LINE CURSOR LOCAL FAST_FORWARD READ_ONLY 
	    FOR
	        SELECT SeqNo
	              ,LineText
	        FROM   @t_CartonCloseRecord
	        ORDER BY SeqNo 
	    
	    OPEN CUR_LINE 
	    
	    FETCH NEXT FROM CUR_LINE INTO @n_SeqNo, @c_LineText      
	    WHILE @@FETCH_STATUS<>-1
	    BEGIN
	        IF @n_SeqNo>1
	        BEGIN
	            INSERT INTO @tCartonCloseDetail 
	              (
	                SerialNo
	               ,MessageNum
	               ,MessageName
	               ,[LineNo]
	               ,OrderKey
	               ,OrderLineNumber
	               ,ConsoOrderKey
	               ,SKU
	               ,QtyExpected
	               ,Qty
	               ,FromTote
	               ,[Status]
	               ,AddDate
	              )
	            SELECT ti.SerialNo
	                  ,ti.MessageNum
	                  ,ISNULL(RTRIM(SUBSTRING(ti.[Data] ,1 ,15)) ,'') AS 
	                   MessageName
	                  ,ISNULL(RTRIM(SUBSTRING(@c_LineText ,1 ,5)) ,'') AS 
	                   [LineNo]
	                  ,ISNULL(RTRIM(SUBSTRING(@c_LineText ,6 ,10)) ,'') AS 
	                   OrderKey
	                  ,ISNULL(RTRIM(SUBSTRING(@c_LineText ,16 ,5)) ,'') AS 
	                   OrderLineNumber
	                  ,ISNULL(RTRIM(SUBSTRING(@c_LineText ,21 ,30)) ,'') AS 
	                   ConsoOrderKey
	                  ,ISNULL(RTRIM(SUBSTRING(@c_LineText ,51 ,20)) ,'') AS SKU
	                  ,CAST(ISNULL(RTRIM(SUBSTRING(@c_LineText ,101 ,10)) ,'0')AS INT) AS 
	                   QtyExpected
	                  ,CAST(ISNULL(RTRIM(SUBSTRING(@c_LineText ,71 ,10)) ,'0')AS INT) AS 
	                   Qty
	                  ,ISNULL(RTRIM(SUBSTRING(@c_LineText ,81 ,20)) ,'') AS 
	                   FromTote
	                  ,ti.[Status]
	                  ,ti.AddDate 
	            FROM   TCPSocket_INLog ti WITH (NOLOCK)
	            WHERE  ti.SerialNo = @nSerialNo
	        END
	        
	        FETCH NEXT FROM CUR_LINE INTO @n_SeqNo, @c_LineText
	    END -- WHILE CUR_LINE  
	    
	    DEALLOCATE CUR_LINE    
	    DELETE 
	    FROM   @t_CartonCloseRecord 
	    
	    FETCH NEXT FROM CUR_INLOG INTO @c_DataString, @nSerialNo, @d_AddDate 
	END -- WHILE CUR_INLOG  
	RETURN
END;  

GO