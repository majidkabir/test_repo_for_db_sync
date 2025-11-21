SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE FUNCTION [dbo].[fnc_GetVC_prTaskLUTGetAssignment_AckData]
(
   @nSerialNo INT
)
RETURNS @tGetAssignmentTask TABLE 
        (
       GroupID             NVARCHAR(100)
      ,ChaseAssigment      NVARCHAR(1)
      ,AssigmentID         NVARCHAR(100)
      ,AssigmentIDdescr    NVARCHAR(100)          
      ,Position            NVARCHAR(10)          
      ,GoalTime            NVARCHAR(10)
      ,[Route]             NVARCHAR(100)
      ,TargetContainer     NVARCHAR(2)
      ,PassAssigment       NVARCHAR(1)
      ,PromptType          NVARCHAR(1)
      ,OverridePrompt      NVARCHAR(1000)
      ,ErrorCode          VARCHAR(20) 
      ,ErrorMessage       NVARCHAR(255)
        )
AS
    
BEGIN
   DECLARE @c_AckData            NVARCHAR(4000)
         , @c_GroupID            NVARCHAR(100)
         , @c_ChaseAssigment     NVARCHAR(1)
         , @c_AssigmentID        NVARCHAR(100)
         , @c_AssigmentIDdescr   NVARCHAR(100)         
         , @c_Position           NVARCHAR(10)          
         , @c_GoalTime           NVARCHAR(10)
         , @c_Route              NVARCHAR(100)
         , @c_TargetContainer    NVARCHAR(2)
         , @c_PassAssigment      NVARCHAR(1)
         , @c_PromptType         NVARCHAR(1)
         , @c_OverridePrompt     NVARCHAR(1000)
         , @c_ErrorCode          VARCHAR(20)
          ,@c_ErrorMessage       NVARCHAR(255)     
   
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
       
         IF @n_SeqNo =  1 SET @c_GroupID            = @c_ColValue
         IF @n_Seqno =  2 SET @c_ChaseAssigment     = @c_ColValue
         IF @n_Seqno =  3 SET @c_AssigmentID        = @c_ColValue
         IF @n_Seqno =  4 SET @c_AssigmentIDdescr   = @c_ColValue
         IF @n_Seqno =  5 SET @c_Position           = @c_ColValue
         IF @n_Seqno =  6 SET @c_GoalTime           = @c_ColValue
         IF @n_Seqno =  7 SET @c_Route              = @c_ColValue
         IF @n_Seqno =  8 SET @c_TargetContainer    = @c_ColValue
         IF @n_Seqno =  9 SET @c_PassAssigment      = @c_ColValue
         IF @n_Seqno = 10 SET @c_PromptType         = @c_ColValue
         IF @n_Seqno = 11 SET @c_OverridePrompt     = @c_ColValue
         IF @n_Seqno = 12 SET @c_ErrorCode          = @c_ColValue
         IF @n_Seqno = 13 SET @c_ErrorMessage       = @c_ColValue
       
      FETCH NEXT FROM CUR1 INTO @n_SeqNo, @c_ColValue
   END
   INSERT INTO @tGetAssignmentTask
   (
      GroupID,
      ChaseAssigment,
      AssigmentID,
      AssigmentIDdescr,
      Position,
      GoalTime,
      [Route],
      TargetContainer,
      PassAssigment,
      PromptType,
      OverridePrompt,
      ErrorCode,
      ErrorMessage
   )
   VALUES
   (
       @c_GroupID     
      ,@c_ChaseAssigment              
      ,@c_AssigmentID       
      ,@c_AssigmentIDdescr             
      ,@c_Position                  
      ,@c_GoalTime               
      ,@c_Route             
      ,@c_TargetContainer      
      ,@c_PassAssigment            
      ,@c_PromptType    
      ,@c_OverridePrompt                           
      ,@c_ErrorCode           
      ,@c_ErrorMessage  

   )
   CLOSE CUR1
   DEALLOCATE CUR1
   
   RETURN
END;

GO