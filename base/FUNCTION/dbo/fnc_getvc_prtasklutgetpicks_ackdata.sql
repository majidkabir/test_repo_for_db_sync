SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE FUNCTION [dbo].[fnc_GetVC_prTaskLUTGetPicks_AckData]      
(      
@nSerialNo INT      
)      
RETURNS @tPickTask TABLE       
        (      
            [Status] NVARCHAR(1) NULL      
           ,[BaseItem] NVARCHAR(1) NULL      
           ,SeqNo NVARCHAR(10) NULL      
           ,LOC NVARCHAR(10) NULL      
           ,Region NVARCHAR(5) NULL      
           ,PreAisleDirection NVARCHAR(50) NULL      
           ,[Aisle] NVARCHAR(20) NULL      
           ,[PostAisleDirection] NVARCHAR(50) NULL      
           ,[Slot] NVARCHAR(10) NULL      
           ,[QtyToPick] NVARCHAR(10) NULL      
           ,[UOM] NVARCHAR(20) NULL      
           ,[SKU] NVARCHAR(20) NULL      
           ,[VariableWeight] NVARCHAR(20) NULL      
           ,[VariableWgtMin] NVARCHAR(20) NULL      
           ,[VariableWgtMax] NVARCHAR(20) NULL      
           ,[QtyPicked] NVARCHAR(20) NULL      
           ,[CheckDigit] NVARCHAR(20) NULL      
           ,[ScanSKU] NVARCHAR(20) NULL      
           ,[SpokeSKU] NVARCHAR(20) NULL      
           ,[SKUdesc] NVARCHAR(20) NULL      
           ,[Size] NVARCHAR(20) NULL      
           ,[UPC] NVARCHAR(20) NULL      
           ,[AssignmentID] NVARCHAR(20) NULL      
           ,[AssgnIDDesc] NVARCHAR(20) NULL      
           ,[DeliveryLoc] NVARCHAR(20) NULL      
           ,[CombineFlag] NVARCHAR(20) NULL      
           ,[Store] NVARCHAR(100) NULL      
           ,[CaseLabelChkDigit] NVARCHAR(20) NULL      
           ,[TargetContainer] NVARCHAR(20) NULL      
           ,[CaptureLot] NVARCHAR(20) NULL      
           ,[LotText] NVARCHAR(20) NULL      
           ,[PickMessage] NVARCHAR(250) NULL      
           ,[VerifyLoc] NVARCHAR(1) NULL      
           ,[CycleCount] NVARCHAR(20) NULL      
           ,[CaptureSerialNo] CHAR(1) NULL      
           ,[SpeakSKUDesc] CHAR(1) NULL      
           ,[ErrorCode] NVARCHAR(10) NULL      
           ,[ErrorMessage] NVARCHAR(60) NULL      
        )      
