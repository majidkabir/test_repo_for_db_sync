SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE FUNCTION [dbo].[fnc_GetVC_prTaskLUTCoreValidFunctions_AckData]
(
   @nSerialNo INT
)
RETURNS @tCoreValidFunc TABLE 
        (
            FuncNo NVARCHAR(2) NULL
           , FuncName NVARCHAR(100) NULL
           , ErrorCode NVARCHAR(10)
           ,[ErrorMessage] NVARCHAR(255) NULL
        )
AS
    
BEGIN
   DECLARE @c_AckData NVARCHAR(4000)
          ,@c_FuncNo NVARCHAR(2)
          ,@c_FuncName NVARCHAR(100)
          ,@c_ErrorCode NVARCHAR(10)
          ,@c_ErrorMessage NVARCHAR(60)  
          ,@c_ColValue  NVARCHAR(215)    
   
   DECLARE @c_Delim CHAR(1), @n_SeqNo INT  
   DECLARE @t_MessageRecSplit TABLE (RowNo INT,Seqno INT ,ColValue NVARCHAR(215))   
   DECLARE @t_MessageRec TABLE (Seqno INT ,ColValue NVARCHAR(215))    
   DECLARE @n_MaxSeqNo INT,@n_GetMaxSeqNo INT, @n_RowNo INT,@n_MaxRowNo INT,@n_MaxRowNo1 INT,@n_StartSeqNo INT
   DECLARE @t_MsgRecSplitResult TABLE (RowNo INT,Seqno1 INT,ColValue1 NVARCHAR(215),Seqno2 INT,ColValue2 NVARCHAR(215)
         ,Seqno3 INT,ColValue3 NVARCHAR(215),Seqno4 INT ,ColValue4 NVARCHAR(215)) 

   SET @c_Delim = ','
   SET @n_MaxSeqNo = 4 
   SET @n_GetMaxSeqNo=0 
   SET @n_RowNo = 1
   SET @n_MaxRowNo = 1
   SET @n_StartSeqNo = 1
   SET @n_seqno = 0
   SET @c_Colvalue = ''
   
   SELECT @c_AckData = ti.ACKData
   FROM   TCPSocket_INLog ti WITH (NOLOCK)
   WHERE  ti.SerialNo = @nSerialNo    
   
  INSERT INTO @t_MessageRec
  SELECT *
  FROM   dbo.fnc_DelimSplit(@c_Delim ,@c_AckData)  

  
   SELECT @n_seqno=seqno,@c_colvalue = colvalue
   FROM @t_MessageRec
  
  

   SELECT @n_GetMaxSeqNo = MAX(seqNo)
   FROM   @t_MessageRec
 
   IF @n_GetMaxSeqNo > @n_MaxSeqNo
   BEGIN
   SET @n_MaxRowNo = ROUND(cast(@n_GetMaxSeqNo as decimal)/@n_MaxSeqNo,0)
    SET @n_MaxRowNo1 = ROUND(cast(@n_GetMaxSeqNo as decimal)/@n_MaxSeqNo,0)
   END
  
   WHILE @n_MaxRowNo <> 0 
   BEGIN

   SELECT @n_seqno = seqno,@c_Colvalue=colvalue
   FROM @t_MessageRec
   WHERE seqno=@n_MaxSeqNo

   IF @c_colvalue like '%<CR><LF>%' 
      BEGIN
      UPDATE  @t_MessageRec
      SET seqno = seqno + 1
      WHERE seqno >= @n_seqno    
      END
      ELSE 
      BEGIN
         UPDATE  @t_MessageRec
         SET seqno = seqno + 1
        WHERE seqno > @n_seqno   
      END 
   SET @n_MaxRowNo = @n_MaxRowNo -1
   SET @n_MaxSeqNo = @n_MaxSeqNo + 4
END

   SELECT @n_GetMaxSeqNo = MAX(seqNo)
   FROM   @t_MessageRec

    SET @n_Maxseqno = 4 

 WHILE @n_MaxRowNo1 <> 0
 
BEGIN
  INSERT INTO @t_MessageRecSplit
  SELECT @n_rowno,seqno,colvalue
  FROM @t_MessageRec
  WHERE seqno between @n_StartSeqNo AND @n_maxseqno
  
  SET @n_rowno = @n_rowno + 1
  SET @n_StartSeqNo = @n_StartSeqNo + 4
  SET @n_MaxRowNo1 = @n_MaxRowNo1 - 1
  SET @n_Maxseqno = @n_Maxseqno + 4
  
 
 END
 
 
  DECLARE CUR_Row CURSOR LOCAL FAST_FORWARD READ_ONLY 
  FOR

   SELECT DISTINCT RowNo
       FROM   @t_MessageRecsplit
       WHERE RowNo > 1
       ORDER BY RowNo

