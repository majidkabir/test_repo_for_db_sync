SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE FUNCTION [dbo].[fnc_GetVC_prTaskLUTForkGetReplenishment_AckData]
(
   @nSerialNo INT
)
RETURNS @tReplenishmentTask TABLE 
        (
       ReplenishmentKey   NVARCHAR(10)
      ,LPNumber           NVARCHAR(18)
      ,ReqSpecificLPN     NVARCHAR(1)
      ,RegionNo           NVARCHAR(5)  -- Operator╬ô├ç├┐s response to picking region prompt.         
      ,SKU                NVARCHAR(20)          
      ,SKUDesc            NVARCHAR(60)
      ,QtyReplen          NVARCHAR(10)
      ,FromPreAisleDrtn   NVARCHAR(50)
      ,FromAisle          NVARCHAR(100)
      ,FromPostAisleDrtn  NVARCHAR(50)
      ,FromSlot           NVARCHAR(100)
      ,FromCheckDigit     NVARCHAR(2)
      ,FromScanValidate   NVARCHAR(100)
      ,ToPreAisleDrtn     NVARCHAR(50)
      ,ToAisle            NVARCHAR(100)
      ,ToPostAisleDrtn    NVARCHAR(50)
      ,ToSlot             NVARCHAR(100)
      ,ToCheckDigit       NVARCHAR(2)
      ,ToScanValidate     NVARCHAR(100)
      ,ToLOC              NVARCHAR(100)
      ,GoalTime           NVARCHAR(10)
      ,ErrorCode          VARCHAR(20) 
        )
AS
    
BEGIN
   DECLARE @c_AckData NVARCHAR(4000)
         , @c_ReplenishmentKey   NVARCHAR(10)
         , @c_LPNumber           NVARCHAR(18)
         , @c_ReqSpecificLPN     NVARCHAR(1)
         , @c_RegionNo           NVARCHAR(5)  -- Operator╬ô├ç├┐s response to picking region prompt.         
         , @c_SKU                NVARCHAR(20)          
         , @c_SKUDesc            NVARCHAR(60)
         , @c_QtyReplen          NVARCHAR(10)
         , @c_FromPreAisleDrtn   NVARCHAR(50)
         , @c_FromAisle          NVARCHAR(100)
         , @c_FromPostAisleDrtn  NVARCHAR(50)
         , @c_FromSlot           NVARCHAR(100)
         , @c_FromCheckDigit     NVARCHAR(2)
         , @c_FromScanValidate   NVARCHAR(100)
         , @c_ToPreAisleDrtn     NVARCHAR(50)
         , @c_ToAisle            NVARCHAR(100)
         , @c_ToPostAisleDrtn    NVARCHAR(50)
         , @c_ToSlot             NVARCHAR(100)
         , @c_ToCheckDigit       NVARCHAR(2)
         , @c_ToScanValidate     NVARCHAR(100)
         , @c_ToLOC              NVARCHAR(100)
         , @c_GoalTime           NVARCHAR(10)
         , @c_ErrorCode          VARCHAR(20)      
   
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
       
         IF @n_SeqNo =  1 SET @c_ReplenishmentKey  = @c_ColValue
         IF @n_Seqno =  2 SET @c_LPNumber          = @c_ColValue
         IF @n_Seqno =  3 SET @c_ReqSpecificLPN    = @c_ColValue
         IF @n_Seqno =  4 SET @c_RegionNo          = @c_ColValue
         IF @n_Seqno =  5 SET @c_SKU               = @c_ColValue
         IF @n_Seqno =  6 SET @c_SKUDesc           = @c_ColValue
         IF @n_Seqno =  7 SET @c_QtyReplen         = @c_ColValue
         IF @n_Seqno =  8 SET @c_FromPreAisleDrtn  = @c_ColValue
         IF @n_Seqno =  9 SET @c_FromAisle         = @c_ColValue
         IF @n_Seqno = 10 SET @c_FromPostAisleDrtn = @c_ColValue
         IF @n_Seqno = 11 SET @c_FromSlot          = @c_ColValue
         IF @n_Seqno = 12 SET @c_FromCheckDigit    = @c_ColValue
         IF @n_Seqno = 13 SET @c_FromScanValidate  = @c_ColValue
         IF @n_Seqno = 14 SET @c_ToPreAisleDrtn    = @c_ColValue
         IF @n_Seqno = 15 SET @c_ToAisle           = @c_ColValue
         IF @n_Seqno = 16 SET @c_ToPostAisleDrtn   = @c_ColValue
         IF @n_Seqno = 17 SET @c_ToSlot            = @c_ColValue
         IF @n_Seqno = 18 SET @c_ToCheckDigit      = @c_ColValue
         IF @n_Seqno = 19 SET @c_ToScanValidate    = @c_ColValue
         IF @n_Seqno = 20 SET @c_ToLOC             = @c_ColValue
         IF @n_Seqno = 21 SET @c_GoalTime          = @c_ColValue
         IF @n_Seqno = 22 SET @c_ErrorCode         = @c_ColValue
       
      FETCH NEXT FROM CUR1 INTO @n_SeqNo, @c_ColValue
   END
   INSERT INTO @tReplenishmentTask
   (
      ReplenishmentKey,
      LPNumber,
      ReqSpecificLPN,
      RegionNo,
      SKU,
      SKUDesc,
      QtyReplen,
      FromPreAisleDrtn,
      FromAisle,
      FromPostAisleDrtn,
      FromSlot,
      FromCheckDigit,
      FromScanValidate,
      ToPreAisleDrtn,
      ToAisle,
      ToPostAisleDrtn,
      ToSlot,
      ToCheckDigit,
      ToScanValidate,
      ToLOC,
      GoalTime,
      ErrorCode
   )
   VALUES
   (
       @c_ReplenishmentKey      
      ,@c_LPNumber              
      ,@c_ReqSpecificLPN        
      ,@c_RegionNo              
      ,@c_SKU                   
      ,@c_SKUDesc               
      ,@c_QtyReplen             
      ,@c_FromPreAisleDrtn      
      ,@c_FromAisle             
      ,@c_FromPostAisleDrtn     
      ,@c_FromSlot              
      ,@c_FromCheckDigit        
      ,@c_FromScanValidate      
      ,@c_ToPreAisleDrtn        
      ,@c_ToAisle               
      ,@c_ToPostAisleDrtn       
      ,@c_ToSlot                
      ,@c_ToCheckDigit          
      ,@c_ToScanValidate        
      ,@c_ToLOC                 
      ,@c_GoalTime              
      ,@c_ErrorCode             

   )
   CLOSE CUR1
   DEALLOCATE CUR1
   
   RETURN
END;

GO