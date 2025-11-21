SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE FUNCTION [dbo].[fnc_GetVC_prTaskLUTSendLot_Data]
(
   @nSerialNo INT
)
RETURNS @tSendLotData TABLE 
        (
            TranDate          NVARCHAR(20) NULL
           ,DeviceSerialNo    NVARCHAR(20) NULL
           ,OperatorID        NVARCHAR(20) NULL
           ,Lottable          NVARCHAR(18)  
           ,QtyPicked         INT  
           ,AssignmentID      NVARCHAR(20)  
           ,SeqNo             NVARCHAR(10)                          
        )
AS
    
BEGIN
   DECLARE @c_Data            NVARCHAR(4000)
          ,@c_TranDate        NVARCHAR(20)
          ,@c_DeviceSerialNo  NVARCHAR(20)
          ,@c_OperatorID      NVARCHAR(20) 
          ,@c_Lottable        NVARCHAR(18)    
          ,@n_QtyPicked       INT    
          ,@c_AssignmentID    NVARCHAR(20)    
          ,@c_SeqNo           NVARCHAR(10)     
              
   
   DECLARE @c_Delim CHAR(1), @n_SeqNo INT  
   DECLARE @t_MessageRec TABLE (Seqno INT ,ColValue NVARCHAR(215))  
   DECLARE @n_StartPos INT, @n_EndPos INT ,@c_Parms NVARCHAR(4000)

   
   SET @c_Delim = ','
   
   SELECT @c_Data = ti.Data
   FROM   TCPSocket_INLog ti WITH (NOLOCK)
   WHERE  ti.SerialNo = @nSerialNo    

SET @n_StartPos = CHARINDEX('(', @c_Data) 
SET @n_EndPos = CHARINDEX(')', @c_Data) 

SET @c_Parms = REPLACE(SUBSTRING(@c_Data, @n_StartPos + 1, (@n_EndPos - @n_StartPos) -1) ,'''','') 

   INSERT INTO @t_MessageRec
   SELECT *
   FROM   dbo.fnc_DelimSplit(@c_Delim ,@c_Parms)  
   
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
       
       IF @n_SeqNo = 1  SET @c_TranDate        = @c_ColValue
       IF @n_SeqNo = 2  SET @c_DeviceSerialNo  = @c_ColValue
       IF @n_SeqNo = 3  SET @c_OperatorID      = @c_ColValue 
       IF @n_SeqNo = 4  SET @c_Lottable        = @c_ColValue
       IF @n_SeqNo = 5  SET @n_QtyPicked       = @c_ColValue
       IF @n_SeqNo = 6  SET @c_AssignmentID    = @c_ColValue 
       IF @n_SeqNo = 7  SET @c_SeqNo           = @c_ColValue
                    
             
  FETCH NEXT FROM CUR1 INTO @n_SeqNo, @c_ColValue
   END
   INSERT INTO @tSendLotData
     (
       TranDate
      ,DeviceSerialNo
      ,OperatorID
      ,Lottable
      ,QtyPicked
      ,AssignmentID
      ,SeqNo
     )
   VALUES
     (
       @c_TranDate
      ,@c_DeviceSerialNo
      ,@c_OperatorID 
      ,@c_Lottable
      ,@n_QtyPicked  
      ,@c_AssignmentID
      ,@c_SeqNo
     )
   CLOSE CUR1
   DEALLOCATE CUR1
   
   RETURN
END;

GO