OPEN CUR_Row
SET @n_Maxseqno = 4

  FETCH NEXT FROM CUR_Row INTO @n_Rowno
   WHILE @@FETCH_STATUS <> -1
   BEGIN

  DECLARE CUR_Rowno CURSOR LOCAL FAST_FORWARD READ_ONLY 
   FOR
       SELECT SeqNo
             ,ColValue
       FROM   @t_MessageRecsplit
       WHERE RowNo = @n_Rowno
       ORDER BY Seqno
   
   OPEN CUR_Rowno
   
   FETCH NEXT FROM CUR_Rowno INTO @n_SeqNo, @c_ColValue
   WHILE @@FETCH_STATUS <> -1
   BEGIN

   
   UPDATE @t_MessageRecsplit
   SET seqno = (seqno - @n_Maxseqno)
   WHERE seqno = @n_SeqNo
   AND rowno = @n_Rowno

    
  FETCH NEXT FROM CUR_Rowno INTO @n_SeqNo, @c_ColValue
  END

   CLOSE CUR_Rowno
   DEALLOCATE CUR_Rowno

SET @n_Maxseqno = @n_Maxseqno + 4

 
  FETCH NEXT FROM CUR_Row INTO @n_RowNo
  END

   CLOSE CUR_Row
   DEALLOCATE CUR_Row
  
 
 DECLARE @c_SQL       NVARCHAR(4000)
          ,@n_Index     INT
          
   
   SET @n_Index = 1
   SET @c_SQL = ''

INSERT INTO @t_MsgRecSplitResult
SELECT Rowno,
       MAX([seq1]) AS [seq1],
       MAX([seq1Value]) AS [seq1Value],
       MAX([seq2]) AS [seq2],
       MAX([seq2Value]) AS [seq2Value],
       MAX([seq3]) AS [seq3],
       MAX([seq3Value]) AS [seq3Value],    
       MAX([seq4]) AS [seq4],
       MAX([seq4Value]) AS [seq4Value]
FROM (
    SELECT Rowno, 
    CASE Seqno WHEN 1 THEN Seqno END AS [Seq1],
           CASE Seqno WHEN 2 THEN Seqno END AS [Seq2],
           CASE Seqno WHEN 3 THEN Seqno END AS [Seq3],
           CASE Seqno WHEN 4 THEN Seqno END AS [Seq4],
           CASE Seqno WHEN 1 THEN REPLACE(colvalue,'<CR><LF>','')  END AS [seq1Value],
           CASE Seqno WHEN 2 THEN Colvalue END AS [seq2Value],
           CASE Seqno WHEN 3 THEN Colvalue END AS [seq3Value],
           CASE Seqno WHEN 4 THEN Colvalue END AS [seq4Value]
    FROM @t_MessageRecsplit
) T
GROUP BY Rowno

INSERT INTO @tCoreValidFunc
     (
       FuncNo
      ,FuncName
      ,ErrorCode
      ,ErrorMessage)
 SELECT Colvalue1,Colvalue2,Colvalue3,Colvalue4
FROM @t_MsgRecSplitResult

 /*  DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY 
   FOR
       SELECT SeqNo
             ,ColValue
       FROM   @t_MessageRec
       ORDER BY Seqno
   
   OPEN CUR1
   
   FETCH NEXT FROM CUR1 INTO @n_SeqNo, @c_ColValue
   WHILE @@FETCH_STATUS <> -1
   BEGIN
       IF LEFT(@c_ColValue ,1) = '''' AND RIGHT(RTRIM(@c_ColValue) ,1) = ''''
           SET @c_ColValue = SUBSTRING(@c_ColValue ,2 ,LEN(RTRIM(@c_ColValue)) - 2)
       
       IF @n_SeqNo = 1
      --     IF @c_Colvalue like '%<CR><LF>%'
    --       BEGIN
    --       SET @c_ColValue = REPLACE(@c_colvalue,'<CR><LF>','')
    --       END
           SET @c_FuncNo = @c_ColValue
       
       IF @n_SeqNo = 2
           SET @c_FuncName = @c_ColValue
          
       IF @n_SeqNo = 3
           SET @c_ErrorCode = @c_ColValue
       
       IF @n_SeqNo = 4
           SET @c_ErrorMessage = @c_ColValue


       
       FETCH NEXT FROM CUR1 INTO @n_SeqNo, @c_ColValue
   END

INSERT INTO @tCoreValidFunc
     (
       FuncNo
      ,FuncName
      ,ErrorCode
      ,ErrorMessage
     )
   VALUES
     (
       @c_FuncNo
      ,@c_FuncName
      ,@c_ErrorCode
      ,@c_ErrorMessage
     )
   
   CLOSE CUR1
   DEALLOCATE CUR1*/

  
   RETURN
END;

GO