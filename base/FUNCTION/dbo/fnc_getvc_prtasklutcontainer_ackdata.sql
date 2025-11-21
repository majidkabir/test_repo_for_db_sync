SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE FUNCTION [dbo].[fnc_GetVC_prTaskLUTContainer_AckData]  
( @nSerialNo INT )  
RETURNS
@tContainerData TABLE   
        (  
            SysContainerID             NVARCHAR(20) NULL  
           ,ScanContainerValidation    NVARCHAR(20) NULL  
           ,SpokeContainerValidation   NVARCHAR(20) NULL  
           ,AssigmentID                NVARCHAR(20) NULL  
           ,IDDescription              NVARCHAR(60) NULL  
           ,TargetContainer            NVARCHAR(20) NULL  
           ,ContainerStatus            NVARCHAR(5)  NULL  
           ,Printed                    NVARCHAR(1)  NULL  
           ,ErrorCode                  NVARCHAR(20) NULL  
           ,ErrorMessage               NVARCHAR(215) NULL  
        )  
AS  
BEGIN  
   DECLARE @c_Data NVARCHAR(4000)  
    ,@c_SysContainerID             NVARCHAR(20)                             
    ,@c_ScanContainerValidation    NVARCHAR(20)                             
    ,@c_SpokeContainerValidation   NVARCHAR(20)                             
    ,@c_AssigmentID                NVARCHAR(20)                             
    ,@c_IDDescription              NVARCHAR(60)                             
    ,@c_TargetContainer            NVARCHAR(20)                             
    ,@c_ContainerStatus            NVARCHAR(5)                              
    ,@c_Printed                    NVARCHAR(1)                              
    ,@c_ErrorCode                  NVARCHAR(20)                             
    ,@c_ErrorMessage               NVARCHAR(215)    
     
   DECLARE @c_Delim NVARCHAR(10)  
          ,@n_SeqNo INT  
          ,@n_ProcessLast INT 
     
   DECLARE @t_MessageRec TABLE (Seqno INT ,ColValue NVARCHAR(215))    
   DECLARE @n_StartPos  INT  
          ,@n_EndPos    INT  
          ,@c_Parms     NVARCHAR(4000)  
        
   DECLARE @n_Position     INT,   
           @c_RecordLine   INT,  
           @c_LineText     NVARCHAR(2000)  
              
   DECLARE @c_SQL       NVARCHAR(4000)  
          ,@n_Index     INT  
          ,@c_ColValue  NVARCHAR(215)             
     
   DECLARE @t_Container TABLE (RecordLine INT, LineText NVARCHAR(2000))  
        
   SELECT @c_Data = ti.AckData  
   FROM   TCPSocket_INLog ti WITH (NOLOCK)  
   WHERE  ti.SerialNo = @nSerialNo        
     
   SET @c_RecordLine = 1             
   SET @c_Delim = ','  
   SET @n_ProcessLast = 0
      
   SET @n_Position = CHARINDEX('<CR><LF>', @c_Data)      
   WHILE @n_Position <> 0 OR @n_ProcessLast = 1      
   BEGIN      
      IF @c_RecordLine = 1   
         SET @c_LineText = LEFT(@c_Data, @n_Position - 1)  
      ELSE      
         SET @c_LineText = SUBSTRING(@c_Data, 8, @n_Position - 8)  
      
      INSERT INTO @t_MessageRec  
      SELECT *  
      FROM   dbo.fnc_DelimSplit(@c_Delim, @c_LineText)    
     
      SET @n_Index = 1  
      SET @c_SQL = ''  
      DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY   
      FOR  
          SELECT SeqNo ,ColValue  
          FROM   @t_MessageRec  
          ORDER BY Seqno  
     
      OPEN CUR1  
     
      FETCH NEXT FROM CUR1 INTO @n_SeqNo, @c_ColValue  
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
          IF LEFT(@c_ColValue ,1) = ''''  
          AND RIGHT(RTRIM(@c_ColValue) ,1) = ''''  
              SET @c_ColValue = SUBSTRING(@c_ColValue ,2 ,LEN(RTRIM(@c_ColValue)) - 2)  
            
         IF @n_SeqNo = 1  SET @c_SysContainerID           = @c_ColValue  
         IF @n_SeqNo = 2  SET @c_ScanContainerValidation  = @c_ColValue  
         IF @n_SeqNo = 3  SET @c_SpokeContainerValidation = @c_ColValue  
         IF @n_SeqNo = 4  SET @c_AssigmentID              = @c_ColValue  
         IF @n_SeqNo = 5  SET @c_IDDescription            = @c_ColValue  
         IF @n_SeqNo = 6  SET @c_TargetContainer          = @c_ColValue  
         IF @n_SeqNo = 7  SET @c_ContainerStatus          = @c_ColValue  
         IF @n_SeqNo = 8  SET @c_Printed                  = @c_ColValue  
         IF @n_SeqNo = 9  SET @c_ErrorCode                = @c_ColValue  
         IF @n_SeqNo = 10 SET @c_ErrorMessage             = @c_ColValue  
            
            
          FETCH NEXT FROM CUR1 INTO @n_SeqNo, @c_ColValue  
      END  
      INSERT INTO @tContainerData  
      VALUES  
        (  @c_SysContainerID                                      
          ,@c_ScanContainerValidation                             
          ,@c_SpokeContainerValidation                            
          ,@c_AssigmentID                                         
          ,@c_IDDescription                                       
          ,@c_TargetContainer                                     
          ,@c_ContainerStatus                                     
          ,@c_Printed                                             
          ,@c_ErrorCode                                           
          ,@c_ErrorMessage )  
      CLOSE CUR1  
      DEALLOCATE CUR1  
  
      IF @n_ProcessLast = 1
         BREAK
         
      SET @c_Data = STUFF(@c_Data, 1, @n_Position  ,'')  
    
      SET @n_Position = CHARINDEX('<CR><LF>', @c_Data)
            
      IF @n_ProcessLast = 0 AND @n_Position = 0
      BEGIN
         SET @n_ProcessLast = 1
         SET @n_Position = LEN(@c_Data)
      END
               
      SET @c_RecordLine = @c_RecordLine + 1  
   END        
   RETURN  
END;

GO