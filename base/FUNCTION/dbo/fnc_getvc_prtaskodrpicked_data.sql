SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE FUNCTION [dbo].[fnc_GetVC_prTaskODRPicked_Data]
(
   @nSerialNo INT
)
RETURNS @tORDPickedData TABLE 
        (
            TranDate          NVARCHAR(20) NULL
           ,DeviceSerialNo    NVARCHAR(20) NULL
           ,OperatorID        NVARCHAR(20) NULL
           ,TaskDetailKey     NVARCHAR(20) NULL 
           ,AssignmentID      NVARCHAR(20) NULL 
           ,Loc               NVARCHAR(10) NULL
           ,QtyPicked         INT  
           ,PickStatus        NVARCHAR(10) NULL
           ,CartonID          NVARCHAR(20) NULL 
           ,Sequence          NVARCHAR(10) NULL
           ,BatchNo           NVARCHAR(20) NULL
           ,VariableWeight    NVARCHAR(20) NULL
           ,SerialNoCapt      NVARCHAR(20) NULL                           
        )
AS
    
BEGIN
   DECLARE @c_Data            NVARCHAR(4000)
          ,@c_TranDate        NVARCHAR(20)
          ,@c_DeviceSerialNo  NVARCHAR(20)
          ,@c_OperatorID      NVARCHAR(20) 
          ,@c_TaskDetailKey   NVARCHAR(20)  
          ,@c_AssignmentID    NVARCHAR(20)  
          ,@c_Loc             NVARCHAR(10)  
          ,@n_QtyPicked       INT  
          ,@c_PickStatus      NVARCHAR(10)  
          ,@c_CartonID        NVARCHAR(20)  
          ,@c_Sequence        NVARCHAR(10)  
          ,@c_BatchNo         NVARCHAR(20)  
          ,@c_VariableWeight  NVARCHAR(20)  
          ,@c_SerialNoCapt    NVARCHAR(20)     
              
   
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
       IF @n_SeqNo = 4  SET @c_TaskDetailKey   = @c_ColValue
       IF @n_SeqNo = 5  SET @c_AssignmentID    = @c_ColValue
       IF @n_SeqNo = 6  SET @c_Loc             = @c_ColValue 
       IF @n_SeqNo = 7  SET @n_QtyPicked       = @c_ColValue
       IF @n_SeqNo = 8  SET @c_PickStatus      = @c_ColValue
       IF @n_SeqNo = 9  SET @c_CartonID        = @c_ColValue 
       IF @n_SeqNo = 10 SET @c_Sequence        = @c_ColValue 
       IF @n_SeqNo = 11 SET @c_BatchNo         = @c_ColValue
       IF @n_SeqNo = 12 SET @c_VariableWeight  = @c_ColValue
       IF @n_SeqNo = 13 SET @c_SerialNoCapt    = @c_ColValue 
             
             
  FETCH NEXT FROM CUR1 INTO @n_SeqNo, @c_ColValue
   END
   INSERT INTO @tORDPickedData
     (
       TranDate
      ,DeviceSerialNo
      ,OperatorID
      ,TaskDetailKey
      ,AssignmentID
      ,Loc
      ,QtyPicked
      ,PickStatus
      ,CartonID
      ,Sequence
      ,BatchNo
      ,VariableWeight
      ,SerialNoCapt 
     )
   VALUES
     (
       @c_TranDate
      ,@c_DeviceSerialNo
      ,@c_OperatorID 
      ,@c_TaskDetailKey 
      ,@c_AssignmentID  
      ,@c_Loc
      ,@n_QtyPicked
      ,@c_PickStatus
      ,@c_CartonID
      ,@c_Sequence
      ,@c_BatchNo
      ,@c_VariableWeight 
      ,@c_SerialNoCapt
     )
   CLOSE CUR1
   DEALLOCATE CUR1
   
   RETURN
END;

GO