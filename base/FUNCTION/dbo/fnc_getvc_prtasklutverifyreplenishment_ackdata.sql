SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE FUNCTION [dbo].[fnc_GetVC_prTaskLUTVerifyReplenishment_AckData]
(
   @nSerialNo INT
)
RETURNS @tVerifyReplenishmentTask TABLE 
        (   Replenished    NVARCHAR(1)
           ,ErrorCode      NVARCHAR(10)
           ,[ErrorMessage] NVARCHAR(255) NULL
        )
AS
    
BEGIN
   DECLARE @c_AckData      NVARCHAR(4000)
          ,@c_Replenished  NVARCHAR(20)
          ,@c_ErrorCode    NVARCHAR(10)
          ,@c_ErrorMessage NVARCHAR(60)      
   
   DECLARE @c_Delim CHAR(1), @n_SeqNo INT  
   DECLARE @t_MessageRec TABLE (Seqno INT ,ColValue NVARCHAR(215))    
   
   SET @c_Delim = ','
   
   SELECT @c_AckData = ti.ACKData
   FROM   TCPSocket_INLog ti WITH (NOLOCK)
   WHERE  ti.SerialNo = @nSerialNo    
   
   INSERT INTO @t_MessageRec
   SELECT *
   FROM   dbo.fnc_DelimSplit(@c_Delim ,@c_AckData)  
   
   DECLARE @c_SQL       NVARCHAR(4000)
          ,@n_Index     INT
          ,@c_ColValue  NVARCHAR(215)
   
   SET @n_Index = 1
   SET @c_SQL = ''
   DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY 
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
                 
       IF @n_SeqNo = 1 SET @c_Replenished  = @c_ColValue 
       IF @n_SeqNo = 2 SET @c_ErrorCode    = @c_ColValue       
       IF @n_SeqNo = 3 SET @c_ErrorMessage = @c_ColValue
       
       FETCH NEXT FROM CUR1 INTO @n_SeqNo, @c_ColValue
   END
   INSERT INTO @tVerifyReplenishmentTask
     ( Replenished 
      ,ErrorCode
      ,ErrorMessage
     )
   VALUES
     ( @c_Replenished 
      ,@c_ErrorCode
      ,@c_ErrorMessage
     )
   CLOSE CUR1
   DEALLOCATE CUR1
   
   RETURN
END;

GO