AS             
BEGIN      
       
   DECLARE @c_AckData NVARCHAR(4000)      
          ,@c_Status NVARCHAR(1)      
          ,@c_BaseItem NVARCHAR(1)      
          ,@c_SeqNo NVARCHAR(10)      
          ,@c_LOC NVARCHAR(10)      
          ,@c_Region NVARCHAR(5)      
          ,@c_PreAisleDirection NVARCHAR(50)      
          ,@c_Aisle NVARCHAR(20)      
          ,@c_PostAisleDirection NVARCHAR(50)      
          ,@c_Slot NVARCHAR(10)      
          ,@c_QtyToPick NVARCHAR(10)      
          ,@c_UOM NVARCHAR(20)      
          ,@c_SKU NVARCHAR(20)      
          ,@c_VariableWeight NVARCHAR(20)      
          ,@c_VariableWgtMin NVARCHAR(20)      
          ,@c_VariableWgtMax NVARCHAR(20)      
          ,@c_QtyPicked NVARCHAR(20)      
          ,@c_CheckDigit NVARCHAR(20)      
          ,@c_ScanSKU NVARCHAR(20)      
          ,@c_SpokeSKU NVARCHAR(20)      
          ,@c_SKUdesc NVARCHAR(20)      
          ,@c_Size NVARCHAR(20)      
          ,@c_UPC NVARCHAR(20)      
          ,@c_AssignmentID NVARCHAR(20)      
          ,@c_AssgnIDDesc NVARCHAR(20)      
          ,@c_DeliveryLoc NVARCHAR(20)      
          ,@c_CombineFlag NVARCHAR(20)      
          ,@c_Store NVARCHAR(100)      
          ,@c_CaseLabelChkDigit NVARCHAR(20)      
          ,@c_TargetContainer NVARCHAR(20)      
          ,@c_CaptureLot NVARCHAR(20)      
          ,@c_LotText NVARCHAR(20)      
          ,@c_PickMessage NVARCHAR(250)      
          ,@c_VerifyLoc NVARCHAR(1)      
          ,@c_CycleCount NVARCHAR(20)      
          ,@c_CaptureSerialNo CHAR(1)      
          ,@c_SpeakSKUDesc CHAR(1)      
          ,@c_ErrorCode NVARCHAR(10)      
          ,@c_ErrorMessage NVARCHAR(60)        
                   
       
                 
         
   SELECT @c_AckData = ti.ACKData      
   FROM   TCPSocket_INLog ti WITH (NOLOCK)      
   WHERE  ti.SerialNo = @nSerialNo          
         
       
       
   DECLARE @n_Position   INT    
         , @c_RecordLine NVARCHAR(512)    
         , @c_Delimited  CHAR(4)    
         , @c_LineText   NVARCHAR(512)    
         , @n_SeqNo      INT             , @c_ColValue   NVARCHAR(512)      
         , @n_Count      INT    
    
   DECLARE @t_Delimieter TABLE (SeqNo INT IDENTITY(1,1), LineText NVARCHAR(512))    
   DECLARE @t_MessageRec TABLE (SeqNo INT, LineText NVARCHAR(512))    
    
   SET @c_Delimited = N','    
     
   SET @c_AckData = @c_AckData + CHAR(13)    
       
   SET @n_Position = CHARINDEX(N'<CR><LF>', @c_AckData)    
   WHILE @n_Position <> 0    
   BEGIN     
       SET @c_RecordLine = LEFT(@c_AckData, @n_Position - 1)    
           
       INSERT INTO @t_Delimieter     
       VALUES(CAST(@c_RecordLine AS NVARCHAR(MAX)))    
    
       SET @c_AckData = SUBSTRING(@c_AckData, @n_Position + 8, LEN(@c_AckData) - (@n_Position + 7 ))   
       SET @n_Position = CHARINDEX(N'<CR><LF>', @c_AckData)    
   END     
   SET @n_Count = 0    
   SELECT @n_Count = Count(LineText) FROM @t_Delimieter    
        
   INSERT INTO @t_Delimieter     
   VALUES (CAST(@c_AckData AS NVARCHAR(MAX)))     
       
   DECLARE CUR_LINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
       
   SELECT LineText FROM @t_Delimieter ORDER BY SeqNo    
    
   OPEN CUR_LINE    
    
   FETCH NEXT FROM CUR_LINE INTO @c_LineText    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
       
      INSERT INTO @t_MessageRec      
      SELECT * FROM   dbo.fnc_DelimSplit(N',' ,@c_LineText)      
          
      DECLARE CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY       
      FOR      
          SELECT SeqNo      
                ,LineText      
          FROM   @t_MessageRec      
          ORDER BY Seqno      
            
      OPEN CUR1      
            
      FETCH NEXT FROM CUR1 INTO @n_SeqNo, @c_ColValue      
      WHILE @@FETCH_STATUS <> -1      
      BEGIN      
              
          IF LEFT(@c_ColValue ,1) = '''' AND RIGHT(RTRIM(@c_ColValue) ,1) = ''''      
              SET @c_ColValue = SUBSTRING(@c_ColValue ,2 ,LEN(RTRIM(@c_ColValue)) - 2)      
                
          IF @n_SeqNo = 1      
              SET @c_Status = @c_ColValue      
                
          IF @n_SeqNo = 2      
              SET @c_BaseItem = @c_ColValue      
                
          IF @n_SeqNo = 3      
              SET @c_SeqNo = @c_ColValue      
                
          IF @n_SeqNo = 4      
              SET @c_LOC = @c_ColValue      
                
          IF @n_SeqNo = 5      
              SET @c_Region = @c_ColValue      
                
          IF @n_SeqNo = 6      
              SET @c_PreAisleDirection = @c_ColValue      
                
          IF @n_SeqNo = 7      
              SET @c_Aisle = @c_ColValue      
                
          IF @n_SeqNo = 8      
              SET @c_PostAisleDirection = @c_ColValue      
                
          IF @n_SeqNo = 9      
              SET @c_Slot = @c_ColValue      
                
          IF @n_SeqNo = 10      
              SET @c_QtyToPick = @c_ColValue      
                
          IF @n_SeqNo = 11      
              SET @c_UOM = @c_ColValue      
                
          IF @n_SeqNo = 12      
              SET @c_SKU = @c_ColValue      
                
          IF @n_SeqNo = 13      
              SET @c_VariableWeight = @c_ColValue      
                
          IF @n_SeqNo = 14      
              SET @c_VariableWgtMin = @c_ColValue      
                
          IF @n_SeqNo = 15      
              SET @c_VariableWgtMax = @c_ColValue      
                
          IF @n_SeqNo = 16      
              SET @c_QtyPicked = @c_ColValue      
                
          IF @n_SeqNo = 17      
              SET @c_CheckDigit = @c_ColValue      
                
          IF @n_SeqNo = 18      
              SET @c_ScanSKU = @c_ColValue      
                
          IF @n_SeqNo = 19      
              SET @c_SpokeSKU = @c_ColValue      
                
          IF @n_SeqNo = 20      
              SET @c_SKUdesc = @c_ColValue      
                
          IF @n_SeqNo = 21      
              SET @c_Size = @c_ColValue      
                
          IF @n_SeqNo = 22      
              SET @c_UPC = @c_ColValue      
           
          IF @n_SeqNo = 23      
              SET @c_AssignmentID = @c_ColValue      
                
          IF @n_SeqNo = 24      
              SET @c_AssgnIDDesc = @c_ColValue      
                
          IF @n_SeqNo = 25      
              SET @c_DeliveryLoc = @c_ColValue      
                
          IF @n_SeqNo = 26      
         SET @c_CombineFlag = @c_ColValue      
                
          IF @n_SeqNo = 27      
              SET @c_Store = @c_ColValue      
                
          IF @n_SeqNo = 28      
              SET @c_CaseLabelChkDigit = @c_ColValue      
                
          IF @n_SeqNo = 29      
              SET @c_TargetContainer = @c_ColValue      
                
          IF @n_SeqNo = 30      
              SET @c_CaptureLot = @c_ColValue      
                
          IF @n_SeqNo = 31      
              SET @c_LotText = @c_ColValue      
                
          IF @n_SeqNo = 32      
              SET @c_PickMessage = @c_ColValue      
                
          IF @n_SeqNo = 33      
              SET @c_VerifyLoc = @c_ColValue      
                
          IF @n_SeqNo = 34      
              SET @c_CycleCount = @c_ColValue      
                
          IF @n_SeqNo = 35      
              SET @c_CaptureSerialNo = @c_ColValue      
                
          IF @n_SeqNo = 36      
              SET @c_SpeakSKUDesc = @c_ColValue      
                
          IF @n_SeqNo = 37      
              SET @c_ErrorCode = @c_ColValue      
                
          IF @n_SeqNo = 38      
              SET @c_ErrorMessage = @c_ColValue      
                
            FETCH NEXT FROM CUR1 INTO @n_SeqNo, @c_ColValue      
      END      
      CLOSE CUR1    
      DEALLOCATE CUR1    
              
      INSERT INTO @tPickTask      
      (      
       [Status]      
      ,BaseItem      
      ,SeqNo      
      ,LOC      
      ,Region      
      ,PreAisleDirection      
      ,Aisle      
      ,PostAisleDirection      
      ,Slot      
      ,QtyToPick      
      ,UOM      
      ,SKU      
      ,VariableWeight      
      ,VariableWgtMin      
      ,VariableWgtMax      
      ,QtyPicked      
      ,CheckDigit      
      ,ScanSKU      
      ,SpokeSKU      
      ,SKUdesc      
      ,[Size]      
      ,UPC      
      ,AssignmentID      
      ,AssgnIDDesc      
      ,DeliveryLoc      
      ,CombineFlag      
      ,Store      
      ,CaseLabelChkDigit      
      ,TargetContainer      
      ,CaptureLot      
      ,LotText      
      ,PickMessage      
      ,VerifyLoc      
      ,CycleCount      
      ,CaptureSerialNo      
      ,SpeakSKUDesc      
      ,ErrorCode      
      ,ErrorMessage      
     )      
     VALUES      
     (      
       @c_Status      
      ,@c_BaseItem      
      ,@c_SeqNo      
      ,@c_LOC      
      ,@c_Region      
      ,@c_PreAisleDirection      
      ,@c_Aisle      
      ,@c_PostAisleDirection      
      ,@c_Slot      
      ,@c_QtyToPick      
      ,@c_UOM      
      ,@c_SKU      
      ,@c_VariableWeight      
      ,@c_VariableWgtMin      
      ,@c_VariableWgtMax      
      ,@c_QtyPicked      
      ,@c_CheckDigit      
      ,@c_ScanSKU      
      ,@c_SpokeSKU      
      ,@c_SKUdesc      
      ,@c_Size      
      ,@c_UPC      
      ,@c_AssignmentID      
      ,@c_AssgnIDDesc      
      ,@c_DeliveryLoc      
      ,@c_CombineFlag      
      ,@c_Store      
      ,@c_CaseLabelChkDigit      
      ,@c_TargetContainer      
      ,@c_CaptureLot      
      ,@c_LotText      
      ,@c_PickMessage      
      ,@c_VerifyLoc      
      ,@c_CycleCount      
      ,@c_CaptureSerialNo      
      ,@c_SpeakSKUDesc      
      ,@c_ErrorCode      
      ,@c_ErrorMessage      
     )      
         
     DELETE @t_MessageRec    
     FETCH NEXT FROM CUR_LINE INTO @c_LineText    
   END    
   CLOSE CUR_LINE    
   DEALLOCATE CUR_LINE    
       
   --SELECT * FROM @tPickTask    
        
 RETURN      
END;

GO